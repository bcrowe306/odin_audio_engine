package main

import fe "fire_engine"

createMpcStudioBlackCs :: proc() -> ^fe.ControlSurface {
    cs := fe.createControlSurface("MPC Studio Black", "")
    return cs
}