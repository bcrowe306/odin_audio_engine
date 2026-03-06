package fire_engine

// Encoder control using MIDI ControlChange messages with relative modes

EncoderControl :: struct {
    using control : Control,
    value: u8,
    onValue: ^Signal,
    onUnitValue: ^Signal,
    onEncode: ^Signal,
}

createEncoderControl :: proc(name: string, channel: u8, identifier: u8, default_value: u8 = 0) -> ^EncoderControl {
    encoder_control := new(EncoderControl)
    configureControl(encoder_control, name)
    encoder_control.channel = channel
    encoder_control.status = 0xB0
    encoder_control.identifier = identifier
    encoder_control.value = default_value
    encoder_control.onValue = createSignal()
    encoder_control.onUnitValue = createSignal()
    encoder_control.onEncode = createSignal()
    encoder_control.onInput = handleEncoderInput
    
    return encoder_control
}

handleEncoderInput :: proc(ptr: rawptr, msg: ^ShortMessage) -> bool {
    control := cast(^EncoderControl)ptr
    if msg->getChannel() == control.channel && msg->getMessageType() == control.status && msg.data1 == control.identifier {
        // Handle relative encoder modes (0-63 = +1 to +64, 65-127 = -1 to -63)
        delta := 0
        if msg.data2 <= 64 {
            delta = int(msg.data2)
        } else {
            delta = int(msg.data2) - 128
        }
        control.value = u8(clamp(int(control.value) + delta, 0, 127))
        control.onValue->emit(delta)
        unit_value := f32(control.value) / 127.0
        control.onUnitValue->emit(unit_value)
        control.onEncode->emit(delta)
        return true
    }
    return false
}