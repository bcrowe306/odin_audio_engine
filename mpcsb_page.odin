package main

import fe "fire_engine"
import cairo "cairo"
import fmt "core:fmt"


MPCSB_Page :: struct {
    control_surface: ^fe.ControlSurface,
    name: string,
    changed: bool,
    elements: [dynamic]^MPCSB_Element,
    element_map : map[string]^MPCSB_Element,
    focused_element_index: int,
    jogFocus: proc(page: ^MPCSB_Page, direction: int),
    addElement: proc(page: ^MPCSB_Page, name: string, element: ^MPCSB_Element),
    connections: [dynamic]^fe.SignalConnection,
    addConnection: proc(page: ^MPCSB_Page, signal: ^fe.Signal, observer: proc (value: any, user_data: rawptr), user_data: rawptr) -> ^fe.SignalConnection,
    clearConnections: proc(page: ^MPCSB_Page),
    enter: proc(page: ^MPCSB_Page),
    exit: proc(page: ^MPCSB_Page),
    onEnter: proc(page: ^MPCSB_Page),
    onExit: proc(page: ^MPCSB_Page),
    draw: proc(page: ^MPCSB_Page, cairo_context: ^cairo.context_t),

    // User hook to update the page's elements when the page is drawn. This is called after the page's draw function is called.
    onDraw: proc(page: ^MPCSB_Page, cairo_context: ^cairo.context_t),

}

MPCSB_Page_create :: proc() -> ^MPCSB_Page {
    page := new(MPCSB_Page)
    page.changed = true
    page.addElement = MPCSB_Page_addElement
    page.addConnection = MPCSB_Page_addConnection
    page.clearConnections = MPCSB_Page_clearConnections
    page.enter = MPCSB_Page_enter
    page.exit = MPCSB_Page_exit
    page.onEnter = nil
    page.onExit = nil
    page.draw = MPCSB_Page_draw
    page.onDraw = nil
    return page
}

MPCSB_Page_enter :: proc(page: ^MPCSB_Page) {

    fmt.println("Entering page")
    if page.onEnter != nil {
        page.onEnter(page)
    }
}

MPCSB_Page_exit :: proc(page: ^MPCSB_Page) {

    fmt.println("Exiting page")
    page->clearConnections()
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
    connection := fe.signalConnect(signal, observer, cast(rawptr)page)
    append(&page.connections, connection)
    return connection
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
    if page.onDraw != nil {
        page.onDraw(page, cairo_context)
    }
}

MPCSB_Page_clearConnections :: proc(page: ^MPCSB_Page) {
    for connection in page.connections {
        fe.signalDisconnect(connection)
    }
    clear(&page.connections)
}

MPCSB_Page_jogFocus :: proc(page: ^MPCSB_Page, direction: int) {
    if len(page.elements) == 0 {
        return
    }

    // Find the next focusable element in the given direction
    new_index := page.focused_element_index
    for i := 0; i < len(page.elements); i += 1{
        new_index = (new_index + direction + len(page.elements)) % len(page.elements)
        element := page.elements[new_index]
        if element.focusable {
            break
        }
    }

    // Update the focused element index and redraw the page if it has changed
    for element, i in page.elements {
        if i == new_index {
            element->setFocus(true)
        } else {
            element->setFocus(false)
        }
    }
    if new_index != page.focused_element_index {
        page.focused_element_index = new_index
        page.changed = true
    }
}