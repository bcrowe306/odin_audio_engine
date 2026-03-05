package main

import "core:fmt"
import app_framework "app_framework"
import vg "vendor:nanovg"
import clay "app_framework/clay-odin"
import fe "fire_engine"

main :: proc() {
    using fmt
    using fe

    // Fire Engine initialization and startup
    fe := createFireEngine()
	fe.midi_engine.debug = true
	fe->init()
	fe->start()
	defer fe->uninit()

    // Create the application framework
    app := app_framework.App_Create("Odin Audio Engine", 1080, 288, 60.0)
    app_framework.App_Init(app)
    app.user_data = fe

    // Create the application UI
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
        vg.Text(ctx, el.bounds.x + 10, el.bounds.y + 30, "Second Page")
    }
    app_framework.signalConnect(button_2.onPressed, proc(value: any, data: rawptr) {
        ui := cast(^app_framework.UI)data
        fmt.printfln("Button clicked, switching to main page")
        ui.router->push("main")
     }, ui )
     
    button_el.onDraw = proc(el: ^app_framework.Element, ctx: ^vg.Context, user_data: rawptr) {
        fe := cast(^fe.FireEngine)user_data
        vg.BeginPath(ctx)
        vg.Rect(ctx, el.bounds.x, el.bounds.y, el.bounds.width, el.bounds.height)
        vg.FillColor(ctx, vg.RGBA(0, 128, 255, 255))
        vg.Fill(ctx)
        vg.FontSize(ctx, 18.0)
        vg.FontFace(ctx, "opensans")
        vg.FillColor(ctx, vg.RGBA(255, 255, 255, 255))
        vg.Text(ctx, el.bounds.x + 10, el.bounds.y + 30, fmt.tprintf("Selected Track: %d", fe.tracks.selected_track_index + 1))
    }

    
    
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

    
    // Tie the ui to the application and run the main loop
    app.ui = ui
    app.run(app)
    app_framework.App_Uninit(app)

}