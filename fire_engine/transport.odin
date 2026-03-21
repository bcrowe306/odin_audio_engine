package fire_engine

Transport :: struct {
    playhead: ^PlayheadNode,
    tempo: ^Float32Parameter,
    time_signature_numerator: ^IntParameter,
    time_signature_denominator: ^IntParameter,
    precount: ^IntParameter,
    loop_enabled: ^BoolParameter,
    play: proc (node: ^Transport),
    record: proc (node: ^Transport),
    pause: proc (node: ^Transport),
    stop: proc (node: ^Transport),
    togglePlay: proc (node: ^Transport),
    toggleRecord: proc (node: ^Transport),
    toggleLoop: proc (node: ^Transport),
    getSongPosition: proc(node: ^Transport) -> SongPosition,
    setSongPosition: proc(node: ^Transport, position: SongPosition),
    isPlaying: proc(node: ^Transport) -> bool,
    isPaused: proc(node: ^Transport) -> bool,
    isRecording: proc(node: ^Transport) -> bool,
    isPrecounting: proc(node: ^Transport) -> bool,
    isLooping: proc(node: ^Transport) -> bool,
}

createTransportNode :: proc(fe: ^FireEngine) -> ^Transport {
    node := new(Transport)
    if fe == nil || fe.audio_engine == nil {
        return node
    }

    node.playhead = fe.audio_engine.playhead
    // Tempo Param setup
    node.tempo = createFloatParameter(fe.command_controller, "Tempo", 120.0, 20.0, 300.0)
    node.tempo.step = 1.0
    node.tempo.small_step = .01
    
    node.time_signature_numerator = createIntParameter(fe.command_controller, "Time Signature Numerator", 4, 1, 16)
    node.time_signature_denominator = createIntParameter(fe.command_controller, "Time Signature Denominator", 4, 1, 16)
    node.precount = createIntParameter(fe.command_controller, "Precount", 0, 0, 16)
    node.loop_enabled = createBoolParameter(fe.command_controller, "Loop Enabled", false)
    node.play = Transport_Play
    node.record = Transport_Record
    node.pause = Transport_Pause
    node.stop = Transport_Stop
    node.togglePlay = Transport_TogglePlay
    node.toggleRecord = Transport_ToggleRecord
    node.toggleLoop = Transport_ToggleLoop
    node.getSongPosition = Transport_GetSongPosition
    node.setSongPosition = Transport_SetSongPosition
    node.isPlaying = Transport_IsPlaying
    node.isPaused = Transport_IsPaused
    node.isRecording = Transport_IsRecording
    node.isPrecounting = Transport_IsPrecounting
    node.isLooping = Transport_IsLooping

    signalConnect(node.tempo.onChange, transportTempoParameterChanged, cast(rawptr)node)
    signalConnect(node.time_signature_numerator.onChange, transportTimeSignatureNumeratorParameterChanged, cast(rawptr)node)
    signalConnect(node.time_signature_denominator.onChange, transportTimeSignatureDenominatorParameterChanged, cast(rawptr)node)
    signalConnect(node.precount.onChange, transportPrecountParameterChanged, cast(rawptr)node)
    signalConnect(node.loop_enabled.onChange, transportLoopEnabledParameterChanged, cast(rawptr)node)

    // Push initial parameter values to playhead so transport and playhead are in sync at startup.
    transportTempoParameterChanged(node.tempo.value, cast(rawptr)node)
    transportTimeSignatureNumeratorParameterChanged(node.time_signature_numerator.value, cast(rawptr)node)
    transportTimeSignatureDenominatorParameterChanged(node.time_signature_denominator.value, cast(rawptr)node)
    transportPrecountParameterChanged(node.precount.value, cast(rawptr)node)
    transportLoopEnabledParameterChanged(node.loop_enabled.value, cast(rawptr)node)

    return node
}

transportTempoParameterChanged :: proc(value: any, user_data: rawptr = nil) {
    node := cast(^Transport)user_data
    if node == nil || node.playhead == nil {
        return
    }

    node.playhead->setTempo(f64(node.tempo.value))
}

transportTimeSignatureNumeratorParameterChanged :: proc(value: any, user_data: rawptr = nil) {
    node := cast(^Transport)user_data
    if node == nil || node.playhead == nil {
        return
    }

    node.playhead.time_signature.numerator = u32(max(1, node.time_signature_numerator.value))
    node.playhead->setTempo(node.playhead.tempo)
}

transportTimeSignatureDenominatorParameterChanged :: proc(value: any, user_data: rawptr = nil) {
    node := cast(^Transport)user_data
    if node == nil || node.playhead == nil {
        return
    }

    node.playhead.time_signature.denominator = u32(max(1, node.time_signature_denominator.value))
    node.playhead->setTempo(node.playhead.tempo)
}

transportPrecountParameterChanged :: proc(value: any, user_data: rawptr = nil) {
    node := cast(^Transport)user_data
    if node == nil || node.playhead == nil {
        return
    }

    bars := max(0, node.precount.value)
    node.playhead.precount_bars = u32(bars)
    node.playhead.precount_enabled = bars > 0
}

transportLoopEnabledParameterChanged :: proc(value: any, user_data: rawptr = nil) {
    node := cast(^Transport)user_data
    if node == nil || node.playhead == nil {
        return
    }

    node.playhead.looping = node.loop_enabled.value
}

Transport_Play :: proc(node: ^Transport) {
    if node == nil || node.playhead == nil {
        return
    }
    node.playhead->setState(.Playing)
}

Transport_Record :: proc(node: ^Transport) {
    if node == nil || node.playhead == nil {
        return
    }

    node.playhead->setState(.Recording)
    
}

Transport_Pause :: proc(node: ^Transport) {
    if node == nil || node.playhead == nil {
        return
    }
    node.playhead->setState(.Paused)
}

Transport_Stop :: proc(node: ^Transport) {
    if node == nil || node.playhead == nil {
        return
    }
    node.playhead->setState(.Stopped)
}

Transport_TogglePlay :: proc(node: ^Transport) {
    if node == nil || node.playhead == nil {
        return
    }

    if Transport_IsPlaying(node) {
        node->stop()
    } else {
        node->play()
    }
}

Transport_GetSongPosition :: proc(node: ^Transport) -> SongPosition {
    if node == nil || node.playhead == nil {
        return createSongPosition()
    }

    return node.playhead.song_position
}

Transport_SetSongPosition :: proc(node: ^Transport, position: SongPosition) {
    if node == nil || node.playhead == nil {
        return
    }

    node.playhead.song_position = position
    node.playhead.currentTick = u64(position.tick)
    calculateSongPosition(node.playhead)
}

Transport_IsPlaying :: proc(node: ^Transport) -> bool {
    if node == nil || node.playhead == nil {
        return false
    }

    return node.playhead.playhead_state == .Playing || node.playhead.playhead_state == .Precount || node.playhead.playhead_state == .Recording
}

Transport_IsPaused :: proc(node: ^Transport) -> bool {
    if node == nil || node.playhead == nil {
        return false
    }

    return node.playhead.playhead_state == .Paused
}

Transport_IsRecording :: proc(node: ^Transport) -> bool {
    if node == nil || node.playhead == nil {
        return false
    }

    return node.playhead.playhead_state == .Recording
}

Transport_IsPrecounting :: proc(node: ^Transport) -> bool {
    if node == nil || node.playhead == nil {
        return false
    }

    return node.playhead.playhead_state == .Precount
}

Transport_IsLooping :: proc(node: ^Transport) -> bool {
    if node == nil || node.playhead == nil {
        return false
    }

    return node.playhead.looping
}

Transport_ToggleRecord :: proc(node: ^Transport) {
    if node == nil || node.playhead == nil {
        return
    }

    if Transport_IsRecording(node) {
        node.playhead->setState(.Playing)
    } else {
        node->record()
    }
}

Transport_ToggleLoop :: proc(node: ^Transport) {
    if node == nil || node.playhead == nil {
        return
    }

    node.loop_enabled->set(!node.loop_enabled.value)
    
}

