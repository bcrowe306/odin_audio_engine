package app

import "core:c"
import "core:time"
import sdl "vendor:sdl3"
import gl "vendor:OpenGL"
import vg "vendor:nanovg"
import vggl "vendor:nanovg/gl"
import fmt "core:fmt"
import clay "clay-odin"

// TODO: Build out layer system from UI. process input and drawing through layers. 
// Each layer can have its own state and can be added/removed dynamically. 
// This will allow for more complex UI structures and better separation of concerns.

App :: struct {
    title: string,
    window: ^sdl.Window,
    gl_context: sdl.GLContext,
    vg_context: ^vg.Context,
    running: bool,
    width: i32,
    height: i32,
    init: proc(app: ^App),
    uninit: proc(app: ^App),
    run: proc(app: ^App),
    setUI: proc(app: ^App, ui: ^UI),
    update: proc(app: ^App, delta_time: f64, events: []sdl.Event, user_data: rawptr),
    draw: proc(app: ^App, user_data: rawptr),
    loadFont: proc(app: ^App, name: string, file_path: string) -> int,
    user_data: rawptr,
    frames_per_second: f32,
    events: [1024]sdl.Event,
    afterInit: proc(app: ^App),
    beforeUninit: proc(app: ^App),
    ui: ^UI,
}

App_Create :: proc(title: string, width: i32, height: i32, frames_per_second: f32) -> ^App {
    app := new(App)
    app.width = width
    app.height = height
    app.title = title
    app.frames_per_second = frames_per_second
    app.init = App_Init
    app.uninit = App_Uninit
    app.run = App_Run
    app.update = App_Update
    app.draw = App_Draw
    app.loadFont = App_LoadFont
    app.setUI = App_SetUI
    return app
}


App_Init :: proc(app: ^App) {

    // SDL window and event loop
    if success := sdl.Init({.VIDEO, .EVENTS}); !success {
        fmt.printf("Failed to initialize SDL: %s\n", sdl.GetError())
        return
    }

    // Configure OpenGL context for NanoVG (GL3 backend)
    sdl.GL_SetAttribute(.DOUBLEBUFFER, 1)
    sdl.GL_SetAttribute(.DEPTH_SIZE, 24)
    sdl.GL_SetAttribute(.STENCIL_SIZE, 8)
    sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, transmute(c.int)sdl.GL_CONTEXT_PROFILE_CORE)
    when ODIN_OS == .Darwin {
        sdl.GL_SetAttribute(.CONTEXT_FLAGS, transmute(c.int)sdl.GL_CONTEXT_FORWARD_COMPATIBLE_FLAG)
        sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 4)
        sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 1)
    } else {
        sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 3)
        sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 3)
    }

    app.window = sdl.CreateWindow(fmt.ctprint(app.title), app.width, app.height, {.OPENGL, .RESIZABLE, .HIGH_PIXEL_DENSITY})
    if app.window == nil {
        fmt.printf("Failed to create SDL window: %s\n", sdl.GetError())
        return
    }

    app.gl_context = sdl.GL_CreateContext(app.window)
    if app.gl_context == nil {
        fmt.printf("Failed to create GL context: %s\n", sdl.GetError())
        return
    }

    if !sdl.GL_MakeCurrent(app.window, app.gl_context) {
        fmt.printf("Failed to make GL context current: %s\n", sdl.GetError())
        return
    }

    sdl.GL_SetSwapInterval(1)

    // Load OpenGL function pointers through SDL.
    when ODIN_OS == .Darwin {
        gl.load_up_to(4, 1, sdl.gl_set_proc_address)
    } else {
        gl.load_up_to(3, 3, sdl.gl_set_proc_address)
    }

    app.vg_context = vggl.Create({.ANTI_ALIAS, .DEBUG})
    if app.vg_context == nil {
        fmt.println("Failed to create NanoVG context")
        return
    }
    
    
    font_ui := app.loadFont(app, "opensans", "OpenSans-Regular.ttf")

    // Call user-defined afterInit if it exists
    if app.afterInit != nil {
        app.afterInit(app)
    }

    // Initialization for clay layout system
    // Clay Layout initialization
    error_handler :: proc "c" (errorData: clay.ErrorData) {
        // Do something with the error data.
    }

    min_memory_size := clay.MinMemorySize()
    memory := make([^]u8, min_memory_size)
    arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), memory)
    clay.Initialize(arena, {f32(app.width), f32(app.height)}, { handler = error_handler })


}

App_LoadFont :: proc(app: ^App, name: string, file_path: string) -> int {
    font_id := vg.CreateFont(app.vg_context, name, file_path)
    if font_id < 0 {
        fmt.printf("Failed to load font '%s' from path '%s'\n", name, file_path)
    }
    return font_id
}

App_Run :: proc(app: ^App) {
    app.running = true
    vg_ctx := app.vg_context
    // Dertmine min_frame_time based on target frames per second
    min_frame_time := 1.0 / app.frames_per_second
    // Calculate delta_time for the first frame
    frame_duration := time.Duration(1/app.frames_per_second * 1_000_000_000) // Convert seconds to nanoseconds
    delta_duration := frame_duration
    fmt.print("Starting main loop with target FPS: %f\n", app.frames_per_second)
    for app.running {
        current_time := time.tick_now()
        // Currate events and delta time
        event: sdl.Event
        event_count := 0
        for sdl.PollEvent(&event) {
            if event_count < len(app.events) {
                app.events[event_count] = event
                event_count += 1
            }
            #partial switch event.type {
                case .QUIT:
                    app.running = false
            }
        }
        delta_time := time.duration_seconds(delta_duration)

        // Update UI and application logic
        if app.ui != nil {
            app.ui->update(app, delta_time, app.events[:event_count], app.user_data)
        }
        if app.update != nil {
            app.update(app, delta_time, app.events[:event_count], app.user_data)
        }

        window_w, window_h: c.int
        fb_w, fb_h: c.int
        sdl.GetWindowSize(app.window, &window_w, &window_h)
        sdl.GetWindowSizeInPixels(app.window, &fb_w, &fb_h)


        device_pixel_ratio := f32(1.0)
        if window_w > 0 {
            device_pixel_ratio = f32(fb_w) / f32(window_w)
        }

        gl.Viewport(0, 0, i32(fb_w), i32(fb_h))
        gl.ClearColor(0.06, 0.06, 0.08, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)

        // Draw UI with NanoVG
        vg.BeginFrame(vg_ctx, f32(window_w), f32(window_h), device_pixel_ratio)

        if app.ui != nil {
            app.ui->draw(app, app.user_data)
        }

        if app.draw != nil {
            app.draw(app, app.user_data)
        }
        
        vg.EndFrame(vg_ctx)
        sdl.GL_SwapWindow(app.window)

        // Calculate elapsed time and sleep if necessary to maintain target frame rate
        elapsed_time := time.tick_lap_time(&current_time)
        if elapsed_time < frame_duration {
            time.sleep(frame_duration - elapsed_time)
            delta_duration = time.tick_lap_time(&current_time) // Recalculate delta time after sleeping
        }
    }
}


App_Uninit :: proc(app: ^App) {
    if app.beforeUninit != nil {
        app.beforeUninit(app)
    }
    if app.vg_context != nil {
        vggl.Destroy(app.vg_context)
    }
    if app.gl_context != nil {
        sdl.GL_DestroyContext(app.gl_context)
    }
    if app.window != nil {
        sdl.DestroyWindow(app.window)
    }
    sdl.Quit()

}

App_Update :: proc(app: ^App, delta_time: f64, events: []sdl.Event, user_data: rawptr) {
    // Example update logic (e.g., handle input, update game state)
}

App_Draw :: proc(app: ^App, user_data: rawptr) {
    // Example drawing code using NanoVG
    // vg_ctx := app.vg_context
    // vg.BeginPath(vg_ctx)
    // vg.Rect(vg_ctx, 100, 100, 200, 150)
    // vg.FillColor(vg_ctx, vg.RGBA(255, 0, 0, 255))
    // vg.Fill(vg_ctx)

    // vg.FontSize(vg_ctx, 24.0)
    // vg.FontFace(vg_ctx, "opensans")
    // vg.FillColor(vg_ctx, vg.RGBA(255, 255, 255, 255))
    // vg.Text(vg_ctx, 120, 150, "Hello NanoVG!")
}

App_SetUI :: proc(app: ^App, ui: ^UI) {
    app.ui = ui
    ui.app_user_data = app.user_data
}

