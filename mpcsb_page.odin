package main

import fe "fire_engine"
import cairo "cairo"


MPCSB_Page :: struct {
    control_surface: ^fe.ControlSurface,
    changed: bool,
    elements: [dynamic]^MPCSB_Element,
    element_map : map[string]^MPCSB_Element,
    addElement: proc(page: ^MPCSB_Page, name: string, element: ^MPCSB_Element),
    connections: [dynamic]^fe.SignalConnection,
    addConnection: proc(page: ^MPCSB_Page, signal: ^fe.Signal, observer: proc (value: any, user_data: rawptr), user_data: rawptr) -> ^fe.SignalConnection,
    enter: proc(page: ^MPCSB_Page),
    exit: proc(page: ^MPCSB_Page),
    onEnter: proc(page: ^MPCSB_Page),
    onExit: proc(page: ^MPCSB_Page),
    draw: proc(page: ^MPCSB_Page, cairo_context: ^cairo.context_t),

}

MPCSB_Page_create :: proc() -> ^MPCSB_Page {
    page := new(MPCSB_Page)
    page.changed = true
    page.addElement = MPCSB_Page_addElement
    page.addConnection = MPCSB_Page_addConnection
    page.enter = MPCSB_Page_enter
    page.exit = MPCSB_Page_exit
    page.onEnter = nil
    page.onExit = nil
    page.draw = MPCSB_Page_draw
    return page
}

MPCSB_Page_enter :: proc(page: ^MPCSB_Page) {
    if page.onEnter != nil {
        page.onEnter(page)
    }
}

MPCSB_Page_exit :: proc(page: ^MPCSB_Page) {
    if page.onExit != nil {
        page.onExit(page)
    }
}

MPCSB_Page_addElement :: proc(page: ^MPCSB_Page, name: string, element: ^MPCSB_Element) {
    append(&page.elements, element)
    page.element_map[name] = element
    page.changed = true
}

MPCSB_Page_addConnection :: proc(page: ^MPCSB_Page, signal: ^fe.Signal, observer: proc (value: any, user_data: rawptr), user_data: rawptr) -> ^fe.SignalConnection {
    return nil
}

MPCSB_Page_draw :: proc(page: ^MPCSB_Page, cairo_context: ^cairo.context_t) {
    for element in page.elements {
        if element.visible {
            element->draw(cairo_context)
        }
        else {
            element->clear(cairo_context)
        }
    }
}