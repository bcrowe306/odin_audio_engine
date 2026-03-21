#+feature using-stmt
package main

import "core:fmt"
import app_framework "app_framework"
import vg "vendor:nanovg"
import clay "app_framework/clay-odin"
import fe "fire_engine"
import "core:log"
import sdl "vendor:sdl3"


createUIMainPage :: proc(fire_engine: ^fe.FireEngine) -> ^app_framework.Page {

    // Create the main page and its subpages
    main_page := app_framework.createPage("main")

    track_select_button := createUITrackSelectButton(main_page, fire_engine)
    device_button := create_text_button(main_page, "device_button", "Sampler")
    sequence_number := create_text_button(main_page, "sequence_number", "Seq: 1")
    song_position := createUISongPosition(main_page, fire_engine)
    tempo_select_button := createUITempoSelectButton(main_page, fire_engine)

    device_page_button := create_text_button(main_page, "device_page_button", "Track", vertical_alignment = .Center, font_size = 20.0)
    mixer_page_button := create_text_button(main_page, "mixer_page_button", "Mixer", vertical_alignment = .Center, font_size = 20.0)
    sequence_page_button := create_text_button(main_page, "sequence_page_button", "Sequencer", vertical_alignment = .Center, font_size = 20.0)
    song_page_button := create_text_button(main_page, "song_page_button", "Song", vertical_alignment = .Center, font_size = 20.0)
    level_meters := createLevelMeter("device_level_meters")
    main_page.addChild(main_page, level_meters)
    
    play_button := createUIPlayButton(main_page, fire_engine)
    stop_button := createUIStopButton(main_page, fire_engine)
    pause_button := createUIPauseButton(main_page, fire_engine)
    record_button := createUIRecordButton(main_page, fire_engine)
    loop_button := createUILoopButton(main_page, fire_engine)
    metronome_button := createUIMetronomeButton(main_page, fire_engine)
    
    main_page.addRouter(main_page, "main_content")
    device_page := createUIDevicePage()
    sequence_page := createUISequencerPage()
    mixer_page := createUIMixerPage()
    song_page := createUISongPage()
    
    
    main_content_router := main_page.getRouter(main_page, "main_content")
    main_content_router.addPage(main_content_router, device_page)
    main_content_router.addPage(main_content_router, sequence_page)
    main_content_router.addPage(main_content_router, mixer_page)
    main_content_router.addPage(main_content_router, song_page)
    main_content_router->push("device_page")

    main_page.update = proc(page: ^app_framework.Page, app: ^app_framework.App, delta_time: f64, events: []sdl.Event, user_data: rawptr) {
        fire_engine := cast(^fe.FireEngine)user_data
        router := page.getRouter(page, "main_content")
        current_page := router.getCurrentPage(router)
        
        if current_page != nil && current_page.name == "device_page" {
            text_button_data := cast(^text_button_data)page.elements["device_page_button"].user_data
            text_button_data.color = app_framework.hexToRGBA(ACCENT_COLOR)
        } else {
            text_button_data := cast(^text_button_data)page.elements["device_page_button"].user_data
            text_button_data.color = app_framework.hexToRGBA(TEXT_COLOR)
        }

        if current_page != nil && current_page.name == "sequence_page" {
            text_button_data := cast(^text_button_data)page.elements["sequence_page_button"].user_data
            text_button_data.color = app_framework.hexToRGBA(ACCENT_COLOR)
        } else {
            text_button_data := cast(^text_button_data)page.elements["sequence_page_button"].user_data
            text_button_data.color = app_framework.hexToRGBA(TEXT_COLOR)
        }

        if current_page != nil && current_page.name == "mixer_page" {
            text_button_data := cast(^text_button_data)page.elements["mixer_page_button"].user_data
            text_button_data.color = app_framework.hexToRGBA(ACCENT_COLOR)
        } else {
            text_button_data := cast(^text_button_data)page.elements["mixer_page_button"].user_data
            text_button_data.color = app_framework.hexToRGBA(TEXT_COLOR)
        }

        if current_page != nil && current_page.name == "song_page" {
            text_button_data := cast(^text_button_data)page.elements["song_page_button"].user_data
            text_button_data.color = app_framework.hexToRGBA(ACCENT_COLOR)
        } else {
            text_button_data := cast(^text_button_data)page.elements["song_page_button"].user_data
            text_button_data.color = app_framework.hexToRGBA(TEXT_COLOR)
        }
    }

    main_page.afterLoad = proc(page: ^app_framework.Page, data: any, app_user_data: rawptr) {
        fire_engine := cast(^fe.FireEngine)app_user_data
        ph := fire_engine.audio_engine->getPlayhead()

        page->addConnection(page.elements["device_page_button"].onPressed, proc(value: any, user_data: rawptr) {
            sig_con_data := cast(^app_framework.PageConnectionData)user_data
            page := sig_con_data.page
            router := page.getRouter(page, "main_content")
            router->push("device_page")
        })

        page->addConnection(page.elements["sequence_page_button"].onPressed, proc(value: any, user_data: rawptr) {
            sig_con_data := cast(^app_framework.PageConnectionData)user_data
            page := sig_con_data.page
            router := page.getRouter(page, "main_content")
            router->push("sequence_page")
        })

        page->addConnection(page.elements["mixer_page_button"].onPressed, proc(value: any, user_data: rawptr) {
            sig_con_data := cast(^app_framework.PageConnectionData)user_data
            page := sig_con_data.page
            router := page.getRouter(page, "main_content")
            router->push("mixer_page")
        })

        page->addConnection(page.elements["song_page_button"].onPressed, proc(value: any, user_data: rawptr) {
            sig_con_data := cast(^app_framework.PageConnectionData)user_data
            page := sig_con_data.page
            router := page.getRouter(page, "main_content")
            router->push("song_page")
        })

        f_engine := cast(^fe.FireEngine)app_user_data
        fmt.println("Setting up metronome button connection")
        page->addConnection(page.elements["metronome_button"].onPressed, proc(value: any, user_data: rawptr) {
            pcd := cast(^app_framework.PageConnectionData)user_data
            fe := cast(^fe.FireEngine)pcd.user_data
            fe.metronome->toggle()
        }, f_engine)
    }

    main_page.draw = proc(page: ^app_framework.Page, vg_ctx: ^vg.Context, user_data: rawptr) {
        using clay
        // Page
        if UI()({
            layout = {
                layoutDirection = LayoutDirection.TopToBottom,
                childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                sizing = {width = SizingGrow(), height = SizingGrow()},
                padding = PaddingAll(0),
            },
        }) {
            // Header
            createHeaderSection(page)

            // Main content area
            if UI()({
                layout = {
                    layoutDirection = LayoutDirection.LeftToRight,
                    childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                    sizing = {width = SizingGrow(), height = SizingGrow()},
                    padding = PaddingAll(1),
                },
                backgroundColor = app_framework.hexToRGBA(MAIN_SECTION_COLOR),
            }) {
                // Main content could go here

                // Left Vertical Tabs
                if UI()({
                    layout = {
                        layoutDirection = LayoutDirection.TopToBottom,
                        childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                        sizing = {width = SizingFixed(96), height = SizingGrow()},
                        padding = PaddingAll(5),
                    },
                    backgroundColor = app_framework.hexToRGBA(BACKGROUND_COLOR),
                }) {
                    
                    // Device Tab Button
                    if UI()({
                        layout = {
                            layoutDirection = LayoutDirection.TopToBottom,
                            childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                            sizing = {width = SizingGrow(), height = SizingGrow()},
                            padding = PaddingAll(5),
                        },
                        backgroundColor = app_framework.hexToRGBA(PLAY_BUTTON_COLOR),
                        custom = {customData = page.elements["device_page_button"]},
                    } ) {}
                    
                    // Sequencer Tab Button
                    if UI()({
                        layout = {
                            layoutDirection = LayoutDirection.TopToBottom,
                            childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                            sizing = {width = SizingGrow(), height = SizingGrow()},
                            padding = PaddingAll(5),
                        },
                        backgroundColor = app_framework.hexToRGBA(BACKGROUND_COLOR),
                        custom = {customData = page.elements["sequence_page_button"]},
                    } ) {}

                    // Mixer Tab Button
                    if UI()({
                        layout = {
                            layoutDirection = LayoutDirection.TopToBottom,
                            childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                            sizing = {width = SizingGrow(), height = SizingGrow()},
                            padding = PaddingAll(5),
                        },
                        backgroundColor = app_framework.hexToRGBA(BACKGROUND_COLOR),
                        custom = {customData = page.elements["mixer_page_button"]},
                    } ) {}

                    // Song Tab Button
                    if UI()({
                        layout = {
                            layoutDirection = LayoutDirection.TopToBottom,
                            childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                            sizing = {width = SizingGrow(), height = SizingGrow()},
                            padding = PaddingAll(5),
                        },
                        backgroundColor = app_framework.hexToRGBA(BACKGROUND_COLOR),
                        custom = {customData = page.elements["song_page_button"]},
                    } ) {}
                }

                // Main area
                if UI()({
                    layout = {
                        layoutDirection = LayoutDirection.TopToBottom,
                        childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                        sizing = {width = SizingGrow(), height = SizingGrow()},
                        padding = PaddingAll(0),
                    },
                    backgroundColor = app_framework.hexToRGBA(MAIN_SECTION_COLOR),
                }) {

                    // Draw the current page in the main content area
                    page.getRouter(page, "main_content")->draw(vg_ctx, user_data)
                }

                // Right Vertical Section
                if UI()({
                    layout = {
                        layoutDirection = LayoutDirection.TopToBottom,
                        childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                        sizing = {width = SizingFixed(96), height = SizingGrow()},
                        padding = PaddingAll(5),
                    },
                    backgroundColor = app_framework.hexToRGBA(BACKGROUND_COLOR),
                }) {
                    // Level Meters
                    if UI()({
                        layout = {
                            layoutDirection = LayoutDirection.LeftToRight,
                            childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                            sizing = {width = SizingFixed(50), height = SizingGrow()},
                            padding = PaddingAll(5),
                        },
                        backgroundColor = app_framework.hexToRGBA(MAIN_SECTION_COLOR),
                        custom = { customData = page.elements["device_level_meters"]}
                    }) {}
                }
            }

            // Footer
            createFooterSection(page)
        }
    }
    return main_page
}