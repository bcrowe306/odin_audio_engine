package main

import "core:fmt"
import app_framework "app_framework"
import vg "vendor:nanovg"
import clay "app_framework/clay-odin"
import fe "fire_engine"
import "core:log"
import sdl "vendor:sdl3"


LevelMetersElement :: struct {
    using element: app_framework.Element,
    linear_peak: [2]f32,
    linear_rms: [2]f32,
    dBfs: f32

}

createLevelMeter :: proc(name: string) -> ^LevelMetersElement {
    el := new(LevelMetersElement)
    app_framework.configureElement(el)
    // Test_data
    el.linear_peak = {0.5, 0.6}
    el.linear_rms = {0.25, 0.3}
    el.dBfs = -6.0
    el.onDraw = LevelMetersElement_draw
    el.name = name
   return el
}

LevelMetersElement_draw :: proc(el: ^app_framework.Element, ctx: ^vg.Context, user_data: rawptr) {
    data := cast(^LevelMetersElement)el
    channel_spacing :f32 = 5.0
    clip_box_height :f32 = 15.0
    font_size :f32 = 12.0
    meter_width := f32 ((f32(el.bounds.width) - channel_spacing) / 2.0)
    meter_height := f32(el.bounds.height) - clip_box_height - font_size - channel_spacing

    // Draw Clip Box Left Channel
    vg.BeginPath(ctx)
    vg.Rect(ctx, el.bounds.x, el.bounds.y, meter_width, clip_box_height)
    vg.FillColor(ctx, {0, 0, 0, 1})
    vg.Fill(ctx)

    // Draw Clip Box Right Channel
    vg.BeginPath(ctx)
    vg.Rect(ctx, el.bounds.x + meter_width + channel_spacing, el.bounds.y, meter_width, clip_box_height)
    vg.FillColor(ctx, {0, 0, 0, 1})
    vg.Fill(ctx)

    // Draw Left Meter black box
    vg.BeginPath(ctx)
    vg.Rect(ctx, el.bounds.x, el.bounds.y + clip_box_height + channel_spacing, meter_width, meter_height)
    vg.FillColor(ctx, {0, 0, 0, 1})
    vg.Fill(ctx)

    // Draw Right Meter black box
    vg.BeginPath(ctx)
    vg.Rect(ctx, el.bounds.x + meter_width + channel_spacing, el.bounds.y + clip_box_height + channel_spacing, meter_width, meter_height)
    vg.FillColor(ctx, {0, 0, 0, 1})
    vg.Fill(ctx)
    
    // Draw Left Meter level
    if data.linear_rms[0] > 0.0 {
         vg.BeginPath(ctx)
        left_fill_height := meter_height * data.linear_rms[0]
        vg.Rect(ctx, el.bounds.x, el.bounds.y + clip_box_height + channel_spacing + (meter_height - left_fill_height), meter_width, left_fill_height)
        vg.FillColor(ctx, {0, 1, 0, 1})
        vg.Fill(ctx)
    }
   


    // Draw Right Meter level
    if data.linear_rms[1] > 0.0 {
        vg.BeginPath(ctx)
        right_fill_height := meter_height * data.linear_rms[1]
        vg.Rect(ctx, el.bounds.x + meter_width + channel_spacing, el.bounds.y + clip_box_height + channel_spacing + (meter_height - right_fill_height), meter_width, right_fill_height)
        vg.FillColor(ctx, {0, 1, 0, 1})
        vg.Fill(ctx)
    }
    

    // Draw left peak white line
    if data.linear_peak[0] > 0.0 {
        vg.BeginPath(ctx)
        left_peak_y := el.bounds.y + clip_box_height + channel_spacing + (meter_height * (1.0 - data.linear_peak[0]))
        vg.Rect(ctx, el.bounds.x, left_peak_y, meter_width, 2.0)
        vg.FillColor(ctx, {1, 1, 1, 1})
        vg.Fill(ctx)
    }

    // Draw right peak white line
    if data.linear_peak[1] > 0.0 {
        vg.BeginPath(ctx)
        right_peak_y := el.bounds.y + clip_box_height + channel_spacing + (meter_height * (1.0 - data.linear_peak[1]))
        vg.Rect(ctx, el.bounds.x + meter_width + channel_spacing, right_peak_y, meter_width, 2.0)
        vg.FillColor(ctx, {1, 1, 1, 1})
        vg.Fill(ctx)
    }
    

}
