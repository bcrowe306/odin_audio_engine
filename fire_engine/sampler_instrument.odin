package fire_engine

import "core:fmt"

// Build out sampler instrument.
// Parameters:
// sample_file_path: string
// sample_name: string
// playback_type: enum (adsr, one_shot)
// pitch_bend_range: i32
// polyphony: u32
// legato: bool
// glide_time: f32
// reverse: bool
// length: u64
// start: u64
// end: u64
// loop: bool
// loop_start: u64
// loop_end: u64
// filter_enabled: bool
// filter_type: enum (lowpass, highpass, bandpass, notch, allpass)
// filter_cutoff: f32
// filter_resonance: f32
// filter_morph: f32
// filter_slope: enum (12db, 24db)
// filter_amount: f32
// Amp ADSR
// Filter ADSR, amount
// Pitch ADSR, amount
// LFO Rate
// LFO Depth
// LFO Destination (pitch, filter cutoff, amp) amounts
// LFO Waveform (sine, square, saw, triangle, reverse saw, noise)
// LFO Tempo Sync (1/4, 1/8, 1/16, etc.)
// LFO trigger (free, envelope, beat, midi)
// Effects
    // reverb
    // delay
    // chorus
    // flanger
    // phaser
    // distortion
    // bitcrusher
    // filter (lowpass, highpass, bandpass, notch, allpass)
    // saturation
    // amp
// transpose: i32
// fine_tune: i32
// volume: f32
// pan: f32



SamplerInstrument :: struct {
    using instrument: Instrument,
    sample_file_path: string `json:"sample_file_path"`,
    sample_name: string `json:"sample_name"`,
    audio_data: ^WaveAudio,
    voice_allocator: VoiceAllocator,

    // Parameters
    playback_type: ^OptionsParameter,
    pitch_bend_range: ^IntParameter,
    polyphony: ^IntParameter,
    legato: ^BoolParameter,
    glide_time: ^Float32Parameter,
    reverse: ^BoolParameter,
    length: ^UIntParameter,
    start: ^UIntParameter,
    end: ^UIntParameter,
    loop: ^BoolParameter,
    loop_start: ^UIntParameter,
    loop_end: ^UIntParameter,
    filter_enabled: ^BoolParameter,
    filter_type: ^OptionsParameter,
    filter_keytrack: ^Float32Parameter,
    filter_cutoff: ^Float32Parameter,
    filter_resonance: ^Float32Parameter,
    filter_morph: ^Float32Parameter,
    filter_slope: ^OptionsParameter,
    filter_amount: ^Float32Parameter,
    amp_attack: ^TimeParameter,
    amp_decay: ^TimeParameter,
    amp_sustain: ^Float32Parameter,
    amp_release: ^TimeParameter,
    filter_attack: ^TimeParameter,
    filter_decay: ^TimeParameter,
    filter_sustain: ^Float32Parameter,
    filter_release: ^TimeParameter,
    filter_env_amount: ^Float32Parameter,
    pitch_attack: ^TimeParameter,
    pitch_decay: ^TimeParameter,
    pitch_sustain: ^Float32Parameter,
    pitch_release: ^TimeParameter,
    lfo_rate: ^Float32Parameter,
    lfo_depth: ^Float32Parameter,
    lfo_destination: ^OptionsParameter,
    lfo_waveform: ^OptionsParameter,
    lfo_tempo_sync: ^OptionsParameter,
    lfo_trigger: ^OptionsParameter,
}


createSamplerDevice :: proc(fe: ^FireEngine, sample_file_path: string = "") -> ^SamplerInstrument {
    new_device := new(SamplerInstrument)
    name := "Sampler"
    configureInstrument(fe, &new_device.instrument, name, InstrumentType.Sampler)
    new_device.sample_file_path = sample_file_path
    new_device.sample_name = "Sampler"


    if new_device.sample_file_path != "" {
        fe->audio_engine->loadWave(new_device.sample_file_path, true)
        wave_audio, err := fe->resource_manager->getWaveAudio(new_device.sample_file_path)
        if err {
            fmt.println("Error loading sample:", err)
        }
        new_device.audio_data = wave_audio
        
    }

    voice_allocator := createVoiceAllocator(fe, 8, new_device.audio_data) // Default to 8 voices of polyphony, this can be changed with the parameter

    // Parameters
    new_device.playback_type = createOptionsParameter(fe.command_controller, "Playback Type", {"ADSR", "One Shot"}, 0)
    new_device.pitch_bend_range = createIntParameter(fe.command_controller, "Pitch Bend Range", 2, 0, 12)
    new_device.polyphony = createIntParameter(fe.command_controller, "Polyphony", 8, 1, 128)
    new_device.legato = createBoolParameter(fe.command_controller, "Legato", false)
    new_device.glide_time = createFloatParameter(fe.command_controller, "Glide Time", 0.1, 0.0, 10.0)
    new_device.reverse = createBoolParameter(fe.command_controller, "Reverse", false)
    new_device.length = createUIntParameter(fe.command_controller, "Length", 0, 0, 1000000)
    new_device.start = createUIntParameter(fe.command_controller, "Start", 0, 0, 1000000)
    new_device.end = createUIntParameter(fe.command_controller, "End", 0, 0, 1000000)
    new_device.loop = createBoolParameter(fe.command_controller, "Loop", false)
    new_device.loop_start = createUIntParameter(fe.command_controller, "Loop Start", 0, 0, 1000000)
    new_device.loop_end = createUIntParameter(fe.command_controller, "Loop End", 0, 0, 1000000)
    new_device.filter_enabled = createBoolParameter(fe.command_controller, "Filter Enabled", false)
    new_device.filter_type = createOptionsParameter(fe.command_controller, "Filter Type", {"Lowpass", "Highpass", "Bandpass", "Notch", "Allpass"}, 0)
    new_device.filter_cutoff = createFloatParameter(fe.command_controller, "Filter Cutoff", 1000.0, 20.0, 20000.0)
    new_device.filter_keytrack = createFloatParameter(fe.command_controller, "Filter Keytrack", 0.0, -1.0, 1.0)
    new_device.filter_resonance = createFloatParameter(fe.command_controller, "Filter Resonance", 0.5, 0.0, 1.0)
    new_device.filter_morph = createFloatParameter(fe.command_controller, "Filter Morph", 0.0, 0.0, 1.0)
    new_device.filter_slope = createOptionsParameter(fe.command_controller, "Filter Slope", {"12dB", "24dB"}, 0)
    new_device.filter_amount = createFloatParameter(fe.command_controller, "Filter Amount", 0.0, 0.0, 1.0)
    new_device.amp_attack = createTimeParameter(fe.command_controller, "Amp Attack", 0.01, 0.0, 10.0)
    new_device.amp_decay = createTimeParameter(fe.command_controller, "Amp Decay", 0.1, 0.0, 10.0)  
    new_device.amp_sustain = createFloatParameter(fe.command_controller, "Amp Sustain", 0.8, 0.0, 1.0)
    new_device.amp_release = createTimeParameter(fe.command_controller, "Amp Release", 0.5, 0.0, 10.0)
    new_device.filter_attack = createTimeParameter(fe.command_controller, "Filter Attack", 0.01, 0.0, 10.0)
    new_device.filter_decay = createTimeParameter(fe.command_controller, "Filter Decay", 0.1, 0.0, 10.0)
    new_device.filter_sustain = createFloatParameter(fe.command_controller, "Filter Sustain", 0.8, 0.0, 1.0)
    new_device.filter_release = createTimeParameter(fe.command_controller, "Filter Release", 0.5, 0.0, 10.0)
    new_device.filter_env_amount = createFloatParameter(fe.command_controller, "Filter Env Amount", 0.0, 0.0, 1.0)
    new_device.pitch_attack = createTimeParameter(fe.command_controller, "Pitch Attack", 0.01, 0.0, 10.0)
    new_device.pitch_decay = createTimeParameter(fe.command_controller, "Pitch Decay", 0.1, 0.0, 10.0)
    new_device.pitch_sustain = createFloatParameter(fe.command_controller, "Pitch Sustain", 0.8, 0.0, 1.0)
    new_device.pitch_release = createTimeParameter(fe.command_controller, "Pitch Release", 0.5, 0.0, 10.0)
    new_device.lfo_rate = createFloatParameter(fe.command_controller, "LFO Rate", 5.0, 0.1, 20.0)
    new_device.lfo_depth = createFloatParameter(fe.command_controller, "LFO Depth", 0.5, 0.0, 1.0)
    new_device.lfo_destination = createOptionsParameter(fe.command_controller, "LFO Destination", {"Pitch", "Filter Cutoff", "Amp"}, 0)
    new_device.lfo_waveform = createOptionsParameter(fe.command_controller, "LFO Waveform", {"Sine", "Square", "Saw", "Triangle", "Reverse Saw", "Noise"}, 0)
    new_device.lfo_tempo_sync = createOptionsParameter(fe.command_controller, "LFO Tempo Sync", {"1/4", "1/8", "1/16", "1/32"}, 0)
    new_device.lfo_trigger = createOptionsParameter(fe.command_controller, "LFO Trigger", {"Free", "Envelope", "Beat", "MIDI"}, 0)  

    return new_device
}