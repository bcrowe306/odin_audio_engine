package fire_engine

import "core:fmt"

VoiceAllocator :: struct {
    voices: [MAX_VOICES]Voice,
    polyphony: int, // Max number of simultaneous voices
    age_counter: int, // Incremented each time a voice is allocated to track the age of voices
    sustain: bool, // Whether sustain is active, which can affect voice deallocation
    noteOn: proc(allocator: ^VoiceAllocator, note: i32, velocity: i32),
    noteOff: proc(allocator: ^VoiceAllocator, note: i32),
    setSustain: proc(allocator: ^VoiceAllocator, sustain: bool),
    allocate: proc(allocator: ^VoiceAllocator, note: i32, velocity: i32),
    deallocate: proc(allocator: ^VoiceAllocator, note: i32),
    oldestVoiceIndex: proc(allocator: ^VoiceAllocator) -> int,
    freeVoiceIndex: proc(allocator: ^VoiceAllocator) -> int,
    printActiveVoices: proc(allocator: ^VoiceAllocator),
}

createVoiceAllocator :: proc(fe: ^FireEngine, polyphony: int = 8, audio: ^WaveAudio = nil) -> ^VoiceAllocator {
    va := new(VoiceAllocator)
    for i in 0..<MAX_VOICES {
        voice := &va.voices[i]
        configureVoice(voice, f32(fe.audio_engine.sample_rate), audio, false)
    }

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

voiceAllocatorNoteOn :: proc(allocator: ^VoiceAllocator, note: i32, velocity: i32) {
    allocateVoice(allocator, note, velocity)
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

allocateVoice :: proc(allocator: ^VoiceAllocator, note: i32, velocity: i32) {
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
    voice->noteOn(note, velocity)
    
}

deallocateVoice :: proc(allocator: ^VoiceAllocator, note: i32) {
    for index in 0..<allocator.polyphony {
        voice := &allocator.voices[index]
        if voice.note == note && voice.state != .Free {
            voice->noteOff()
            return
        }
    }
}