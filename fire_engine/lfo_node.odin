package fire_engine
import "core:math"


LFO_MIN_RATE_HZ :: f32(0.01)
LFO_MAX_RATE_HZ :: f32(20.0)
LFO_MIN_BIAS :: f32(-1.0)
LFO_MAX_BIAS :: f32(1.0)
LFO_MIN_DEPTH :: f32(0.0)
LFO_MAX_DEPTH :: f32(1.0)
LFO_MIN_ATTACK_SECONDS :: f32(0.001)
LFO_MAX_ATTACK_SECONDS :: f32(20.0)
LFO_MIN_TEMPO_BPM :: f32(1.0)

LFORateMode :: enum {
	Hz,
	BeatTime,
}

LFOBeatTime :: enum {
	N1_64,
	N1_32,
	N1_16,
	N1_8,
	N1_4,
	N1_2,
	N1,
	N2,
	N4,
	N8,
}

LFONode :: struct {
	node_id: u64,
	wavetable_type: WaveTableType,
	wavetables: WaveTables,
	rate_mode: LFORateMode,
	rate_hz: f32,
	rate_beat_time: LFOBeatTime,
	tempo_bpm: f32,
	depth: f32,
	bias: f32,
	enabled: bool,
	attack_time_seconds: f32,
	offset_normalized: f32,
	phase_normalized: f32,
	attack_level: f32,
	last_sample_rate: u32,

	attachToGraph: proc(node: ^LFONode, graph: ^AudioGraph),
	setWaveTableByName: proc(node: ^LFONode, name: string) -> bool,
	setWaveTableType: proc(node: ^LFONode, wavetable_type: WaveTableType),
	getWaveTableType: proc(node: ^LFONode) -> WaveTableType,
	setDepth: proc(node: ^LFONode, depth: f32),
	getDepth: proc(node: ^LFONode) -> f32,
	setBias: proc(node: ^LFONode, bias: f32),
	getBias: proc(node: ^LFONode) -> f32,
	setRateMode: proc(node: ^LFONode, mode: LFORateMode),
	getRateMode: proc(node: ^LFONode) -> LFORateMode,
	setRateHz: proc(node: ^LFONode, hz: f32),
	getRateHz: proc(node: ^LFONode) -> f32,
	setRateBeatTime: proc(node: ^LFONode, beat_time: LFOBeatTime),
	getRateBeatTime: proc(node: ^LFONode) -> LFOBeatTime,
	setRateBeatDivision: proc(node: ^LFONode, division: string) -> bool,
	getRateBeatDivision: proc(node: ^LFONode) -> string,
	setTempoBPM: proc(node: ^LFONode, tempo_bpm: f32),
	getTempoBPM: proc(node: ^LFONode) -> f32,
	setEnabled: proc(node: ^LFONode, enabled: bool),
	isEnabled: proc(node: ^LFONode) -> bool,
	setAttackTime: proc(node: ^LFONode, attack_time_seconds: f32),
	getAttackTime: proc(node: ^LFONode) -> f32,
	setOffsetNormalized: proc(node: ^LFONode, offset_normalized: f32),
	setOffsetDegrees: proc(node: ^LFONode, offset_degrees: f32),
	getOffsetNormalized: proc(node: ^LFONode) -> f32,
}

createLFONode :: proc(
	wavetable_name: string = "sine",
	rate_mode: LFORateMode = .Hz,
	rate_hz: f32 = 1.0,
	rate_beat_time: LFOBeatTime = .N1_4,
	depth: f32 = 1.0,
	bias: f32 = 0.0,
	enabled: bool = true,
	attack_time_seconds: f32 = 0.01,
	offset_normalized: f32 = 0.0,
	tempo_bpm: f32 = 120.0,
) -> ^LFONode {
	node := new(LFONode)
	node.wavetable_type = .Sine
	node.wavetables = createWaveTables(48000, .Sine, 1.0)
	node.rate_mode = rate_mode
	node.rate_hz = clamp(rate_hz, LFO_MIN_RATE_HZ, LFO_MAX_RATE_HZ)
	node.rate_beat_time = rate_beat_time
	node.tempo_bpm = max(tempo_bpm, LFO_MIN_TEMPO_BPM)
	node.depth = clamp(depth, LFO_MIN_DEPTH, LFO_MAX_DEPTH)
	node.bias = clamp(bias, LFO_MIN_BIAS, LFO_MAX_BIAS)
	node.enabled = enabled
	node.attack_time_seconds = clamp(attack_time_seconds, LFO_MIN_ATTACK_SECONDS, LFO_MAX_ATTACK_SECONDS)
	node.offset_normalized = lfoWrapPhase(offset_normalized)
	node.phase_normalized = 0
	node.attack_level = 1
	if !enabled {
		node.attack_level = 0
	}
	node.last_sample_rate = 48000

	node.attachToGraph = lfoNodeAttachToGraph
	node.setWaveTableByName = lfoNodeSetWaveTableByName
	node.setWaveTableType = lfoNodeSetWaveTableType
	node.getWaveTableType = lfoNodeGetWaveTableType
	node.setDepth = lfoNodeSetDepth
	node.getDepth = lfoNodeGetDepth
	node.setBias = lfoNodeSetBias
	node.getBias = lfoNodeGetBias
	node.setRateMode = lfoNodeSetRateMode
	node.getRateMode = lfoNodeGetRateMode
	node.setRateHz = lfoNodeSetRateHz
	node.getRateHz = lfoNodeGetRateHz
	node.setRateBeatTime = lfoNodeSetRateBeatTime
	node.getRateBeatTime = lfoNodeGetRateBeatTime
	node.setRateBeatDivision = lfoNodeSetRateBeatDivision
	node.getRateBeatDivision = lfoNodeGetRateBeatDivision
	node.setTempoBPM = lfoNodeSetTempoBPM
	node.getTempoBPM = lfoNodeGetTempoBPM
	node.setEnabled = lfoNodeSetEnabled
	node.isEnabled = lfoNodeIsEnabled
	node.setAttackTime = lfoNodeSetAttackTime
	node.getAttackTime = lfoNodeGetAttackTime
	node.setOffsetNormalized = lfoNodeSetOffsetNormalized
	node.setOffsetDegrees = lfoNodeSetOffsetDegrees
	node.getOffsetNormalized = lfoNodeGetOffsetNormalized

	_ = node.setWaveTableByName(node, wavetable_name)

	return node
}

lfoNodeAttachToGraph :: proc(node: ^LFONode, graph: ^AudioGraph) {
	node.node_id = graph->queueAddNode("lfo", 0, 1, lfoNodeProcess, cast(rawptr)node)
}

lfoNodeSetWaveTableByName :: proc(node: ^LFONode, name: string) -> bool {
	switch name {
	case "sine", "Sine", "SINE":
		node.setWaveTableType(node, .Sine)
		return true
	case "triangle", "Triangle", "TRIANGLE":
		node.setWaveTableType(node, .Triangle)
		return true
	case "saw", "Saw", "SAW":
		node.setWaveTableType(node, .Saw)
		return true
	case "square", "Square", "SQUARE":
		node.setWaveTableType(node, .Square)
		return true
	}
	return false
}

lfoNodeSetWaveTableType :: proc(node: ^LFONode, wavetable_type: WaveTableType) {
	node.wavetable_type = wavetable_type
	node.wavetables.type = wavetable_type
}

lfoNodeGetWaveTableType :: proc(node: ^LFONode) -> WaveTableType {
	return node.wavetable_type
}

lfoNodeSetDepth :: proc(node: ^LFONode, depth: f32) {
	node.depth = clamp(depth, LFO_MIN_DEPTH, LFO_MAX_DEPTH)
}

lfoNodeGetDepth :: proc(node: ^LFONode) -> f32 {
	return node.depth
}

lfoNodeSetBias :: proc(node: ^LFONode, bias: f32) {
	node.bias = clamp(bias, LFO_MIN_BIAS, LFO_MAX_BIAS)
}

lfoNodeGetBias :: proc(node: ^LFONode) -> f32 {
	return node.bias
}

lfoNodeSetRateMode :: proc(node: ^LFONode, mode: LFORateMode) {
	node.rate_mode = mode
}

lfoNodeGetRateMode :: proc(node: ^LFONode) -> LFORateMode {
	return node.rate_mode
}

lfoNodeSetRateHz :: proc(node: ^LFONode, hz: f32) {
	node.rate_hz = clamp(hz, LFO_MIN_RATE_HZ, LFO_MAX_RATE_HZ)
}

lfoNodeGetRateHz :: proc(node: ^LFONode) -> f32 {
	return node.rate_hz
}

lfoNodeSetRateBeatTime :: proc(node: ^LFONode, beat_time: LFOBeatTime) {
	node.rate_beat_time = beat_time
}

lfoNodeGetRateBeatTime :: proc(node: ^LFONode) -> LFOBeatTime {
	return node.rate_beat_time
}

lfoNodeSetRateBeatDivision :: proc(node: ^LFONode, division: string) -> bool {
	switch division {
	case "1/64":
		node.rate_beat_time = .N1_64
		return true
	case "1/32":
		node.rate_beat_time = .N1_32
		return true
	case "1/16":
		node.rate_beat_time = .N1_16
		return true
	case "1/8":
		node.rate_beat_time = .N1_8
		return true
	case "1/4":
		node.rate_beat_time = .N1_4
		return true
	case "1/2":
		node.rate_beat_time = .N1_2
		return true
	case "1/1":
		node.rate_beat_time = .N1
		return true
	case "2/1":
		node.rate_beat_time = .N2
		return true
	case "4/1":
		node.rate_beat_time = .N4
		return true
	case "8/1":
		node.rate_beat_time = .N8
		return true
	}
	return false
}

lfoNodeGetRateBeatDivision :: proc(node: ^LFONode) -> string {
	switch node.rate_beat_time {
	case .N1_64:
		return "1/64"
	case .N1_32:
		return "1/32"
	case .N1_16:
		return "1/16"
	case .N1_8:
		return "1/8"
	case .N1_4:
		return "1/4"
	case .N1_2:
		return "1/2"
	case .N1:
		return "1/1"
	case .N2:
		return "2/1"
	case .N4:
		return "4/1"
	case .N8:
		return "8/1"
	}
	return "1/4"
}

lfoNodeSetTempoBPM :: proc(node: ^LFONode, tempo_bpm: f32) {
	node.tempo_bpm = max(tempo_bpm, LFO_MIN_TEMPO_BPM)
}

lfoNodeGetTempoBPM :: proc(node: ^LFONode) -> f32 {
	return node.tempo_bpm
}

lfoNodeSetEnabled :: proc(node: ^LFONode, enabled: bool) {
	node.enabled = enabled
}

lfoNodeIsEnabled :: proc(node: ^LFONode) -> bool {
	return node.enabled
}

lfoNodeSetAttackTime :: proc(node: ^LFONode, attack_time_seconds: f32) {
	node.attack_time_seconds = clamp(attack_time_seconds, LFO_MIN_ATTACK_SECONDS, LFO_MAX_ATTACK_SECONDS)
}

lfoNodeGetAttackTime :: proc(node: ^LFONode) -> f32 {
	return node.attack_time_seconds
}

lfoNodeSetOffsetNormalized :: proc(node: ^LFONode, offset_normalized: f32) {
	node.offset_normalized = lfoWrapPhase(offset_normalized)
}

lfoNodeSetOffsetDegrees :: proc(node: ^LFONode, offset_degrees: f32) {
	node.offset_normalized = lfoWrapPhase(offset_degrees / 360.0)
}

lfoNodeGetOffsetNormalized :: proc(node: ^LFONode) -> f32 {
	return node.offset_normalized
}

lfoNodeProcess :: proc(graph: ^AudioGraph, graph_node: ^AudioNode, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int, midi_messages: []ShortMessage) {
	node := cast(^LFONode)graph_node.user_data
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

	sample_rate := engine_context.sample_rate
	if sample_rate == 0 {
		sample_rate = 48000
	}

	if node.last_sample_rate != sample_rate {
		node.wavetables = createWaveTables(sample_rate, node.wavetable_type, node.rate_hz)
		node.last_sample_rate = sample_rate
	}
	node.wavetables.type = node.wavetable_type

	rate_hz := node.rate_hz
	if node.rate_mode == .BeatTime {
		beats_per_cycle := lfoBeatTimeToQuarterNoteBeats(node.rate_beat_time)
		if beats_per_cycle > 0 {
			beats_per_second := node.tempo_bpm / 60.0
			rate_hz = beats_per_second / beats_per_cycle
		}
	}
	rate_hz = clamp(rate_hz, LFO_MIN_RATE_HZ, LFO_MAX_RATE_HZ)

	phase_step := rate_hz / f32(sample_rate)
	attack_step := f32(1.0)
	if node.attack_time_seconds > 0 {
		attack_samples := node.attack_time_seconds * f32(sample_rate)
		if attack_samples > 1 {
			attack_step = 1.0 / attack_samples
		}
	}

	phase := node.phase_normalized
	attack_level := node.attack_level

	for frame_index in 0..<frame_buffer_size {
		if node.enabled {
			if attack_level < 1.0 {
				attack_level = min(1.0, attack_level+attack_step)
			}
		} else {
			if attack_level > 0.0 {
				attack_level = max(0.0, attack_level-attack_step)
			}
		}

		value := f32(0)
		if attack_level > 0 {
			table_cursor := (lfoWrapPhase(phase+node.offset_normalized)) * f32(WAVETABLE_SIZE)
			wave := node.wavetables.interpolate(&node.wavetables, table_cursor)
			value = (wave*node.depth + node.bias) * attack_level
			value = clamp(value, -1.0, 1.0)
		}

		base := frame_index * channel_count
		out[base] = value
		for ch in 1..<channel_count {
			out[base+ch] = 0
		}

		phase = lfoWrapPhase(phase + phase_step)
	}

	node.phase_normalized = phase
	node.attack_level = attack_level
}

lfoWrapPhase :: proc(phase: f32) -> f32 {
	wrapped := math.mod_f32(phase, 1.0)
	if wrapped < 0 {
		wrapped += 1.0
	}
	return wrapped
}

lfoBeatTimeToQuarterNoteBeats :: proc(beat_time: LFOBeatTime) -> f32 {
	switch beat_time {
	case .N1_64:
		return 0.0625
	case .N1_32:
		return 0.125
	case .N1_16:
		return 0.25
	case .N1_8:
		return 0.5
	case .N1_4:
		return 1.0
	case .N1_2:
		return 2.0
	case .N1:
		return 4.0
	case .N2:
		return 8.0
	case .N4:
		return 16.0
	case .N8:
		return 32.0
	}
	return 1.0
}