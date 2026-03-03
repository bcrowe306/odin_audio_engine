package main

import "base:runtime"
import "core:math/rand"
import "core:time"
import ma "vendor:miniaudio"
import fe "../fire_engine"
import "core:fmt"


device_config: ma.device_config
Sampler :: struct {
    sample_data: fe.WaveAudio,
    cursor: f32,
}

voice: ^fe.Voice

sample: Sampler

device_callback :: proc "c" (device: ^ma.device, output: rawptr, input: rawptr, frameCount: u32) {
    context = runtime.default_context()
    voice := cast(^fe.Voice)device.pUserData

    output := cast([^]f32)output
    voice->process(output, frameCount, int(device.playback.channels))
    
}

main :: proc() {
    data, err := fe.loadWaveFile("perc.wav")
    
    if err != nil {
        fmt.println("Failed to load wave file:", err)
        return
    }
    voice = fe.createVoice(&data, false) // Create a voice with the loaded audio data and set it to loop
    sample.sample_data = data
    sample.cursor = 0.0

    device_config = ma.device_config_init(ma.device_type.playback)
    device_config.playback.format = ma.format.f32
    device_config.playback.channels = 2
    device_config.sampleRate = 48000
    device_config.periodSizeInFrames = 256
    device_config.dataCallback = device_callback
    device_config.pUserData = voice // You can set this to point to your audio engine or state if needed
    qm := fe.createQuickMidi(proc(msg: fe.MidiMsg, user_data: rawptr) {
        if (msg.status & 0xF0) == 0x90 && (msg.data2 > 0) { // Note On message with velocity > 0
            voice->setNote(msg.data1, msg.data2) // Set the note and velocity for the voice
            voice->setState(.NoteOn)
        } else if ((msg.status & 0xF0) == 0x80) || ((msg.status & 0xF0) == 0x90 && (msg.data2 == 0)) { // Note Off message or Note On with velocity 0
            voice->setState(.NoteOff)
        }
        else{
            fmt.println("Received MIDI message: status=", msg.status, " data1=", msg.data1, " data2=", msg.data2)
            if msg.status == 176 && msg.data1 > 69 && msg.data1 < 78 {
                if msg.data1 == 74 {
                    if msg.data2 == 1 {
                        voice->setUnison(voice.unison_count + 1)
                    } else {
                        voice->setUnison(voice.unison_count - 1)
                    }
                    fmt.println("Unison count set to: ", voice.unison_count)
                }

                if msg.data1 == 75 {
                    if msg.data2 == 1 {
                        voice->setDetune(voice.unison_detune + 0.01)
                    } else {
                        voice->setDetune(voice.unison_detune - 0.01)
                    }
                    fmt.println("Unison detune set to: ", voice.unison_detune)
                }
            }

        }
    }, nil)

    qm->start()
    device : ma.device
    ma.device_init(nil, &device_config, &device)
    ma.device_start(&device)

    for {
        // Main loop can do other things, or just sleep
        time.sleep(10 * time.Millisecond)
    }
}