package main

import "core:math"
import ma "vendor:miniaudio"
import "base:runtime"
import "core:fmt"

LevelsNodeVTable : ma.node_vtable = {
    onProcess = levelsNodeProcess,
    outputBusCount = 1,
    inputBusCount = 1,
    flags = {.CONTINUOUS_PROCESSING, .PASSTHROUGH},
}


LevelsNodeConfig : ma.node_config = {
    vtable = &LevelsNodeVTable,
    inputBusCount = 1,
    outputBusCount = 1,
    pInputChannels = &inputChannels[0],
    pOutputChannels = &outputChannels[0],
    initialState = ma.node_state.started
}

LevelsNode :: struct {
    using base: ma.node_base,
    engine: ^ma.engine,
    peak_linear: [2]f32,
    rms_linear: [2]f32,
    peak_db: [2]f32,
    rms_db: [2]f32,
    frameCounter: u64,

}

createLevelsNode :: proc(engine: ^AudioEngine) -> ^LevelsNode {
    node := new(LevelsNode)
    node.engine = &engine.engine
    if res := ma.node_init(&engine.engine.nodeGraph, &LevelsNodeConfig, nil, cast(^ma.node)(node)); res != ma.result.SUCCESS {
        fmt.println("Failed to initialize levels node: ", res)
    }
    return node
}

levelsNodeProcess :: proc "c" (pNode: ^ma.node, ppFramesIn: ^[^]f32, pFrameCountIn: ^u32, ppFramesOut: ^[^]f32, pFrameCountOut: ^u32){
    context = runtime.default_context()
    node := cast(^LevelsNode)pNode
    channels :u32= 2
     for i in 0..<pFrameCountIn^ {
         for ch in 0..<channels {
             sample := ppFramesIn[i * channels + ch]
             abs_sample := abs(sample)
             if abs_sample > node.peak_linear[ch] {
                 node.peak_linear[ch] = abs_sample
             }
             node.rms_linear[ch] += sample * sample
         }
     }
     for ch in 0..<channels {
         node.rms_linear[ch] = math.sqrt(node.rms_linear[ch] / f32(pFrameCountIn^))
         if node.peak_linear[ch] > 0.0 { 
            node.peak_db[ch] = 20.0 * math.log10(node.peak_linear[ch]) } else { node.peak_db[ch] = math.INF_F32 }
         if node.rms_linear[ch] > 0.0 { 
            node.rms_db[ch] = 20.0 * math.log10(node.rms_linear[ch]) } else { node.rms_db[ch] = math.INF_F32 }
     }
    //  fmt.println("Peak dB: ", node.peak_linear[0], " RMS dB: ", node.rms_linear[0])
 }  