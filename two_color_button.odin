package main

import fire_engine "fire_engine"
import log "core:log"

TCB_Colors :: enum u8 {
    Off = 0,
    Primary = 1,
    Secondary = 2
}

TwoColorButton :: struct {
    using control : fire_engine.Control,
    pressed: bool,
    sendColor: proc(control: ^TwoColorButton, color: TCB_Colors),
    onPress: ^fire_engine.Signal,
    onRelease: ^fire_engine.Signal,
    onClick: ^fire_engine.Signal,
    onValue: ^fire_engine.Signal,
    value: u8,
}

    
TwoColorButton_SendColor :: proc(control: ^TwoColorButton, color: TCB_Colors) {
    msg := fire_engine.ShortMessage{
        status = fire_engine.CONTROL_CHANGE | u8(control.channel),
        data1 = control.identifier,
        data2 = u8(color),
    }
    control.sendMidi(control, msg)
}


createTwoColorButton :: proc(name: string, identifier: u8) -> ^TwoColorButton {
    button := new(TwoColorButton)
    fire_engine.configureControl(button, name)
    button.channel = 0
    button.status = fire_engine.NOTE_ON
    button.identifier = identifier
    button.pressed = false
    button.value = 0
    button.sendColor = TwoColorButton_SendColor
    button.onPress = fire_engine.createSignal()
    button.onRelease = fire_engine.createSignal()
    button.onClick = fire_engine.createSignal()
    button.onValue = fire_engine.createSignal()
    button.onDeactivate = twoColorButton_onDeactivate
    button.onInput = twoColorButton_handleButtonInput
    return button
}

twoColorButton_handleButtonInput :: proc(ptr: rawptr, msg: ^fire_engine.ShortMessage) -> bool {
    control := cast(^TwoColorButton)ptr
    handled := false
    log.infof("Received MIDI message for control %s: status=0x%X, data1=%d, data2=%d", control.name, msg.status, msg.data1, msg.data2)
    if isMatchingMessage(control, msg) {
        if msg->isNoteOn() {
            control.pressed = true
            if control.onPress != nil {
                control.onPress->emit(msg)
            }

            handled = true
        } else if msg->isNoteOff() {
            control.pressed = false
            
            if control.onRelease != nil {
                control.onRelease->emit(msg)
            }
            if control.onClick != nil {
                // control.onClick->emit(msg)
            }
            handled = true
        } else {
            handled = false
        }

    } else {
        handled = false
    }

    // If the message was handled emit value change if needed
    if handled {
        if msg.data2 != control.value {
            control.value = msg.data2
            control.onValue->emit(msg)
        }
    }

    return handled
}

twoColorButton_onDeactivate :: proc(control_ptr: rawptr) {
    control := cast(^TwoColorButton)control_ptr
    control.sendColor(control, TCB_Colors.Off)
}