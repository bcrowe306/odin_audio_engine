package fire_engine


// MIDI Fader control  using ControlChange messages
FaderControl :: struct {
    using control : Control,
    value: u8,
    onValue: ^Signal,
    onUnitValue: ^Signal,
}

createFaderControl :: proc(name: string, channel: u8, identifier: u8) -> ^FaderControl {
    fader_control := new(FaderControl)
    configureControl(fader_control, name)
    fader_control.channel = channel
    fader_control.status = 0xB0
    fader_control.identifier = identifier
    fader_control.value = 0
    fader_control.onValue = createSignal()
    fader_control.onUnitValue = createSignal()
    fader_control.onInput = FaderControl_HandleInput
    
    return fader_control
}

FaderControl_HandleInput :: proc(ptr: rawptr, msg: ^ShortMessage) -> bool {
    control := cast(^FaderControl)ptr
    if msg->getChannel() == control.channel && msg->getMessageType() == control.status && msg.data1 == control.identifier {
        if control.value != msg.data2 {
            control.value = msg.data2
            control.onValue->emit(msg)
            unit_value := f32(msg.data2) / 127.0
            control.onUnitValue->emit(unit_value)
        }
        return true
    }
    return false
}

