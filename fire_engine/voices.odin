package fire_engine

import "core:fmt"
import ow "./odinworks"

MAX_VOICES :: 32
VoiceState :: enum {
    Free,
    NoteOn,
    Sustained,
    NoteOff,
}

Voice :: struct {
    note : i32,
    age: int, // Used to track the age of the voice for allocation purposes
    state: VoiceState,
    audio: ^WaveAudio, // Reference to the audio data being played by this voice
    process: proc(this: ^Voice, buffer: [^]f32, frameCount: u32, channels: int), // Function to fill the audio buffer for this voice
    looping: bool, // Whether the voice should loop when it reaches the end of the sample
    start: u64, // Position in frames to start playback from.
    end: u64, // Position in frames to end playback at (for sample looping or one-shot playback)
    base_note: i32, // The MIDI note number that corresponds to the original pitch of the sample, used for calculating pitch shifts
    velocity: i32, // Store the velocity of the note for use in amplitude scaling or other expressive parameters
    parts: [8]VoicePart,
    unison_count: u32,
    unison_detune: f32,
    unison_spread: f32, // Pan spread for unison voices, 0.0 = no spread, 1.0 = full left/right
    max_detune_cents: f32,
    applyDetune: proc(voice: ^Voice),
    setNote: proc(voice: ^Voice, note: i32, velocity: i32), // Function to set the note for the voice which can also update the playback rate based on the base_note
    setState: proc(voice: ^Voice, state: VoiceState), // Function to handle state changes for the voice
    setDetune: proc(voice: ^Voice, detune_amount: f32),
    setUnison: proc(voice: ^Voice, unison_count: u32),
    setStart: proc(voice: ^Voice, start_frame: u64),
    setEnd: proc(voice: ^Voice, end_frame: u64),
    gain_coefs: ow.ow_gain_coeffs,
}


VoicePart :: struct {
    cursor: f32,
    rate: f32,
    pan: f32,
    gain: f32,
}

createVoice :: proc(audio: ^WaveAudio, looping: bool) -> ^Voice {
    voice := new(Voice)
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
    voice.applyDetune = voiceApplyDetune
    voice.setDetune = voiceSetDetune
    voice.setUnison = voiceSetUnision
    voice.setStart = voiceSetStart
    voice.setEnd = voiceSetEnd
    ow.ow_gain_init(&voice.gain_coefs)
    for i in 0..<len(voice.parts) {
        voice.parts[i].cursor = f32(voice.start)
        voice.parts[i].rate = 1.0
        voice.parts[i].pan = 0.0
    }
    voice->applyDetune()
    return voice
}

voiceProcess :: proc(this: ^Voice, buffer: [^]f32, frameCount: u32, channels: int) {
    // This is where the voice would generate its audio for the current buffer. It would typically read from its audio data using the cursor, apply any envelopes or effects, and fill the buffer.
    // For simplicity, this example just fills the buffer with silence. You would replace this with your actual audio generation logic.
    buf := [2]f32{0, 0} 
    for i in 0..<frameCount {
        // Assuming stereo output, initialize buffer for this frame
        buf = {0, 0}
        for channel in 0..<channels {
            if this.state == .NoteOn || this.state == .Sustained {
                // Here you would read the sample data from this.audio using this.cursor, apply any necessary processing (envelopes, effects, etc.), and write it to the buffer.
                // For example:
                // sample_value := readSample(this.audio, this.cursor)
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
        if this.state == .NoteOff {
            // If the voice is in the NoteOff state, we can transition it to Free after processing the current buffer. This allows any release envelopes to finish.
            voiceSetState(this, .Free)
        }
        for u in 0..<this.unison_count {
            part := &this.parts[u]
            part.cursor += part.rate // Move the cursor forward by the playback rate for this part
            if this.audio != nil && part.cursor >= f32(this.end) {
                if this.looping {
                    part.cursor = f32(this.start) // Loop back to the beginning
                } else {
                    voiceSetState(this, .Free) // Set to Free if not looping
                }
            }
        }
    }
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

voiceSetUnision :: proc(voice: ^Voice, unison_count: u32) {
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

voiceSetState :: proc(voice: ^Voice, state: VoiceState) {
    // Here you can add any additional logic needed when changing states, such as triggering envelopes, resetting parameters, etc.
    voice.state = state
    if state == .NoteOn {
        for u in 0..<voice.unison_count {
            part := &voice.parts[u]
            part.cursor = 0.0 // Reset each part's cursor as well
        }
    }
}

voiceSetVelocity :: proc(voice: ^Voice, velocity: i32) {
    voice.velocity = clamp(velocity, 0, 127)
    // You could also apply the velocity to the gain of the voice here, for example:
    voice.gain_coefs.gain = midiToNormal(u8(voice.velocity)) // Convert MIDI velocity to a 0.0 - 1.0 range for gain control
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


VoiceAllocator :: struct {
    voices: [MAX_VOICES]Voice, // Dynamic at first, try fixed array size later
    polyphony: int, // Max number of simultaneous voices
    age_counter: int, // Incremented each time a voice is allocated to track the age of voices
    sustain: bool, // Whether sustain is active, which can affect voice deallocation
    noteOn: proc(allocator: ^VoiceAllocator, note: i32),
    noteOff: proc(allocator: ^VoiceAllocator, note: i32),
    setSustain: proc(allocator: ^VoiceAllocator, sustain: bool),
    allocate: proc(allocator: ^VoiceAllocator, note: i32),
    deallocate: proc(allocator: ^VoiceAllocator, note: i32),
    oldestVoiceIndex: proc(allocator: ^VoiceAllocator) -> int,
    freeVoiceIndex: proc(allocator: ^VoiceAllocator) -> int,
    printActiveVoices: proc(allocator: ^VoiceAllocator),
}

createVoiceAllocator :: proc(polyphony: int = 8) -> ^VoiceAllocator {
    va := new(VoiceAllocator)
    va.age_counter = 0
    va.sustain = false
    va.polyphony = clamp(polyphony, 1, MAX_VOICES)
    // Methods
    va.noteOn = voiceAllocatorNoteOn
    va.noteOff = voiceAllocatorNoteOff
    va.allocate = allocateVoice
    va.deallocate = deallocateVoice
    va.oldestVoiceIndex = getOldestVoiceIndex
    va.freeVoiceIndex = getFreeVoiceIndex
    va.printActiveVoices = voiceAllocatorPrintActiveVoices
    va.setSustain = voiceAllocatorSetSustain
    return va
   
}
voiceAllocatorSetPolyphony :: proc(allocator: ^VoiceAllocator, polyphony: int) {
    allocator.polyphony = clamp(polyphony, 1, MAX_VOICES)
    // Optionally, you could also reset the voices here or handle any necessary cleanup if reducing polyphony
    // TODO: If the polyphony is reduced, we should probably deallocate oldest voices that are now above the new polyphony limit. 
    // This could be done by oldest voices and setting any that are above the new limit to Free.
}

voiceAllocatorPrintActiveVoices :: proc(allocator: ^VoiceAllocator) {
    fmt.println("Active Voices:")
    for index in 0..<allocator.polyphony {
        voice := &allocator.voices[index]
        if voice.state != .Free {
            fmt.printfln("Note: %d, Age: %d, State: %v", voice.note, voice.age, voice.state)
        }
    }
}

voiceAllocatorSetSustain :: proc(allocator: ^VoiceAllocator, sustain: bool) {
    // Only act on changes to the sustain state
    if sustain == allocator.sustain {
        return
    }
    allocator.sustain = sustain
    if !allocator.sustain {
        // If sustain is released, we need to deallocate any voices that were marked as sustained
        for index in 0..<allocator.polyphony {
            voice := &allocator.voices[index]
            if voice.state == .Sustained {
                voiceSetState(voice, .NoteOff)
            }
        }
    }
}
// If negative, no free voice was found
getFreeVoiceIndex :: proc (allocator: ^VoiceAllocator) -> int {
    oldestIndex := -1
    for index in 0..<allocator.polyphony {
        voice := &allocator.voices[index]
        if voice.state == .Free {
            return index
        }
    }
    return oldestIndex
}

getOldestVoiceIndex :: proc (allocator: ^VoiceAllocator) -> int {
    oldestIndex := -1
    oldestAge := 0
    for index in 0..<allocator.polyphony {
        voice := &allocator.voices[index]
        if oldestAge == 0 || voice.age < oldestAge {
            oldestAge = voice.age
            oldestIndex = index
        }
    }
    return oldestIndex
}

voiceAllocatorNoteOn :: proc(allocator: ^VoiceAllocator, note: i32) {
    allocateVoice(allocator, note)
}

voiceAllocatorNoteOff :: proc(allocator: ^VoiceAllocator, note: i32) {
    if allocator.sustain {
        // If sustain is active, we don't want to deallocate the voice immediately. Instead, we can mark it as sustained and handle the actual deallocation when sustain is released.
        for index in 0..<allocator.polyphony {
            voice := &allocator.voices[index]
            if voice.note == note && voice.state == .NoteOn {
                voiceSetState(voice, .Sustained)
                return
            }
        }
    }
    deallocateVoice(allocator, note)
}

allocateVoice :: proc(allocator: ^VoiceAllocator, note: i32) {
    allocator.age_counter += 1
    next_voice_index := getFreeVoiceIndex(allocator)
    stealing := false
    // If no free voice is found, we need to steal the oldest active voice
    if next_voice_index == -1 {
        stealing = true
        next_voice_index = getOldestVoiceIndex(allocator)
    }
    voice := &allocator.voices[next_voice_index]
    voice.note = note
    voice.age = allocator.age_counter
    // probably need to use set state here, could pass tick offset for note start timing etc.
    voiceSetState(voice, .NoteOn)
    
}

deallocateVoice :: proc(allocator: ^VoiceAllocator, note: i32) {
    for index in 0..<allocator.polyphony {
        voice := &allocator.voices[index]
        if voice.note == note && voice.state != .Free {
            voiceSetState(voice, .NoteOff)
            return
        }
    }
}