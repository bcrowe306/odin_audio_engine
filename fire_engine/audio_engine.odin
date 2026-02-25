package main

import "base:runtime"
import "core:fmt"
import ma "vendor:miniaudio"

DEFAULT_SAMPLE_RATE :: 48000
DEFAULT_CHANNELS :: 2
DEFAULT_FORMAT :: ma.format.f32
DEFAULT_BUFFER_SIZE :: 256

inputChannels := [2]u32{2,2}
outputChannels := [2]u32{2,2}

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
    audio_graph: ^AudioGraph,
    playhead: ^PlayheadNode,
    resource_manager: ^ResourceManager,
    format: ma.format,
    engine: ma.engine,
    d_config: ma.device_config,
    e_config: ma.engine_config,
    device: ma.device,
    initialized: bool,
    started: bool,
    ctx: EngineContext,
    midi_message_queue: SPSC(1024, MidiMessage),

    // Methods
    init: proc(ae: ^AudioEngine),
    uninit: proc(ae: ^AudioEngine),
    applyConfig: proc(ae: ^AudioEngine, auto_start: bool),
    start: proc(ae: ^AudioEngine),
    stop: proc(ae: ^AudioEngine),
    getOutputBus: proc(ae: ^AudioEngine) -> ^ma.node,
    attachNode: proc(ae: ^AudioEngine, node: ^ma.node) -> ma.result,
    getNodeGraph: proc(ae: ^AudioEngine) -> ^ma.node_graph,
    attachAudioGraph: proc(ae: ^AudioEngine, graph: ^AudioGraph),
    getPlayhead: proc(ae: ^AudioEngine) -> ^PlayheadNode,
    loadWave: proc(ae: ^AudioEngine, path: string, async: bool = true) -> ^WaveResource,
    releaseWave: proc(ae: ^AudioEngine, path: string) -> bool,
    getWaveAudio: proc(ae: ^AudioEngine, path: string) -> (^WaveAudio, bool),
    getWaveStatus: proc(ae: ^AudioEngine, path: string) -> ResourceLoadStatus,

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
    ae.attachAudioGraph = audioEngineAttachAudioGraph
    ae.getPlayhead = audioEngineGetPlayhead
    ae.loadWave = audioEngineLoadWave
    ae.releaseWave = audioEngineReleaseWave
    ae.getWaveAudio = audioEngineGetWaveAudio
    ae.getWaveStatus = audioEngineGetWaveStatus

    // Custom wave resource manager (uses wave_file_loader.odin, optionally async)
    ae.resource_manager = createResourceManager()

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

    if ae.resource_manager != nil {
        ae.resource_manager->shutdown()
        free(ae.resource_manager)
        ae.resource_manager = nil
    }

    ae.initialized = false
}

audioEngineApplyConfig :: proc(ae: ^AudioEngine, auto_start: bool = true) {
    previous_sample_rate := ae.ctx.sample_rate
    previous_buffer_size := ae.ctx.buffer_size


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

    if ae.audio_graph != nil {
        if previous_sample_rate != ae.sample_rate || previous_buffer_size != ae.buffer_size {
            ae.audio_graph->markEngineDirty()
        }
    }

}

audioEngineCallback :: proc "c" (device: ^ma.device, output: rawptr, input: rawptr, frameCount: u32) {
    context = runtime.default_context()
    ae := cast(^AudioEngine)device.pUserData

    if ae.audio_graph != nil {
        sample_count := int(frameCount) * int(ae.channels)
        out_samples := (cast([^]f32)output)[:sample_count]

        // Clear output buffer before graph render pass.
        for i in 0..<len(out_samples) {
            out_samples[i] = 0
        }

        graph_context := AudioGraphEngineContext{
            sample_rate = ae.sample_rate,
            render_quantum = ae.ctx.render_quantum,
            buffer_size = ae.buffer_size,
            output_channel_count = ae.channels,
        }

        ae.audio_graph->process(graph_context, &out_samples, int(frameCount))
    } else {
        // Fallback to miniaudio node graph when no custom graph is attached.
        ma.engine_read_pcm_frames(&ae.engine, output, u64(frameCount), nil)
    }

    // Increment the render quantum
    ae.ctx.render_quantum += 1
}

audioEngineGetOutputBus :: proc(ae: ^AudioEngine) -> ^ma.node {
    return ma.engine_get_endpoint(&ae.engine)
}

audioEngineAttachNode :: proc(ae: ^AudioEngine, node: ^ma.node) -> ma.result {
    return ma.node_attach_output_bus(node, 0, audioEngineGetOutputBus(ae), 0)
}

audioEngineGetNodeGraph :: proc(ae: ^AudioEngine) -> ^ma.node_graph {
    return &ae.engine.nodeGraph
}

audioEngineAttachAudioGraph :: proc(ae: ^AudioEngine, graph: ^AudioGraph) {
    ae.audio_graph = graph

    if ae.audio_graph == nil {
        return
    }

    // Ensure a default playhead exists and is attached to the currently attached graph.
    ae.playhead = createPlayhead()
    ae.playhead.sample_rate = f64(ae.sample_rate)
    ae.playhead->calculateSamplesPerTick()
    ae.playhead->attachToGraph(ae.audio_graph)

    ae.audio_graph->markEngineDirty()
}

audioEngineGetPlayhead :: proc(ae: ^AudioEngine) -> ^PlayheadNode {
    return ae.playhead
}

audioEngineLoadWave :: proc(ae: ^AudioEngine, path: string, async: bool = true) -> ^WaveResource {
    if ae.resource_manager == nil {
        return nil
    }
    return ae.resource_manager->acquireWave(path, ae.sample_rate, async)
}

audioEngineReleaseWave :: proc(ae: ^AudioEngine, path: string) -> bool {
    if ae.resource_manager == nil {
        return false
    }
    return ae.resource_manager->releaseWave(path)
}

audioEngineGetWaveAudio :: proc(ae: ^AudioEngine, path: string) -> (^WaveAudio, bool) {
    if ae.resource_manager == nil {
        return nil, false
    }
    return ae.resource_manager->getWaveAudio(path)
}

audioEngineGetWaveStatus :: proc(ae: ^AudioEngine, path: string) -> ResourceLoadStatus {
    if ae.resource_manager == nil {
        return .Unloaded
    }
    return ae.resource_manager->getWaveStatus(path)
}