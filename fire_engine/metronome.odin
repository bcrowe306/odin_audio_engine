package fire_engine

Metronome :: struct {
    node_id: u64,
    metronome_sample_node: ^AudioSampleNode,
    gain_node: ^GainNode,
    levels_node: ^LevelsNode,
    enabled: ^BoolParameter,
    metronome_volume: ^DbParameter,
    beat_volume: ^DbParameter,
    bar_volume: ^DbParameter,
    current_tick_type: TickType,
    attachToGraph: proc(node: ^Metronome, graph: ^AudioGraph),
}

metronomeEffectiveGainDB :: proc(node: ^Metronome, tick_type: TickType) -> f32 {
    if node == nil {
        return 0.0
    }

    accent_db := node.beat_volume.value
    if tick_type == .Bar {
        accent_db = node.bar_volume.value
    }

    return node.metronome_volume.value + accent_db
}

metronomeApplyGainForTickType :: proc(node: ^Metronome, tick_type: TickType) {
    if node == nil || node.gain_node == nil {
        return
    }
    node.gain_node->setGainDB(metronomeEffectiveGainDB(node, tick_type))
}

metronomeVolumeParameterChanged :: proc(value: any, user_data: rawptr = nil) {
    node := cast(^Metronome)user_data
    if node == nil {
        return
    }
    metronomeApplyGainForTickType(node, node.current_tick_type)
}

metronomeBeatVolumeParameterChanged :: proc(value: any, user_data: rawptr = nil) {
    node := cast(^Metronome)user_data
    if node == nil {
        return
    }
    metronomeApplyGainForTickType(node, node.current_tick_type)
}

metronomeBarVolumeParameterChanged :: proc(value: any, user_data: rawptr = nil) {
    node := cast(^Metronome)user_data
    if node == nil {
        return
    }
    metronomeApplyGainForTickType(node, node.current_tick_type)
}

createMetronomeNode :: proc(fe: ^FireEngine) -> ^Metronome {
    node := new(Metronome)
    node.metronome_sample_node = createAudioSampleNode(fe.audio_engine, "metronome.wav", true, false)
    node.gain_node = createGainNode()
    node.levels_node = createLevelsNode()
    node.enabled = createBoolParameter(fe.command_controller, "Metronome Enabled", true)
    node.metronome_volume = createDbParameter(fe.command_controller, "Metronome Volume", 0.0)
    node.beat_volume = createDbParameter(fe.command_controller, "Beat Volume", 0.0)
    node.bar_volume = createDbParameter(fe.command_controller, "Bar Volume", 0.0)
    node.current_tick_type = .Beat
    node.attachToGraph = metronomeNodeAttachToGraph

    signalConnect(node.metronome_volume.onChange, metronomeVolumeParameterChanged, cast(rawptr)node)
    signalConnect(node.beat_volume.onChange, metronomeBeatVolumeParameterChanged, cast(rawptr)node)
    signalConnect(node.bar_volume.onChange, metronomeBarVolumeParameterChanged, cast(rawptr)node)

    signalConnect(fe.audio_engine.playhead.onTick, metronomeOnPlayheadTick, cast(rawptr)node)

    // Set default levels
    node.metronome_volume->set(-12.0)
    node.beat_volume->set(-9.0)
    node.bar_volume->set(0.0)
    return node
}

metronomeOnPlayheadTick :: proc(value: any, user_data: rawptr) {
    node := cast(^Metronome)user_data
    tick_event := value.(TickEvent)
    if node == nil || node.metronome_sample_node == nil || !node.enabled.value {
        return
    }
    if node.enabled->get() {

        if tick_event.type == .Bar {
            node.current_tick_type = .Bar
            metronomeApplyGainForTickType(node, .Bar)
            node.metronome_sample_node->setRateFromMidiNote(60) // C2 for bar
            node.metronome_sample_node->play(u32(tick_event.frame_offset))
        } else if tick_event.type == .Beat {
            node.current_tick_type = .Beat
            metronomeApplyGainForTickType(node, .Beat)
            node.metronome_sample_node->setRateFromMidiNote(55) // C3 for beat
            node.metronome_sample_node->play(u32(tick_event.frame_offset))
        }
    }
}

metronomeNodeAttachToGraph :: proc(node: ^Metronome, graph: ^AudioGraph) {
    if node == nil || node.metronome_sample_node == nil || node.gain_node == nil || node.levels_node == nil {
        return
    }

    node.metronome_sample_node->attachToGraph(graph)
    node.gain_node->attachToGraph(graph)
    node.levels_node->attachToGraph(graph)

    graph->queueConnect(node.metronome_sample_node.node_id, 0, node.gain_node.node_id, 0)
    graph->queueConnect(node.gain_node.node_id, 0, node.levels_node.node_id, 0)

    metronomeApplyGainForTickType(node, node.current_tick_type)
    node.node_id = node.levels_node.node_id
}

