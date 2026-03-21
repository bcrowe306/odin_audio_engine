package main

import "core:fmt"
import app_framework "app_framework"
import vg "vendor:nanovg"
import clay "app_framework/clay-odin"
import fe "fire_engine"
import "core:log"

TEXT_BUTTON_ALIGNMENT :: enum {
    Left,
    Center,
    Right,
}

TEXT_BUTTON_VERTICAL_ALIGNMENT :: enum {
    Top,
    Center,
    Bottom,
}

text_button_data :: struct {
    text: string,
    alignment: TEXT_BUTTON_ALIGNMENT,
    vertical_alignment: TEXT_BUTTON_VERTICAL_ALIGNMENT,
    padding: [4]f32,
    color: [4]f32,
    background_color: [4]f32,
    font_size: f32,
}

create_text_button :: proc(
    page: ^app_framework.Page,
    name: string, 
    text: string, 
    padding: [4]f32 = {0.0, 0.0, 0.0, 0.0},
    alignment: TEXT_BUTTON_ALIGNMENT = .Center, 
    vertical_alignment: TEXT_BUTTON_VERTICAL_ALIGNMENT = .Center,
    color: [4]f32 = {191.0 / 255.0, 191.0 / 255.0, 191.0 / 255.0, 1.0},
    background_color: [4]f32 = {49.0 / 255.0, 48.0 / 255.0, 48.0/255.0, 1.0},
    font_size: f32 = 16.0,
) -> ^app_framework.Element 
{
    data := new(text_button_data)
    data.text = text
    data.alignment = alignment
    data.vertical_alignment = vertical_alignment
    data.padding = padding
    data.color = color
    data.font_size = font_size
    data.background_color = background_color
    button_el := app_framework.createElement(name, data)
    button_el.onDraw = proc(el: ^app_framework.Element, ctx: ^vg.Context, user_data: rawptr) {
        data := cast(^text_button_data)el.user_data
        vg.BeginPath(ctx)
        vg.Rect(ctx, el.bounds.x, el.bounds.y, el.bounds.width, el.bounds.height)
        vg.FillColor(ctx, data.background_color)
        vg.Fill(ctx)

        

        // Draw text with alignment and padding if specified
        vg.FontSize(ctx, data.font_size)
        vg.FontFace(ctx, "opensans")
        text_x : f32
        text_y : f32
        text_bounds : [4]f32
        vg.TextBounds(ctx, 0, 0, data.text, &text_bounds   )
        text_width := text_bounds[2] - text_bounds[0]
        text_height := text_bounds[3] - text_bounds[1]

        // Horizontal alignment
        switch data.alignment {

            case TEXT_BUTTON_ALIGNMENT.Left:
                text_x = el.bounds.x + data.padding[0]

            case TEXT_BUTTON_ALIGNMENT.Center:
                text_x = el.bounds.x + (el.bounds.width - text_width) / 2

            case TEXT_BUTTON_ALIGNMENT.Right:
                text_x = el.bounds.x + el.bounds.width - text_width - data.padding[2]
        }

        // Vertical alignment
        switch data.vertical_alignment {

            case TEXT_BUTTON_VERTICAL_ALIGNMENT.Top:
                vg.TextAlignVertical(ctx, .TOP)
                height_diff := el.bounds.height - text_height
                text_y = el.bounds.y - height_diff + data.padding[1]

            case TEXT_BUTTON_VERTICAL_ALIGNMENT.Center:
                height_diff := el.bounds.height - text_height
                vg.TextAlignVertical(ctx, .MIDDLE)
                text_y = el.bounds.y + height_diff / 2 + text_height / 2

            case TEXT_BUTTON_VERTICAL_ALIGNMENT.Bottom:
                height_diff := el.bounds.height - text_height
                text_y = el.bounds.y + height_diff + text_height - data.padding[3]

        }

        
        vg.FillColor(ctx, data.color)
        vg.Text(ctx, text_x, text_y, data.text)
    }

    page->addChild(button_el)
    return button_el
}