package main

import fe "fire_engine"
import log "core:log"
import fmt "core:fmt"
import cairo "cairo"



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
    mpcsb_display := MPCSB_Display_create(cs)
    cs.user_data = cast(rawptr)mpcsb_display


    // Display trial code: Just to test functionality, this will be removed later.
    home_page := MPCSB_Page_create()
    mpcsb_display->addPage("Home", home_page)

    btn1 := MPCSB_Element_create({0, 10, 360, 50})
    btn1.draw = proc(element: ^MPCSB_Element, cairo_context: ^cairo.context_t) {
        cairo.set_source_rgba(cairo_context, 1, 1, 1, 1)\
        cairo.rectangle(cairo_context, element.bounds.x, element.bounds.y, element.bounds.width, element.bounds.height)
        cairo.fill(cairo_context)
    }
    home_page->addElement("btn1", btn1)
    mpcsb_display.router->switchPage("Home")

    cs.application_loop.frame_hook = proc(delta_time: f32, frame_count: int, user_data: rawptr) {
        control_surface := cast(^fe.ControlSurface)user_data
        mpcsb_display := cast(^MPCSB_Display)control_surface.user_data
        // Custom frame hook logic for MPC Studio Black
        // For example, you can poll the device state or update controls here
        mpcsb_display->draw()
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