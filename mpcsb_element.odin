package main

import cairo "cairo"

MPCSB_Element :: struct {
    changed: bool,
    draw: proc(element_ptr: ^MPCSB_Element, cairo_context: ^cairo.context_t),
    bounds: cairo.rectangle_t,
    visible: bool,
    setBounds: proc(element: ^MPCSB_Element, bounds: cairo.rectangle_t),
    setVisible: proc(element: ^MPCSB_Element, visible: bool),
    clear: proc(element: ^MPCSB_Element, cairo_context: ^cairo.context_t),
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
    element.changed = true
    return element
}


MPCSB_Element_draw_default :: proc(element: ^MPCSB_Element, cairo_context: ^cairo.context_t) {
}

MPCSB_Element_setBounds :: proc(element: ^MPCSB_Element, bounds: cairo.rectangle_t) {
    element.bounds = bounds
    element.changed = true
}

MPCSB_Element_setVisible :: proc(element: ^MPCSB_Element, visible: bool) {
    element.visible = visible
    element.changed = true
}

MPCSB_Element_clear :: proc(element: ^MPCSB_Element, cairo_context: ^cairo.context_t) {
    cairo.set_source_rgba(cairo_context, 0.0, 0.0, 0.0, 1.0) // Set color to black
    cairo.rectangle(cairo_context, element.bounds.x, element.bounds.y, element.bounds.width, element.bounds.height) // Define the rectangle area
    cairo.fill(cairo_context) // Fill the rectangle with the current color
}