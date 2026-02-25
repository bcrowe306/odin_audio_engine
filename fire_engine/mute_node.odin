package main

DEFAULT_MUTE_NODE_RAMP_SECONDS :: f32(0.01)
MIN_MUTE_NODE_RAMP_SECONDS :: f32(0.0001)

MuteNode :: struct {
	node_id: u64,
	muted: bool,
	current_gain: f32,
	ramp_seconds: f32,

	attachToGraph: proc(node: ^MuteNode, graph: ^AudioGraph),
	setMuted: proc(node: ^MuteNode, muted: bool),
	isMuted: proc(node: ^MuteNode) -> bool,
	setRampSeconds: proc(node: ^MuteNode, ramp_seconds: f32),
	getRampSeconds: proc(node: ^MuteNode) -> f32,
}

createMuteNode :: proc(initial_muted: bool = false, ramp_seconds: f32 = DEFAULT_MUTE_NODE_RAMP_SECONDS) -> ^MuteNode {
	node := new(MuteNode)
	node.muted = initial_muted
	node.current_gain = 1.0
	if node.muted {
		node.current_gain = 0.0
	}
	node.ramp_seconds = max(ramp_seconds, MIN_MUTE_NODE_RAMP_SECONDS)

	node.attachToGraph = muteNodeAttachToGraph
	node.setMuted = muteNodeSetMuted
	node.isMuted = muteNodeIsMuted
	node.setRampSeconds = muteNodeSetRampSeconds
	node.getRampSeconds = muteNodeGetRampSeconds

	return node
}

muteNodeAttachToGraph :: proc(node: ^MuteNode, graph: ^AudioGraph) {
	node.node_id = graph->queueAddNode("mute", 1, 1, muteNodeProcess, cast(rawptr)node)
}

muteNodeSetMuted :: proc(node: ^MuteNode, muted: bool) {
	node.muted = muted
}

muteNodeIsMuted :: proc(node: ^MuteNode) -> bool {
	return node.muted
}

muteNodeSetRampSeconds :: proc(node: ^MuteNode, ramp_seconds: f32) {
	node.ramp_seconds = max(ramp_seconds, MIN_MUTE_NODE_RAMP_SECONDS)
}

muteNodeGetRampSeconds :: proc(node: ^MuteNode) -> f32 {
	return node.ramp_seconds
}

muteNodeProcess :: proc(graph: ^AudioGraph, graph_node: ^AudioNode, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int) {
	node := cast(^MuteNode)graph_node.user_data
	if node == nil {
		return
	}

	channel_count := int(engine_context.output_channel_count)
	if channel_count < 1 {
		channel_count = 1
	}

	sample_count := frame_buffer_size * channel_count
	out := graph->ensureOutputBuffer(graph_node, 0, sample_count)
	if len(out) != sample_count {
		return
	}

	input_len := 0
	if frame_buffer != nil {
		input_len = len(frame_buffer^)
	}

	sample_rate := int(engine_context.sample_rate)
	if sample_rate < 1 {
		sample_rate = 48000
	}

	ramp_samples := f32(sample_rate) * node.ramp_seconds
	if ramp_samples < 1 {
		ramp_samples = 1
	}
	max_step := f32(1.0) / ramp_samples

	gain := node.current_gain
	target := f32(1.0)
	if node.muted {
		target = 0.0
	}

	for i in 0..<sample_count {
		diff := target - gain
		if diff > max_step {
			gain += max_step
		} else if diff < -max_step {
			gain -= max_step
		} else {
			gain = target
		}

		sample := f32(0)
		if i < input_len {
			sample = frame_buffer^[i]
		}

		out[i] = sample * gain
	}

	node.current_gain = gain
}