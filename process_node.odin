package main

import "core:math"
import ma "vendor:miniaudio"
import "base:runtime"
import "core:fmt"

ProcessNodeVTable : ma.node_vtable = {
    onProcess = processNodeProcess,
    outputBusCount = 1,
    inputBusCount = 1,
    flags = {.CONTINUOUS_PROCESSING},
}


ProcessNodeConfig : ma.node_config = {
    vtable = &ProcessNodeVTable,
    inputBusCount = 1,
    outputBusCount = 1,
    pInputChannels = &inputChannels[0],
    pOutputChannels = &outputChannels[0],
    initialState = ma.node_state.started
}

ProcessNode :: struct {
    using base: ma.node_base,
    engine: ^ma.engine,
    peak_linear: [2]f32,
    rms_linear: [2]f32,
    peak_db: [2]f32,
    rms_db: [2]f32,
    frameCounter: u64,
    processFunction: proc (pNode: ^ma.node, ppFramesIn: ^[^]f32, pFrameCountIn: ^u32, ppFramesOut: ^[^]f32, pFrameCountOut: ^u32, user_data: rawptr),
    user_data: rawptr,

}

createProcessNode :: proc(engine: ^AudioEngine) -> ^ProcessNode {
    node := new(ProcessNode)
    node.engine = &engine.engine
    if res := ma.node_init(&engine.engine.nodeGraph, &ProcessNodeConfig, nil, cast(^ma.node)(node)); res != ma.result.SUCCESS {
        fmt.println("Failed to initialize levels node: ", res)
    }
    return node
}

processNodeProcess :: proc "c" (pNode: ^ma.node, ppFramesIn: ^[^]f32, pFrameCountIn: ^u32, ppFramesOut: ^[^]f32, pFrameCountOut: ^u32){
    context = runtime.default_context()
    node := cast(^ProcessNode)pNode
    if node.processFunction != nil {
        node.processFunction(pNode, ppFramesIn, pFrameCountIn, ppFramesOut, pFrameCountOut, node.user_data)
    } else {
        // If no process function is set, just pass through the audio
         for i in 0..<pFrameCountIn^ * 2 {
            ppFramesOut[i] = ppFramesIn[i]
        }
        
    }
   
 }  