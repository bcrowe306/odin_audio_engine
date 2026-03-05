package fire_engine

import "core:encoding/uuid"
import "core:crypto"

// TODO: Build out default node graph structure for tracks
// TODO: Complete midi routing. Need to route midi to tracks and tracks to instruments. 
// TODO: Could arm track on selection and insure track is selected on pad press before sending midi messages to the track's instrument. This will likely require a more robust node graph structure for tracks and instruments, as well as a way to route midi messages to specific tracks and instruments.
// This will likely require a more robust node graph structure for tracks and instruments, as well as a way to route midi messages to specific tracks and instruments.

TrackType :: enum {
    Audio,
    Midi,
    Instrument,
}

TrackPassthroughNode :: struct {
    node_id: u64,

    attachToGraph: proc(node: ^TrackPassthroughNode, graph: ^AudioGraph),
}

createTrackPassthroughNode :: proc() -> ^TrackPassthroughNode {
    node := new(TrackPassthroughNode)
    node.attachToGraph = trackPassthroughNodeAttachToGraph
    return node
}

trackPassthroughNodeAttachToGraph :: proc(node: ^TrackPassthroughNode, graph: ^AudioGraph) {
    node.node_id = graph->queueAddNode("track_device_passthrough", 1, 1, trackPassthroughNodeProcess, cast(rawptr)node)
}

trackPassthroughNodeProcess :: proc(graph: ^AudioGraph, graph_node: ^AudioNode, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int, midi_messages: []ShortMessage) {
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
}

Track :: struct {
    fe: ^FireEngine,
    id: uuid.Identifier,
    name: string,
    type: TrackType,
    parameters: []^Parameter,
    device: ^Instrument,
    volume: ^Float32Parameter,
    pan: ^Float32Parameter,
    mute: ^BoolParameter,
    solo: ^BoolParameter,
    arm: ^BoolParameter,

    device_passthrough_node: ^TrackPassthroughNode,
    volume_node: ^GainNode,
    pan_node: ^PanNode,
    levels_node: ^LevelsNode,
    mute_node: ^MuteNode,
}

trackVolumeParameterChanged :: proc(value: any, user_data: rawptr = nil) {
    track := cast(^Track)user_data
    if track == nil || track.volume_node == nil {
        return
    }
    gain_db, ok := value.(f32)
    if !ok {
        return
    }
    track.volume_node->setGainDB(gain_db)
}

trackPanParameterChanged :: proc(value: any, user_data: rawptr = nil) {
    track := cast(^Track)user_data
    if track == nil || track.pan_node == nil {
        return
    }
    pan_value, ok := value.(f32)
    if !ok {
        return
    }
    track.pan_node->setPan(pan_value)
}

trackMuteParameterChanged :: proc(value: any, user_data: rawptr = nil) {
    track := cast(^Track)user_data
    if track == nil || track.mute_node == nil {
        return
    }
    mute_value, ok := value.(bool)
    if !ok {
        return
    }
    track.mute_node->setMuted(mute_value)
}

trackCreateNodeChain :: proc(track: ^Track) {
    if track == nil || track.fe == nil || track.fe.audio_engine == nil || track.fe.audio_engine.audio_graph == nil {
        return
    }

    graph := track.fe.audio_engine.audio_graph

    track.device_passthrough_node = createTrackPassthroughNode()
    track.volume_node = createGainNode()
    track.pan_node = createPanNode()
    track.levels_node = createLevelsNode()
    track.mute_node = createMuteNode()

    track.device_passthrough_node->attachToGraph(graph)
    track.volume_node->attachToGraph(graph)
    track.pan_node->attachToGraph(graph)
    track.levels_node->attachToGraph(graph)
    track.mute_node->attachToGraph(graph)

    track.volume_node->setGainDB(track.volume.value)
    track.pan_node->setPan(track.pan.value)
    track.mute_node->setMuted(track.mute.value)

    graph->queueConnect(track.device_passthrough_node.node_id, 0, track.volume_node.node_id, 0)
    graph->queueConnect(track.volume_node.node_id, 0, track.pan_node.node_id, 0)
    graph->queueConnect(track.pan_node.node_id, 0, track.levels_node.node_id, 0)
    graph->queueConnect(track.levels_node.node_id, 0, track.mute_node.node_id, 0)
    graph->connectToEndpoint(track.mute_node.node_id)

    signalConnect(track.volume.onChange, trackVolumeParameterChanged, cast(rawptr)track)
    signalConnect(track.pan.onChange, trackPanParameterChanged, cast(rawptr)track)
    signalConnect(track.mute.onChange, trackMuteParameterChanged, cast(rawptr)track)
}


createTrack :: proc(fe: ^FireEngine, name: string, type: TrackType = TrackType.Instrument) -> ^Track {
    context.random_generator = crypto.random_generator()
    new_track := new(Track)
    new_track.fe = fe
    new_track.id = uuid.generate_v4()
    new_track.name = name
    new_track.type = type
    new_track.volume = createFloatParameter(fe.command_controller, "Volume", 0.0, -60.0, 6.0)
    new_track.pan = createFloatParameter(fe.command_controller, "Pan", 0.0, -1.0, 1.0)
    new_track.mute = createBoolParameter(fe.command_controller, "Mute", false)
    new_track.solo = createBoolParameter(fe.command_controller, "Solo", false)
    new_track.arm = createBoolParameter(fe.command_controller, "Arm", false)
    new_track.parameters = []^Parameter{
        new_track.volume, 
        new_track.pan, 
        new_track.mute, 
        new_track.solo,
        new_track.arm,
    }

    trackCreateNodeChain(new_track)
    return new_track
}