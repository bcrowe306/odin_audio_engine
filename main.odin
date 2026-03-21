#+feature using-stmt
package main

import "core:fmt"
import app_framework "app_framework"
import vg "vendor:nanovg"
import clay "app_framework/clay-odin"
import fe "fire_engine"
import "core:log"
import sdl "vendor:sdl3"

BACKGROUND_COLOR : u32 = 0x313030FF
MAIN_SECTION_COLOR : u32 = 0x252525FF
ACCENT_COLOR : u32 = 0xCEA10CFF
ACCENT_DIM_COLOR : u32 = 0x9F8018FF
TEXT_COLOR : u32 = 0xBFBFBFFF
TEXT_COLOR_BRIGHT : u32 = 0xFFFFFFFF
TEXT_COLOR_DIM : u32 = 0x7F7F7FFF
PLAY_BUTTON_COLOR: u32 = 0x00FF00FF
RECORD_BUTTON_COLOR: u32 = 0xFF0000FF
SOLO_BUTTON_COLOR: u32 = 0x2279CFFF


main :: proc() {
    logger := log.create_console_logger()
    context.logger = logger
    // Fire Engine initialization and startup
    fire_engine := fe.createFireEngine()
	fire_engine.midi_engine.debug = true
    fire_engine.audio_engine->setMultithreadedGraph(false)
    cs := createMpcStudioBlackCs()
    fire_engine->addControlSurface(cs)
	fire_engine->init()
	fire_engine->start()
	defer fire_engine->uninit()
    ph := fire_engine.audio_engine->getPlayhead()

    // Create the application framework
    app := app_framework.App_Create("Odin Audio Engine", 1080, 288, 60.0)
    app_framework.App_Init(app)
    app.user_data = fire_engine

    // Create the application UI
    ui := app_framework.createUI(vg.Color{0, 0, 0, 255})
    main_page := createUIMainPage(fire_engine)
    
    // Tie the ui to the application and run the main loop
    app->setUI(ui) // Must set ui first before setting the main page
    ui.setMainPage(ui, main_page)
    app.run(app)
    app_framework.App_Uninit(app)

}