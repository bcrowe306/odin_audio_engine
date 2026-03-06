package fire_engine

ControlSurface :: struct {
    name: string,
    midi_device_name: string,
    
    fe: ^FireEngine,
    handleMidiMsg: proc(control_surface: ^ControlSurface, msg: ^ShortMessage) -> bool,
    modes: [dynamic]^ModesComponent,
    components: [dynamic]^Component,
    controls: [dynamic]rawptr,
    addModesComponent: proc(control_surface: ^ControlSurface, modes_component: ^ModesComponent),
    addComponent: proc(control_surface: ^ControlSurface, component: ^Component),
    addControl: proc(control_surface: ^ControlSurface, control: rawptr, control_name: string),
    initialize: proc(control_surface: ^ControlSurface, fe: ^FireEngine),
    deInitialize: proc(control_surface: ^ControlSurface),
    activate: proc(control_surface: ^ControlSurface),
    deactivate: proc(control_surface: ^ControlSurface),
}

createControlSurface :: proc(name: string, device_id: string) -> ^ControlSurface {
    control_surface := new(ControlSurface)
    control_surface.name = name
    control_surface.midi_device_name = device_id
    control_surface.handleMidiMsg = defaultHandleMidiMsg
    control_surface.addModesComponent = controlSurfaceAddModesComponent
    control_surface.addComponent = controlSurfaceAddComponent
    control_surface.addControl = controlSurfaceAddControl
    control_surface.initialize = initializeControlSurface
    control_surface.deInitialize = deInitializeControlSurface
    control_surface.activate = activateControlSurface
    control_surface.deactivate = deactivateControlSurface
    return control_surface
}

defaultHandleMidiMsg :: proc(control_surface: ^ControlSurface, msg: ^ShortMessage) -> bool {
    handled := false
    for modes_component in control_surface.modes {
        if modes_component.current_mode != "" {
            mode := modes_component.modes[modes_component.current_mode]
            if mode != nil {
                if mode.handleMidiMsg(mode, msg) {
                    handled = true
                }
            }
        }
    }
    for component in control_surface.components {
        if component.handleInput != nil {
            if component.handleInput(component, msg) {
                handled = true
            }
        }
    }
    return handled
}

controlSurfaceAddModesComponent :: proc(control_surface: ^ControlSurface, modes_component: ^ModesComponent) {
    append(&control_surface.modes, modes_component)
}

controlSurfaceAddComponent :: proc(control_surface: ^ControlSurface, component: ^Component) {
    append(&control_surface.components, component)
}

controlSurfaceAddControl :: proc(control_surface: ^ControlSurface, control: rawptr, control_name: string) {
    // Process additions
    exists := false
    new := cast(^Control)control
    for ptr in control_surface.controls {
        existing_control := cast(^Control)ptr
        if new.id == existing_control.id {
            exists = true
            break
        }
    }
    if !exists {
        append(&control_surface.controls, control)
    }
}

initializeControlSurface :: proc(control_surface: ^ControlSurface, fe: ^FireEngine) {
    control_surface.fe = fe
    for modes_component in control_surface.modes {
        for _, mode in modes_component.modes {
            mode.initialize(mode, control_surface, control_surface.midi_device_name, fe)
        }
    }
    for component in control_surface.components {
        component.initialize(component, control_surface, control_surface.midi_device_name, fe)
    }
}

deInitializeControlSurface :: proc(control_surface: ^ControlSurface) {
    for modes_component in control_surface.modes {
        for _, mode in modes_component.modes {
            mode.deInitialize(mode)
        }
    }
    for component in control_surface.components {
        component.deInitialize(component)
    }
}

activateControlSurface :: proc(control_surface: ^ControlSurface) {
    for modes_component in control_surface.modes {
        if modes_component.current_mode != "" {
            mode := modes_component.modes[modes_component.current_mode]
            if mode != nil {
                mode.activate(mode)
            }
        }
    }
    for component in control_surface.components {
        component.activate(component)
    }
}

deactivateControlSurface :: proc(control_surface: ^ControlSurface) {
    for modes_component in control_surface.modes {
        if modes_component.current_mode != "" {
            mode := modes_component.modes[modes_component.current_mode]
            if mode != nil {
                mode.deactivate(mode)
            }
        }
    }
    for component in control_surface.components {
        component.deactivate(component)
    }
}
