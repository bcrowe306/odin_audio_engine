package main

import fire_engine "fire_engine"
import log "core:log"

PadInput :: struct {
    msg: fire_engine.ShortMessage,
    padIndex: u32,
    velocity: u8,
    aftertouch: u8,
}

MPCPadsControl :: struct {
    using control : fire_engine.Control,
    sendColor: proc(control: ^MPCPadsControl, padId: u8, color: u8),
    bank: u32,
    PadMapping: map[u8]u32,
    setBank: proc(pc: ^MPCPadsControl, bank: u32),
    getPadId: proc(pc: ^MPCPadsControl, padIndex: u32) -> u8,
    getPadIndex: proc(pc: ^MPCPadsControl, padId: u8) -> u32,
    isMatching: proc(pc: ^MPCPadsControl, msg: ^fire_engine.ShortMessage) -> bool,
    onPadInput: ^fire_engine.Signal,
    onPadPress: ^fire_engine.Signal,
    onPadRelease: ^fire_engine.Signal,
    onValue: ^fire_engine.Signal,
}

createMPCPadsControl :: proc(name: string, channel: u8 = 9) -> ^MPCPadsControl {
    pc := new(MPCPadsControl)
    fire_engine.configureControl(pc, name)
    pc.channel = channel
    pc.status = fire_engine.NOTE_ON

    // Initialize pad mapping
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_1)] = 0
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_2)] = 1
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_3)] = 2
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_4)] = 3
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_5)] = 4
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_6)] = 5
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_7)] = 6 
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_8)] = 7
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_9)] = 8
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_10)] = 9
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_11)] = 10
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_12)] = 11
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_13)] = 12
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_14)] = 13
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_15)] = 14
    pc.PadMapping[u8(MPCSB_CONTROL.PAD_16)] = 15
    pc.onPadInput = fire_engine.createSignal()
    pc.onPadPress = fire_engine.createSignal()
    pc.onPadRelease = fire_engine.createSignal()
    pc.sendColor = MPCPadsControl_sendColor
    pc.onValue = fire_engine.createSignal()
    pc.onInput = MPCPadsControl_onInput
    pc.setBank = MPCPadsControl_setBank
    pc.getPadId = MPCPadsControl_getPadId
    pc.getPadIndex = MPCPadsControl_getPadIndex
    pc.isMatching = MPCPadsControl_isMatching

    return pc
}

MPCPadsControl_setBank :: proc(pc: ^MPCPadsControl, bank: u32) {
    pc.bank = clamp(bank, 0, MPC_PAD_BANK_COUNT - 1)
}

MPCPadsControl_getPadId :: proc(pc: ^MPCPadsControl, padIndex: u32) -> u8 {
    for id, index in pc.PadMapping {
        if index == (padIndex % 16) {
            return id
        }
    }
    log.warn("Unknown pad index: {}", padIndex)
    return 0
}


MPCPadsControl_getPadIndex :: proc(pc: ^MPCPadsControl, padId: u8) -> u32 {
    index :u32= 0
    if padId, ok := pc.PadMapping[padId]; ok {
        index = padId
    } else {
        log.warn("Unknown pad ID: {}", padId)
    }
    return index + pc.bank * 16
}

MPCPadsControl_sendColor :: proc(pc: ^MPCPadsControl, padId: u8, color: u8) {
    msg := fire_engine.ShortMessage{
        status = fire_engine.CONTROL_CHANGE | u8(pc.channel),
        data1 = padId,
        data2 = color,
    }
    pc.sendMidi(pc, msg)
}

MPCPadsControl_isMatching :: proc(pc: ^MPCPadsControl, msg: ^fire_engine.ShortMessage) -> bool {
    return msg->getChannel() == pc.channel && (msg->isNoteOn() || msg->isNoteOff() || msg->isPolyPressure())
}

MPCPadsControl_onInput :: proc(ptr: rawptr, msg: ^fire_engine.ShortMessage) -> bool {
    pc := cast(^MPCPadsControl)ptr
    handled := false
    log.infof("Received MIDI message for control %s: status=0x%X, data1=%d, data2=%d", pc.name, msg.status, msg.data1, msg.data2)
    if MPCPadsControl_isMatching(pc, msg) {
        padIndex := MPCPadsControl_getPadIndex(pc, msg.data1)
        velocity := msg.data2
        aftertouch := u8(0)
        if msg->isPolyPressure() {
            aftertouch = msg.data2
        }
        input := PadInput{
            msg = msg^,
            padIndex = padIndex,
            velocity = velocity,
            aftertouch = aftertouch,
        }
        fire_engine.signalEmit(pc.onPadInput, input)
        if msg->isNoteOn() {
            fire_engine.signalEmit(pc.onPadPress, input)
        } else if msg->isNoteOff() {
            fire_engine.signalEmit(pc.onPadRelease, input)
        }
        fire_engine.signalEmit(pc.onValue, input)
        handled = true
    }
    return handled
}
