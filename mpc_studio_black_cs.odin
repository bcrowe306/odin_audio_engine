package main

import fe "fire_engine"

createMpcStudioBlackCs :: proc() -> ^fe.ControlSurface {
    cs := fe.createControlSurface("Akai MPC Studio Black", "Akai MPC Studio Black")
    cs.addModal()
    return cs
}