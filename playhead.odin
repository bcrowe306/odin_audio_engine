package main

import ma "vendor:miniaudio"
import "base:runtime"
import "core:fmt"

// TODO: Test out tempo change. Afraid of samplecounter logic being incorrect when tempo changes mid-tick. Maybe need to calculate the sample counter offset based on the new tempo and the number of samples already processed in the current tick?

MAX_TEMPO :: 300.0
MIN_TEMPO :: 20.0

PlayheadNodeVTable : ma.node_vtable = {
    onProcess = playheadNodeProcess,
    outputBusCount = 1,
    inputBusCount = 1,
    flags = {.CONTINUOUS_PROCESSING, .SILENT_OUTPUT},
}


PlayheadNodeConfig : ma.node_config = {
    vtable = &PlayheadNodeVTable,
    inputBusCount = 1,
    outputBusCount = 1,
    pInputChannels = &inputChannels[0],
    pOutputChannels = &outputChannels[0],
    initialState = ma.node_state.started

}

TimeSignature :: struct {
    numerator: u32,
    denominator: u32,
}


BeatTime :: struct {
    bar  : int,
    beat : int,
    sub  : f64, // fractional part inside beat
}

ticks_to_beattime :: proc(
    ticks: i64,
    ppqn: i32,
    time_signature: TimeSignature
) -> BeatTime {

    beats := f64(ticks) / f64(ppqn)

    beat_unit := 4.0 / f64(time_signature.denominator)
    musical_beats := beats / beat_unit

    bar_index := int(musical_beats / f64(time_signature.numerator))
    beat_in_bar := musical_beats - f64(bar_index * int(time_signature.numerator))

    beat_index := int(beat_in_bar)

    return BeatTime{
        bar  = bar_index + 1,
        beat = beat_index + 1,
        sub  = beat_in_bar - f64(beat_index),
    }
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

    beat_time: BeatTime, // The musical time corresponding to the current tick, including bar, beat, and fractional sub-beat information.

    // The frame offset withing the current render period where the tick event occurred. This can be used for scheduling events with sample accuracy.
    frame_offset: u64
}

SongPosition :: struct {
    bar: u32,
    beat: u32,
    tick: u32,
    frame: u64, // Absolute frame count since the playhead started. This can be used for sample-accurate scheduling and synchronization.
}

PlayheadState :: enum {
    Stopped,
    Playing,
    Paused,
    Precount,
    Recording,
}

PlayheadNode :: struct {
    using base: ma.node_base,
    tempo: f64,
    engine: ^ma.engine,
    time_signature: TimeSignature,
    ppqn: f64,
    samplesPerTick: f64,
    currentTick: u64,
    sampleCounter: f64,
    playhead_state: PlayheadState,
    song_position: SongPosition,
    precount_enabled: bool,
    precount_bars: u32,
    return_to_zero_on_stop: bool,
    frameCounter: u64,
    looping: bool,
    loop_start_tick: u64,
    loop_end_tick: u64,
    ds: ma.sound,

    // Methods
    calculateSamplesPerTick: proc(m: ^PlayheadNode),
    setTempo: proc(m: ^PlayheadNode, newTempo: f64),
    ticksPerBeat: proc(m: ^PlayheadNode) -> f64,
    ticksPerBar: proc(m: ^PlayheadNode) -> f64,
    isBar: proc(m: ^PlayheadNode) -> bool,
    isBeat: proc(m: ^PlayheadNode) -> bool,
    setState: proc(playhead: ^PlayheadNode, newState: PlayheadState),
    playheadProcess: proc "c" (pNode: ^ma.node, ppFramesIn: ^[^]f32, pFrameCountIn: ^u32, ppFramesOut: ^[^]f32, pFrameCountOut: ^u32),
    isTick: proc(met: ^PlayheadNode, frame: u32) -> bool,
    setLoopStart: proc(playhead: ^PlayheadNode, bar: u32, beat: u32, tick: u32),
    setLoopEnd: proc(playhead: ^PlayheadNode, bar: u32, beat: u32, tick: u32),

    // Signals
    onTick: ^Signal,
    onStateChange: ^Signal,

}

createPlayhead :: proc(audio_engine: ^AudioEngine, tempo: f64 = 120.0, time_signature: TimeSignature = TimeSignature{numerator = 4, denominator = 4}) -> ^PlayheadNode {

    ph := new(PlayheadNode)
    ph.ppqn = 480
    ph.time_signature = time_signature
    ph.engine = &audio_engine.engine
    ph.calculateSamplesPerTick = playheadCalculateSamplesPerTick
    ph.setTempo = playheadSetTempo
    ph.ticksPerBeat = playheadTicksPerBeat
    ph.isBeat = playheadIsBeat
    ph.ticksPerBar = playheadTicksPerBar
    ph.isBar = playheadIsBar
    ph.playheadProcess = playheadNodeProcess
    ph.isTick = playheadIsTick
    ph.setState = playheadSetState
    ph.setLoopStart = playheadSetLoopStart
    ph.setLoopEnd = playheadSetLoopEnd
    ph.onTick = createSignal()
    ph.onStateChange = createSignal()
    ph.playhead_state = PlayheadState.Playing
    ph.song_position.bar = 0
    ph.song_position.beat = 0
    ph.song_position.tick = 0
    ph.song_position.frame = 0
    playheadSetTempo(ph, tempo)
    if res := ma.node_init(&audio_engine.engine.nodeGraph, &PlayheadNodeConfig, nil, cast(^ma.node)(ph)); res != ma.result.SUCCESS {
        fmt.println("Failed to initialize playhead node: ", res)
    }
    if res := ma.sound_init_from_file(&audio_engine.engine, "perc.wav", {.NO_SPATIALIZATION}, nil, nil, &ph.ds); res != ma.result.SUCCESS {
        fmt.println("Failed to load sound: ", res)
    }
    // ma.node_attach_output_bus(cast(^ma.node)(&ph.ds), 0, cast(^ma.node)(ph), 0)

    return ph
}

playheadNodeProcess :: proc "c" (pNode: ^ma.node, ppFramesIn: ^[^]f32, pFrameCountIn: ^u32, ppFramesOut: ^[^]f32, pFrameCountOut: ^u32) {
    context = runtime.default_context()
    met := cast(^PlayheadNode)pNode

    for i in 0..<pFrameCountOut^ {
        switch met.playhead_state {
            case .Stopped:
                playheadStateStopped(met, i)
            case .Playing:
                playheadStatePlaying(met, i)
            case .Paused:
                playheadStatePaused(met, i)
            case .Precount:
                playheadStatePrecount(met, i)
            case .Recording:
                playheadStateRecording(met, i)
        }
    }
    
    met.frameCounter += u64(pFrameCountOut^)
}

playheadIsTick :: proc(met: ^PlayheadNode, frame: u32) -> bool {
    is_tick := false
    if met.sampleCounter >= met.samplesPerTick {
        is_tick = true
        tick_event := TickEvent{}
        tick_event.current_tick = met.currentTick
        tick_event.playhead_state = met.playhead_state
        tick_event.beat_time = ticks_to_beattime(i64(met.currentTick), i32(met.ppqn), met.time_signature)
        tick_event.frame_offset = u64(frame)
        if met->isBar() {
            tick_event.type = TickType.Bar
        } else if met->isBeat() {
            tick_event.type = TickType.Beat
        } else {
            tick_event.type = TickType.Tick   
        }
        signalEmit(met.onTick, tick_event)
        met.sampleCounter -= met.samplesPerTick
        met.currentTick += 1
    }
    met.sampleCounter += 1
    return is_tick
}

playheadTicksPerBeat :: proc(m: ^PlayheadNode) -> f64 {
    return m.ppqn * (4.0 / f64(m.time_signature.denominator))
}

playheadIsBeat :: proc(m: ^PlayheadNode) -> bool {
    ticksPerBeat := m.ppqn * (4.0 / f64(m.time_signature.denominator))
    return m.currentTick % u64(m->ticksPerBeat()) == 0
}

playheadTicksPerBar :: proc(m: ^PlayheadNode) -> f64 {
    return m.ppqn * m->ticksPerBeat() * f64(m.time_signature.numerator)
}

playheadIsBar :: proc(m: ^PlayheadNode) -> bool {
    ticksPerBar := m.ppqn * (4.0 / f64(m.time_signature.denominator)) * f64(m.time_signature.numerator)
    return m.currentTick % u64(ticksPerBar) == 0
}

playheadCalculateSamplesPerTick :: proc(m: ^PlayheadNode)  {
    m.samplesPerTick = (f64(m.engine.sampleRate) * 60.0) / (m.tempo * m.ppqn)
    m.sampleCounter = m.samplesPerTick
}

playheadSetTempo :: proc(m: ^PlayheadNode, newTempo: f64) {
    m.tempo = clamp(newTempo, MIN_TEMPO, MAX_TEMPO)
    m->calculateSamplesPerTick()
}


playheadStateStopped :: proc(playhead: ^PlayheadNode, frame: u32) {
    playheadIsTick(playhead, frame)
    playhead.song_position.frame = 0
    playhead.song_position.tick = 0
    playhead.song_position.beat = u32(playhead.song_position.tick / u32(playhead->ticksPerBeat()))
    playhead.song_position.bar = u32(playhead.song_position.beat / u32(playhead.time_signature.numerator))
}

playheadStatePlaying :: proc(playhead: ^PlayheadNode, frame: u32) {
    if playheadIsTick(playhead, frame) {
        playhead.song_position.frame = auto_cast frame
        playhead.song_position.tick = u32(playhead.currentTick)
        playhead.song_position.beat = u32(playhead.song_position.tick / u32(playhead->ticksPerBeat()))
        playhead.song_position.bar = u32(playhead.song_position.beat / u32(playhead.time_signature.numerator))
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
        playhead.song_position.frame = auto_cast frame
        playhead.song_position.tick = u32(playhead.currentTick)
        playhead.song_position.beat = u32(playhead.song_position.tick / u32(playhead->ticksPerBeat()))
        playhead.song_position.bar = u32(playhead.song_position.beat / u32(playhead.time_signature.numerator))
    } else {
        playhead.song_position.frame = auto_cast frame
    }
}

playheadSetState :: proc(playhead: ^PlayheadNode, newState: PlayheadState) {
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
                case .Playing:
                    state_change_allowed = true
                case .Precount:
                    state_change_allowed = false
                case .Recording:
                    state_change_allowed = true
                case .Paused:
                    state_change_allowed = false
            }
    }
    if state_change_allowed {
        playhead.playhead_state = newState
        signalEmit(playhead.onStateChange, newState)
    }
}

playheadSetLoopStart :: proc(playhead: ^PlayheadNode, bar: u32, beat: u32, tick: u32) {
    total_ticks := (bar * u32(playhead.time_signature.numerator) * u32(playhead.ppqn)) + (beat * u32(playhead->ticksPerBeat())) + tick
    playhead.loop_start_tick = u64(total_ticks)
}

playheadSetLoopEnd :: proc(playhead: ^PlayheadNode, bar: u32, beat: u32, tick: u32) {
    total_ticks := (bar * u32(playhead.time_signature.numerator) * u32(playhead.ppqn)) + (beat * u32(playhead->ticksPerBeat())) + tick
    playhead.loop_end_tick = u64(total_ticks)
}


