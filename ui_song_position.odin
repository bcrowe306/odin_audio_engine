package main

import app_framework "app_framework"
import fire_engine "fire_engine"
import sdl "vendor:sdl3"

createUISongPosition :: proc(page: ^app_framework.Page, fe: ^fire_engine.FireEngine) -> ^app_framework.Element {
    song_position := create_text_button(page, "song_position", "1.1.1")
    song_position.onUpdate = proc(element: ^app_framework.Element, app: ^app_framework.App, delta_time: f64, events: []sdl.Event, user_data: rawptr) {
        fe := cast(^fire_engine.FireEngine)app.user_data
        text_data: ^text_button_data = cast(^text_button_data) element.user_data
        sp := fe.transport->getSongPosition()
        text_data.text = sp->toStringShort()
    }
    return song_position
}