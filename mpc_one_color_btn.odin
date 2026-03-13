package main

import fire_engine "fire_engine"
import log "core:log"

OCB_Colors :: enum {
    Off,
    On
}

OneColorButton :: struct {
    using control : fire_engine.Control,
    sendColor: proc(control: ^OneColorButton, color: OCB_Colors),
    pressed: bool,
    onPress: ^fire_engine.Signal,
    onRelease: ^fire_engine.Signal,
    onClick: ^fire_engine.Signal,
    onValue: ^fire_engine.Signal,
    value: u8,
}

createOneColorButton :: proc(name: string, identifier: u8) -> ^OneColorButton {
    button := new(OneColorButton)
    fire_engine.configureControl(button, name)
    button.channel = 0
    button.status = fire_engine.NOTE_ON
    button.identifier = identifier
    button.pressed = false
    button.value = 0
    button.sendColor = oneColorButton_SendColor
    button.onPress = fire_engine.createSignal()
    button.onRelease = fire_engine.createSignal()
    button.onClick = fire_engine.createSignal()
    button.onValue = fire_engine.createSignal()
    button.handleInput = handleButtonInput
    return button
}

    
isMatchingMessage :: proc(control_ptr: rawptr, msg: ^fire_engine.ShortMessage) -> bool {
    control := cast(^fire_engine.Control)control_ptr
    return msg->getChannel() == control.channel && msg.data1 == control.identifier
}
oneColorButton_SendColor :: proc(control: ^OneColorButton, color: OCB_Colors) {
    msg := fire_engine.ShortMessage{
        status = fire_engine.CONTROL_CHANGE | u8(control.channel),
        data1 = control.identifier,
        data2 = u8(color),
    }
    control.sendMidi(control, msg)
 }

 oneColorButton_onDeactivate :: proc(control_ptr: rawptr) {
    control := cast(^OneColorButton)control_ptr
    control.sendColor(control, OCB_Colors.Off)
 }

// Handle button Input
handleButtonInput :: proc(ptr: rawptr, msg: ^fire_engine.ShortMessage) -> bool {
    control := cast(^OneColorButton)ptr
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

createButtonControl :: proc(name: string, channel: u8, status: u8, identifier: u8, midi_device: ^fire_engine.MidiDevice = nil) -> ^OneColorButton {
    button := new(OneColorButton)
    fire_engine.configureControl(button, name)
    button.channel = channel
    button.status = status
    button.identifier = identifier
    button.pressed = false
    button.value = 0
    button.onPress = fire_engine.createSignal()
    button.onRelease = fire_engine.createSignal()
    button.onClick = fire_engine.createSignal()
    button.onValue = fire_engine.createSignal()
    button.onDeactivate = oneColorButton_onDeactivate
    button.onInput = handleButtonInput
    return button
}