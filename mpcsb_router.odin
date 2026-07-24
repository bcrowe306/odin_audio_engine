package main

import fe "fire_engine"
import cairo "cairo"
import fmt "core:fmt"



MPCSB_Router :: struct {
    pages: map[string]^MPCSB_Page,
    current_page: ^MPCSB_Page,
    default_page: ^MPCSB_Page,
    addPage: proc(router: ^MPCSB_Router, name: string, page: ^MPCSB_Page),
    switchPage: proc(router: ^MPCSB_Router, name: string),
    draw: proc(router: ^MPCSB_Router, cairo_context: ^cairo.context_t),
}

MPCSB_Router_create :: proc(default_page: ^MPCSB_Page) -> ^MPCSB_Router {
    router := new(MPCSB_Router)
    router.pages = make(map[string]^MPCSB_Page)
    router.default_page = default_page
    router.addPage = MPCSB_Router_addPage
    router.switchPage = MPCSB_Router_switchPage
    router.draw = MPCSB_Router_draw
    return router
}

MPCSB_Router_addPage :: proc(router: ^MPCSB_Router, name: string, page: ^MPCSB_Page) {
    router.pages[name] = page
}

MPCSB_Router_switchPage :: proc(router: ^MPCSB_Router, name: string) {

    if router.pages[name] == nil {
        fmt.println("Page not found: ", name)
        if router.default_page != nil {
            router.current_page = router.default_page
            router.current_page->enter()
        }
        return
    }

    if router.current_page != nil {
        router.current_page->exit()
    }
    router.current_page = router.pages[name]
    if router.current_page != nil {
        router.current_page->enter()
    }
}

MPCSB_Router_draw :: proc(router: ^MPCSB_Router, cairo_context: ^cairo.context_t) {
    if router.current_page != nil {
        router.current_page->draw(cairo_context)
    }
}