package main

import "core:fmt"
import ma "vendor:miniaudio"
import app_framework "app_framework"
import vg "vendor:nanovg"
import clay "app_framework/clay-odin"

perc : ma.sound
ph : ^PlayheadNode

main :: proc() {
    using fmt
    ae := createEngine(auto_start = true)
    ae->init()
    ph = createPlayhead(ae)
    defer free(ph)
    levels := createLevelsNode(ae)
    defer free(levels)
    wt := createWaveTables(48000, .Square, 220.0)

    wproc := createProcessNode(ae)
    defer free(wproc)
    wproc.user_data = &wt

    wproc.processFunction = proc (pNode: ^ma.node, ppFramesIn: ^[^]f32, pFrameCountIn: ^u32, ppFramesOut: ^[^]f32, pFrameCountOut: ^u32, user_data: rawptr) {
        // Example processing function that applies a simple gain to the input audio
        // wt := cast(^WaveTables)user_data
        // for fr in 0..<pFrameCountOut^ {
        //     samp := wt->readAdvance()
        //     for ch in 0..<2 {
        //         ppFramesOut[fr * 2 + u32(ch)] = samp * 0.2 // Apply gain
        //     }
            
        // }
    }

    perc_wave, err := loadWaveFile("perc.wav", 48000); 
    if err != .None {
        fmt.printf("Failed to load wave file: %s\n", err)
        return
    }


    ae->attachNode(cast(^ma.node)ph)
    ma.sound_init_from_file(&ae.engine, "perc.wav", {.DECODE}, nil, nil, &perc)
    ma.node_attach_output_bus(cast(^ma.node)&perc, 0, cast(^ma.node)levels, 0)
    ae->attachNode(cast(^ma.node)levels)
    ae->attachNode(cast(^ma.node)wproc)


    signalConnect(ph.onTick, proc(value: any, data: rawptr) {
        ph := cast(^PlayheadNode)data
        tick_event := value.(TickEvent)
        if ph->isBeat() && tick_event.playhead_state == .Playing {
            ma.sound_stop(&perc)
            ma.sound_seek_to_pcm_frame(&perc, 0)
            ma.sound_start(&perc)
        }
     }, cast(rawptr)ph      
    ) 

    ph->setTempo(120.0)


    ui := app_framework.createUI(vg.Color{0, 0, 0, 255})
    main_page := app_framework.createPage("main")
    second_page := app_framework.createPage("second")
    button_el := app_framework.createElement("button")
    button_2 := app_framework.createElement("button2")
    button_2.onDraw = proc(el: ^app_framework.Element, ctx: ^vg.Context, user_data: rawptr) {
        vg.BeginPath(ctx)
        vg.Rect(ctx, el.bounds.x, el.bounds.y, el.bounds.width, el.bounds.height)
        vg.FillColor(ctx, vg.RGBA(200, 0, 20, 255))
        vg.Fill(ctx)
        vg.FontSize(ctx, 18.0)
        vg.FontFace(ctx, "opensans")
        vg.FillColor(ctx, vg.RGBA(255, 255, 255, 255))
        vg.Text(ctx, el.bounds.x + 10, el.bounds.y + 30, "Main Page")
    }
    app_framework.signalConnect(button_2.onPressed, proc(value: any, data: rawptr) {
        ui := cast(^app_framework.UI)data
        fmt.printfln("Button clicked, switching to main page")
        ui.router->push("main")
     }, ui )
     
    button_el.onDraw = proc(el: ^app_framework.Element, ctx: ^vg.Context, user_data: rawptr) {
        vg.BeginPath(ctx)
        vg.Rect(ctx, el.bounds.x, el.bounds.y, el.bounds.width, el.bounds.height)
        vg.FillColor(ctx, vg.RGBA(0, 128, 255, 255))
        vg.Fill(ctx)
        vg.FontSize(ctx, 18.0)
        vg.FontFace(ctx, "opensans")
        vg.FillColor(ctx, vg.RGBA(255, 255, 255, 255))
        vg.Text(ctx, el.bounds.x + 10, el.bounds.y + 30, fmt.tprintf("%d. %d. %d", ph.song_position.bar + 1, ph.song_position.beat + 1, ph.song_position.sixteenth + 1))
    }

    app_framework.signalConnect(button_el.onPressed, proc(value: any, data: rawptr) {
        ph := cast(^PlayheadNode)data
        if ph.playhead_state == PlayheadState.Playing {
            ph->setState(PlayheadState.Stopped)
        } else {
            ph->setState(PlayheadState.Playing)
        }
     }, ph )
    
    second_page.addChild(second_page, button_2)
    second_page.createLayout = proc(page: ^app_framework.Page) -> clay.ClayArray(clay.RenderCommand) {
        using clay
        BeginLayout()
        if UI()({
            layout = {
                layoutDirection = LayoutDirection.TopToBottom,
                childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                sizing = {width = SizingGrow(), height = SizingGrow()},
                padding = PaddingAll(5),
            }
        }) {
            if UI()({
                layout = {
                    layoutDirection = LayoutDirection.LeftToRight,
                    childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                    sizing = {width = SizingFixed(800), height = SizingFixed(50)},
                    padding = PaddingAll(5),
                },
                custom = { customData = page.elements["button2"] },
            }) {}
        }
        return EndLayout()
    }
    main_page.addChild(main_page, button_el)
    main_page.createLayout = proc(page: ^app_framework.Page) -> clay.ClayArray(clay.RenderCommand) {
        using clay
        BeginLayout()
        if UI()({
            layout = {
                layoutDirection = LayoutDirection.TopToBottom,
                childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                sizing = {width = SizingGrow(), height = SizingGrow()},
                padding = PaddingAll(5),
            }
        }) {
            if UI()({
                layout = {
                    layoutDirection = LayoutDirection.LeftToRight,
                    childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Top},
                    sizing = {width = SizingFixed(800), height = SizingFixed(50)},
                    padding = PaddingAll(5),
                },
                custom = { customData = page.elements["button"] },
            }) {}
        }
        return EndLayout()
    }
    ui.addPage(ui, main_page)
    ui.addPage(ui, second_page)
    fmt.printfln("Starting application ui")
    ui.router->push("main")

    app := app_framework.App_Create("Odin Audio Engine", 1080, 288, 60.0)
    app_framework.App_Init(app)

    app.ui = ui
    app.run(app)
    app_framework.App_Uninit(app)

}