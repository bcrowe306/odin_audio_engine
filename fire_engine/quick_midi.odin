package fire_engine

import pm "vendor:portmidi"
import "core:time"
import "core:thread"
import "core:fmt"

MidiMsg :: struct {
    status: i32,
    data1: i32,
    data2: i32,
}
qm_isNoteOn :: proc(msg: MidiMsg) -> bool {
    return (msg.status & 0xF0) == 0x90 && msg.data2 > 0
}
qm_isNoteOff :: proc(msg: MidiMsg) -> bool {
    return ((msg.status & 0xF0) == 0x80) || ((msg.status & 0xF0) == 0x90 && msg.data2 == 0)
}

qm_isSustainMsg :: proc(msg: MidiMsg) -> bool {
    return (msg.status & 0xF0) == 0xB0 && msg.data1 == 64
}

qm_isControlChange :: proc(msg: MidiMsg) -> bool {
    return (msg.status & 0xF0) == 0xB0
}

qm_isPitchBend :: proc(msg: MidiMsg) -> bool {
    return (msg.status & 0xF0) == 0xE0
}

QuickMidi :: struct {
    deviceStreams: [128]pm.Stream,
    input_count: int,
    midi_buffer: [1024]pm.Event,
    start : proc(this: ^QuickMidi),
    handleMidiMsg: proc(msg: MidiMsg, user_data: rawptr),
    user_data: rawptr,
    running: bool,
    thread: ^thread.Thread,
}

createQuickMidi :: proc(handleMidiMsg: proc(msg: MidiMsg, user_data: rawptr), user_data: rawptr) -> ^QuickMidi {
    qm := new(QuickMidi)
    qm.input_count = 0
    qm.handleMidiMsg = handleMidiMsg
    qm.user_data = user_data
    qm.start = qm_start
    return qm
}

qm_start :: proc(this: ^QuickMidi) {
    this.running = true
    this.thread = thread.create(qm_midi_input)
    this.thread.data = this
    thread.start(this.thread)
}


qm_midi_input :: proc(thread: ^thread.Thread) {
    this := cast(^QuickMidi)thread.data
    err := pm.Initialize()
    if err != nil {
        fmt.println("Failed to initialize PortMidi:", err)
        return
    }
    for i in 0..<pm.CountDevices() {
        dId:= cast(pm.DeviceID)i
        device_info := pm.GetDeviceInfo(dId)
        if cast(bool)device_info.input {
            fmt.println("Opening MIDI input device: ", device_info.name)
            pm.OpenInput(&this.deviceStreams[this.input_count], dId, nil, 1024, nil, nil)
            this.input_count += 1
        }
        
    }
    for this.running {
        for i in 0..<this.input_count {
            stream := this.deviceStreams[i]
            err := pm.Poll(stream)
            if err == .GotData {
                count := pm.Read(stream, &this.midi_buffer[0], 1024)
                for j in 0..<count {
                    event := this.midi_buffer[j]
                    msg := MidiMsg{
                        status= pm.MessageStatus(event.message),
                        data1= pm.MessageData1(event.message),
                        data2= pm.MessageData2(event.message),
                    }
                    if this.handleMidiMsg != nil {
                        this.handleMidiMsg(msg, this.user_data)
                    }
                }
            }
        }

        time.sleep(10 * time.Millisecond)
    }
}