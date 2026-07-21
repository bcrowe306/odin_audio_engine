package main

import fe "fire_engine"
import log "core:log"
import fmt "core:fmt"

createMpcStudioBlackCs :: proc() -> ^fe.ControlSurface {
    cs := fe.createControlSurface("MPC Studio Black", "MPC Studio Black MPC Private")
    createMPCStudioBlackControls(cs)
    createMPCStudioBlackComponents(cs)
    cs.onInitialize = initializeMPCStudioBlack
    cs.onDeInitialize = deInitializeMPCStudioBlack

    // Set the run_application_loop flag to true to enable the application loop for this control surface
    cs.run_application_loop = true

    // This is custom frame hook for MPC Study Black display. It runs a predefined frame rate independent of the main application loop. 
    // You can use this to update the display or perform other periodic tasks.
    cs.application_loop.frame_hook = proc(delta_time: f32, frame_count: int, user_data: rawptr) {
        control_surface := cast(^fe.ControlSurface)user_data
        // Custom frame hook logic for MPC Studio Black
        // For example, you can poll the device state or update controls here
        fmt.println("MPC Studio Black Frame Hook: delta_time=", delta_time, ", frame_count=", frame_count)
    }
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