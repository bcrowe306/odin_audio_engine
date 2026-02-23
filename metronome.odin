package main

import ma "vendor:miniaudio"
import "base:runtime"
import "core:fmt"


MetronomeNodeVTable : ma.node_vtable = {
    onProcess = metronomeNodeProcess,
    outputBusCount = 1,
    inputBusCount = 1,
    flags = {.PASSTHROUGH, .CONTINUOUS_PROCESSING},
}


MetronomeNodeConfig : ma.node_config = {
    vtable = &MetronomeNodeVTable,
    inputBusCount = 1,
    outputBusCount = 1,
    pInputChannels = &inputChannels[0],
    pOutputChannels = &outputChannels[0],
    initialState = ma.node_state.started

}


MetronomeNode :: struct {
    using base: ma.node_base,
    tempo: f64,
    engine: ^ma.engine,
    time_signature: TimeSignature,
    ppqn: f64,
    samplesPerTick: f64,
    currentTick: u64,
    sampleCounter: f64,
    beat_sound: ma.sound,

    calculateSamplesPerTick: proc(m: ^MetronomeNode),
    setTempo: proc(m: ^MetronomeNode, newTempo: f64),
    ticksPerBeat: proc(m: ^MetronomeNode) -> f64,
    ticksPerBar: proc(m: ^MetronomeNode) -> f64,
    isBar: proc(m: ^MetronomeNode) -> bool,
    isBeat: proc(m: ^MetronomeNode) -> bool,
    frameCounter: u64,

}
ticksPerBeat :: proc(m: ^MetronomeNode) -> f64 {
    return m.ppqn * (4.0 / f64(m.time_signature.denominator))
}

isBeat :: proc(m: ^MetronomeNode) -> bool {
    ticksPerBeat := m.ppqn * (4.0 / f64(m.time_signature.denominator))
    return m.currentTick % u64(m->ticksPerBeat()) == 0
}

ticksPerBar :: proc(m: ^MetronomeNode) -> f64 {
    return m.ppqn * m->ticksPerBeat() * f64(m.time_signature.numerator)
}

isBar :: proc(m: ^MetronomeNode) -> bool {
    ticksPerBar := m.ppqn * (4.0 / f64(m.time_signature.denominator)) * f64(m.time_signature.numerator)
    return m.currentTick % u64(ticksPerBar) == 0
}

calculateSamplesPerTick :: proc(m: ^MetronomeNode)  {
    m.samplesPerTick = (f64(m.engine.sampleRate) * 60.0) / (m.tempo * m.ppqn)
    m.sampleCounter = m.samplesPerTick
}

setTempo :: proc(m: ^MetronomeNode, newTempo: f64) {
    m.tempo = clamp(newTempo, MIN_TEMPO, MAX_TEMPO)
    m->calculateSamplesPerTick()
}


createMet :: proc(engine: ^ma.engine, tempo: f64 = 120.0, time_signature: TimeSignature = TimeSignature{numerator = 4, denominator = 4}) -> ^MetronomeNode {

    m := new(MetronomeNode)
    m.ppqn = 480
    m.time_signature = time_signature
    m.engine = engine
    m.calculateSamplesPerTick = calculateSamplesPerTick
    m.setTempo = setTempo
    m.ticksPerBeat = ticksPerBeat
    m.isBeat = isBeat
    m.ticksPerBar = ticksPerBar
    m.isBar = isBar
    setTempo(m, tempo)
    ma.node_init(&engine.nodeGraph, &MetronomeNodeConfig, nil, cast(^ma.node)(m))
    if res := ma.sound_init_from_file(engine, "perc.wav", {.NO_SPATIALIZATION}, nil, nil, &m.beat_sound); res != ma.result.SUCCESS {
        fmt.println("Failed to load sound: ", res)
    }
    ma.node_attach_output_bus(cast(^ma.node)(&m.beat_sound), 0, cast(^ma.node)(m), 0)
    return m

}

metronomeNodeProcess :: proc "c" (pNode: ^ma.node, ppFramesIn: ^[^]f32, pFrameCountIn: ^u32, ppFramesOut: ^[^]f32, pFrameCountOut: ^u32) {
    context = runtime.default_context()
    met := cast(^MetronomeNode)pNode

    

    for i in 0..<pFrameCountOut^ {
        ppFramesOut[i] = ppFramesIn[i]
        if met.sampleCounter >= met.samplesPerTick {
            
            if met->isBeat() {
                
                ma.sound_seek_to_pcm_frame(&met.beat_sound, 0)
                ma.sound_set_start_time_in_pcm_frames(&met.beat_sound, ma.engine_get_time_in_pcm_frames(met.engine) + u64(i))
                ma.sound_start(&met.beat_sound)
            }
            met.sampleCounter -= met.samplesPerTick
            met.currentTick += 1
        }
        met.sampleCounter += 1
    }
    
    met.frameCounter += u64(pFrameCountOut^)
}



