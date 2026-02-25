package main

import "base:runtime"
import "core:sync"

AudioGraphEngineContext :: struct {
	sample_rate: u32,
	render_quantum: u64,
	buffer_size: u32,
	output_channel_count: u32,
}

AudioNodeProcessProc :: #type proc(
	graph: ^AudioGraph,
	node: ^AudioNode,
	engine_context: AudioGraphEngineContext,
	frame_buffer: ^[]f32,
	frame_buffer_size: int,
)

ModulationInput :: struct {
	has_source: bool,
	source_node_id: u64,
	source_output_index: int,
	apply: proc(input: ^ModulationInput, node: ^AudioNode, sample_buffer: []f32, frame_buffer_size: int),
	user_data: rawptr,
	buffer: []f32,
}

GraphNodeInput :: struct {
	has_source: bool,
	source_node_id: u64,
	source_output_index: int,
}

GraphNodeOutputTarget :: struct {
	target_node_id: u64,
	target_input_index: int,
}

GraphNodeOutput :: struct {
	targets: [dynamic]GraphNodeOutputTarget,
}

AudioNode :: struct {
	id: u64,
	name: string,

	inputs: [dynamic]GraphNodeInput,
	modulation_inputs: [dynamic]ModulationInput,
	outputs: [dynamic]GraphNodeOutput,

	// Interleaved f32 cache per output bus. The node's process callback owns writing to these.
	output_cache: [dynamic][]f32,
	mixed_input_cache: []f32,

	process: AudioNodeProcessProc,
	user_data: rawptr,

	// Per-callback cache guard.
	last_render_quantum: u64,
	has_processed_quantum: bool,
}

GraphMutationKind :: enum {
	AddNode,
	RemoveNode,
	Connect,
	Disconnect,
	SetRoot,
}

GraphMutation :: struct {
	kind: GraphMutationKind,

	node: ^AudioNode,
	node_id: u64,

	source_node_id: u64,
	source_output_index: int,
	target_node_id: u64,
	target_input_index: int,

	root_enabled: bool,
}

AudioGraph :: struct {
	allocator: runtime.Allocator,

	nodes: map[u64]^AudioNode,
	endpoint_node_id: u64,
	root_node_ids: [dynamic]u64,
	render_order: [dynamic]^AudioNode,

	pending_mutations: [dynamic]GraphMutation,

	dirty: bool,
	engine_dirty: bool,
	processing: bool,
	next_node_id: u64,
	cached_frame_buffer_size: int,
	cached_output_channel_count: int,
	lock: sync.Mutex,

	init: proc(g: ^AudioGraph),
	uninit: proc(g: ^AudioGraph),

	queueAddNode: proc(g: ^AudioGraph, name: string, input_count: int, output_count: int, process: AudioNodeProcessProc, user_data: rawptr = nil, modulation_input_count: int = 0) -> u64,
	setModulationInputProcessor: proc(g: ^AudioGraph, node_id: u64, modulation_input_index: int, apply: proc(input: ^ModulationInput, node: ^AudioNode, sample_buffer: []f32, frame_buffer_size: int), user_data: rawptr = nil),
	getModulationInputTargetIndex: proc(g: ^AudioGraph, node_id: u64, modulation_input_index: int) -> (int, bool),
	queueRemoveNode: proc(g: ^AudioGraph, node_id: u64),
	queueConnect: proc(g: ^AudioGraph, source_node_id: u64, source_output_index: int, target_node_id: u64, target_input_index: int),
	connectModulationInput: proc(g: ^AudioGraph, node_id: u64, modulation_input_index: int, source_node_id: u64, source_output_index: int = 0) -> bool,
	connectToEndpoint: proc(g: ^AudioGraph, source_node_id: u64, source_output_index: int = 0),
	queueDisconnect: proc(g: ^AudioGraph, target_node_id: u64, target_input_index: int),
	queueSetRoot: proc(g: ^AudioGraph, node_id: u64, enabled: bool),
	markEngineDirty: proc(g: ^AudioGraph),

	beginRenderCycle: proc(g: ^AudioGraph, render_quantum: u64),
	process: proc(g: ^AudioGraph, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int),

	getRenderOrder: proc(g: ^AudioGraph) -> []^AudioNode,
	getNode: proc(g: ^AudioGraph, node_id: u64) -> (^AudioNode, bool),
	getEndpointNodeId: proc(g: ^AudioGraph) -> u64,
	ensureOutputBuffer: proc(g: ^AudioGraph, node: ^AudioNode, output_index: int, sample_count: int) -> []f32,
}

createAudioGraph :: proc(allocator := context.allocator) -> ^AudioGraph {
	g := new(AudioGraph)
	g.allocator = allocator
	g.init = audioGraphInit
	g.uninit = audioGraphUninit
	g.queueAddNode = audioGraphQueueAddNode
	g.setModulationInputProcessor = audioGraphSetModulationInputProcessor
	g.getModulationInputTargetIndex = audioGraphGetModulationInputTargetIndex
	g.queueRemoveNode = audioGraphQueueRemoveNode
	g.queueConnect = audioGraphQueueConnect
	g.connectModulationInput = audioGraphConnectModulationInput
	g.connectToEndpoint = audioGraphConnectToEndpoint
	g.queueDisconnect = audioGraphQueueDisconnect
	g.queueSetRoot = audioGraphQueueSetRoot
	g.markEngineDirty = audioGraphMarkEngineDirty
	g.beginRenderCycle = audioGraphBeginRenderCycle
	g.process = audioGraphProcess
	g.getRenderOrder = audioGraphGetRenderOrder
	g.getNode = audioGraphGetNode
	g.getEndpointNodeId = audioGraphGetEndpointNodeId
	g.ensureOutputBuffer = audioGraphEnsureOutputBuffer
	g.init(g)
	return g
}

audioGraphInit :: proc(g: ^AudioGraph) {
	g.nodes = make(map[u64]^AudioNode)
	g.root_node_ids = make([dynamic]u64, 0, 8, g.allocator)
	g.render_order = make([dynamic]^AudioNode, 0, 16, g.allocator)
	g.pending_mutations = make([dynamic]GraphMutation, 0, 32, g.allocator)
	g.dirty = true
	g.engine_dirty = true
	g.next_node_id = 1

	endpoint_id := g.next_node_id
	g.next_node_id += 1

	endpoint := graphNodeCreate(endpoint_id, "graph_endpoint", 1, 1, graphEndpointProcess, nil, 0, g.allocator)
	g.nodes[endpoint_id] = endpoint
	g.endpoint_node_id = endpoint_id
	append(&g.root_node_ids, endpoint_id)
}

audioGraphUninit :: proc(g: ^AudioGraph) {
	sync.mutex_lock(&g.lock)
	for _, node in g.nodes {
		graphNodeDestroy(node, g.allocator)
	}
	delete(g.nodes)
	delete(g.root_node_ids)
	delete(g.render_order)
	delete(g.pending_mutations)
	g^ = AudioGraph{}
	sync.mutex_unlock(&g.lock)
}

audioGraphQueueAddNode :: proc(g: ^AudioGraph, name: string, input_count: int, output_count: int, process: AudioNodeProcessProc, user_data: rawptr = nil, modulation_input_count: int = 0) -> u64 {
	in_count := input_count
	out_count := output_count
	mod_count := modulation_input_count

	if in_count < 0 {
		in_count = 0
	}
	if out_count < 0 {
		out_count = 0
	}
	if mod_count < 0 {
		mod_count = 0
	}

	sync.mutex_lock(&g.lock)

	node_id := g.next_node_id
	g.next_node_id += 1

	node := graphNodeCreate(node_id, name, in_count, out_count, process, user_data, mod_count, g.allocator)
	append(&g.pending_mutations, GraphMutation{kind = .AddNode, node = node, node_id = node_id})
	g.dirty = true
	g.engine_dirty = true

	sync.mutex_unlock(&g.lock)
	return node_id
}

audioGraphSetModulationInputProcessor :: proc(g: ^AudioGraph, node_id: u64, modulation_input_index: int, apply: proc(input: ^ModulationInput, node: ^AudioNode, sample_buffer: []f32, frame_buffer_size: int), user_data: rawptr = nil) {
	sync.mutex_lock(&g.lock)
	node: ^AudioNode = nil
	if existing, ok := g.nodes[node_id]; ok {
		node = existing
	} else {
		for i := len(g.pending_mutations) - 1; i >= 0; i -= 1 {
			mutation := g.pending_mutations[i]
			if mutation.kind == .AddNode && mutation.node_id == node_id {
				node = mutation.node
				break
			}
		}
	}

	if node == nil || modulation_input_index < 0 || modulation_input_index >= len(node.modulation_inputs) {
		sync.mutex_unlock(&g.lock)
		return
	}
	node.modulation_inputs[modulation_input_index].apply = apply
	node.modulation_inputs[modulation_input_index].user_data = user_data
	sync.mutex_unlock(&g.lock)
}

audioGraphGetModulationInputTargetIndex :: proc(g: ^AudioGraph, node_id: u64, modulation_input_index: int) -> (int, bool) {
	sync.mutex_lock(&g.lock)
	node: ^AudioNode = nil
	if existing, ok := g.nodes[node_id]; ok {
		node = existing
	} else {
		for i := len(g.pending_mutations) - 1; i >= 0; i -= 1 {
			mutation := g.pending_mutations[i]
			if mutation.kind == .AddNode && mutation.node_id == node_id {
				node = mutation.node
				break
			}
		}
	}
	sync.mutex_unlock(&g.lock)

	if node == nil {
		return 0, false
	}
	if modulation_input_index < 0 || modulation_input_index >= len(node.modulation_inputs) {
		return 0, false
	}
	return len(node.inputs) + modulation_input_index, true
}

audioGraphQueueRemoveNode :: proc(g: ^AudioGraph, node_id: u64) {
	if node_id == g.endpoint_node_id {
		return
	}
	sync.mutex_lock(&g.lock)
	append(&g.pending_mutations, GraphMutation{kind = .RemoveNode, node_id = node_id})
	g.dirty = true
	sync.mutex_unlock(&g.lock)
}

audioGraphQueueConnect :: proc(g: ^AudioGraph, source_node_id: u64, source_output_index: int, target_node_id: u64, target_input_index: int) {
	sync.mutex_lock(&g.lock)
	append(&g.pending_mutations, GraphMutation{
		kind = .Connect,
		source_node_id = source_node_id,
		source_output_index = source_output_index,
		target_node_id = target_node_id,
		target_input_index = target_input_index,
	})
	g.dirty = true
	sync.mutex_unlock(&g.lock)
}

audioGraphConnectModulationInput :: proc(g: ^AudioGraph, node_id: u64, modulation_input_index: int, source_node_id: u64, source_output_index: int = 0) -> bool {
	target_input_index, ok := g.getModulationInputTargetIndex(g, node_id, modulation_input_index)
	if !ok {
		return false
	}
	g.queueConnect(g, source_node_id, source_output_index, node_id, target_input_index)
	return true
}

audioGraphConnectToEndpoint :: proc(g: ^AudioGraph, source_node_id: u64, source_output_index: int = 0) {
	audioGraphQueueConnect(g, source_node_id, source_output_index, g.endpoint_node_id, 0)
}

audioGraphQueueDisconnect :: proc(g: ^AudioGraph, target_node_id: u64, target_input_index: int) {
	sync.mutex_lock(&g.lock)
	append(&g.pending_mutations, GraphMutation{kind = .Disconnect, target_node_id = target_node_id, target_input_index = target_input_index})
	g.dirty = true
	sync.mutex_unlock(&g.lock)
}

audioGraphQueueSetRoot :: proc(g: ^AudioGraph, node_id: u64, enabled: bool) {
	sync.mutex_lock(&g.lock)
	append(&g.pending_mutations, GraphMutation{kind = .SetRoot, node_id = node_id, root_enabled = enabled})
	g.dirty = true
	sync.mutex_unlock(&g.lock)
}

audioGraphMarkEngineDirty :: proc(g: ^AudioGraph) {
	sync.mutex_lock(&g.lock)
	g.engine_dirty = true
	sync.mutex_unlock(&g.lock)
}

audioGraphBeginRenderCycle :: proc(g: ^AudioGraph, render_quantum: u64) {
	sync.mutex_lock(&g.lock)
	if len(g.pending_mutations) > 0 {
		graphApplyPendingMutations(g)
	}
	if g.dirty {
		graphRebuildRenderOrder(g)
		g.dirty = false
	}
	g.processing = true
	sync.mutex_unlock(&g.lock)

	// Reset per-node processing markers for this quantum.
	for node in g.render_order {
		if node.last_render_quantum != render_quantum {
			node.has_processed_quantum = false
		}
	}
}

audioGraphProcess :: proc(g: ^AudioGraph, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int) {
	channel_count := int(engine_context.output_channel_count)
	if channel_count < 1 {
		channel_count = 1
	}

	sync.mutex_lock(&g.lock)
	if g.cached_frame_buffer_size != frame_buffer_size || g.cached_output_channel_count != channel_count {
		g.cached_frame_buffer_size = frame_buffer_size
		g.cached_output_channel_count = channel_count
		g.engine_dirty = true
	}
	sync.mutex_unlock(&g.lock)

	audioGraphBeginRenderCycle(g, engine_context.render_quantum)
	audioGraphResizeNodeCachesIfEngineDirty(g)

	if frame_buffer != nil {
		for i in 0..<len(frame_buffer^) {
			frame_buffer^[i] = 0
		}
	}

	sync.mutex_lock(&g.lock)
	roots := g.root_node_ids
	if len(roots) == 0 {
		roots = make([dynamic]u64, 0, len(g.nodes), g.allocator)
		defer delete(roots)
		for node_id, _ in g.nodes {
			append(&roots, node_id)
		}
	}
	sync.mutex_unlock(&g.lock)

	for node_id in roots {
		node, ok := audioGraphGetNode(g, node_id)
		if !ok {
			continue
		}
		graphProcessNodeDFS(g, node, engine_context, frame_buffer, frame_buffer_size)

		if frame_buffer != nil && len(node.output_cache) > 0 {
			root_out := node.output_cache[0]
			sample_count := len(frame_buffer^)
			if len(root_out) < sample_count {
				sample_count = len(root_out)
			}
			for i in 0..<sample_count {
				frame_buffer^[i] += root_out[i]
			}
		}
	}

	sync.mutex_lock(&g.lock)
	g.processing = false
	sync.mutex_unlock(&g.lock)
}

audioGraphGetRenderOrder :: proc(g: ^AudioGraph) -> []^AudioNode {
	return g.render_order[:]
}

audioGraphGetNode :: proc(g: ^AudioGraph, node_id: u64) -> (^AudioNode, bool) {
	sync.mutex_lock(&g.lock)
	node, ok := g.nodes[node_id]
	sync.mutex_unlock(&g.lock)
	return node, ok
}

audioGraphGetEndpointNodeId :: proc(g: ^AudioGraph) -> u64 {
	return g.endpoint_node_id
}

audioGraphEnsureOutputBuffer :: proc(g: ^AudioGraph, node: ^AudioNode, output_index: int, sample_count: int) -> []f32 {
	if output_index < 0 || output_index >= len(node.output_cache) {
		return nil
	}
	expected_sample_count := g.cached_frame_buffer_size * g.cached_output_channel_count
	if sample_count > 0 {
		expected_sample_count = sample_count
	}

	buffer := node.output_cache[output_index]
	if len(buffer) != expected_sample_count {
		return nil
	}
	return buffer
}

audioGraphEnsureMixedInputBuffer :: proc(g: ^AudioGraph, node: ^AudioNode, sample_count: int) -> []f32 {
	expected_sample_count := g.cached_frame_buffer_size * g.cached_output_channel_count
	if sample_count > 0 {
		expected_sample_count = sample_count
	}
	if len(node.mixed_input_cache) != expected_sample_count {
		return nil
	}
	return node.mixed_input_cache
}

audioGraphResizeNodeCachesIfEngineDirty :: proc(g: ^AudioGraph) {
	sync.mutex_lock(&g.lock)
	if !g.engine_dirty {
		sync.mutex_unlock(&g.lock)
		return
	}

	sample_count := g.cached_frame_buffer_size * g.cached_output_channel_count
	if sample_count < 0 {
		sample_count = 0
	}

	for _, node in g.nodes {
		graphResizeNodeCaches(g, node, sample_count)
	}

	g.engine_dirty = false
	sync.mutex_unlock(&g.lock)
}

graphResizeNodeCaches :: proc(g: ^AudioGraph, node: ^AudioNode, sample_count: int) {
	for i in 0..<len(node.output_cache) {
		if len(node.output_cache[i]) != sample_count {
			if len(node.output_cache[i]) > 0 {
				delete(node.output_cache[i], g.allocator)
			}
			node.output_cache[i] = make([]f32, sample_count, g.allocator)
		}
	}

	if len(node.mixed_input_cache) != sample_count {
		if len(node.mixed_input_cache) > 0 {
			delete(node.mixed_input_cache, g.allocator)
		}
		node.mixed_input_cache = make([]f32, sample_count, g.allocator)
	}

	mod_sample_count := g.cached_frame_buffer_size
	if mod_sample_count < 0 {
		mod_sample_count = 0
	}
	for i in 0..<len(node.modulation_inputs) {
		if len(node.modulation_inputs[i].buffer) != mod_sample_count {
			if len(node.modulation_inputs[i].buffer) > 0 {
				delete(node.modulation_inputs[i].buffer, g.allocator)
			}
			node.modulation_inputs[i].buffer = make([]f32, mod_sample_count, g.allocator)
		}
	}
}

graphProcessNodeDFS :: proc(g: ^AudioGraph, node: ^AudioNode, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int) {
	if node.has_processed_quantum && node.last_render_quantum == engine_context.render_quantum {
		return
	}

	for input in node.inputs {
		if !input.has_source {
			continue
		}

		upstream, ok := audioGraphGetNode(g, input.source_node_id)
		if !ok {
			continue
		}

		graphProcessNodeDFS(g, upstream, engine_context, frame_buffer, frame_buffer_size)
	}

	for modulation_input in node.modulation_inputs {
		if !modulation_input.has_source {
			continue
		}

		upstream, ok := audioGraphGetNode(g, modulation_input.source_node_id)
		if !ok {
			continue
		}

		graphProcessNodeDFS(g, upstream, engine_context, frame_buffer, frame_buffer_size)
	}

	mixed_input := audioGraphEnsureMixedInputBuffer(g, node, frame_buffer_size*int(engine_context.output_channel_count))
	if len(mixed_input) == 0 {
		return
	}
	for i in 0..<len(mixed_input) {
		mixed_input[i] = 0
	}

	for input in node.inputs {
		if !input.has_source {
			continue
		}

		upstream, ok := audioGraphGetNode(g, input.source_node_id)
		if !ok {
			continue
		}
		if input.source_output_index < 0 || input.source_output_index >= len(upstream.output_cache) {
			continue
		}

		source := upstream.output_cache[input.source_output_index]
		if len(source) == 0 {
			continue
		}

		sample_count := len(mixed_input)
		if len(source) < sample_count {
			sample_count = len(source)
		}

		for i in 0..<sample_count {
			mixed_input[i] += source[i]
		}
	}

	channel_count := int(engine_context.output_channel_count)
	if channel_count < 1 {
		channel_count = 1
	}

	for i in 0..<len(node.modulation_inputs) {
		modulation_input := &node.modulation_inputs[i]
		if !modulation_input.has_source || modulation_input.apply == nil {
			continue
		}
		if len(modulation_input.buffer) != frame_buffer_size {
			continue
		}

		for sample_index in 0..<frame_buffer_size {
			modulation_input.buffer[sample_index] = 0
		}

		upstream, ok := audioGraphGetNode(g, modulation_input.source_node_id)
		if !ok || modulation_input.source_output_index < 0 || modulation_input.source_output_index >= len(upstream.output_cache) {
			continue
		}

		source := upstream.output_cache[modulation_input.source_output_index]
		if len(source) == 0 {
			continue
		}

		for sample_index in 0..<frame_buffer_size {
			source_index := sample_index * channel_count
			if source_index >= len(source) {
				break
			}
			modulation_input.buffer[sample_index] = source[source_index]
		}

		modulation_input.apply(modulation_input, node, modulation_input.buffer, frame_buffer_size)
	}

	if node.process != nil {
		node.process(g, node, engine_context, &mixed_input, frame_buffer_size)
	}

	node.last_render_quantum = engine_context.render_quantum
	node.has_processed_quantum = true
}

graphApplyPendingMutations :: proc(g: ^AudioGraph) {
	for mutation in g.pending_mutations {
		switch mutation.kind {
		case .AddNode:
			g.nodes[mutation.node_id] = mutation.node

		case .RemoveNode:
			graphRemoveNodeImmediate(g, mutation.node_id)

		case .Connect:
			graphConnectImmediate(g, mutation.source_node_id, mutation.source_output_index, mutation.target_node_id, mutation.target_input_index)

		case .Disconnect:
			graphDisconnectInputImmediate(g, mutation.target_node_id, mutation.target_input_index)

		case .SetRoot:
			graphSetRootImmediate(g, mutation.node_id, mutation.root_enabled)
		}
	}
	clear(&g.pending_mutations)
}

graphRebuildRenderOrder :: proc(g: ^AudioGraph) {
	clear(&g.render_order)

	visited := make(map[u64]bool)
	defer delete(visited)

	// If no explicit roots, all nodes are considered render roots.
	if len(g.root_node_ids) == 0 {
		for _, node in g.nodes {
			graphRebuildDFS(g, node, &visited)
		}
		return
	}

	for node_id in g.root_node_ids {
		node, ok := g.nodes[node_id]
		if !ok {
			continue
		}
		graphRebuildDFS(g, node, &visited)
	}
}

graphRebuildDFS :: proc(g: ^AudioGraph, node: ^AudioNode, visited: ^map[u64]bool) {
	if seen, ok := visited^[node.id]; ok && seen {
		return
	}
	visited^[node.id] = true

	for input in node.inputs {
		if !input.has_source {
			continue
		}
		upstream, ok := g.nodes[input.source_node_id]
		if !ok {
			continue
		}
		graphRebuildDFS(g, upstream, visited)
	}

	for modulation_input in node.modulation_inputs {
		if !modulation_input.has_source {
			continue
		}
		upstream, ok := g.nodes[modulation_input.source_node_id]
		if !ok {
			continue
		}
		graphRebuildDFS(g, upstream, visited)
	}

	append(&g.render_order, node)
}

graphNodeCreate :: proc(node_id: u64, name: string, input_count: int, output_count: int, process: AudioNodeProcessProc, user_data: rawptr, modulation_input_count: int = 0, allocator := context.allocator) -> ^AudioNode {
	node := new(AudioNode, allocator)
	node.id = node_id
	node.name = name
	node.process = process
	node.user_data = user_data
	node.inputs = make([dynamic]GraphNodeInput, input_count, input_count, allocator)
	node.modulation_inputs = make([dynamic]ModulationInput, modulation_input_count, modulation_input_count, allocator)
	node.outputs = make([dynamic]GraphNodeOutput, output_count, output_count, allocator)
	node.output_cache = make([dynamic][]f32, output_count, output_count, allocator)
	node.mixed_input_cache = nil
	return node
}

graphNodeDestroy :: proc(node: ^AudioNode, allocator := context.allocator) {
	if node == nil {
		return
	}

	for i in 0..<len(node.output_cache) {
		if len(node.output_cache[i]) > 0 {
			delete(node.output_cache[i], allocator)
		}
	}

	if len(node.mixed_input_cache) > 0 {
		delete(node.mixed_input_cache, allocator)
	}

	for i in 0..<len(node.modulation_inputs) {
		if len(node.modulation_inputs[i].buffer) > 0 {
			delete(node.modulation_inputs[i].buffer, allocator)
		}
	}

	for i in 0..<len(node.outputs) {
		if len(node.outputs[i].targets) > 0 {
			delete(node.outputs[i].targets)
		}
	}

	delete(node.output_cache)
	delete(node.outputs)
	delete(node.modulation_inputs)
	delete(node.inputs)
	free(node, allocator)
}

graphRemoveNodeImmediate :: proc(g: ^AudioGraph, node_id: u64) {
	if node_id == g.endpoint_node_id {
		return
	}
	node, exists := g.nodes[node_id]
	if !exists {
		return
	}

	// Remove incoming links from source outputs.
	for input_index in 0..<len(node.inputs) {
		graphDisconnectInputImmediate(g, node_id, input_index)
	}
	for modulation_input_index in 0..<len(node.modulation_inputs) {
		graphDisconnectInputImmediate(g, node_id, len(node.inputs)+modulation_input_index)
	}

	// Remove outgoing links from target inputs.
	for output_index in 0..<len(node.outputs) {
		targets := node.outputs[output_index].targets
		for target in targets {
			graphDisconnectInputImmediate(g, target.target_node_id, target.target_input_index)
		}
		clear(&node.outputs[output_index].targets)
	}

	delete_key(&g.nodes, node_id)
	graphSetRootImmediate(g, node_id, false)
	graphNodeDestroy(node, g.allocator)
}

graphConnectImmediate :: proc(g: ^AudioGraph, source_node_id: u64, source_output_index: int, target_node_id: u64, target_input_index: int) {
	source_node, source_ok := g.nodes[source_node_id]
	target_node, target_ok := g.nodes[target_node_id]
	if !source_ok || !target_ok {
		return
	}

	if source_output_index < 0 || source_output_index >= len(source_node.outputs) {
		return
	}
	if target_input_index < 0 {
		return
	}

	audio_input_count := len(target_node.inputs)
	modulation_input_count := len(target_node.modulation_inputs)
	is_audio_input := target_input_index < audio_input_count
	modulation_input_index := target_input_index - audio_input_count

	if !is_audio_input && (modulation_input_index < 0 || modulation_input_index >= modulation_input_count) {
		return
	}

	// Target inputs are single-source. Disconnect any existing source first.
	graphDisconnectInputImmediate(g, target_node_id, target_input_index)

	if is_audio_input {
		target_node.inputs[target_input_index] = GraphNodeInput{
			has_source = true,
			source_node_id = source_node_id,
			source_output_index = source_output_index,
		}
	} else {
		target_node.modulation_inputs[modulation_input_index].has_source = true
		target_node.modulation_inputs[modulation_input_index].source_node_id = source_node_id
		target_node.modulation_inputs[modulation_input_index].source_output_index = source_output_index
	}

	append(&source_node.outputs[source_output_index].targets, GraphNodeOutputTarget{
		target_node_id = target_node_id,
		target_input_index = target_input_index,
	})
}

graphDisconnectInputImmediate :: proc(g: ^AudioGraph, target_node_id: u64, target_input_index: int) {
	target_node, target_ok := g.nodes[target_node_id]
	if !target_ok {
		return
	}
	if target_input_index < 0 {
		return
	}

	audio_input_count := len(target_node.inputs)
	modulation_input_count := len(target_node.modulation_inputs)
	is_audio_input := target_input_index < audio_input_count
	modulation_input_index := target_input_index - audio_input_count
	if !is_audio_input && (modulation_input_index < 0 || modulation_input_index >= modulation_input_count) {
		return
	}

	has_source := false
	source_node_id := u64(0)
	source_output_index := 0

	if is_audio_input {
		input := target_node.inputs[target_input_index]
		has_source = input.has_source
		source_node_id = input.source_node_id
		source_output_index = input.source_output_index
	} else {
		input := target_node.modulation_inputs[modulation_input_index]
		has_source = input.has_source
		source_node_id = input.source_node_id
		source_output_index = input.source_output_index
	}

	if !has_source {
		return
	}

	source_node, source_ok := g.nodes[source_node_id]
	if source_ok && source_output_index >= 0 && source_output_index < len(source_node.outputs) {
		targets := &source_node.outputs[source_output_index].targets
		for i in 0..<len(targets^) {
			t := targets^[i]
			if t.target_node_id == target_node_id && t.target_input_index == target_input_index {
				unordered_remove(targets, i)
				break
			}
		}
	}

	if is_audio_input {
		target_node.inputs[target_input_index] = GraphNodeInput{}
	} else {
		target_node.modulation_inputs[modulation_input_index].has_source = false
		target_node.modulation_inputs[modulation_input_index].source_node_id = 0
		target_node.modulation_inputs[modulation_input_index].source_output_index = 0
	}
}

graphSetRootImmediate :: proc(g: ^AudioGraph, node_id: u64, enabled: bool) {
	if node_id == g.endpoint_node_id && !enabled {
		return
	}
	if enabled {
		for existing in g.root_node_ids {
			if existing == node_id {
				return
			}
		}
		append(&g.root_node_ids, node_id)
		return
	}

	for i in 0..<len(g.root_node_ids) {
		if g.root_node_ids[i] == node_id {
			unordered_remove(&g.root_node_ids, i)
			return
		}
	}
}

graphEndpointProcess :: proc(graph: ^AudioGraph, node: ^AudioNode, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int) {
	channel_count := int(engine_context.output_channel_count)
	if channel_count < 1 {
		channel_count = 1
	}

	sample_count := frame_buffer_size * channel_count
	out := graph->ensureOutputBuffer(node, 0, sample_count)
	if len(out) != sample_count {
		return
	}

	for i in 0..<sample_count {
		value := f32(0)
		if frame_buffer != nil && i < len(frame_buffer^) {
			value = frame_buffer^[i]
		}
		out[i] = value
	}
}
