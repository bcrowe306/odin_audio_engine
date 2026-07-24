package main

import fe "fire_engine"
import cairo "cairo"
import "core:fmt"
import "core:mem"

createHomePage :: proc() -> ^MPCSB_Page {
    home_page := MPCSB_Page_create()
    // Add elements to the home page
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


    home_page.onEnter = proc(page: ^MPCSB_Page) {
        fe := page.control_surface.fe
        cs := page.control_surface
        page->addConnection(fe.tracks.onTrackSelected, home_page_onTrackSelected, page)
        home_page_onTrackSelected(nil, cast(rawptr)page)
    }

    home_page.onDraw = proc(page: ^MPCSB_Page, cairo_context: ^cairo.context_t) {
        fe := page.control_surface.fe
        cs := page.control_surface

        meter1 := cast(^MPCSB_Element)page.element_map["meter1"]
        meter_def := cast(^MeterElementDef)meter1.data
        MeterElement_setMeters(meter1, f64(fe.metronome.levels_node.rms_db[0]), f64(fe.metronome.levels_node.rms_db[1]))
        
    }
    return home_page
}

home_page_onTrackSelected :: proc(value: any, user_data: rawptr) {
        home_page := cast(^MPCSB_Page)user_data
        ButtonElement1 := cast(^MPCSB_Element)home_page.element_map["btn7"]
        bt1_def := cast(^ButtonElementDef)ButtonElement1.data

        // cast value to int
        fe := home_page.control_surface.fe
        
        ButtonElement_setLabel(ButtonElement1, fmt.tprintf("Track %d", fe.tracks.selected_track_index + 1))
}