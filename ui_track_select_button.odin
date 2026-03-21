package main

import "core:fmt"
import app_framework "app_framework"
import fire_engine "fire_engine"
import sdl "vendor:sdl3"

createUITrackSelectButton :: proc(page: ^app_framework.Page, fe: ^fire_engine.FireEngine) -> ^app_framework.Element {
    track_select_button := create_text_button(page, "track_select_button", "Track 1")
    track_select_button.onUpdate = proc(element: ^app_framework.Element, app: ^app_framework.App, delta_time: f64, events: []sdl.Event, user_data: rawptr) {
        fe := cast(^fire_engine.FireEngine)app.user_data
        text_data: ^text_button_data = cast(^text_button_data) element.user_data
        sp := fe.transport->getSongPosition()
        text_data.text = fmt.tprintf("Track %d", fe.tracks.selected_track_index + 1)
    }
    page->addConnection(track_select_button.onDrag, proc(value: any, user_data: rawptr) {
        pcd := cast(^app_framework.PageConnectionData)user_data
        fe := cast(^fire_engine.FireEngine)pcd.user_data
        value := value.(f64)
        if value > 0.0 {
            fe.tracks->previousTrack()
        }
        else if value < 0.0 {
            fe.tracks->nextTrack()
        }
    }, fe)
    return track_select_button
}