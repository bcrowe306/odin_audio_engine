package fire_engine

// TouchEncoderControl combines relative encoder input with touch/focus events.
//
// Encoder movement defaults to ControlChange (0xB0) on `identifier`.
// Touch defaults to Note (0x90) on `touch_identifier`.
TouchEncoderControl :: struct {
    using control: Control,
    value: u8,
    touched: bool,

    touch_status: u8,
    touch_identifier: u8,

    onValue: ^Signal,
    onUnitValue: ^Signal,
    onEncode: ^Signal,
    onFocusChanged: ^Signal,
}

createTouchEncoderControl :: proc( name: string, channel: u8, identifier: u8, touch_identifier: u8, default_value: u8 = 0, encoder_msg_type: u8 = 0xB0, touch_msg_type: u8 = 0x90) -> ^TouchEncoderControl {
    touch_encoder_control := new(TouchEncoderControl)
    configureControl(touch_encoder_control, name)

    touch_encoder_control.channel = channel
    touch_encoder_control.status = encoder_msg_type
    touch_encoder_control.identifier = identifier
    touch_encoder_control.touch_status = touch_msg_type
    touch_encoder_control.touch_identifier = touch_identifier

    touch_encoder_control.value = default_value
    touch_encoder_control.touched = false

    touch_encoder_control.onValue = createSignal()
    touch_encoder_control.onUnitValue = createSignal()
    touch_encoder_control.onEncode = createSignal()
    touch_encoder_control.onFocusChanged = createSignal()

    touch_encoder_control.onInput = handleTouchEncoderInput

    return touch_encoder_control
}

handleTouchEncoderInput :: proc(ptr: rawptr, msg: ^ShortMessage) -> bool {
    control := cast(^TouchEncoderControl)ptr

    if msg->getChannel() != control.channel {
        return false
    }

    message_type := msg->getMessageType()

    // Encoder movement (same relative mode behavior as EncoderControl)
    if message_type == control.status && msg.data1 == control.identifier {
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

    // Touch / focus handling.
    // Default touch mode is NOTE (0x90): velocity > 0 => touched, 0 => released.
    // Also accepts explicit NOTE OFF (0x80) when touch_msg_type is NOTE.
    if msg.data1 == control.touch_identifier {
        if message_type == control.touch_status {
            touched_now := msg.data2 > 0
            if touched_now != control.touched {
                control.touched = touched_now
                control.onFocusChanged->emit(touched_now)
            }
            return true
        }

        if control.touch_status == 0x90 && message_type == 0x80 {
            if control.touched {
                control.touched = false
                control.onFocusChanged->emit(false)
            }
            return true
        }
    }

    return false
}