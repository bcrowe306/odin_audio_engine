package app

import "core:fmt"
import sdl "vendor:sdl3"
import vg "vendor:nanovg"


// TODO: Add layers for drawing and events
// TODO: Add support for ui scaling and input events.
// TODO: Add support for clay to respond to ui scaling


UI :: struct {
    cr : ^vg.Context,
    backgound_color: vg.Color,
    router : ^Router,
    update : proc(ui: ^UI, app: ^App, delta_time: f64, events: []sdl.Event, user_data: rawptr),
    draw: proc(ui: ^UI, app: ^App, user_data: rawptr),
    addPage: proc(ui: ^UI, page: ^Page),
}

createUI :: proc(background_color: vg.Color) -> ^UI {
    ui := new(UI)
    configureUI(ui, background_color)
    return ui
}


configureUI :: proc(ui_type: $T, background_color: vg.Color) {
    ui := cast(^UI)ui_type
    ui.backgound_color = background_color
    ui.router = createRouter()
    ui.addPage = addPageToUI
    ui.update = uiUpdate
    ui.draw = uiDraw
    
    
    // Setup methods
    ui.draw = uiDraw
    ui.update = uiUpdate
}


uiDraw :: proc(ui: ^UI, app: ^App, user_data: rawptr) {
    vg_ctx := app.vg_context
    current_page := ui.router->getCurrentPage()
    if ui.router.next_page.command != RouterStackCommand.None {
        if current_page != nil {
            fmt.printf("Clearing widgets on page switch from page: %s\n", current_page.name)
            current_page->clearPage(vg_ctx)
        }
    }
    
    page_changed := ui.router->processPageSwitch()
    page := ui.router->getCurrentPage()
    if page != nil {
        page->drawPage(vg_ctx, user_data)
    }

}

uiUpdate :: proc(ui: ^UI, app: ^App, delta_time: f64, events: []sdl.Event, user_data: rawptr) {
    // Update
    page:= ui.router->getCurrentPage()
    
    if page != nil {
        page->_update(app, delta_time, events, user_data)
    }
}

addPageToUI :: proc(ui: ^UI, page: ^Page) {
    ui.router->addPage(page)
}
