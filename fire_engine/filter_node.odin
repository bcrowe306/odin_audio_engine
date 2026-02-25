package main

import "core:math"

FILTER_MIN_CUTOFF_HZ :: f32(20.0)
FILTER_MAX_CUTOFF_HZ :: f32(20000.0)
FILTER_MIN_RESONANCE_Q :: f32(0.1)
FILTER_MAX_RESONANCE_Q :: f32(20.0)
FILTER_MIN_MORPH :: f32(0.0)
FILTER_MAX_MORPH :: f32(1.0)
FILTER_DEFAULT_CUTOFF_SMOOTHING_SECONDS :: f32(0.01)

FILTER_MOD_INPUT_CUTOFF :: int(0)
FILTER_MOD_INPUT_RESONANCE :: int(1)

FilterType :: enum {
	Lowpass,
	Highpass,
	Bandpass,
	Notch,
	MorphSvf,
}

FilterSlope :: enum {
	Db12,
	Db24,
}

FilterNode :: struct {
	node_id: u64,
	filter_type: FilterType,
	cutoff_frequency_hz: f32,
	resonance_q: f32,
	morph_parameter: f32,
	slope: FilterSlope,
	enabled: bool,
	cutoff_smoothing_seconds: f32,
	smoothed_cutoff_frequency_hz: f32,
	modulation_cutoff_value: f32,
	modulation_resonance_value: f32,

	state_channels: int,
	stage1_ic1eq: []f32,
	stage1_ic2eq: []f32,
	stage2_ic1eq: []f32,
	stage2_ic2eq: []f32,

	attachToGraph: proc(node: ^FilterNode, graph: ^AudioGraph),
	setType: proc(node: ^FilterNode, filter_type: FilterType),
	getType: proc(node: ^FilterNode) -> FilterType,
	setCutoffFrequencyHz: proc(node: ^FilterNode, cutoff_hz: f32),
	getCutoffFrequencyHz: proc(node: ^FilterNode) -> f32,
	setResonanceQ: proc(node: ^FilterNode, resonance_q: f32),
	getResonanceQ: proc(node: ^FilterNode) -> f32,
	setMorphParameter: proc(node: ^FilterNode, morph: f32),
	getMorphParameter: proc(node: ^FilterNode) -> f32,
	setSlope: proc(node: ^FilterNode, slope: FilterSlope),
	getSlope: proc(node: ^FilterNode) -> FilterSlope,
	setSlopeDbPerOctave: proc(node: ^FilterNode, db_per_octave: int),
	getSlopeDbPerOctave: proc(node: ^FilterNode) -> int,
	setEnabled: proc(node: ^FilterNode, enabled: bool),
	isEnabled: proc(node: ^FilterNode) -> bool,
	resetState: proc(node: ^FilterNode),
}

createFilterNode :: proc(
	filter_type: FilterType = .Lowpass,
	cutoff_frequency_hz: f32 = 1000.0,
	resonance_q: f32 = 0.707,
	morph_parameter: f32 = 0.5,
	slope: FilterSlope = .Db12,
) -> ^FilterNode {
	node := new(FilterNode)
	node.filter_type = filter_type
	node.cutoff_frequency_hz = clamp(cutoff_frequency_hz, FILTER_MIN_CUTOFF_HZ, FILTER_MAX_CUTOFF_HZ)
	node.resonance_q = clamp(resonance_q, FILTER_MIN_RESONANCE_Q, FILTER_MAX_RESONANCE_Q)
	node.morph_parameter = clamp(morph_parameter, FILTER_MIN_MORPH, FILTER_MAX_MORPH)
	node.slope = slope
	node.enabled = true
	node.cutoff_smoothing_seconds = FILTER_DEFAULT_CUTOFF_SMOOTHING_SECONDS
	node.smoothed_cutoff_frequency_hz = node.cutoff_frequency_hz
	node.modulation_cutoff_value = 0
	node.modulation_resonance_value = 0
	node.state_channels = 0

	node.attachToGraph = filterNodeAttachToGraph
	node.setType = filterNodeSetType
	node.getType = filterNodeGetType
	node.setCutoffFrequencyHz = filterNodeSetCutoffFrequencyHz
	node.getCutoffFrequencyHz = filterNodeGetCutoffFrequencyHz
	node.setResonanceQ = filterNodeSetResonanceQ
	node.getResonanceQ = filterNodeGetResonanceQ
	node.setMorphParameter = filterNodeSetMorphParameter
	node.getMorphParameter = filterNodeGetMorphParameter
	node.setSlope = filterNodeSetSlope
	node.getSlope = filterNodeGetSlope
	node.setSlopeDbPerOctave = filterNodeSetSlopeDbPerOctave
	node.getSlopeDbPerOctave = filterNodeGetSlopeDbPerOctave
	node.setEnabled = filterNodeSetEnabled
	node.isEnabled = filterNodeIsEnabled
	node.resetState = filterNodeResetState

	return node
}

filterNodeAttachToGraph :: proc(node: ^FilterNode, graph: ^AudioGraph) {
	node.node_id = graph->queueAddNode("filter", 1, 1, filterNodeProcess, cast(rawptr)node, 2)
	graph->setModulationInputProcessor(node.node_id, FILTER_MOD_INPUT_CUTOFF, filterNodeApplyCutoffModulation)
	graph->setModulationInputProcessor(node.node_id, FILTER_MOD_INPUT_RESONANCE, filterNodeApplyResonanceModulation)
}

filterNodeSetType :: proc(node: ^FilterNode, filter_type: FilterType) {
	node.filter_type = filter_type
}

filterNodeGetType :: proc(node: ^FilterNode) -> FilterType {
	return node.filter_type
}

filterNodeSetCutoffFrequencyHz :: proc(node: ^FilterNode, cutoff_hz: f32) {
	node.cutoff_frequency_hz = clamp(cutoff_hz, FILTER_MIN_CUTOFF_HZ, FILTER_MAX_CUTOFF_HZ)
}

filterNodeGetCutoffFrequencyHz :: proc(node: ^FilterNode) -> f32 {
	return node.cutoff_frequency_hz
}

filterNodeSetResonanceQ :: proc(node: ^FilterNode, resonance_q: f32) {
	node.resonance_q = clamp(resonance_q, FILTER_MIN_RESONANCE_Q, FILTER_MAX_RESONANCE_Q)
}

filterNodeGetResonanceQ :: proc(node: ^FilterNode) -> f32 {
	return node.resonance_q
}

filterNodeSetMorphParameter :: proc(node: ^FilterNode, morph: f32) {
	node.morph_parameter = clamp(morph, FILTER_MIN_MORPH, FILTER_MAX_MORPH)
}

filterNodeGetMorphParameter :: proc(node: ^FilterNode) -> f32 {
	return node.morph_parameter
}

filterNodeSetSlope :: proc(node: ^FilterNode, slope: FilterSlope) {
	node.slope = slope
}

filterNodeGetSlope :: proc(node: ^FilterNode) -> FilterSlope {
	return node.slope
}

filterNodeSetSlopeDbPerOctave :: proc(node: ^FilterNode, db_per_octave: int) {
	if db_per_octave >= 24 {
		node.slope = .Db24
		return
	}
	node.slope = .Db12
}

filterNodeGetSlopeDbPerOctave :: proc(node: ^FilterNode) -> int {
	if node.slope == .Db24 {
		return 24
	}
	return 12
}

filterNodeSetEnabled :: proc(node: ^FilterNode, enabled: bool) {
	node.enabled = enabled
}

filterNodeIsEnabled :: proc(node: ^FilterNode) -> bool {
	return node.enabled
}

filterNodeResetState :: proc(node: ^FilterNode) {
	node.modulation_cutoff_value = 0
	node.modulation_resonance_value = 0
	node.smoothed_cutoff_frequency_hz = node.cutoff_frequency_hz
	for i in 0..<len(node.stage1_ic1eq) {
		node.stage1_ic1eq[i] = 0
		node.stage1_ic2eq[i] = 0
		node.stage2_ic1eq[i] = 0
		node.stage2_ic2eq[i] = 0
	}
}

filterNodeApplyCutoffModulation :: proc(input: ^ModulationInput, node: ^AudioNode, sample_buffer: []f32, frame_buffer_size: int) {
	filter_node := cast(^FilterNode)node.user_data
	if filter_node == nil {
		return
	}
	if !input.has_source || frame_buffer_size <= 0 || len(sample_buffer) == 0 {
		filter_node.modulation_cutoff_value = 0
		return
	}

	count := frame_buffer_size
	if len(sample_buffer) < count {
		count = len(sample_buffer)
	}
	if count <= 0 {
		filter_node.modulation_cutoff_value = 0
		return
	}

	sum := f32(0)
	for i in 0..<count {
		sum += sample_buffer[i]
	}
	filter_node.modulation_cutoff_value = clamp(sum/f32(count), -1.0, 1.0)
}

filterNodeApplyResonanceModulation :: proc(input: ^ModulationInput, node: ^AudioNode, sample_buffer: []f32, frame_buffer_size: int) {
	filter_node := cast(^FilterNode)node.user_data
	if filter_node == nil {
		return
	}
	if !input.has_source || frame_buffer_size <= 0 || len(sample_buffer) == 0 {
		filter_node.modulation_resonance_value = 0
		return
	}

	count := frame_buffer_size
	if len(sample_buffer) < count {
		count = len(sample_buffer)
	}
	if count <= 0 {
		filter_node.modulation_resonance_value = 0
		return
	}

	sum := f32(0)
	for i in 0..<count {
		sum += sample_buffer[i]
	}
	filter_node.modulation_resonance_value = clamp(sum/f32(count), -1.0, 1.0)
}

filterNodeProcess :: proc(graph: ^AudioGraph, graph_node: ^AudioNode, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int) {
	node := cast(^FilterNode)graph_node.user_data
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

	filterNodeEnsureStateChannels(node, channel_count)

	input_len := 0
	if frame_buffer != nil {
		input_len = len(frame_buffer^)
	}

	if len(graph_node.modulation_inputs) > FILTER_MOD_INPUT_CUTOFF && !graph_node.modulation_inputs[FILTER_MOD_INPUT_CUTOFF].has_source {
		node.modulation_cutoff_value = 0
	}
	if len(graph_node.modulation_inputs) > FILTER_MOD_INPUT_RESONANCE && !graph_node.modulation_inputs[FILTER_MOD_INPUT_RESONANCE].has_source {
		node.modulation_resonance_value = 0
	}

	if !node.enabled {
		for i in 0..<sample_count {
			if i < input_len {
				out[i] = frame_buffer^[i]
			} else {
				out[i] = 0
			}
		}
		return
	}

	sample_rate := f32(engine_context.sample_rate)
	if sample_rate <= 0 {
		sample_rate = 48000
	}

	cutoff_modulated := node.cutoff_frequency_hz * f32(math.pow(2.0, f64(node.modulation_cutoff_value)))
	target_cutoff := clamp(cutoff_modulated, FILTER_MIN_CUTOFF_HZ, min(FILTER_MAX_CUTOFF_HZ, sample_rate*0.49))
	q := clamp(node.resonance_q+node.modulation_resonance_value*2.0, FILTER_MIN_RESONANCE_Q, FILTER_MAX_RESONANCE_Q)
	k := f32(1.0) / q

	if node.smoothed_cutoff_frequency_hz <= 0 {
		node.smoothed_cutoff_frequency_hz = target_cutoff
	}

	smoothing_seconds := node.cutoff_smoothing_seconds
	if smoothing_seconds <= 0 {
		smoothing_seconds = 0.0001
	}
	alpha := f32(1.0) - f32(math.exp(f64(-1.0)/(f64(smoothing_seconds)*f64(sample_rate))))
	if alpha < 0 {
		alpha = 0
	}
	if alpha > 1 {
		alpha = 1
	}

	for frame_index in 0..<frame_buffer_size {
		node.smoothed_cutoff_frequency_hz += alpha * (target_cutoff - node.smoothed_cutoff_frequency_hz)
		smoothed_cutoff := clamp(node.smoothed_cutoff_frequency_hz, FILTER_MIN_CUTOFF_HZ, min(FILTER_MAX_CUTOFF_HZ, sample_rate*0.49))
		g := f32(math.tan(f64(math.PI*smoothed_cutoff/sample_rate)))
		a1 := f32(1.0) / (1.0 + g*(g+k))
		a2 := g * a1
		a3 := g * a2

		for ch in 0..<channel_count {
			idx := frame_index*channel_count + ch
			x := f32(0)
			if idx < input_len {
				x = frame_buffer^[idx]
			}

			stage1_out := filterNodeProcessSvfSample(node, ch, x, a1, a2, a3, k, .stage1)
			result := stage1_out

			if node.slope == .Db24 {
				stage2_out := filterNodeProcessSvfSample(node, ch, stage1_out, a1, a2, a3, k, .stage2)
				result = stage2_out
			}

			out[idx] = result
		}
	}
}

FilterNodeStage :: enum {
	stage1,
	stage2,
}

filterNodeProcessSvfSample :: proc(node: ^FilterNode, ch: int, x: f32, a1: f32, a2: f32, a3: f32, k: f32, stage: FilterNodeStage) -> f32 {
	ic1eq := &node.stage1_ic1eq[ch]
	ic2eq := &node.stage1_ic2eq[ch]
	if stage == .stage2 {
		ic1eq = &node.stage2_ic1eq[ch]
		ic2eq = &node.stage2_ic2eq[ch]
	}

	v3 := x - ic2eq^
	v1 := a1*ic1eq^ + a2*v3
	v2 := ic2eq^ + a2*ic1eq^ + a3*v3

	ic1eq^ = 2.0*v1 - ic1eq^
	ic2eq^ = 2.0*v2 - ic2eq^

	low := v2
	high := v3 - k*v1
	band := v1
	notch := low + high

	switch node.filter_type {
	case .Lowpass:
		return low
	case .Highpass:
		return high
	case .Bandpass:
		return band
	case .Notch:
		return notch
	case .MorphSvf:
		morph := clamp(node.morph_parameter, 0.0, 1.0)
		if morph <= 0.5 {
			t := morph * 2.0
			return low*(1.0-t) + band*t
		}
		t := (morph - 0.5) * 2.0
		return band*(1.0-t) + high*t
	}

	return low
}

filterNodeEnsureStateChannels :: proc(node: ^FilterNode, channel_count: int) {
	if channel_count <= 0 || node.state_channels == channel_count {
		return
	}

	node.state_channels = channel_count
	node.stage1_ic1eq = make([]f32, channel_count)
	node.stage1_ic2eq = make([]f32, channel_count)
	node.stage2_ic1eq = make([]f32, channel_count)
	node.stage2_ic2eq = make([]f32, channel_count)
}