#+feature using-stmt
package main

import "core:fmt"
import app_framework "app_framework"
import vg "vendor:nanovg"
import clay "app_framework/clay-odin"
import fe "fire_engine"
import "core:log"
import sdl "vendor:sdl3"


createUISamplerDevice :: proc() -> ^app_framework.Page {
    sampler_device_page := app_framework.createPage("sampler_device_page")
    // Add UI elements specific to the sampler device here
    global_button := create_text_button(sampler_device_page, "global_button", "Global")
    env_button := create_text_button(sampler_device_page, "env_button", "Env")
    filter_button := create_text_button(sampler_device_page, "filter_button", "Filter")
    lfo_button := create_text_button(sampler_device_page, "lfo_button", "LFO")
    effects_button := create_text_button(sampler_device_page, "effects_button", "Effects")

    sampler_device_page.draw = proc(page: ^app_framework.Page, vg_ctx: ^vg.Context, user_data: rawptr) {
        using clay
        if UI()({
            layout = {
                layoutDirection = LayoutDirection.TopToBottom,
                childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                sizing = {width = SizingGrow(), height = SizingGrow()},
                padding = PaddingAll(0),
            },
            backgroundColor = app_framework.hexToRGBA(SOLO_BUTTON_COLOR),
        }) {
            // Top section for content

            // Bottom section for tabs
            if UI()({
                layout = {
                    layoutDirection = LayoutDirection.LeftToRight,
                    childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Center},
                    sizing = {width = SizingFixed(50), height = SizingGrow()},
                    padding = PaddingAll(5),
                },
                backgroundColor = app_framework.hexToRGBA(SOLO_BUTTON_COLOR),
            }) {
                
                // Global
                if UI()({
                        layout = {
                            layoutDirection = LayoutDirection.TopToBottom,
                            childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                            sizing = {width = SizingGrow(), height = SizingGrow()},
                            padding = PaddingAll(0),
                        },
                        backgroundColor = app_framework.hexToRGBA(MAIN_SECTION_COLOR),
                        custom = {customData = page.elements["global_button"]},
                }) {}

                // Env
                if UI()({
                        layout = {
                            layoutDirection = LayoutDirection.TopToBottom,
                            childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                            sizing = {width = SizingGrow(), height = SizingGrow()},
                            padding = PaddingAll(0),
                        },
                        backgroundColor = app_framework.hexToRGBA(MAIN_SECTION_COLOR),
                        custom = {customData = page.elements["env_button"]},
                }) {}

                // Filter
                if UI()({
                        layout = {
                            layoutDirection = LayoutDirection.TopToBottom,
                            childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                            sizing = {width = SizingGrow(), height = SizingGrow()},
                            padding = PaddingAll(0),
                        },
                        backgroundColor = app_framework.hexToRGBA(MAIN_SECTION_COLOR),
                        custom = {customData = page.elements["filter_button"]},
                }) {}

                // LFO
                if UI()({
                        layout = {
                            layoutDirection = LayoutDirection.TopToBottom,
                            childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                            sizing = {width = SizingGrow(), height = SizingGrow()},
                            padding = PaddingAll(0),
                        },
                        backgroundColor = app_framework.hexToRGBA(MAIN_SECTION_COLOR),
                        custom = {customData = page.elements["lfo_button"]},
                }) {}

                // Effects
                if UI()({
                        layout = {
                            layoutDirection = LayoutDirection.TopToBottom,
                            childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                            sizing = {width = SizingGrow(), height = SizingGrow()},
                            padding = PaddingAll(0),
                        },
                        backgroundColor = app_framework.hexToRGBA(MAIN_SECTION_COLOR),
                        custom = {customData = page.elements["effects_button"]},
                }) {}
            }
        }
    }
    sampler_device_page.update = proc(page: ^app_framework.Page, app: ^app_framework.App, delta_time: f64, events: []sdl.Event, user_data: rawptr) {
        // Update sampler device specific data here
    }
    return sampler_device_page
}