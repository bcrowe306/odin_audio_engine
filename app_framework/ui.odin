package app

import "core:fmt"
import sdl "vendor:sdl3"
import vg "vendor:nanovg"
import clay "clay-odin"


// TODO: Add layers for drawing and events
// TODO: Add support for ui scaling and input events.
// TODO: Add support for clay to respond to ui scaling


UI :: struct {
    cr : ^vg.Context,
    app_user_data: rawptr,
    backgound_color: vg.Color,
    main_page: ^Page,
    update : proc(ui: ^UI, app: ^App, delta_time: f64, events: []sdl.Event, user_data: rawptr),
    draw: proc(ui: ^UI, app: ^App, user_data: rawptr),
    setMainPage: proc(ui: ^UI, page: ^Page),
}

createUI :: proc(background_color: vg.Color) -> ^UI {
    ui := new(UI)
    configureUI(ui, background_color)
    return ui
}


configureUI :: proc(ui_type: $T, background_color: vg.Color) {
    ui := cast(^UI)ui_type
    ui.backgound_color = background_color
    ui.setMainPage = UI_SetMainPage
    ui.update = uiUpdate
    ui.draw = uiDraw
    ui.app_user_data = nil
    
    // Setup methods
    ui.draw = uiDraw
    ui.update = uiUpdate
}


uiDraw :: proc(ui: ^UI, app: ^App, user_data: rawptr) {
    vg_ctx := app.vg_context
    clay.BeginLayout()

    // Draw the main page and all of its children elements and child routers
    ui.main_page->draw(vg_ctx, user_data)

    // Process clay render commands for this frame. This will draw all clay elements that were added to the layout with clay.AddElement() and clay.AddCustomElement() in their draw methods.
    render_cmd_array := clay.EndLayout()
    for i in 0..<render_cmd_array.length {
        cmd := clay.RenderCommandArray_Get(&render_cmd_array, i)

        #partial switch cmd.commandType {
            case clay.RenderCommandType.Rectangle:
                vg.BeginPath(vg_ctx)
                vg.Rect(vg_ctx, cmd.boundingBox.x, cmd.boundingBox.y, cmd.boundingBox.width, cmd.boundingBox.height)
                vg.FillColor(vg_ctx, cmd.renderData.rectangle.backgroundColor)
                vg.Fill(vg_ctx)

            case clay.RenderCommandType.Custom:
                element_ptr := cmd.renderData.custom.customData
                element := cast(^Element)element_ptr
                element.setBounds(element, cmd.boundingBox)
                if element._draw != nil {
                    element._draw(element, vg_ctx, user_data)
                }
        }
    }

}

uiUpdate :: proc(ui: ^UI, app: ^App, delta_time: f64, events: []sdl.Event, user_data: rawptr) {
    // Update
    if ui.main_page != nil {
        ui.main_page->_update(app, delta_time, events, user_data)
    }
}

UI_SetMainPage :: proc(ui: ^UI, page: ^Page) {
    ui.main_page = page
    if ui.main_page.afterLoad != nil {
        ui.main_page->afterLoad(nil, ui.app_user_data)
    }   
}
