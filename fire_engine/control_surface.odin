package fire_engine

import "core:log"
import "core:time"
import "core:thread"

ApplicationLoop :: struct {
    app_thread: ^thread.Thread,
    thread_tick: time.Tick,
    fps: f32,
    frame_duration: time.Duration,
    frame_count: int,
    delta_time: f32,
    frame_hook: proc(delta_time: f32, frame_count: int, user_data: rawptr),
    user_data: rawptr,
    running: bool,
    run : proc(loop: ^ApplicationLoop),
}

ApplicationLoop_Create :: proc(fps: f32, frame_hook: proc(delta_time: f32, frame_count: int, user_data: rawptr), user_data: rawptr) -> ^ApplicationLoop {
    loop := new(ApplicationLoop)
    loop.fps = fps
    loop.frame_hook = frame_hook
    loop.user_data = user_data
    loop.run = RunGameLoop
    loop.app_thread = thread.create(ApplicationLoop_ThreadFunction)
    loop.app_thread.data = cast(rawptr)loop
    running := false
    return loop
}

RunGameLoop :: proc(loop: ^ApplicationLoop) {
    loop.thread_tick = time.tick_now()
    loop.frame_duration = time.Duration(1.0 / loop.fps * 1e9)
    loop.frame_count = 0
    loop.delta_time = 0.0
    loop.running = true
    for {
        dur : time.Duration
        dur = time.tick_diff(loop.thread_tick, time.tick_now())
        if dur >= loop.frame_duration {
            loop.thread_tick = time.tick_now()
            loop.delta_time = f32(dur) / 1e9
            loop.frame_count += 1
            if loop.frame_hook != nil {
                loop.frame_hook(loop.delta_time, loop.frame_count, loop.user_data)
            }
        }
        if !loop.running {
            break
        }
    }
}


ApplicationLoop_ThreadFunction :: proc(t: ^thread.Thread) {
    game_loop := cast(^ApplicationLoop)t.data
    game_loop->run()
}


ControlSurface :: struct {
    name: string,
    midi_device_name: string,
    fe: ^FireEngine,
    handleMidiMsg: proc(control_surface: ^ControlSurface, msg: ^ShortMessage) -> bool,
    components: [dynamic]rawptr,
    controls: map[string]rawptr,
    user_data: rawptr,
    application_loop: ^ApplicationLoop,
    run_application_loop: bool,

    addComponent: proc(control_surface: ^ControlSurface, component: rawptr),
    addControl: proc(control_surface: ^ControlSurface, control: rawptr),
    getControl: proc(control_surface: ^ControlSurface, control_name: string) -> rawptr,
    initialize: proc(control_surface: ^ControlSurface, fe: ^FireEngine),
    deInitialize: proc(control_surface: ^ControlSurface),
    activate: proc(control_surface: ^ControlSurface),
    deactivate: proc(control_surface: ^ControlSurface),

    // Sends a MIDI message to the MIDI device associated with this control surface. The message is sent as a ShortMessage struct, which contains the status byte, data1 byte, and data2 byte of the MIDI message.
    sendMidi: proc(control_surface: ^ControlSurface, msg: ShortMessage),

    // Sends a SysEx message to the MIDI device associated with this control surface. The message is sent as a slice of bytes, and the function automatically adds the start (0xF0) and end (0xF7) bytes to the message.
    sendSysex: proc(control_surface: ^ControlSurface, msg: []u8),

    onInitialize: proc(control_surface: ^ControlSurface),
    onDeInitialize: proc(control_surface: ^ControlSurface),
    onActivate: proc(control_surface: ^ControlSurface),
    onDeactivate: proc(control_surface: ^ControlSurface),
}

createControlSurface :: proc(name: string, device_id: string, fps: f32 = 60.0) -> ^ControlSurface {
    control_surface := new(ControlSurface)
    control_surface.name = name
    control_surface.midi_device_name = device_id
    control_surface.handleMidiMsg = defaultHandleMidiMsg
    control_surface.addComponent = controlSurfaceAddComponent
    control_surface.addControl = controlSurfaceAddControl
    control_surface.getControl = ControlSurface_GetControl
    control_surface.initialize = initializeControlSurface
    control_surface.deInitialize = deInitializeControlSurface
    control_surface.activate = activateControlSurface
    control_surface.deactivate = deactivateControlSurface
    control_surface.sendMidi = controlSurface_sendMidi
    control_surface.sendSysex = controlSurface_sendSysex
    control_surface.application_loop = ApplicationLoop_Create(fps, nil, cast(rawptr)control_surface)
    control_surface.run_application_loop = false

    return control_surface
}
ControlSurface_GetControl :: proc(control_surface: ^ControlSurface, control_name: string) -> rawptr {
    if control_ptr, ok := control_surface.controls[control_name]; ok {
        return control_ptr
    } else {
        log.error("Control not found: %s", control_name)
        return nil
    }
}

defaultHandleMidiMsg :: proc(control_surface: ^ControlSurface, msg: ^ShortMessage) -> bool {
    handled := false
    for control_name, control_ptr in control_surface.controls {
        control := cast(^Control)control_ptr
        if control.handleInput(control_ptr, msg) {
            handled = true
        }
    }
    return handled
}

controlSurfaceAddComponent :: proc(control_surface: ^ControlSurface, component: rawptr) {
    append(&control_surface.components, component)
}

controlSurfaceAddControl :: proc(control_surface: ^ControlSurface, control_ptr: rawptr) {
    // Process additions
    control := cast(^Control)control_ptr
    control_surface.controls[control.name] = control_ptr
}

GetControl :: proc(control_surface: ^ControlSurface, control_name: string, $T: typeid) -> ^T {
    if control_ptr, ok := control_surface.controls[control_name]; ok {
        return cast(^T)control_ptr
    } else {
        log.error("Control not found: %s", control_name)
        return nil
    }
}

initializeControlSurface :: proc(control_surface: ^ControlSurface, fe: ^FireEngine) {
    control_surface.fe = fe
    log.info("Initializing control surface: %s", control_surface.name)

    // Initialize controls
    for control_name, control_ptr in control_surface.controls {
        control := cast(^Control)control_ptr
        if control.initialize != nil {
            control.initialize(control_ptr, control_surface, control_surface.midi_device_name, fe)
        }
    }

    for component_ptr in control_surface.components {
        component := cast(^Component)component_ptr
        component.initialize(component, fe, control_surface)
    }

    if control_surface.onInitialize != nil {
        control_surface.onInitialize(control_surface)
    }
}

deInitializeControlSurface :: proc(control_surface: ^ControlSurface) {
    for control_name, control_ptr in control_surface.controls {
        control := cast(^Control)control_ptr
        control.deactivate(control_ptr)
    }
    for component_ptr in control_surface.components {
        component := cast(^Component)component_ptr
        component.deInitialize(component)
    }
    if control_surface.onDeInitialize != nil {
        control_surface.onDeInitialize(control_surface)
    }
}

activateControlSurface :: proc(control_surface: ^ControlSurface) {
    for component_ptr in control_surface.components {
        component := cast(^Component)component_ptr
        component.activate(component)
    }
    if control_surface.onActivate != nil {
        control_surface.onActivate(control_surface)
    }
    if control_surface.run_application_loop && control_surface.application_loop != nil {
        thread.start(control_surface.application_loop.app_thread)
    }
}

deactivateControlSurface :: proc(control_surface: ^ControlSurface) {
    control_surface.application_loop.running = false
    thread.join(control_surface.application_loop.app_thread)
    for component_ptr in control_surface.components {
        component := cast(^Component)component_ptr
        component.deactivate(component)
    }
    if control_surface.onDeactivate != nil {
        control_surface.onDeactivate(control_surface)
    }
    
}



controlSurface_sendMidi :: proc(control_surface: ^ControlSurface, msg: ShortMessage) {
    if control_surface.fe != nil && control_surface.fe.midi_engine != nil {
        control_surface.fe.midi_engine->sendMsg(control_surface.midi_device_name, msg)
    }

}

controlSurface_sendSysex :: proc(control_surface: ^ControlSurface, msg: []u8) {
    if control_surface.fe != nil && control_surface.fe.midi_engine != nil {
        control_surface.fe.midi_engine->sendSysexMsg(control_surface.midi_device_name, msg)
    }
}
