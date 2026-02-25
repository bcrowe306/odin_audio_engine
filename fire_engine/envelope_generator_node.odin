package main

import "core:math"

ENVELOPE_MIN_ATTACK_SECONDS :: f32(0.0)
ENVELOPE_MAX_ATTACK_SECONDS :: f32(20.0)
ENVELOPE_MIN_DECAY_SECONDS :: f32(0.001)
ENVELOPE_MAX_DECAY_SECONDS :: f32(60.0)
ENVELOPE_MIN_RELEASE_SECONDS :: f32(0.001)
ENVELOPE_MAX_RELEASE_SECONDS :: f32(60.0)
ENVELOPE_MIN_SUSTAIN_LINEAR :: f32(0.0)
ENVELOPE_MAX_SUSTAIN_LINEAR :: f32(1.0)
ENVELOPE_MIN_SUSTAIN_DB :: f32(-120.0)
ENVELOPE_MAX_SUSTAIN_DB :: f32(0.0)

EnvelopeGeneratorStage :: enum {
	Idle,
	Attack,
	Decay,
	Sustain,
	Release,
}

EnvelopeGeneratorNode :: struct {
	node_id: u64,
	attack_seconds: f32,
	decay_seconds: f32,
	sustain_linear: f32,
	release_seconds: f32,

	current_value: f32,
	release_start_value: f32,
	stage: EnvelopeGeneratorStage,
	gate_open: bool,

	attachToGraph: proc(node: ^EnvelopeGeneratorNode, graph: ^AudioGraph),
	setAttack: proc(node: ^EnvelopeGeneratorNode, seconds: f32),
	getAttack: proc(node: ^EnvelopeGeneratorNode) -> f32,
	setDecay: proc(node: ^EnvelopeGeneratorNode, seconds: f32),
	getDecay: proc(node: ^EnvelopeGeneratorNode) -> f32,
	setSustain: proc(node: ^EnvelopeGeneratorNode, sustain: f32),
	getSustain: proc(node: ^EnvelopeGeneratorNode) -> f32,
	setSustainDB: proc(node: ^EnvelopeGeneratorNode, sustain_db: f32),
	getSustainDB: proc(node: ^EnvelopeGeneratorNode) -> f32,
	setRelease: proc(node: ^EnvelopeGeneratorNode, seconds: f32),
	getRelease: proc(node: ^EnvelopeGeneratorNode) -> f32,
	noteOn: proc(node: ^EnvelopeGeneratorNode),
	noteOff: proc(node: ^EnvelopeGeneratorNode),
	reset: proc(node: ^EnvelopeGeneratorNode),
	getStage: proc(node: ^EnvelopeGeneratorNode) -> EnvelopeGeneratorStage,
	getValue: proc(node: ^EnvelopeGeneratorNode) -> f32,
}

createEnvelopeGeneratorNode :: proc(
	attack_seconds: f32 = 0.01,
	decay_seconds: f32 = 0.1,
	sustain_linear: f32 = 0.8,
	release_seconds: f32 = 0.2,
) -> ^EnvelopeGeneratorNode {
	node := new(EnvelopeGeneratorNode)
	node.attack_seconds = clamp(attack_seconds, ENVELOPE_MIN_ATTACK_SECONDS, ENVELOPE_MAX_ATTACK_SECONDS)
	node.decay_seconds = clamp(decay_seconds, ENVELOPE_MIN_DECAY_SECONDS, ENVELOPE_MAX_DECAY_SECONDS)
	node.sustain_linear = clamp(sustain_linear, ENVELOPE_MIN_SUSTAIN_LINEAR, ENVELOPE_MAX_SUSTAIN_LINEAR)
	node.release_seconds = clamp(release_seconds, ENVELOPE_MIN_RELEASE_SECONDS, ENVELOPE_MAX_RELEASE_SECONDS)
	node.current_value = 0
	node.release_start_value = 0
	node.stage = .Idle
	node.gate_open = false

	node.attachToGraph = envelopeGeneratorNodeAttachToGraph
	node.setAttack = envelopeGeneratorNodeSetAttack
	node.getAttack = envelopeGeneratorNodeGetAttack
	node.setDecay = envelopeGeneratorNodeSetDecay
	node.getDecay = envelopeGeneratorNodeGetDecay
	node.setSustain = envelopeGeneratorNodeSetSustain
	node.getSustain = envelopeGeneratorNodeGetSustain
	node.setSustainDB = envelopeGeneratorNodeSetSustainDB
	node.getSustainDB = envelopeGeneratorNodeGetSustainDB
	node.setRelease = envelopeGeneratorNodeSetRelease
	node.getRelease = envelopeGeneratorNodeGetRelease
	node.noteOn = envelopeGeneratorNodeNoteOn
	node.noteOff = envelopeGeneratorNodeNoteOff
	node.reset = envelopeGeneratorNodeReset
	node.getStage = envelopeGeneratorNodeGetStage
	node.getValue = envelopeGeneratorNodeGetValue

	return node
}

envelopeGeneratorNodeAttachToGraph :: proc(node: ^EnvelopeGeneratorNode, graph: ^AudioGraph) {
	node.node_id = graph->queueAddNode("envelope_generator", 0, 1, envelopeGeneratorNodeProcess, cast(rawptr)node)
}

envelopeGeneratorNodeSetAttack :: proc(node: ^EnvelopeGeneratorNode, seconds: f32) {
	node.attack_seconds = clamp(seconds, ENVELOPE_MIN_ATTACK_SECONDS, ENVELOPE_MAX_ATTACK_SECONDS)
}

envelopeGeneratorNodeGetAttack :: proc(node: ^EnvelopeGeneratorNode) -> f32 {
	return node.attack_seconds
}

envelopeGeneratorNodeSetDecay :: proc(node: ^EnvelopeGeneratorNode, seconds: f32) {
	node.decay_seconds = clamp(seconds, ENVELOPE_MIN_DECAY_SECONDS, ENVELOPE_MAX_DECAY_SECONDS)
}

envelopeGeneratorNodeGetDecay :: proc(node: ^EnvelopeGeneratorNode) -> f32 {
	return node.decay_seconds
}

envelopeGeneratorNodeSetSustain :: proc(node: ^EnvelopeGeneratorNode, sustain: f32) {
	node.sustain_linear = clamp(sustain, ENVELOPE_MIN_SUSTAIN_LINEAR, ENVELOPE_MAX_SUSTAIN_LINEAR)
}

envelopeGeneratorNodeGetSustain :: proc(node: ^EnvelopeGeneratorNode) -> f32 {
	return node.sustain_linear
}

envelopeGeneratorNodeSetSustainDB :: proc(node: ^EnvelopeGeneratorNode, sustain_db: f32) {
	clamped_db := clamp(sustain_db, ENVELOPE_MIN_SUSTAIN_DB, ENVELOPE_MAX_SUSTAIN_DB)
	node.sustain_linear = f32(math.pow(10.0, f64(clamped_db)/20.0))
}

envelopeGeneratorNodeGetSustainDB :: proc(node: ^EnvelopeGeneratorNode) -> f32 {
	if node.sustain_linear <= 0 {
		return ENVELOPE_MIN_SUSTAIN_DB
	}
	db := f32(20.0 * math.log10(f64(node.sustain_linear)))
	if db < ENVELOPE_MIN_SUSTAIN_DB {
		return ENVELOPE_MIN_SUSTAIN_DB
	}
	if db > ENVELOPE_MAX_SUSTAIN_DB {
		return ENVELOPE_MAX_SUSTAIN_DB
	}
	return db
}

envelopeGeneratorNodeSetRelease :: proc(node: ^EnvelopeGeneratorNode, seconds: f32) {
	node.release_seconds = clamp(seconds, ENVELOPE_MIN_RELEASE_SECONDS, ENVELOPE_MAX_RELEASE_SECONDS)
}

envelopeGeneratorNodeGetRelease :: proc(node: ^EnvelopeGeneratorNode) -> f32 {
	return node.release_seconds
}

envelopeGeneratorNodeNoteOn :: proc(node: ^EnvelopeGeneratorNode) {
	node.gate_open = true
	node.stage = .Attack
}

envelopeGeneratorNodeNoteOff :: proc(node: ^EnvelopeGeneratorNode) {
	node.gate_open = false
	node.release_start_value = node.current_value
	node.stage = .Release
}

envelopeGeneratorNodeReset :: proc(node: ^EnvelopeGeneratorNode) {
	node.current_value = 0
	node.release_start_value = 0
	node.gate_open = false
	node.stage = .Idle
}

envelopeGeneratorNodeGetStage :: proc(node: ^EnvelopeGeneratorNode) -> EnvelopeGeneratorStage {
	return node.stage
}

envelopeGeneratorNodeGetValue :: proc(node: ^EnvelopeGeneratorNode) -> f32 {
	return node.current_value
}

envelopeGeneratorNodeProcess :: proc(graph: ^AudioGraph, graph_node: ^AudioNode, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int) {
	node := cast(^EnvelopeGeneratorNode)graph_node.user_data
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

	sample_rate := f32(engine_context.sample_rate)
	if sample_rate <= 0 {
		sample_rate = 48000
	}

	value := node.current_value
	release_start := node.release_start_value
	stage := node.stage

	for frame_index in 0..<frame_buffer_size {
		switch stage {
		case .Idle:
			value = 0

		case .Attack:
			if node.attack_seconds <= 0 {
				value = 1
				stage = .Decay
			} else {
				step := f32(1.0) / (node.attack_seconds * sample_rate)
				value += step
				if value >= 1.0 {
					value = 1.0
					stage = .Decay
				}
			}

		case .Decay:
			target := node.sustain_linear
			if node.decay_seconds <= 0 {
				value = target
				stage = .Sustain
			} else {
				step := (f32(1.0) - target) / (node.decay_seconds * sample_rate)
				value -= step
				if value <= target {
					value = target
					stage = .Sustain
				}
			}

		case .Sustain:
			value = node.sustain_linear
			if !node.gate_open {
				release_start = value
				stage = .Release
			}

		case .Release:
			if node.release_seconds <= 0 {
				value = 0
				stage = .Idle
			} else {
				step := release_start / (node.release_seconds * sample_rate)
				value -= step
				if value <= 0 {
					value = 0
					stage = .Idle
				}
			}
		}

		value = clamp(value, 0.0, 1.0)
		base := frame_index * channel_count
		out[base] = value
		for ch in 1..<channel_count {
			out[base+ch] = 0
		}
	}

	node.current_value = value
	node.release_start_value = release_start
	node.stage = stage
}