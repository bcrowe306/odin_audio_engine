package main

import "core:fmt"
import "core:c"
import app_framework "app_framework"
import vg "vendor:nanovg"
import clay "app_framework/clay-odin"
import fire_engine "fire_engine"


createUIMetronomeButton :: proc(page: ^app_framework.Page, fe: ^fire_engine.FireEngine) -> ^app_framework.Element {
    metronome_button := app_framework.createElement("metronome_button", nil)
    metronome_button.onDraw = proc(el: ^app_framework.Element, ctx: ^vg.Context, user_data: rawptr) {
        fe := cast(^fire_engine.FireEngine)user_data
        color := app_framework.hexToRGBA(TEXT_COLOR)
        if fe.metronome.enabled->get(){
            color = app_framework.hexToRGBA(ACCENT_COLOR)
        }
        icon_size :f32 = 20.0
        center_x := el.bounds.x + el.bounds.width / 2 - icon_size / 2
        center_y := el.bounds.y + el.bounds.height / 2 - icon_size / 2
        draw_metronome_icon(ctx, center_x, center_y, icon_size + 10.0, icon_size, color, app_framework.hexToRGBA(BACKGROUND_COLOR))
    }

    page->addChild(metronome_button)
    return metronome_button
}