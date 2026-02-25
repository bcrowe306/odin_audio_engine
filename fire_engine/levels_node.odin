package fire_engine

import "core:math"

LevelsNode :: struct {
    node_id: u64,
    peak_linear: []f32,
    rms_linear: []f32,
    peak_db: []f32,
    rms_db: []f32,

    attachToGraph: proc(node: ^LevelsNode, graph: ^AudioGraph),
    reset: proc(node: ^LevelsNode),
}

createLevelsNode :: proc() -> ^LevelsNode {
    node := new(LevelsNode)
    node.attachToGraph = levelsNodeAttachToGraph
    node.reset = levelsNodeReset
    return node
}

levelsNodeAttachToGraph :: proc(node: ^LevelsNode, graph: ^AudioGraph) {
    node.node_id = graph->queueAddNode("levels", 1, 1, levelsNodeProcess, cast(rawptr)node)
}

levelsNodeReset :: proc(node: ^LevelsNode) {
    if node == nil {
        return
    }
    for i in 0..<len(node.peak_linear) {
        node.peak_linear[i] = 0
        node.rms_linear[i] = 0
        node.peak_db[i] = -math.INF_F32
        node.rms_db[i] = -math.INF_F32
    }
}

levelsNodeEnsureCapacity :: proc(node: ^LevelsNode, channel_count: int) {
    cc := channel_count
    if cc < 1 {
        cc = 1
    }

    if len(node.peak_linear) != cc {
        node.peak_linear = make([]f32, cc)
        node.rms_linear = make([]f32, cc)
        node.peak_db = make([]f32, cc)
        node.rms_db = make([]f32, cc)
        levelsNodeReset(node)
    } else {
        levelsNodeReset(node)
    }
}

levelsNodeProcess :: proc(graph: ^AudioGraph, graph_node: ^AudioNode, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int, midi_messages: []ShortMessage) {
    node := cast(^LevelsNode)graph_node.user_data
    if node == nil {
        return
    }

    channel_count := int(engine_context.output_channel_count)
    if channel_count < 1 {
        channel_count = 1
    }

    levelsNodeEnsureCapacity(node, channel_count)

    sample_count := frame_buffer_size * channel_count
    out := graph->ensureOutputBuffer(graph_node, 0, sample_count)
    if len(out) != sample_count {
        return
    }

    input_len := 0
    if frame_buffer != nil {
        input_len = len(frame_buffer^)
    }

    // Copy input to output while collecting peak/RMS.
    for i in 0..<sample_count {
        sample := f32(0)
        if i < input_len {
            sample = frame_buffer^[i]
        }
        out[i] = sample

        ch := i % channel_count
        abs_sample := math.abs(sample)
        if abs_sample > node.peak_linear[ch] {
            node.peak_linear[ch] = abs_sample
        }
        node.rms_linear[ch] += sample * sample
    }

    frames_with_input := frame_buffer_size
    if channel_count > 0 && input_len/channel_count < frames_with_input {
        frames_with_input = input_len / channel_count
    }

    for ch in 0..<channel_count {
        if frames_with_input > 0 {
            node.rms_linear[ch] = math.sqrt(node.rms_linear[ch] / f32(frames_with_input))
        } else {
            node.rms_linear[ch] = 0
        }

        if node.peak_linear[ch] > 0.0 {
            node.peak_db[ch] = 20.0 * math.log10(node.peak_linear[ch])
        } else {
            node.peak_db[ch] = -math.INF_F32
        }

        if node.rms_linear[ch] > 0.0 {
            node.rms_db[ch] = 20.0 * math.log10(node.rms_linear[ch])
        } else {
            node.rms_db[ch] = -math.INF_F32
        }
    }
}