package fire_engine
import "core:fmt"


MAX_TEMPO :: 300.0
MIN_TEMPO :: 20.0

TimeSignature :: struct {
    numerator: u32,
    denominator: u32,
}

TickType :: enum {
    Beat,
    Bar,
    Tick,
}

TickEvent :: struct {
    // The current tick count since the playhead started. This is a running count of ticks and does not reset on bars or beats.
    current_tick: u64,

    // The type of tick event (beat, bar, or tick)
    type: TickType,

    // The state of the playhead (playing, stopped, paused, etc.)
    playhead_state: PlayheadState,

    beat_time: f64, // The musical time corresponding to the current tick, including bar, beat, and fractional sub-beat information.

    // The frame offset withing the current render period where the tick event occurred. This can be used for scheduling events with sample accuracy.
    frame_offset: u64
}

SongPosition :: struct {
    bar: u32,
    beat: u32,
    sixteenth: u32,
    tick: u32,
    beat_time: f64,
    frame: u64, // Absolute frame count since the playhead started.
    clock_time: f64, // Absolute time in seconds since the playhead started. 
    toStringShort: proc(pos: ^SongPosition) -> string,
    }

songPositionToStringShort :: proc(song_position: ^SongPosition) -> string {
    return fmt.tprintf("%d. %d. %d", song_position.bar + 1, song_position.beat + 1, song_position.sixteenth + 1)
}

createSongPosition :: proc() -> SongPosition {
    return SongPosition{
        bar = 0,
        beat = 0,
        sixteenth = 0,
        tick = 0,
        beat_time = 0,
        frame = 0,
        clock_time = 0,
        toStringShort = songPositionToStringShort,

    }
}

PlayheadState :: enum {
    Stopped,
    Playing,
    Paused,
    Precount,
    Recording,
}

PlayheadNode :: struct {
    node_id: u64,
    tempo: f64,
    sample_rate: f64,
    time_signature: TimeSignature,
    ppqn: f64,
    samplesPerTick: f64,
    currentTick: u64,
    sampleCounter: f64,
    playhead_state: PlayheadState,
    song_position: SongPosition,
    ticks_per_beat: u32,
    ticks_per_bar: u32,
    precount_enabled: bool,
    precount_bars: u32,
    return_to_zero_on_stop: bool,
    frameCounter: u64,
    looping: bool,
    loop_start_tick: u64,
    loop_end_tick: u64,

    // Methods
    calculateSamplesPerTick: proc(m: ^PlayheadNode),
    setTempo: proc(m: ^PlayheadNode, newTempo: f64),
    ticksPerBeat: proc(m: ^PlayheadNode) -> u32,
    ticksPerBar: proc(m: ^PlayheadNode) -> u32,
    isBar: proc(m: ^PlayheadNode) -> bool,
    isBeat: proc(m: ^PlayheadNode) -> bool,
    attachToGraph: proc(playhead: ^PlayheadNode, graph: ^AudioGraph),
    setState: proc(playhead: ^PlayheadNode, newState: PlayheadState),
    playheadProcess: AudioNodeProcessProc,
    isTick: proc(met: ^PlayheadNode, frame: u32) -> bool,
    setLoopStart: proc(playhead: ^PlayheadNode, bar: u32, beat: u32, tick: u32),
    setLoopEnd: proc(playhead: ^PlayheadNode, bar: u32, beat: u32, tick: u32),

    // Signals
    onTick: ^Signal,
    onStateChange: ^Signal,

}

createPlayhead :: proc(tempo: f64 = 120.0, time_signature: TimeSignature = TimeSignature{numerator = 4, denominator = 4}) -> ^PlayheadNode {

    ph := new(PlayheadNode)
    ph.ppqn = 480
    ph.time_signature = time_signature
    ph.sample_rate = 48000
    ph.calculateSamplesPerTick = playheadCalculateSamplesPerTick
    ph.setTempo = playheadSetTempo
    ph.ticksPerBeat = playheadTicksPerBeat
    ph.isBeat = playheadIsBeat
    ph.ticksPerBar = playheadTicksPerBar
    ph.isBar = playheadIsBar
    ph.playheadProcess = playheadNodeProcess
    ph.attachToGraph = playheadAttachToGraph
    ph.isTick = playheadIsTick
    ph.setState = playheadSetState
    ph.setLoopStart = playheadSetLoopStart
    ph.return_to_zero_on_stop = true
    ph.setLoopEnd = playheadSetLoopEnd
    ph.song_position = createSongPosition()
    ph.onTick = createSignal()
    ph.onStateChange = createSignal()
    ph.playhead_state = PlayheadState.Stopped
    playheadSetTempo(ph, tempo)
    return ph
}

playheadAttachToGraph :: proc(playhead: ^PlayheadNode, graph: ^AudioGraph) {
    playhead.node_id = graph->queueAddNode("playhead", 0, 1, playhead.playheadProcess, cast(rawptr)playhead)
    graph->queueSetRoot(playhead.node_id, true)
}

playheadNodeProcess :: proc(graph: ^AudioGraph, node: ^AudioNode, engine_context: AudioGraphEngineContext, frame_buffer: ^[]f32, frame_buffer_size: int, midi_messages: []ShortMessage) {
    met := cast(^PlayheadNode)node.user_data
    if met == nil {
        return
    }

    if met.sample_rate != f64(engine_context.sample_rate) {
        met.sample_rate = f64(engine_context.sample_rate)
        met->calculateSamplesPerTick()
    }

    channel_count := int(engine_context.output_channel_count)
    if channel_count < 1 {
        channel_count = 1
    }

    sample_count := frame_buffer_size * channel_count
    out := graph->ensureOutputBuffer(node, 0, sample_count)
    if len(out) == sample_count {
        for i in 0..<sample_count {
            out[i] = 0
        }
    }

    for i in 0..<frame_buffer_size {
        frame := u32(i)
        switch met.playhead_state {
            case .Stopped:
                playheadStateStopped(met, frame)
            case .Playing:
                playheadStatePlaying(met, frame)
            case .Paused:
                playheadStatePaused(met, frame)
            case .Precount:
                playheadStatePrecount(met, frame)
            case .Recording:
                playheadStateRecording(met, frame)
        }
    }
    
    met.frameCounter += u64(frame_buffer_size)
}

playheadIsTick :: proc(playhead: ^PlayheadNode, frame: u32) -> bool {
    is_tick := false
    if playhead.sampleCounter >= playhead.samplesPerTick {
        is_tick = true
        tick_event := TickEvent{}
        tick_event.current_tick = playhead.currentTick
        tick_event.playhead_state = playhead.playhead_state
        tick_event.frame_offset = u64(frame)

        // Emit tick event with current tick, playhead state, and beat time information
        if playhead->isBar() {
            tick_event.type = TickType.Bar
        } else if playhead->isBeat() {
            tick_event.type = TickType.Beat
        } else {
            tick_event.type = TickType.Tick   
        }
        signalEmit(playhead.onTick, tick_event)

        // Increment tick and reset sample counter
        playhead.sampleCounter -= playhead.samplesPerTick
        playhead.currentTick += 1

        // If Playing or Recording, we want to advance the song position on every tick. If Paused or Stopped, we want to keep the song position static until we start playing again. So we only update the song position on ticks, and ignore frame updates.
        if playhead.playhead_state == .Playing || playhead.playhead_state == .Recording {
            playhead.song_position.tick += 1
        }
    }
    playhead.sampleCounter += 1
    return is_tick
}

playheadTicksPerBeat :: proc(m: ^PlayheadNode) -> u32 {
    return u32(m.ppqn) * (4 / m.time_signature.denominator)
}

playheadIsBeat :: proc(playhead: ^PlayheadNode) -> bool {
    return playhead.song_position.tick % playhead.ticks_per_beat == 0
}

playheadTicksPerBar :: proc(m: ^PlayheadNode) -> u32 {
    return m->ticksPerBeat() * m.time_signature.numerator
}

playheadIsBar :: proc(playhead: ^PlayheadNode) -> bool {
    ticksPerBar := playhead->ticksPerBar()
    return playhead.song_position.tick % u32(ticksPerBar) == 0
}


playheadCalculateSamplesPerTick :: proc(m: ^PlayheadNode)  {
    m.samplesPerTick = (m.sample_rate * 60.0) / (m.tempo * m.ppqn)
    m.sampleCounter = m.samplesPerTick
}

playheadSetTempo :: proc(playhead: ^PlayheadNode, newTempo: f64) {
    playhead.tempo = clamp(newTempo, MIN_TEMPO, MAX_TEMPO)
    playhead->calculateSamplesPerTick()
    playhead.ticks_per_beat = playhead->ticksPerBeat()
    playhead.ticks_per_bar = playhead->ticksPerBar()

}

calculateSongPosition :: proc(playhead: ^PlayheadNode) {
    ticks_into_bar := playhead.song_position.tick % playhead.ticks_per_bar
    ticks_into_beat := playhead.song_position.tick % playhead.ticks_per_beat
    beats := f64(ticks_into_bar) / f64(playhead.ticks_per_beat)
    
    playhead.song_position.beat = u32(playhead.song_position.tick / playhead.ticks_per_beat) % u32(playhead.time_signature.numerator)
    playhead.song_position.bar = u32(playhead.song_position.tick / playhead.ticks_per_bar)
    playhead.song_position.sixteenth = u32(ticks_into_beat * 4 / playhead.ticks_per_beat)
    playhead.song_position.beat_time = f64(playhead.song_position.bar) + (beats / f64(playhead.time_signature.numerator))
}

playheadResetSongPosition :: proc(playhead: ^PlayheadNode) {
    playhead.song_position.frame = 0
    playhead.song_position.tick = 0
    playhead.song_position.beat = 0
    playhead.song_position.bar = 0
    playhead.song_position.sixteenth = 0
    playhead.song_position.beat_time = 0
    playhead.song_position.clock_time = 0
}

playheadStateStopped :: proc(playhead: ^PlayheadNode, frame: u32) {
    playheadIsTick(playhead, frame)
    playheadResetSongPosition(playhead)
}

playheadStatePlaying :: proc(playhead: ^PlayheadNode, frame: u32) {
    if playheadIsTick(playhead, frame) {
        calculateSongPosition(playhead)
    } else {
        playhead.song_position.frame = auto_cast frame
    }
}

playheadStatePaused :: proc(playhead: ^PlayheadNode, frame: u32) {
    playheadIsTick(playhead, frame)
    // When paused, we want to keep the song position static until we start playing again. So we only update the song position on ticks, and ignore frame updates.
}

playheadStatePrecount :: proc(playhead: ^PlayheadNode, frame: u32) {
    playheadIsTick(playhead, frame) 
    if playhead.precount_enabled {
        if playhead.currentTick >= u64(playhead.precount_bars * u32(playhead.time_signature.numerator) * u32(playhead.ppqn)) {
            playhead.playhead_state = PlayheadState.Playing
        }
    } 

}

playheadStateRecording :: proc(playhead: ^PlayheadNode, frame: u32) {
    if playheadIsTick(playhead, frame) {
        calculateSongPosition(playhead)
    } else {
        playhead.song_position.frame = auto_cast frame
    }
}

playheadSetState :: proc(playhead: ^PlayheadNode, newState: PlayheadState) {
    newState := newState
    state_change_allowed := false
    if playhead.playhead_state == newState {
        return
    }
    old_state := playhead.playhead_state
    switch newState {
        case .Stopped:
            state_change_allowed = true
            if playhead.return_to_zero_on_stop {
                playhead.song_position.tick = 0
                playhead.song_position.frame = 0
                playhead.song_position.beat = 0
                playhead.song_position.bar = 0
            }
        case .Playing:
            switch old_state {
                case .Stopped:
                    state_change_allowed = true
                case .Paused:
                    state_change_allowed = true
                case .Precount:
                    state_change_allowed = false
                case .Recording:
                    state_change_allowed = true
                case .Playing:
                    state_change_allowed = false
            }
            playhead.sampleCounter = playhead.samplesPerTick // reset sample counter when starting to ensure accurate timing
            playhead.currentTick = u64(playhead.song_position.tick) // sync current tick to song position when starting playback

        case .Paused:
            switch old_state {
                case .Stopped:
                    state_change_allowed = false
                case .Playing:
                    state_change_allowed = true
                case .Precount:
                    state_change_allowed = false
                case .Recording:
                    state_change_allowed = true
                case .Paused:
                    state_change_allowed = false
            }
        case .Precount:
            switch old_state {
                case .Stopped:
                    state_change_allowed = true
                case .Playing:
                    state_change_allowed = false
                case .Precount:
                    state_change_allowed = false
                case .Recording:
                    state_change_allowed = false
                case .Paused:
                    state_change_allowed = false
            }
        case .Recording:
            switch old_state {
                case .Stopped:
                    state_change_allowed = true
                    if playhead.precount_enabled {
                        newState = .Precount
                    }
                case .Playing:
                    state_change_allowed = true
                case .Precount:
                    state_change_allowed = true
                case .Recording:
                    state_change_allowed = false
                case .Paused:
                    state_change_allowed = true
            }
    }
    if state_change_allowed {
        playhead.playhead_state = newState
        signalEmit(playhead.onStateChange, newState)
    }
}

playheadSetLoopStart :: proc(playhead: ^PlayheadNode, bar: u32, beat: u32, tick: u32) {
    total_ticks := (bar * u32(playhead.time_signature.numerator) * u32(playhead.ppqn)) + (beat * u32(playhead.ticks_per_beat)) + tick
    playhead.loop_start_tick = u64(total_ticks)
}

playheadSetLoopEnd :: proc(playhead: ^PlayheadNode, bar: u32, beat: u32, tick: u32) {
    total_ticks := (bar * u32(playhead.time_signature.numerator) * u32(playhead.ppqn)) + (beat * u32(playhead.ticks_per_beat)) + tick
    playhead.loop_end_tick = u64(total_ticks)
}


