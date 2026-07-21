package main

import fe "fire_engine"
import cairo "cairo"

MPCSB_Page :: struct {
    changed: bool,
    elements: [dynamic]rawptr,
    addElement: proc(page_ptr: rawptr, element_ptr: rawptr),
    removeElement: proc(page_ptr: rawptr, element_ptr: rawptr),
    clear: proc(page_ptr: rawptr),
    connections: [dynamic]^fe.SignalConnection,
    onEnter: proc(page_ptr: rawptr),
    onExit: proc(page_ptr: rawptr),
    draw: proc(page_ptr: rawptr, cairo_context: ^cairo.context_t),

}


MPCSB_Page_addElement :: proc(page: ^MPCSB_Page, element_ptr: rawptr) {
    append(&page.elements, element_ptr)
    page.changed = true
}

MPCSB_Page_removeElement :: proc(page: ^MPCSB_Page, element_ptr: rawptr) {
    for index in 0..<len(page.elements) {
        if page.elements[index] == element_ptr {
            ordered_remove(&page.elements, index)
            page.changed = true
            break
        }
    }
}