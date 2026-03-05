package fire_engine
import "core:math"
import "core:fmt"


MIDI_NOTE_A4 :: 69.0
MIDI_FREQ_A4 :: 440.0
MIDI_NOTE_C4 :: 60.0
MIDI_FREQ_C4 :: 261.6255653005986

AudioSampleNode :: struct {
	engine: ^AudioEngine,
	node_id: u64,
	path: string,

	start_normalized: f32,
	end_normalized: f32,
	looping: bool,
	playing: bool,
	offset_frames: u32,
	rate_ratio: f64,
	read_cursor: f64,

	// Methods
	attachToGraph: proc(node: ^AudioSampleNode, graph: ^AudioGraph),
	releaseResource: proc(node: ^AudioSampleNode),

	setStartNormalized: proc(node: ^AudioSampleNode, normalized: f32),
	setEndNormalized: proc(node: ^AudioSampleNode, normalized: f32),
	setLooping: proc(node: ^AudioSampleNode, looping: bool),
	setPlaying: proc(node: ^AudioSampleNode, playing: bool),
	isPlaying: proc(node: ^AudioSampleNode) -> bool,
	play: proc(node: ^AudioSampleNode, offset_frames: u32 = 0),

	setRateRatio: proc(node: ^AudioSampleNode, ratio: f64),
	setRateFromMidiNote: proc(node: ^AudioSampleNode, midi_note: f64),

	setReadCursor: proc(node: ^AudioSampleNode, frame: f64),
	getReadCursor: proc(node: ^AudioSampleNode) -> f64,
	process: AudioNodeProcessProc,
}
// This node is responsible for playing back an audio sample loaded from a file. It supports setting a playback range, looping, and adjusting the playback rate. The node reads audio data from the engine's resource manager and outputs it to the audio graph. It also processes incoming MIDI messages, which can be used for triggering playback or modulating parameters in the future.
createAudioSampleNode :: proc(engine: ^AudioEngine, path: string, async: bool = true, looping: bool = false) -> ^AudioSampleNode {
	node := new(AudioSampleNode)
	node.engine = engine
	node.path = path
	node.start_normalized = 0.0
	node.end_normalized = 1.0
	node.looping = looping
	node.playing = false
	node.offset_frames = 0
	node.rate_ratio = 1.0
	node.read_cursor = 0.0

	node.attachToGraph = audioSampleNodeAttachToGraph
	node.releaseResource = audioSampleNodeReleaseResource
	node.setStartNormalized = audioSampleNodeSetStartNormalized
	node.setEndNormalized = audioSampleNodeSetEndNormalized
	node.setLooping = audioSampleNodeSetLooping
	node.setPlaying = audioSampleNodeSetPlaying
	node.isPlaying = audioSampleNodeIsPlaying
	node.play = audioSampleNodePlay
	node.setRateRatio = audioSampleNodeSetRateRatio
	node.setRateFromMidiNote = audioSampleNodeSetRateFromMidiNote
	node.setReadCursor = audioSampleNodeSetReadCursor
	node.getReadCursor = audioSampleNodeGetReadCursor
	node.releaseResource = audioSampleNodeReleaseResource
	node.process = audioSampleNodeProcess

	if engine != nil {
		engine->loadWave(path, async)
	}

	return node
}

audioSampleNodeAttachToGraph :: proc(node: ^AudioSampleNode, graph: ^AudioGraph) {
	node.node_id = graph->queueAddNode("audio_sample", 0, 1, audioSampleNodeProcess, cast(rawptr)node)
}

audioSampleNodeReleaseResource :: proc(node: ^AudioSampleNode) {
	if node.engine == nil {
		return
	}
	_ = node.engine->releaseWave(node.path)
}

audioSampleNodeSetStartNormalized :: proc(node: ^AudioSampleNode, normalized: f32) {
	node.start_normalized = clamp(normalized, 0.0, 1.0)
	if node.end_normalized < node.start_normalized {
		node.end_normalized = node.start_normalized
	}
}

audioSampleNodeSetEndNormalized :: proc(node: ^AudioSampleNode, normalized: f32) {
	node.end_normalized = clamp(normalized, 0.0, 1.0)
	if node.end_normalized < node.start_normalized {
		node.start_normalized = node.end_normalized
	}
}

audioSampleNodeSetLooping :: proc(node: ^AudioSampleNode, looping: bool) {
	node.looping = looping
}

audioSampleNodeSetPlaying :: proc(node: ^AudioSampleNode, playing: bool) {
	node.playing = playing
}

audioSampleNodeIsPlaying :: proc(node: ^AudioSampleNode) -> bool {
	return node.playing
}

audioSampleNodePlay :: proc(node: ^AudioSampleNode, offset_frames: u32 = 0) {
	node.playing = true
	node.offset_frames = offset_frames
	node.read_cursor = 0
}

audioSampleNodeSetRateRatio :: proc(node: ^AudioSampleNode, ratio: f64) {
	if ratio <= 0 {
		node.rate_ratio = 0.0001
		return
	}
	node.rate_ratio = ratio
}

audioSampleNodeSetRateFromMidiNote :: proc(node: ^AudioSampleNode, midi_note: f64) {
	hz := midiNoteToHz(midi_note)
	audioSampleNodeSetRateRatio(node, hz / MIDI_FREQ_C4)
}

audioSampleNodeSetReadCursor :: proc(node: ^AudioSampleNode, frame: f64) {
	if frame < 0 {
		node.read_cursor = 0
		return
	}
	node.read_cursor = frame
}

audioSampleNodeGetReadCursor :: proc(node: ^AudioSampleNode) -> f64 {
	return node.read_cursor
}

audioSampleNodeProcess :: proc(graph: ^AudioGraph, graph_node: ^AudioNode, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int, midi_messages: []ShortMessage) {
	sample_node := cast(^AudioSampleNode)graph_node.user_data
	if sample_node == nil || sample_node.engine == nil {
		return
	}

	channel_count := int(engine_context.output_channel_count)
	if channel_count < 1 {
		channel_count = 1
	}

    // Ensure output buffer is the correct size for the current render block and channel count.
	sample_count := frame_buffer_size * channel_count
	out := graph->ensureOutputBuffer(graph_node, 0, sample_count)
	if len(out) != sample_count {
		return
	}

	// Check if the sample is ready before processing.
	if sample_node.engine->getWaveStatus(sample_node.path) != .Ready {
		return
	}

    // Clear output buffer before rendering.
	for i in 0..<sample_count {
		out[i] = 0
	}

	
	// Get the audio data for the sample. This should be fast since it should already be loaded in memory by the resource manager.
	audio, ok := sample_node.engine->getWaveAudio(sample_node.path)
	if !ok || audio == nil || audio.frames <= 0 || len(audio.samples) == 0 {
		return
	}

	source_channels := int(audio.channels)
	if source_channels < 1 {
		return
	}

	start_frame, end_frame := audioSampleNodePlaybackRange(sample_node, audio.frames)
	if end_frame <= start_frame {
		return
	}
	
	if !sample_node.playing {
		return
	}

	cursor := sample_node.read_cursor
	if cursor < f64(start_frame) {
		cursor = f64(start_frame)
	}
    if cursor >= f64(end_frame) {
        if sample_node.looping {
            cursor = f64(start_frame)
        } else {
            cursor = f64(end_frame)
			sample_node.playing = false
			sample_node.read_cursor = cursor
			return
        }
    }
	render_offset := int(sample_node.offset_frames)
	if render_offset < 0 {
		render_offset = 0
	}
	if render_offset > frame_buffer_size {
		render_offset = frame_buffer_size
	}
	// Offset is only for the current render block.
	sample_node.offset_frames = 0

	for frame_index in render_offset..<frame_buffer_size {
		if cursor >= f64(end_frame) {
			if sample_node.looping {
				cursor = f64(start_frame)
			} else {
				sample_node.playing = false
				cursor = f64(end_frame)
				break
			}
		}

		left_frame := int(math.floor(cursor))
		if left_frame < start_frame {
			left_frame = start_frame
		}
		if left_frame >= end_frame {
			left_frame = end_frame - 1
		}
		right_frame := left_frame + 1
		if right_frame >= end_frame {
			right_frame = end_frame - 1
		}
		frac := f32(cursor - f64(left_frame))

		base_out := frame_index * channel_count
		base_left := left_frame * source_channels
		base_right := right_frame * source_channels

		for ch in 0..<channel_count {
			src_ch := ch
			if src_ch >= source_channels {
				src_ch = source_channels - 1
			}

			left := audio.samples[base_left+src_ch]
			right := audio.samples[base_right+src_ch]
			out[base_out+ch] = left + (right-left)*frac
		}

		cursor += sample_node.rate_ratio
	}

	sample_node.read_cursor = cursor
}

audioSampleNodePlaybackRange :: proc(node: ^AudioSampleNode, total_frames: int) -> (start_frame: int, end_frame: int) {
	if total_frames <= 0 {
		return 0, 0
	}

	start_frame = int(f64(total_frames) * f64(node.start_normalized))
	end_frame = int(f64(total_frames) * f64(node.end_normalized))

	if start_frame < 0 {
		start_frame = 0
	}
	if start_frame >= total_frames {
		start_frame = total_frames - 1
	}
	if end_frame <= start_frame {
		end_frame = start_frame + 1
	}
	if end_frame > total_frames {
		end_frame = total_frames
	}

	return
}

midiNoteToHz :: proc(midi_note: f64) -> f64 {
	return MIDI_FREQ_A4 * math.pow(2.0, (midi_note-MIDI_NOTE_A4)/12.0)
}
