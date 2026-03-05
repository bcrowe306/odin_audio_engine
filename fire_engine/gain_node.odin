package fire_engine
import "core:math"
import ow "./odinworks"

DEFAULT_GAIN_NODE_RAMP_SECONDS :: f32(0.005)
MIN_GAIN_NODE_RAMP_SECONDS :: f32(0.0001)
MIN_GAIN_NODE_DB :: f32(-120.0)
MAX_GAIN_NODE_DB :: f32(12.0)
MAX_GAIN_NODE_LINEAR :: f32(3.9810717)

GainNode :: struct {
	node_id: u64,
	target_gain: f32,
	current_gain: f32,
	modulation_gain_offset: f32,
	ramp_seconds: f32,
	gain_coefs: ow.ow_gain_coeffs,
	coeff_sample_rate: u32,

	attachToGraph: proc(node: ^GainNode, graph: ^AudioGraph),
	setGain: proc(node: ^GainNode, gain: f32),
	getGain: proc(node: ^GainNode) -> f32,
	setGainDB: proc(node: ^GainNode, gain_db: f32),
	getGainDB: proc(node: ^GainNode) -> f32,
	setRampSeconds: proc(node: ^GainNode, ramp_seconds: f32),
	getRampSeconds: proc(node: ^GainNode) -> f32,
}

createGainNode :: proc(initial_gain: f32 = 1.0, ramp_seconds: f32 = DEFAULT_GAIN_NODE_RAMP_SECONDS) -> ^GainNode {
	node := new(GainNode)

	gain := clamp(initial_gain, 0.0, MAX_GAIN_NODE_LINEAR)
	node.target_gain = gain
	node.current_gain = gain
	node.modulation_gain_offset = 0
	node.ramp_seconds = max(ramp_seconds, MIN_GAIN_NODE_RAMP_SECONDS)
	node.coeff_sample_rate = 48000
	ow.ow_gain_init(&node.gain_coefs)
	ow.ow_gain_set_sample_rate(&node.gain_coefs, f32(node.coeff_sample_rate))
	ow.ow_gain_set_smooth_tau(&node.gain_coefs, node.ramp_seconds)
	ow.ow_gain_set_gain_lin(&node.gain_coefs, gain)

	node.attachToGraph = gainNodeAttachToGraph
	node.setGain = gainNodeSetGain
	node.getGain = gainNodeGetGain
	node.setGainDB = gainNodeSetGainDB
	node.getGainDB = gainNodeGetGainDB
	node.setRampSeconds = gainNodeSetRampSeconds
	node.getRampSeconds = gainNodeGetRampSeconds

	return node
}

gainNodeAttachToGraph :: proc(node: ^GainNode, graph: ^AudioGraph) {
	node.node_id = graph->queueAddNode("gain", 1, 1, gainNodeProcess, cast(rawptr)node, 1)
	graph->setModulationInputProcessor(node.node_id, 0, gainNodeApplyGainModulation, cast(rawptr)node)
}

gainNodeSetGain :: proc(node: ^GainNode, gain: f32) {
	node.target_gain = clamp(gain, 0.0, MAX_GAIN_NODE_LINEAR)
}

gainNodeGetGain :: proc(node: ^GainNode) -> f32 {
	return node.target_gain
}

gainNodeSetGainDB :: proc(node: ^GainNode, gain_db: f32) {
	clamped_db := clamp(gain_db, MIN_GAIN_NODE_DB, MAX_GAIN_NODE_DB)
	node.target_gain = gainNodeDbToLinear(clamped_db)
}

gainNodeGetGainDB :: proc(node: ^GainNode) -> f32 {
	return gainNodeLinearToDb(node.target_gain)
}

gainNodeSetRampSeconds :: proc(node: ^GainNode, ramp_seconds: f32) {
	node.ramp_seconds = max(ramp_seconds, MIN_GAIN_NODE_RAMP_SECONDS)
	ow.ow_gain_set_smooth_tau(&node.gain_coefs, node.ramp_seconds)
}

gainNodeGetRampSeconds :: proc(node: ^GainNode) -> f32 {
	return node.ramp_seconds
}

gainNodeDbToLinear :: proc(gain_db: f32) -> f32 {
	return f32(math.pow(10.0, f64(gain_db)/20.0))
}

gainNodeLinearToDb :: proc(gain_linear: f32) -> f32 {
	if gain_linear <= 0 {
		return MIN_GAIN_NODE_DB
	}
	db := f32(20.0 * math.log10(f64(gain_linear)))
	if db < MIN_GAIN_NODE_DB {
		return MIN_GAIN_NODE_DB
	}
	if db > MAX_GAIN_NODE_DB {
		return MAX_GAIN_NODE_DB
	}
	return db
}

gainNodeApplyGainModulation :: proc(input: ^ModulationInput, node: ^AudioNode, sample_buffer: []f32, frame_buffer_size: int) {
	gain_node := cast(^GainNode)node.user_data
	if gain_node == nil {
		return
	}
	if !input.has_source || frame_buffer_size <= 0 || len(sample_buffer) == 0 {
		gain_node.modulation_gain_offset = 0
		return
	}

	count := frame_buffer_size
	if len(sample_buffer) < count {
		count = len(sample_buffer)
	}
	if count <= 0 {
		gain_node.modulation_gain_offset = 0
		return
	}

	sum := f32(0)
	for i in 0..<count {
		sum += sample_buffer[i]
	}
	gain_node.modulation_gain_offset = sum / f32(count)
}

gainNodeProcess :: proc(graph: ^AudioGraph, graph_node: ^AudioNode, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int, midi_messages: []ShortMessage) {
	node := cast(^GainNode)graph_node.user_data
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
	for i in 0..<sample_count {
		sample := f32(0)
		if i < input_len {
			sample = frame_buffer^[i]
		}
		out[i] = sample
	}

	sample_rate := engine_context.sample_rate
	if sample_rate < 1 {
		sample_rate = 48000
	}
	if node.coeff_sample_rate != sample_rate {
		node.coeff_sample_rate = sample_rate
		ow.ow_gain_set_sample_rate(&node.gain_coefs, f32(sample_rate))
	}

	target := clamp(node.target_gain+node.modulation_gain_offset, 0.0, MAX_GAIN_NODE_LINEAR)
	ow.ow_gain_set_gain_lin(&node.gain_coefs, target)
	if sample_count > 0 {
		ow.ow_gain_process(&node.gain_coefs, &out[0], &out[0], sample_count)
	}
	node.current_gain = ow.ow_gain_get_gain_cur(&node.gain_coefs)
}