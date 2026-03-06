package fire_engine

import "core:fmt"

ButtonControl :: struct {
    using control : Control,
    pressed: bool,
    onPress: ^Signal,
    onRelease: ^Signal,
    onClick: ^Signal,
    onValue: ^Signal,

    value: u8,
}

    
isMatchingMessage :: proc(control: ^ButtonControl, msg: ^ShortMessage) -> bool {
    return msg->getMessageType() == control.status && msg->getChannel() == control.channel && msg.data1 == control.identifier
}

defaultOnPress :: proc(control: ^ButtonControl) {
    fmt.printf("Button %s Pressed\n", control.name)
}

defaultOnRelease :: proc(control: ^ButtonControl) {
    fmt.printf("Button %s Released\n", control.name)
}

defaultOnClick :: proc(control: ^ButtonControl) {
    fmt.printf("Button %s Clicked\n", control.name)
}


// Handle button Input
handleButtonInput :: proc(ptr: rawptr, msg: ^ShortMessage) -> bool {

    control := cast(^ButtonControl)ptr
    if isMatchingMessage(control, msg) {


        if msg.data2 != control.value {
            control.value = msg.data2
            control.onValue->emit(msg)
        }
        if msg.data2 > 0 {
            if !control.pressed {
                control.pressed = true
                if control.onPress != nil {
                    control.onPress->emit(msg)
                }
            }
        } else {
            if control.pressed {
                control.pressed = false
                
                if control.onRelease != nil {
                    control.onRelease->emit(msg)
                }
                if control.onClick != nil {
                    control.onClick->emit(msg)
                }
            }
        }
        return true

    }
    return false
}

createButtonControl :: proc(name: string, channel: u8, status: u8, identifier: u8, midi_device: ^MidiDevice = nil) -> ^ButtonControl {
    button := new(ButtonControl)
    configureControl(button, name)
    button.channel = channel
    button.status = status
    button.identifier = identifier
    button.pressed = false
    button.value = 0
    button.onPress = createSignal()
    button.onRelease = createSignal()
    button.onClick = createSignal()
    button.onValue = createSignal()
    button.handleInput = handleButtonInput
    return button
}