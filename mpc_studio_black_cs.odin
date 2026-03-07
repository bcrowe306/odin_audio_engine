package main

import fe "fire_engine"
import log "core:log"

createMpcStudioBlackCs :: proc() -> ^fe.ControlSurface {
    cs := fe.createControlSurface("MPC Studio Black", "MPC Studio Black MPC Private")
    createMPCStudioBlackControls(cs)
    cs.onInitialize = initializeMPCStudioBlack
    cs.onDeInitialize = deInitializeMPCStudioBlack
    return cs
}

initializeMPCStudioBlack :: proc(control_surface: ^fe.ControlSurface) {
    log.info("Custom initialization for MPC Studio Black")
    msg := generateMPCSysexCommand(MPC_STUDIO_BLACK_COMMANDS.SET_MODE, {u8(MPC_STUDIO_BLACK_MODE.PRIVATE)})
    control_surface->sendSysex(msg)
}

deInitializeMPCStudioBlack :: proc(control_surface: ^fe.ControlSurface) {
    log.info("Custom de-initialization for MPC Studio Black")
    msg := generateMPCSysexCommand(MPC_STUDIO_BLACK_COMMANDS.SET_MODE, {u8(MPC_STUDIO_BLACK_MODE.PUBLIC)})
    control_surface->sendSysex(msg)
}


generateMPCSysexCommand :: proc(command: MPC_STUDIO_BLACK_COMMANDS, message: []u8) -> []u8 {
    message_length := fe.toMsbLsbArr(u16(len(message)))
    message_type := u8(command)

    sysexMessage := make([]u8, len(MPC_SYSEX_HEADER) + 1 + len(message_length) + len(message)) // Header + Message ID
    copy(sysexMessage, MPC_SYSEX_HEADER[:])
    sysexMessage[len(MPC_SYSEX_HEADER)] = message_type
    copy(sysexMessage[len(MPC_SYSEX_HEADER) + 1:], message_length[:])
    copy(sysexMessage[len(MPC_SYSEX_HEADER) + 1 + len(message_length):], message[:])
    return sysexMessage
}