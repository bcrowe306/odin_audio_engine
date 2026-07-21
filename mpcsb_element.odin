package main

import cairo "cairo"

MPCSB_Element :: struct {
    changed: bool,
    draw: proc(element_ptr: rawptr, cairo_context: ^cairo.context_t),
    bounds: cairo.rectangle_t,
    visible: bool,
    setBounds: proc(element_ptr: rawptr, bounds: cairo.rectangle_t),
    setVisible: proc(element_ptr: rawptr, visible: bool),
    clear: proc(element_ptr: rawptr),
    data: rawptr,
    
}

MPCSB_Element_create :: proc( bounds: cairo.rectangle_t, visible: bool = true) -> ^MPCSB_Element {
    element := new(MPCSB_Element)
    element.draw = MPCSB_Element_draw_default
    element.bounds = bounds
    element.visible = visible
    element.setBounds = MPCSB_Element_setBounds
    element.setVisible = MPCSB_Element_setVisible
    element.clear = MPCSB_Element_clear
    element.data = nil
    return element
}


MPCSB_Element_draw_default :: proc(element_ptr: rawptr, cairo_context: ^cairo.context_t) {
    element := cast(^MPCSB_Element)element_ptr
    if element.visible {
        // Custom drawing logic for the element
        // For example, you can use Cairo to draw shapes, text, or images on the display
        // You can access the element's bounds using element.bounds
        // You can also use the control surface's Cairo context to perform drawing operations
    }
    element.changed = false // Reset the changed flag after drawing
}

MPCSB_Element_setBounds :: proc(element_ptr: rawptr, bounds: cairo.rectangle_t) {
    element := cast(^MPCSB_Element)element_ptr
    element.bounds = bounds
    element.changed = true
}

MPCSB_Element_setVisible :: proc(element_ptr: rawptr, visible: bool) {
    element := cast(^MPCSB_Element)element_ptr
    element.visible = visible
    element.changed = true
}

MPCSB_Element_clear :: proc(element_ptr: rawptr) {
    element := cast(^MPCSB_Element)element_ptr
    element.changed = true
}