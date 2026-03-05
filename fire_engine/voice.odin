package fire_engine

import "core:c"
import "core:fmt"
import ow "./odinworks"

// TODO: Keytrack is based on middle C, 60. 
// Keytrack Modulation is calculated based on diff of incoming note to middle C,60. Amount of modulation applied is based on key_track amount: f32
// Example incoming note:  = 72, 72-60 = 12. If key_track is 1.0, then modulation applied to filter cutoff would be 1 octave (12 semitones) increase. If key_track is 0.5, then modulation would be 0.5 octaves (6 semitones) increase, etc.

MAX_VOICES :: 32
VoiceState :: enum {
    Free,
    NoteOn,
    Sustained,
    NoteOff,
}

SamplePlaybackMode :: enum {
    ADSR,
    OneShot
}

Voice :: struct {
    note : i32,
    age: int, // Used to track the age of the voice for allocation purposes
    state: VoiceState,
    playback_mode: SamplePlaybackMode,
    audio: ^WaveAudio, // Reference to the audio data being played by this voice
    process: proc(this: ^Voice, buffer: [^]f32, frameCount: u32, channels: int), // Function to fill the audio buffer for this voice
    gate: bool, // Whether the note is currently held (NoteOn) or has been released (NoteOff), used for envelope processing
    looping: bool, // Whether the voice should loop when it reaches the end of the sample
    start: u64, // Position in frames to start playback from.
    end: u64, // Position in frames to end playback at (for sample looping or one-shot playback)
    base_note: i32, // The MIDI note number that corresponds to the original pitch of the sample, used for calculating pitch shifts
    velocity: i32, // Store the velocity of the note for use in amplitude scaling or other expressive parameters
    velocity_unit: f32, // Velocity converted to a 0.0 - 1.0 range for easier use in gain calculations
    parts: [8]VoicePart,
    unison_count: u32,
    unison_detune: f32,
    unison_spread: f32, // Pan spread for unison voices, 0.0 = no spread, 1.0 = full left/right
    max_detune_cents: f32,
    applyDetune: proc(voice: ^Voice),
    setNote: proc(voice: ^Voice, note: i32, velocity: i32), // Function to set the note for the voice which can also update the playback rate based on the base_note
    setState: proc(voice: ^Voice, state: VoiceState), // Function to handle state changes for the voice
    setDetune: proc(voice: ^Voice, detune_amount: f32), // Function to set the detune amount for unison voices, which will affect the playback rate of each part
    setUnison: proc(voice: ^Voice, unison_count: u32), // Function to set the number of unison voices, which will affect how many parts are active and their detune/pan settings
    setStart: proc(voice: ^Voice, start_frame: u64), // Function to set the start position for the voice, which can be used for sample playback to define where in the sample the voice should start
    setEnd: proc(voice: ^Voice, end_frame: u64), // Function to set the end position for the voice, which can be used for sample playback to define where in the sample the voice should stop or loop back to the start
    noteOn: proc(voice: ^Voice, note: i32, velocity: i32), // Function to trigger a note on event for the voice, which will set the note, velocity, and change the state to NoteOn
    noteOff: proc(voice: ^Voice), // Function to trigger a note off event for the voice, which will change the state to NoteOff and allow for release envelopes to take effect
    
    // OW Coefs
    gain_coefs: ow.ow_gain_coeffs,
    amp_env_coefs: ow.ow_env_gen_coeffs,
    amp_env_state: ow.ow_env_gen_state,
    amp_env_value: f32, // Store the current value of the amplitude envelope for use in gain modulation
    
    filter_env_enabled: bool, // Whether the filter envelope is enabled for this voice, which can be used to conditionally apply filter modulation in the processing function
    filter_key_track: f32, // Amount of key tracking to apply to the filter cutoff, where 0.0 means no tracking and 1.0 means full tracking (cutoff increases by 1 octave for every 12 MIDI notes)
    filter_env_coefs: ow.ow_env_gen_coeffs,
    filter_env_state: ow.ow_env_gen_state,
    filter_env_value: f32, // Store the current value of the filter envelope for use in filter modulation
    
    pitch_env_enabled: bool, // Whether the pitch envelope is enabled for this voice, which can be used to conditionally apply pitch modulation in the processing function
    pitch_env_coefs: ow.ow_env_gen_coeffs,
    pitch_env_state: ow.ow_env_gen_state,
    pitch_env_value: f32, // Store the current value of the pitch envelope for use in pitch modulation
    filter_coefs: ow.ow_mm2_coeffs, // Coefficients for the mm2 filter, which can be modulated by the filter envelope
    filter_state: ow.ow_mm2_state,

}


VoicePart :: struct {
    cursor: f32,
    rate: f32,
    pan: f32,
    gain: f32,
}



createVoice :: proc(sample_rate: f32, audio: ^WaveAudio, looping: bool) -> ^Voice {
    voice := new(Voice)
    configureVoice(voice, sample_rate, audio, looping)
    return voice
}

configureVoice :: proc(voice: ^Voice, sample_rate: f32, audio: ^WaveAudio, looping: bool) {
    voice.audio = audio
    voice.note = -1 // No note assigned yet
    voice.age = 0
    voice.state = .Free
    voice.audio = audio
    voice.start = 0
    if audio != nil {
        voice.end = u64(audio.frames)
    } else {
        voice.end = 0
    }

    voice.process = voiceProcess
    voice.looping = looping
    voice.setState = voiceSetState
    voice.base_note = 60 // Default to middle C (MIDI note 60)
    voice.setNote = voiceSetNote
    voice.unison_count = 1
    voice.unison_detune = 1.0 // Unit value: 1.0 = 100 cents
    voice.unison_spread = 0.5 // Pan spread for unison voices, 0.0 = no spread, 1.0 = full left/right
    voice.max_detune_cents = 5000.0
    voice.playback_mode = .ADSR

    // Methods
    voice.applyDetune = voiceApplyDetune
    voice.setDetune = voiceSetDetune
    voice.setUnison = voiceSetUnison
    voice.setStart = voiceSetStart
    voice.setEnd = voiceSetEnd
    voice.noteOn = voiceNoteOn
    voice.noteOff = voiceNoteOff
    
    ow.ow_gain_init(&voice.gain_coefs)

    ow.ow_env_gen_init(&voice.amp_env_coefs)
    ow.ow_env_gen_init(&voice.filter_env_coefs)
    ow.ow_env_gen_init(&voice.pitch_env_coefs)

    // TODO: May need a better way to handle sample rate changes, currently this just sets it at voice creation time. If the engine's sample rate can change dynamically, we would need to update this for all active voices when that happens.
    ow.ow_env_gen_set_sample_rate(&voice.amp_env_coefs, sample_rate)
    ow.ow_env_gen_set_sample_rate(&voice.filter_env_coefs, sample_rate)
    ow.ow_env_gen_set_sample_rate(&voice.pitch_env_coefs, sample_rate)
    for i in 0..<len(voice.parts) {
        voice.parts[i].cursor = f32(voice.start)
        voice.parts[i].rate = 1.0
        voice.parts[i].pan = 0.0
    }
    voice->applyDetune()
}

voiceProcess :: proc(this: ^Voice, buffer: [^]f32, frameCount: u32, channels: int) {
    // This is where the voice would generate its audio for the current buffer. It would typically read from its audio data using the cursor, apply any envelopes or effects, and fill the buffer.
    // For simplicity, this example just fills the buffer with silence. You would replace this with your actual audio generation logic.
    buf := [2]f32{0, 0} 
    for i in 0..<frameCount {
        // Assuming stereo output, initialize buffer for this frame
        buf = {0, 0}

        // Process env for voice
        voiceProcessEnvelopes(this)
        ow.ow_gain_set_gain_lin(&this.gain_coefs, this.velocity_unit * this.amp_env_value) // Modulate gain by envelope value
        
        // Per Channel processing for the voice
        for channel in 0..<channels {
            if this.state != .Free {
                if this.audio != nil {
                    for u in 0..<this.unison_count {
                        part := &this.parts[u]
                        interpolateInterleavedSamples(this.audio, part.cursor, &buf)
                        applyBasicPanning(&buf, part.pan)
                        applyBasicGain(&buf, part.gain)
                        // Apply any per-part processing here (e.g., pan, volume, etc.)
                        buffer[i * u32(channels) + u32(channel)] += buf[channel] // Mix the part's output into the main buffer
                        
                    }
                    // After mixing all unison parts, apply the gain processing for the voice
                    ow.ow_gain_process(&this.gain_coefs, &buffer[i * u32(channels) + u32(channel)], &buffer[i * u32(channels) + u32(channel)], 1) // Apply gain processing to the mixed sample
                    
                } 
                 // Write the processed sample to the output buffer
            } else {
                buffer[i * u32(channels) + u32(channel)] = 0 // Silence for voices that are not active
            }
        }

        // Check phase of env and set state of voice accordingly
        env_phase := ow.ow_env_gen_get_phase(&this.amp_env_state)
        if env_phase == .ow_env_gen_phase_off {
             voiceSetState(this, .Free)
        }

        for u in 0..<this.unison_count {
            part := &this.parts[u]
            part.cursor += part.rate // Move the cursor forward by the playback rate for this part
            if this.audio != nil && part.cursor >= f32(this.end) {
                if this.looping {
                    part.cursor = f32(this.start) // Loop back to the beginning
                
                } else {
                    // Reached end and not looping, so we can mark the voice as Free. In a more complex implementation, you might want to allow the voice to stay in NoteOff state for a short time to allow release envelopes to finish before setting it to Free.
                    // part.cursor = f32(this.start)
                    this.gate = false // Trigger release phase of envelope
                    voiceResetEnvelopes(this, this.gate)
                    voiceSetState(this, .Free) // Set to Free if not looping
                }
            }
        }
    }
}

voiceResetEnvelopes :: proc(this: ^Voice, gate: bool) {
    ow.ow_env_gen_reset_state(&this.amp_env_coefs, &this.amp_env_state, gate) 
    ow.ow_env_gen_reset_state(&this.filter_env_coefs, &this.filter_env_state, gate)
    ow.ow_env_gen_reset_state(&this.pitch_env_coefs, &this.pitch_env_state, gate)
}

voiceProcessEnvelopes :: proc(this: ^Voice) {
    ow.ow_env_gen_process(&this.amp_env_coefs, &this.amp_env_state, this.gate, nil, 1 )
    ow.ow_env_gen_process(&this.filter_env_coefs, &this.filter_env_state, this.gate, nil, 1 )
    ow.ow_env_gen_process(&this.pitch_env_coefs, &this.pitch_env_state, this.gate, nil, 1 )
    this.amp_env_value = ow.ow_env_gen_get_y_z1(&this.amp_env_state)
    this.filter_env_value = ow.ow_env_gen_get_y_z1(&this.filter_env_state)
    this.pitch_env_value = ow.ow_env_gen_get_y_z1(&this.pitch_env_state)
}

voiceSetStart :: proc(voice: ^Voice, start_frame: u64) {
    voice.start = start_frame
    for i in 0..<len(voice.parts) {
        voice.parts[i].cursor = f32(start_frame)
    }
}

voiceSetEnd :: proc(voice: ^Voice, end_frame: u64) {
    voice.end = end_frame
}

voiceSetUnison :: proc(voice: ^Voice, unison_count: u32) {
    voice.unison_count = clamp(unison_count, 1, u32(len(voice.parts)))
    voice->applyDetune()
}

voiceSetDetune :: proc(voice: ^Voice, detune_amount: f32) {
    voice.unison_detune = clamp(detune_amount, 0.0, 1.0)
    voice->applyDetune()
}

voiceApplyDetune :: proc(voice: ^Voice) {
    if voice.unison_count <= 1 {
        // If unison count is 1, we don't need to apply any detune
        part := &voice.parts[0]
        part.rate = rateFromBaseNote(voice.base_note, voice.note)
        part.pan = 0.0
        part.gain = 1.0
        return
    }

    for u in 0..<voice.unison_count {
        part := &voice.parts[u]
        detune_amount := (f32(u) - f32(voice.unison_count-1)/2.0) * voice.unison_detune * voice.max_detune_cents
        part.rate = detuneRateByCents( rateFromBaseNote( voice.base_note, voice.note ), detune_amount )
        part.pan = (f32(u) - f32(voice.unison_count-1)/2.0) * voice.unison_spread
        part.gain = dBToLinear_f32(-3.0) // Additional gain reduction based on detune amount to help control the overall level increase from unison voices
    }
}

voiceSetState :: proc(this: ^Voice, new_state: VoiceState) {
    // Here you can add any additional logic needed when changing states, such as triggering envelopes, resetting parameters, etc.
    current_state := this.state
    switch new_state {
        case .NoteOn:
            // Trigger attack phase of envelopes
            this.gate = true
            for u in 0..<this.unison_count {
                part := &this.parts[u]
                part.cursor = f32(this.start)
            }
            voiceResetEnvelopes(this, this.gate)
            this.state = new_state

        case .NoteOff:
            if current_state == .NoteOn && this.playback_mode == .ADSR {
                this.gate = false // Trigger release phase of envelopes
                this.state = new_state
            }
        
        case .Sustained:
            // This state can be used to indicate that the note is being sustained (e.g., by a sustain pedal) even though the key has been released. You might want to handle this differently in your envelope processing.
            this.state = new_state
        case .Free:
            // Reset any parameters as needed when the voice becomes free
            this.state = new_state
    }

}


voiceNoteOn :: proc(this: ^Voice, note: i32, velocity: i32) {
    this.setNote(this, note, velocity)
    this.setState(this, .NoteOn)
    
}

voiceNoteOff :: proc(this: ^Voice) {
    this.setState(this, .NoteOff)
}

voiceSetVelocity :: proc(voice: ^Voice, velocity: i32) {
    voice.velocity = clamp(velocity, 0, 127)
    // You could also apply the velocity to the gain of the voice here, for example:
    voice.velocity_unit = midiToNormal(u8(voice.velocity)) // Store the velocity in a 0.0 - 1.0 range for easier use in gain calculations
}

voiceSetNote :: proc(voice: ^Voice, note: i32, velocity: i32 = -1) {
     if velocity >= 0 {
        voiceSetVelocity(voice, velocity)
    }
    voice.note = note

    // Optionally, you could also calculate the playback rate for pitch shifting based on the note and the base_note of the sample
    rate := rateFromBaseNote(voice.base_note, voice.note)
    voice->applyDetune() // Recalculate the rates for all parts based on the new note
}

