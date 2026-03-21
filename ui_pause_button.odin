package main

import "core:c"
import "core:fmt"
import app_framework "app_framework"
import vg "vendor:nanovg"
import clay "app_framework/clay-odin"
import fire_engine "fire_engine"
import "core:log"


createUIPauseButton :: proc(page: ^app_framework.Page, fe: ^fire_engine.FireEngine) -> ^app_framework.Element {
    pause_button := app_framework.createElement("pause_button", nil)
    pause_button.onDraw = proc(el: ^app_framework.Element, ctx: ^vg.Context, user_data: rawptr) {
        fe := cast(^fire_engine.FireEngine)user_data
        color := app_framework.hexToRGBA(TEXT_COLOR)
        if fe.transport->isPaused() {
            color = app_framework.hexToRGBA(RECORD_BUTTON_COLOR)
        }
        icon_size :f32 = 20.0
        center_x := el.bounds.x + el.bounds.width / 2 - icon_size / 2
        center_y := el.bounds.y + el.bounds.height / 2 - icon_size / 2
        draw_pause_icon(ctx, center_x, center_y, icon_size, icon_size, color)
    }

    page->addConnection(pause_button.onPressed, proc(value: any, user_data: rawptr) {
        pcd := cast(^app_framework.PageConnectionData)user_data
        fe := cast(^fire_engine.FireEngine)pcd.user_data
        fe.transport->pause()
    }, fe)
    
    page->addChild(pause_button)
    return pause_button
}