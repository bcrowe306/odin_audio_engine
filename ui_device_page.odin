#+feature using-stmt
package main

import "core:fmt"
import app_framework "app_framework"
import vg "vendor:nanovg"
import clay "app_framework/clay-odin"
import fe "fire_engine"
import "core:log"
import sdl "vendor:sdl3"

createUIDevicePage :: proc() -> ^app_framework.Page {
    device_page := app_framework.createPage("device_page")
    
    device_page.draw = proc(page: ^app_framework.Page, vg_ctx: ^vg.Context, user_data: rawptr) {
        using clay
        if UI()({
            layout = {
                layoutDirection = LayoutDirection.TopToBottom,
                childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                sizing = {width = SizingGrow(), height = SizingGrow()},
                padding = PaddingAll(0),
            },
            backgroundColor = app_framework.hexToRGBA(MAIN_SECTION_COLOR),
        }) {
            
        }
    }
    
    return device_page
}