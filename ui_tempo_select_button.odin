package main

import "core:fmt"
import app_framework "app_framework"
import fire_engine "fire_engine"
import sdl "vendor:sdl3"

createUITempoSelectButton :: proc(page: ^app_framework.Page, fe: ^fire_engine.FireEngine) -> ^app_framework.Element {
    tempo_select_button := create_text_button(page, "tempo_select_button", "120.00 BPM")
    tempo_select_button.onUpdate = proc(element: ^app_framework.Element, app: ^app_framework.App, delta_time: f64, events: []sdl.Event, user_data: rawptr) {
        fe := cast(^fire_engine.FireEngine)app.user_data
        text_data: ^text_button_data = cast(^text_button_data) element.user_data
        text_data.text = fmt.tprintf("%.2f BPM", fe.transport.tempo->get())
    }


    page->addConnection(tempo_select_button.onDrag, proc(value: any, user_data: rawptr) {
        pcd := cast(^app_framework.PageConnectionData)user_data
        fe := cast(^fire_engine.FireEngine)pcd.user_data
        value := value.(f64)
        fe.transport.tempo->encoder(-f32(value))
        
    }, fe)
    return tempo_select_button
}