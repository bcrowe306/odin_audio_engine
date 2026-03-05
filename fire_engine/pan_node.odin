package fire_engine
import ow "./odinworks"


PanNode :: struct {
	node_id: u64,
	pan: f32,
	pan_coefs: ow.ow_pan_coeffs,
	coeff_sample_rate: u32,

	attachToGraph: proc(node: ^PanNode, graph: ^AudioGraph),
	setPan: proc(node: ^PanNode, pan: f32),
	getPan: proc(node: ^PanNode) -> f32,
}

createPanNode :: proc(initial_pan: f32 = 0.0) -> ^PanNode {
	node := new(PanNode)
	node.pan = clamp(initial_pan, -1.0, 1.0)
	node.coeff_sample_rate = 48000
	ow.ow_pan_init(&node.pan_coefs)
	ow.ow_pan_set_sample_rate(&node.pan_coefs, f32(node.coeff_sample_rate))
	ow.ow_pan_set_pan(&node.pan_coefs, node.pan)
	ow.ow_pan_reset_coeffs(&node.pan_coefs)

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
	ow.ow_pan_set_pan(&node.pan_coefs, node.pan)
}

panNodeGetPan :: proc(node: ^PanNode) -> f32 {
	return node.pan
}

panNodeProcess :: proc(graph: ^AudioGraph, graph_node: ^AudioNode, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int, midi_messages: []ShortMessage) {
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

	sample_rate := engine_context.sample_rate
	if sample_rate < 1 {
		sample_rate = 48000
	}
	if node.coeff_sample_rate != sample_rate {
		node.coeff_sample_rate = sample_rate
		ow.ow_pan_set_sample_rate(&node.pan_coefs, f32(sample_rate))
		ow.ow_pan_reset_coeffs(&node.pan_coefs)
	}
	ow.ow_pan_set_pan(&node.pan_coefs, node.pan)
	ow.ow_pan_update_coeffs_ctrl(&node.pan_coefs)

	in_len := len(frame_buffer^)

	if channel_count == 1 {
		for frame_index in 0..<frame_buffer_size {
			if frame_index >= in_len {
				break
			}
			ow.ow_pan_update_coeffs_audio(&node.pan_coefs)
			left_gain := ow.ow_gain_get_gain_cur(&node.pan_coefs.l_coeffs)
			right_gain := ow.ow_gain_get_gain_cur(&node.pan_coefs.r_coeffs)
			mono_gain := 0.5 * (left_gain + right_gain)
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

		ow.ow_pan_update_coeffs_audio(&node.pan_coefs)
		out[base] = ow.ow_gain_process1(&node.pan_coefs.l_coeffs, left_in)
		out[base+1] = ow.ow_gain_process1(&node.pan_coefs.r_coeffs, right_in)

		for ch in 2..<channel_count {
			idx := base + ch
			if idx < in_len {
				out[idx] = frame_buffer^[idx]
			}
		}
	}
}