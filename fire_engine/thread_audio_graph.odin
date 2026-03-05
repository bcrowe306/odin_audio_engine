package fire_engine

import "base:runtime"
import "core:mem"
import "core:os"
import "core:thread"

THREAD_AUDIO_GRAPH_MAX_WORKERS :: 8
THREAD_AUDIO_GRAPH_MUTATION_QUEUE_SIZE :: 4096

ThreadAudioGraphState :: struct {
	allocator: runtime.Allocator,
	pool_allocator: mem.Allocator,
	pool: thread.Pool,
	worker_count: int,
	pool_started: bool,
	task_data: [dynamic]ThreadAudioGraphTaskData,
	level_groups: [dynamic][dynamic]^AudioNode,
	mutation_queue: SPSC(THREAD_AUDIO_GRAPH_MUTATION_QUEUE_SIZE, GraphMutation),
	producer_node_lookup: map[u64]^AudioNode,
}

ThreadAudioGraphTaskData :: struct {
	graph: ^AudioGraph,
	node: ^AudioNode,
	engine_context: AudioGraphEngineContext,
	frame_buffer_size: int,
	midi_messages: []ShortMessage,
}

createThreadAudioGraph :: proc(allocator := context.allocator) -> ^AudioGraph {
	g := createAudioGraph(allocator)
	state := threadAudioGraphStateCreate(g.allocator)
	if state != nil {
		g.threaded_state = state
		g.queueAddNode = threadAudioGraphQueueAddNode
		g.setModulationInputProcessor = threadAudioGraphSetModulationInputProcessor
		g.getModulationInputTargetIndex = threadAudioGraphGetModulationInputTargetIndex
		g.queueRemoveNode = threadAudioGraphQueueRemoveNode
		g.queueConnect = threadAudioGraphQueueConnect
		g.connectModulationInput = audioGraphConnectModulationInput
		g.connectToEndpoint = threadAudioGraphConnectToEndpoint
		g.queueDisconnect = threadAudioGraphQueueDisconnect
		g.queueSetRoot = threadAudioGraphQueueSetRoot
		g.markEngineDirty = threadAudioGraphMarkEngineDirty
		g.beginRenderCycle = threadAudioGraphBeginRenderCycle
		g.process = threadAudioGraphProcess
		g.getRenderOrder = threadAudioGraphGetRenderOrder
		g.getNode = threadAudioGraphGetNode
	}
	return g
}

threadAudioGraphStateCreate :: proc(allocator := context.allocator) -> ^ThreadAudioGraphState {
	state := new(ThreadAudioGraphState, allocator)
	state.allocator = allocator
	state.pool_allocator = allocator
	state.task_data = make([dynamic]ThreadAudioGraphTaskData, 0, 32, allocator)
	state.level_groups = make([dynamic][dynamic]^AudioNode, 0, 16, allocator)
	state.producer_node_lookup = make(map[u64]^AudioNode)

	worker_count := max(os.processor_core_count() - 1, 1)
	worker_count = min(worker_count, THREAD_AUDIO_GRAPH_MAX_WORKERS)
	state.worker_count = worker_count

	thread.pool_init(&state.pool, state.pool_allocator, state.worker_count)
	thread.pool_start(&state.pool)
	state.pool_started = true

	return state
}

threadAudioGraphStateDestroy :: proc(g: ^AudioGraph) {
	if g == nil || g.threaded_state == nil {
		return
	}

	state := g.threaded_state
	if state.pool_started {
		thread.pool_join(&state.pool)
		state.pool_started = false
	}
	thread.pool_destroy(&state.pool)

	for i in 0..<len(state.level_groups) {
		if len(state.level_groups[i]) > 0 {
			delete(state.level_groups[i])
		}
	}
	if len(state.level_groups) > 0 {
		delete(state.level_groups)
	}
	if len(state.task_data) > 0 {
		delete(state.task_data)
	}
	delete(state.producer_node_lookup)

	free(state, state.allocator)
	g.threaded_state = nil
}

threadAudioGraphEnqueueMutation :: proc(g: ^AudioGraph, mutation: GraphMutation) {
	state := g.threaded_state
	if state == nil {
		return
	}

	for !spsc_push(&state.mutation_queue, mutation) {
		thread.yield()
	}
}

threadAudioGraphQueueAddNode :: proc(g: ^AudioGraph, name: string, input_count: int, output_count: int, process: AudioNodeProcessProc, user_data: rawptr = nil, modulation_input_count: int = 0) -> u64 {
	in_count := max(input_count, 0)
	out_count := max(output_count, 0)
	mod_count := max(modulation_input_count, 0)

	node_id := g.next_node_id
	g.next_node_id += 1

	node := graphNodeCreate(node_id, name, in_count, out_count, process, user_data, mod_count, g.allocator)
	if g.threaded_state != nil {
		g.threaded_state.producer_node_lookup[node_id] = node
	}

	threadAudioGraphEnqueueMutation(g, GraphMutation{kind = .AddNode, node = node, node_id = node_id})
	return node_id
}

threadAudioGraphSetModulationInputProcessor :: proc(g: ^AudioGraph, node_id: u64, modulation_input_index: int, apply: proc(input: ^ModulationInput, node: ^AudioNode, sample_buffer: []f32, frame_buffer_size: int), user_data: rawptr = nil) {
	node: ^AudioNode = nil
	if existing, ok := g.nodes[node_id]; ok {
		node = existing
	} else if g.threaded_state != nil {
		if pending_node, ok := g.threaded_state.producer_node_lookup[node_id]; ok {
			node = pending_node
		}
	}

	if node == nil || modulation_input_index < 0 || modulation_input_index >= len(node.modulation_inputs) {
		return
	}
	node.modulation_inputs[modulation_input_index].apply = apply
	node.modulation_inputs[modulation_input_index].user_data = user_data
}

threadAudioGraphGetModulationInputTargetIndex :: proc(g: ^AudioGraph, node_id: u64, modulation_input_index: int) -> (int, bool) {
	node: ^AudioNode = nil
	if existing, ok := g.nodes[node_id]; ok {
		node = existing
	} else if g.threaded_state != nil {
		if pending_node, ok := g.threaded_state.producer_node_lookup[node_id]; ok {
			node = pending_node
		}
	}

	if node == nil || modulation_input_index < 0 || modulation_input_index >= len(node.modulation_inputs) {
		return 0, false
	}

	return len(node.inputs) + modulation_input_index, true
}

threadAudioGraphQueueRemoveNode :: proc(g: ^AudioGraph, node_id: u64) {
	if node_id == g.endpoint_node_id {
		return
	}
	threadAudioGraphEnqueueMutation(g, GraphMutation{kind = .RemoveNode, node_id = node_id})
}

threadAudioGraphQueueConnect :: proc(g: ^AudioGraph, source_node_id: u64, source_output_index: int, target_node_id: u64, target_input_index: int) {
	threadAudioGraphEnqueueMutation(g, GraphMutation{
		kind = .Connect,
		source_node_id = source_node_id,
		source_output_index = source_output_index,
		target_node_id = target_node_id,
		target_input_index = target_input_index,
	})
}

threadAudioGraphConnectToEndpoint :: proc(g: ^AudioGraph, source_node_id: u64, source_output_index: int = 0) {
	threadAudioGraphQueueConnect(g, source_node_id, source_output_index, g.endpoint_node_id, 0)
}

threadAudioGraphQueueDisconnect :: proc(g: ^AudioGraph, target_node_id: u64, target_input_index: int) {
	threadAudioGraphEnqueueMutation(g, GraphMutation{kind = .Disconnect, target_node_id = target_node_id, target_input_index = target_input_index})
}

threadAudioGraphQueueSetRoot :: proc(g: ^AudioGraph, node_id: u64, enabled: bool) {
	threadAudioGraphEnqueueMutation(g, GraphMutation{kind = .SetRoot, node_id = node_id, root_enabled = enabled})
}

threadAudioGraphMarkEngineDirty :: proc(g: ^AudioGraph) {
	g.engine_dirty = true
}

threadAudioGraphGetRenderOrder :: proc(g: ^AudioGraph) -> []^AudioNode {
	return g.render_order[:]
}

threadAudioGraphGetNode :: proc(g: ^AudioGraph, node_id: u64) -> (^AudioNode, bool) {
	node, ok := g.nodes[node_id]
	return node, ok
}

threadAudioGraphApplyPendingMutations :: proc(g: ^AudioGraph) {
	for mutation, ok := spsc_pop(&g.threaded_state.mutation_queue); ok; mutation, ok = spsc_pop(&g.threaded_state.mutation_queue) {
		switch mutation.kind {
		case .AddNode:
			g.nodes[mutation.node_id] = mutation.node
			g.dirty = true
			g.engine_dirty = true

		case .RemoveNode:
			graphRemoveNodeImmediate(g, mutation.node_id)
			g.dirty = true

		case .Connect:
			graphConnectImmediate(g, mutation.source_node_id, mutation.source_output_index, mutation.target_node_id, mutation.target_input_index)
			g.dirty = true

		case .Disconnect:
			graphDisconnectInputImmediate(g, mutation.target_node_id, mutation.target_input_index)
			g.dirty = true

		case .SetRoot:
			graphSetRootImmediate(g, mutation.node_id, mutation.root_enabled)
			g.dirty = true
		}
	}
}

threadAudioGraphBeginRenderCycle :: proc(g: ^AudioGraph, render_quantum: u64) {
	threadAudioGraphApplyPendingMutations(g)
	if g.dirty {
		graphRebuildRenderOrder(g)
		g.dirty = false
	}
	g.processing = true

	for node in g.render_order {
		if node.last_render_quantum != render_quantum {
			node.has_processed_quantum = false
		}
	}
}

threadAudioGraphResizeNodeCachesIfEngineDirty :: proc(g: ^AudioGraph) {
	if !g.engine_dirty {
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
}

threadAudioGraphProcess :: proc(g: ^AudioGraph, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int, midi_messages: []ShortMessage) {
	if g == nil || g.threaded_state == nil {
		audioGraphProcess(g, engine_context, frame_buffer, frame_buffer_size, midi_messages)
		return
	}

	channel_count := int(engine_context.output_channel_count)
	if channel_count < 1 {
		channel_count = 1
	}

	if g.cached_frame_buffer_size != frame_buffer_size || g.cached_output_channel_count != channel_count {
		g.cached_frame_buffer_size = frame_buffer_size
		g.cached_output_channel_count = channel_count
		g.engine_dirty = true
	}

	threadAudioGraphBeginRenderCycle(g, engine_context.render_quantum)
	threadAudioGraphResizeNodeCachesIfEngineDirty(g)

	if frame_buffer != nil {
		for i in 0..<len(frame_buffer^) {
			frame_buffer^[i] = 0
		}
	}

	threadAudioGraphBuildLevelGroups(g)
	state := g.threaded_state

	for group in state.level_groups {
		if len(group) == 0 {
			continue
		}

		if state.worker_count <= 1 || len(group) == 1 {
			for node in group {
				threadAudioGraphProcessNodeNoLock(g, node, engine_context, frame_buffer_size, midi_messages)
			}
			continue
		}

		clear(&state.task_data)
		for node in group {
			append(&state.task_data, ThreadAudioGraphTaskData{
				graph = g,
				node = node,
				engine_context = engine_context,
				frame_buffer_size = frame_buffer_size,
				midi_messages = midi_messages,
			})
		}

		for i in 0..<len(state.task_data) {
			thread.pool_add_task(&state.pool, runtime.nil_allocator(), threadAudioGraphNodeTaskHandler, &state.task_data[i], i)
		}

		for thread.pool_num_outstanding(&state.pool) > 0 {
			thread.yield()
		}

		for thread.pool_num_done(&state.pool) > 0 {
			_, _ = thread.pool_pop_done(&state.pool)
		}
	}

	roots := g.root_node_ids
	if len(roots) == 0 {
		roots = make([dynamic]u64, 0, len(g.nodes), g.allocator)
		defer delete(roots)
		for node_id, _ in g.nodes {
			append(&roots, node_id)
		}
	}

	for node_id in roots {
		node, ok := g.nodes[node_id]
		if !ok {
			continue
		}

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

	g.processing = false
}

threadAudioGraphBuildLevelGroups :: proc(g: ^AudioGraph) {
	state := g.threaded_state
	if state == nil {
		return
	}

	for i in 0..<len(state.level_groups) {
		clear(&state.level_groups[i])
	}
	clear(&state.level_groups)

	node_level := make(map[u64]int)
	defer delete(node_level)

	for node in g.render_order {
		level := 0
		for input in node.inputs {
			for source_connection in input.sources {
				if upstream_level, ok := node_level[source_connection.source_node_id]; ok {
					level = max(level, upstream_level+1)
				}
			}
		}
		for modulation_input in node.modulation_inputs {
			if !modulation_input.has_source {
				continue
			}
			if upstream_level, ok := node_level[modulation_input.source_node_id]; ok {
				level = max(level, upstream_level+1)
			}
		}

		node_level[node.id] = level

		for len(state.level_groups) <= level {
			append(&state.level_groups, make([dynamic]^AudioNode, 0, 8, state.allocator))
		}
		append(&state.level_groups[level], node)
	}
}

threadAudioGraphNodeTaskHandler :: proc(task: thread.Task) {
	task_data := cast(^ThreadAudioGraphTaskData)task.data
	if task_data == nil || task_data.graph == nil || task_data.node == nil {
		return
	}

	threadAudioGraphProcessNodeNoLock(task_data.graph, task_data.node, task_data.engine_context, task_data.frame_buffer_size, task_data.midi_messages)
}

threadAudioGraphProcessNodeNoLock :: proc(g: ^AudioGraph, node: ^AudioNode, engine_context: AudioGraphEngineContext, frame_buffer_size: int, midi_messages: []ShortMessage) {
	if node.has_processed_quantum && node.last_render_quantum == engine_context.render_quantum {
		return
	}

	channel_count := int(engine_context.output_channel_count)
	if channel_count < 1 {
		channel_count = 1
	}

	mixed_input := audioGraphEnsureMixedInputBuffer(g, node, frame_buffer_size*channel_count)
	if len(mixed_input) == 0 {
		return
	}
	for i in 0..<len(mixed_input) {
		mixed_input[i] = 0
	}

	for input in node.inputs {
		for source_connection in input.sources {
			upstream, ok := g.nodes[source_connection.source_node_id]
			if !ok {
				continue
			}
			if source_connection.source_output_index < 0 || source_connection.source_output_index >= len(upstream.output_cache) {
				continue
			}

			source := upstream.output_cache[source_connection.source_output_index]
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

		upstream, ok := g.nodes[modulation_input.source_node_id]
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
		node.process(g, node, engine_context, &mixed_input, frame_buffer_size, midi_messages)
	}

	node.last_render_quantum = engine_context.render_quantum
	node.has_processed_quantum = true
}
