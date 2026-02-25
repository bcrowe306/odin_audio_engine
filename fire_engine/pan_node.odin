package main

import "core:math"

PanNode :: struct {
	node_id: u64,
	pan: f32,

	attachToGraph: proc(node: ^PanNode, graph: ^AudioGraph),
	setPan: proc(node: ^PanNode, pan: f32),
	getPan: proc(node: ^PanNode) -> f32,
}

createPanNode :: proc(initial_pan: f32 = 0.0) -> ^PanNode {
	node := new(PanNode)
	node.pan = clamp(initial_pan, -1.0, 1.0)

	node.attachToGraph = panNodeAttachToGraph
	node.setPan = panNodeSetPan
	node.getPan = panNodeGetPan

	return node
}

panNodeAttachToGraph :: proc(node: ^PanNode, graph: ^AudioGraph) {
	node.node_id = graph->queueAddNode("pan", 1, 1, panNodeProcess, cast(rawptr)node)
}

panNodeSetPan :: proc(node: ^PanNode, pan: f32) {
	node.pan = clamp(pan, -1.0, 1.0)
}

panNodeGetPan :: proc(node: ^PanNode) -> f32 {
	return node.pan
}

panNodeProcess :: proc(graph: ^AudioGraph, graph_node: ^AudioNode, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int) {
	node := cast(^PanNode)graph_node.user_data
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

	for i in 0..<sample_count {
		out[i] = 0
	}

	if frame_buffer == nil || len(frame_buffer^) == 0 || frame_buffer_size <= 0 {
		return
	}

	t := (node.pan + 1.0) * 0.5
	left_gain := f32(math.cos(f64(t) * math.PI / 2.0))
	right_gain := f32(math.sin(f64(t) * math.PI / 2.0))

	in_len := len(frame_buffer^)

	if channel_count == 1 {
		mono_gain := 0.5 * (left_gain + right_gain)
		for frame_index in 0..<frame_buffer_size {
			if frame_index >= in_len {
				break
			}
			out[frame_index] = frame_buffer^[frame_index] * mono_gain
		}
		return
	}

	for frame_index in 0..<frame_buffer_size {
		base := frame_index * channel_count
		if base >= in_len {
			break
		}

		left_in := frame_buffer^[base]
		right_in := left_in
		if base+1 < in_len {
			right_in = frame_buffer^[base+1]
		}

		out[base] = left_in * left_gain
		out[base+1] = right_in * right_gain

		for ch in 2..<channel_count {
			idx := base + ch
			if idx < in_len {
				out[idx] = frame_buffer^[idx]
			}
		}
	}
}