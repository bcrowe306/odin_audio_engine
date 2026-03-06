package fire_engine

FireEngine :: struct {
    audio_engine: ^AudioEngine,
    midi_engine: ^MidiEngine,
    resource_manager: ^ResourceManager,
    command_controller: ^CommandController,
    tracks: Tracks,
    metronome: ^Metronome,
    transport: ^Transport,

    // Methods
    init: proc(fe: ^FireEngine),
    start: proc(fe: ^FireEngine),
    stop: proc(fe: ^FireEngine),
    addControlSurface: proc(fe: ^FireEngine, controlSurface: ^ControlSurface),
    uninit: proc(fe: ^FireEngine),
}

FireEngine_AddControlSurface :: proc(fe: ^FireEngine, controlSurface: ^ControlSurface) {
    fe.midi_engine->addControlSurface(controlSurface)
}

createFireEngine :: proc() -> ^FireEngine {
    fe := new(FireEngine)
    fe.resource_manager = createResourceManager()
    fe.command_controller = createController()
    fe.audio_engine = createEngine(auto_start = false)
    fe.audio_engine.resource_manager = fe.resource_manager
    fe.midi_engine = createMidiEngine()
    fe.midi_engine.audio_engine_midi_message_queue = &fe.audio_engine.midi_message_queue
    
    
    fe.init = FireEngine_Init
    fe.start = FireEngine_Start
    fe.stop = FireEngine_Stop
    fe.uninit = FireEngine_Uninit
    fe.addControlSurface = FireEngine_AddControlSurface
    fe.tracks = createTracks(fe)
    fe.transport = createTransportNode(fe)
    return fe
}

FireEngine_Init :: proc(fe: ^FireEngine) {
    fe.resource_manager->init()
    fe.audio_engine->init()
    fe.midi_engine->init()
}

FireEngine_Uninit :: proc(fe: ^FireEngine) {

    fe.audio_engine->uninit()
    free(fe.audio_engine)
    fe.midi_engine->uninit()
    free(fe.midi_engine)

    // Resource manager
    fe.resource_manager->shutdown()
    free(fe.resource_manager)
    fe.resource_manager = nil
}

FireEngine_Start :: proc(fe: ^FireEngine) {
    fe.audio_engine->start()
    
    // Set default tempo
    fe.audio_engine.playhead->setTempo(120.0)

    // Start the metronome
    fe.metronome = createMetronomeNode(fe)
    fe.metronome->attachToGraph(fe.audio_engine.audio_graph)
    fe.audio_engine.audio_graph->connectToEndpoint(fe.metronome.node_id)
}

FireEngine_Stop :: proc(fe: ^FireEngine) {
    fe.audio_engine->stop()
}