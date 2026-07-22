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

    
    F1 := FunctionButtonElement_create(0, 84, 60, 12, "F1", false)
    F2 := FunctionButtonElement_create(60 * 1, 84, 60, 12, "F2", false)
    F3 := FunctionButtonElement_create(60 * 2, 84, 60, 12, "F3", false)
    F4 := FunctionButtonElement_create(60 * 3, 84, 60, 12, "F4", false)
    F5 := FunctionButtonElement_create(60 * 4, 84, 60, 12, "F5", false)
    F6 := FunctionButtonElement_create(60 * 5, 84, 60, 12, "F6", false)
    home_page->addElement("btn1", F1)
    home_page->addElement("btn2", F2)
    home_page->addElement("btn3", F3)
    home_page->addElement("btn4", F4)
    home_page->addElement("btn5", F5)
    home_page->addElement("btn6", F6)

    ButtonElement1 := ButtonElement_create(0, 0, 60, 12, "Button", false)
    ButtonElement2 := ButtonElement_create(60 * 1, 0, 60, 12, "Button", true)
    ButtonElement3 := ButtonElement_create(60 * 2, 0, 60, 12, "Button", false)
    ButtonElement4 := ButtonElement_create(60 * 3, 0, 60, 12, "Button", false)
    ButtonElement5 := ButtonElement_create(60 * 4, 0, 60, 12, "Button", false)
    ButtonElement6 := ButtonElement_create(60 * 5, 0, 60, 12, "Button", false)
    home_page->addElement("btn7", ButtonElement1)
    home_page->addElement("btn8", ButtonElement2)
    home_page->addElement("btn9", ButtonElement3)
    home_page->addElement("btn10", ButtonElement4)
    home_page->addElement("btn11", ButtonElement5)
    home_page->addElement("btn12", ButtonElement6)

    Knob1 := KnobElement_create(0, 18, 60, 60, "Knob1", 0.0, 1.0, 0.5)
    home_page->addElement("knob1", Knob1)

    Meter1 := MeterElement_create(60 * 1, 18, 60, 60, -60.0, 0.0)
    home_page->addElement("meter1", Meter1)


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