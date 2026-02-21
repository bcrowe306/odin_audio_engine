package main

import "base:runtime"
import "core:time"
import "core:fmt"
import ma "vendor:miniaudio"

DEFAULT_SAMPLE_RATE :: 48000
DEFAULT_CHANNELS :: 2
DEFAULT_FORMAT :: ma.format.f32
DEFAULT_BUFFER_SIZE :: 256

EngineContext :: struct {
    engine: ^AudioEngine,
    sample_rate: u32,
    buffer_size: u32,
    render_quantum: u64,

}

AudioEngine :: struct {
    sample_rate: u32,
    buffer_size: u32,
    channels: u32,
    format: ma.format,
    engine: ma.engine,
    resource_manager: ma.resource_manager,
    r_config: ma.resource_manager_config,
    d_config: ma.device_config,
    e_config: ma.engine_config,
    device: ma.device,
    initialized: bool,
    started: bool,
    ctx: EngineContext,

    // Methods
    init: proc(ae: ^AudioEngine),
    uninit: proc(ae: ^AudioEngine),
    applyConfig: proc(ae: ^AudioEngine, auto_start: bool),
    start: proc(ae: ^AudioEngine),
    stop: proc(ae: ^AudioEngine),
    getOutputBus: proc(ae: ^AudioEngine) -> ^ma.node,
    attachNode: proc(ae: ^AudioEngine, node: ^ma.node),
    getNodeGraph: proc(ae: ^AudioEngine) -> ^ma.node_graph,

}

createEngine :: proc(sample_rate: u32 = 48000, channels: u32 = 2, format: ma.format = ma.format.f32, buffer_size: u32 = 256, auto_start: bool = true) -> ^AudioEngine {
    ae := new(AudioEngine)
    using fmt


    ae.sample_rate = sample_rate
    ae.channels = channels
    ae.format = format
    ae.buffer_size = buffer_size

    // Methods
    ae.init = audioEngineInit
    ae.uninit = audioEngineUninit
    ae.applyConfig = audioEngineApplyConfig
    ae.start = audioEngineStart
    ae.stop = audioEngineStop
    ae.getOutputBus = audioEngineGetOutputBus
    ae.attachNode = audioEngineAttachNode
    ae.getNodeGraph = audioEngineGetNodeGraph

    // Resource Manager Configuration
    ae.r_config = ma.resource_manager_config_init()
    ae.r_config.decodedChannels = ae.channels
    ae.r_config.decodedSampleRate = ae.sample_rate
    ae.r_config.decodedFormat = ae.format
    
    ma.resource_manager_init(&ae.r_config, &ae.resource_manager)

    audioEngineApplyConfig(ae, auto_start)

    return ae
}

audioEngineStart :: proc(ae: ^AudioEngine) {
    fmt.println("Starting audio engine.")
    res := ma.engine_start(&ae.engine)
    if res != ma.result.SUCCESS {
        fmt.println("Failed to start audio engine: ", res)
        return
    }
    ae.started = true
}

audioEngineStop :: proc(ae: ^AudioEngine) {
    fmt.println("Stopping audio engine.")
    res := ma.engine_stop(&ae.engine)
    if res != ma.result.SUCCESS {
        fmt.println("Failed to stop audio engine: ", res)
        return
    }
    ae.started = false
}

audioEngineInit :: proc(ae: ^AudioEngine) {

    // Initialize the engine
    fmt.printfln("Initializing audio engine with sample rate: %d, channels: %d, format: %d, buffer size: %d", ae.sample_rate, ae.channels, ae.format, ae.buffer_size)
    if result := ma.engine_init(&ae.e_config, &ae.engine); result != ma.result.SUCCESS {
        fmt.println("Failed to initialize engine: ", result)
        return
    }


    ae.ctx = EngineContext{
        engine = ae,
        sample_rate = ae.sample_rate,
        buffer_size = ae.buffer_size,
        render_quantum = 0,
    }

    ae.initialized = true
}

audioEngineUninit :: proc(ae: ^AudioEngine) {
    if ae.started {
        audioEngineStop(ae)
    }
    
    if !ae.initialized {
        return
    }

    ma.engine_uninit(&ae.engine)
    ma.device_uninit(&ae.device)
    ae.initialized = false
}

audioEngineApplyConfig :: proc(ae: ^AudioEngine, auto_start: bool = true) {

    // Device Configuration
    ae.d_config = ma.device_config_init(ma.device_type.playback)
    ae.d_config.sampleRate = ae.sample_rate
    ae.d_config.playback.format = ae.format
    ae.d_config.playback.channels = ae.channels
    ae.d_config.dataCallback = audioEngineCallback
    ae.d_config.pUserData = ae
    ae.d_config.periodSizeInFrames = ae.buffer_size

    // Initialize the device
    if result := ma.device_init(nil, &ae.d_config, &ae.device); result != ma.result.SUCCESS {
        fmt.println("Failed to initialize device: ", result)
        return 
    }

    // Engine Configuration
    ae.e_config = ma.engine_config_init()
    ae.e_config.sampleRate = ae.sample_rate
    ae.e_config.periodSizeInFrames = ae.buffer_size
    ae.e_config.channels = ae.channels
    ae.e_config.pResourceManager = &ae.resource_manager
    ae.e_config.pDevice = &ae.device
    ae.e_config.dataCallback = audioEngineCallback
    ae.e_config.noAutoStart = true
    ae.e_config.pProcessUserData = ae

    if ae.started {
        audioEngineStop(ae)
    }

    if ae.initialized {
        audioEngineUninit(ae)
    }

    audioEngineInit(ae)

    if auto_start {
        audioEngineStart(ae)
    }

}

audioEngineCallback :: proc "c" (device: ^ma.device, output: rawptr, input: rawptr, frameCount: u32) {
    context = runtime.default_context()
    ae := cast(^AudioEngine)device.pUserData
    ma.engine_read_pcm_frames(&ae.engine, output, u64(frameCount), nil)

    // Increment the render quantum
    ae.ctx.render_quantum += 1
}

audioEngineGetOutputBus :: proc(ae: ^AudioEngine) -> ^ma.node {
    return ma.engine_get_endpoint(&ae.engine)
}

audioEngineAttachNode :: proc(ae: ^AudioEngine, node: ^ma.node) {
    ma.node_attach_output_bus(node, 0, audioEngineGetOutputBus(ae), 0)
}

audioEngineGetNodeGraph :: proc(ae: ^AudioEngine) -> ^ma.node_graph {
    return &ae.engine.nodeGraph
}