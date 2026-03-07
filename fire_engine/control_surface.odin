package fire_engine

import "core:log"

ControlSurface :: struct {
    name: string,
    midi_device_name: string,
    
    fe: ^FireEngine,
    handleMidiMsg: proc(control_surface: ^ControlSurface, msg: ^ShortMessage) -> bool,
    components: [dynamic]rawptr,
    controls: map[string]rawptr,
    user_data: rawptr,
    addComponent: proc(control_surface: ^ControlSurface, component: rawptr),
    addControl: proc(control_surface: ^ControlSurface, control: rawptr),
    getControl: proc(control_surface: ^ControlSurface, control_name: string) -> rawptr,
    initialize: proc(control_surface: ^ControlSurface, fe: ^FireEngine),
    deInitialize: proc(control_surface: ^ControlSurface),
    activate: proc(control_surface: ^ControlSurface),
    deactivate: proc(control_surface: ^ControlSurface),
    sendMidi: proc(control_surface: ^ControlSurface, msg: ShortMessage),
    sendSysex: proc(control_surface: ^ControlSurface, msg: []u8),

    onInitialize: proc(control_surface: ^ControlSurface),
    onDeInitialize: proc(control_surface: ^ControlSurface),
    onActivate: proc(control_surface: ^ControlSurface),
    onDeactivate: proc(control_surface: ^ControlSurface),
}

createControlSurface :: proc(name: string, device_id: string) -> ^ControlSurface {
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
}

deactivateControlSurface :: proc(control_surface: ^ControlSurface) {
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
