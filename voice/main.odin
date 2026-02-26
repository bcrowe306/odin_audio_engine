package main

import "core:time"
import "core:fmt"
import "vendor:portmidi"
import "../fire_engine"

Note :: struct {
    note: i32,
    velocity: i32,
    start: time.Tick,
    duration: time.Duration,
}

printNote :: proc(n: Note) {
    fmt.printfln("Note: %d, Velocity: %d, Start: %d, Duration: %.2f", n.note, n.velocity, n.start._nsec, time.duration_seconds(n.duration))
}

MidiMsg :: struct {
    status: i32,
    data1: i32,
    data2: i32,
}
isNoteOn :: proc(msg: MidiMsg) -> bool {
    return (msg.status & 0xF0) == 0x90 && msg.data2 > 0
}
isNoteOff :: proc(msg: MidiMsg) -> bool {
    return ((msg.status & 0xF0) == 0x80) || ((msg.status & 0xF0) == 0x90 && msg.data2 == 0)
}

isSustainMsg :: proc(msg: MidiMsg) -> bool {
    return (msg.status & 0xF0) == 0xB0 && msg.data1 == 64
}

Notes := [128]Note{}

main :: proc() {

    va := fire_engine.createVoiceAllocator(4)
    err := portmidi.Initialize()
    if err != nil {
        fmt.println("Failed to initialize PortMidi:", err)
        return
    }
    deviceStreams: [128]portmidi.Stream
    input_count := 0
    for i in 0..<portmidi.CountDevices() {
        dId:= cast(portmidi.DeviceID)i
        device_info := portmidi.GetDeviceInfo(dId)
        if cast(bool)device_info.input {
            fmt.println("Opening MIDI input device: ", device_info.name)
            portmidi.OpenInput(&deviceStreams[input_count], dId, nil, 1024, nil, nil)
            input_count += 1
        }
        
    }
    buffer: [1024]portmidi.Event
    notes := [128]bool{}
    
    for {

        for i in 0..<input_count {
            stream := deviceStreams[i]
            err := portmidi.Poll(stream)
            if err == .GotData {
                count := portmidi.Read(stream, &buffer[0], 1024)
                for j in 0..<count {
                    event := buffer[j]
                    msg := MidiMsg{
                        status= portmidi.MessageStatus(event.message),
                        data1= portmidi.MessageData1(event.message),
                        data2= portmidi.MessageData2(event.message),
                    }
                    // Mock voice allocator voices ADSR setting from noteoff to free
                    for &voice in &va.voices {
                        if voice.state == .NoteOff {
                            fire_engine.voiceSetState(&voice, .Free)
                        }
                    }
                    // Note on
                    if isNoteOn(msg) {
                        va->noteOn(msg.data1)
                        Notes[msg.data1] = Note{
                            note = msg.data1,
                            velocity = msg.data2,
                            start = time.tick_now(),
                        }
                        va->printActiveVoices()

                    // Note off
                    } else if isNoteOff(msg) {
                        if Notes[msg.data1].note != 0 {
                            note := Notes[msg.data1]
                            note.duration = time.tick_diff(note.start, time.tick_now())
                            // printNote(note)
                        }
                        va->noteOff(msg.data1)
                        va->printActiveVoices()
                    } else if isSustainMsg(msg) {
                        sustainOn := msg.data2 > 0
                        va->setSustain(sustainOn)
                        va->printActiveVoices()
                    }

                    
                }
            }
        }

        time.sleep(10 * time.Millisecond)
    }
}