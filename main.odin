package main

import "core:time"
import "core:fmt"
import ma "vendor:miniaudio"
import rl "vendor:raylib"

perc : ma.sound
dummy : ma.sound
userData :: struct {
    engine: ^ma.engine,
}


main :: proc() {
    using fmt
    ae := createEngine(auto_start = true)
    metNode : ^MetronomeNode = createMet(&ae.engine, 120.0)
    ae->attachNode(cast(^ma.node)(metNode))


    // Raylib window setup
    rl.InitWindow(800, 600, "Metronome Test")
    rl.SetTargetFPS(60)
    tempo :f32 = auto_cast metNode.tempo
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        rl.GuiButton(rl.Rectangle{x = 100, y = 100, width = 200, height = 50}, "Hello")

        res := rl.GuiSlider(rl.Rectangle{x = 100, y = 200, width = 200, height = 20}, "Tempo", fmt.ctprintf("%.2f", tempo), &tempo , 30.0, 300.0)
        metNode->setTempo(f64(tempo))
        fmt.printfln("Slider result: %d, Tempo: %.2f", res, tempo)

        rl.EndDrawing()
    }

    rl.CloseWindow()
    ae->uninit()

}