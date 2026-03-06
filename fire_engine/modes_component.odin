package fire_engine

Mode :: struct {
    name: string,
    components: [dynamic]^Component,
    active: bool,
    initialized: bool,
    activate: proc(ptr: rawptr),
    deactivate: proc(ptr: rawptr),
    initialize: proc(ptr: rawptr, control_surface: ^ControlSurface, device_name: string, fe: ^FireEngine),
    deInitialize: proc(ptr: rawptr),
    onActivate: proc(ptr: rawptr),
    onDeactivate: proc(ptr: rawptr),
    onInitialize: proc(ptr: rawptr),
    onDeInitialize: proc(ptr: rawptr),
    addComponent: proc(mode: ^Mode, component: ^Component),
    removeComponent: proc(mode: ^Mode, component: ^Component),
    handleMidiMsg: proc(mode: ^Mode, msg: ^ShortMessage) -> bool,
}

Mode_HandleMidiMsg :: proc(modes_component: ^ModesComponent, msg: ^ShortMessage) -> bool {
    mode := cast(^Mode)modes_component
    handled := false
    if !mode.active {
        return false
    }
    for component_ptr in mode.components {
        component := cast(^Component)component_ptr
        if component.handleInput != nil {
            if component.handleInput(component, msg) {
                handled = true
            }
         }
    }
    return handled
}

Mode_Activate :: proc(ptr: rawptr) {
    mode := cast(^Mode)ptr
    for component_ptr in mode.components {
        component := cast(^Component)component_ptr
        component.activate(component_ptr)
    }
    mode.active = true
    if mode.onActivate != nil {
        mode.onActivate(ptr)
    }
}

Mode_Deactivate :: proc(ptr: rawptr) {
    mode := cast(^Mode)ptr
    for component_ptr in mode.components {
        component := cast(^Component)component_ptr
        component.deactivate(component_ptr)
    }
    mode.active = false
    if mode.onDeactivate != nil {
        mode.onDeactivate(ptr)
    }
}

Mode_Initialize :: proc(ptr: rawptr, control_surface: ^ControlSurface, device_name: string, fe: ^FireEngine) {
    mode := cast(^Mode)ptr
    for component_ptr in mode.components {
        component := cast(^Component)component_ptr
        if component.initialize != nil {
            component.initialize(component_ptr, control_surface, device_name, fe)
        }
    }
    mode.initialized = true
    if mode.onInitialize != nil {
        mode.onInitialize(ptr)
    }
}

Mode_DeInitialize :: proc(ptr: rawptr) {
    mode := cast(^Mode)ptr
    for component_ptr in mode.components {
        component := cast(^Component)component_ptr
        if component.deInitialize != nil {
            component.deInitialize(component_ptr)
        }
    }
    mode.initialized = false
    if mode.onDeInitialize != nil {
        mode.onDeInitialize(ptr)
    }
}

Mode_AddComponent :: proc(mode: ^Mode, component: ^Component) {
    append(&mode.components, component)
}

Mode_RemoveComponent :: proc(mode: ^Mode, component: ^Component) {
    for comp_ptr, i in mode.components {
        if comp_ptr == component {
            ordered_remove(&mode.components, i)
            break
        }
    }
}


ModesComponent :: struct {
    modes: map[string]^Mode,
    current_mode: string,
    mode_stack: [dynamic]string,
    activate: proc(modes_component: ^ModesComponent),
    deactivate: proc(modes_component: ^ModesComponent),
    initialize: proc(modes_component: ^ModesComponent, control_surface: ^ControlSurface, device_name: string, fe: ^FireEngine),
    deInitialize: proc(modes_component: ^ModesComponent),
    
    addMode: proc(modes_component: ^ModesComponent, mode: ^Mode),
    switchMode: proc(modes_component: ^ModesComponent, mode_name: string),
    pushMode: proc(modes_component: ^ModesComponent, mode_name: string),
    popMode: proc(modes_component: ^ModesComponent),
    onModeChange: ^Signal,
    



    // User defined callbacks for mode changes. These can be used to trigger additional behavior in the control surface or other parts of the system when modes are switched.
    onActivate: proc(modes_component: ^ModesComponent),
    onDeactivate: proc(modes_component: ^ModesComponent),
    onInitialize: proc(modes_component: ^ModesComponent),
    onDeInitialize: proc(modes_component: ^ModesComponent),
}

createModesComponent :: proc() -> ^ModesComponent {
    modes_component := new(ModesComponent)
    modes_component.current_mode = ""
    modes_component.onModeChange = createSignal()
    modes_component.activate = ModesComponent_Activate
    modes_component.deactivate = ModesComponent_Deactivate
    modes_component.initialize = ModesComponent_Initialize
    modes_component.deInitialize = ModesComponent_DeInitialize
    modes_component.addMode = ModesComponent_AddMode
    modes_component.switchMode = ModesComponent_SwitchMode
    modes_component.pushMode = ModesComponent_PushMode
    modes_component.popMode = ModesComponent_PopMode
    return modes_component
}

ModesComponent_Activate :: proc(modes_component: ^ModesComponent) {
    if modes_component.current_mode != "" {
        currentMode := modes_component.modes[modes_component.current_mode]
        if currentMode != nil {
            currentMode.activate(currentMode)
        }
    }
    if modes_component.onActivate != nil {
        modes_component.onActivate(modes_component)
    }
}

ModesComponent_Deactivate :: proc(modes_component: ^ModesComponent) {
    if modes_component.current_mode != "" {
        currentMode := modes_component.modes[modes_component.current_mode]
        if currentMode != nil {
            currentMode.deactivate(currentMode)
        }
    }
    if modes_component.onDeactivate != nil {
        modes_component.onDeactivate(modes_component)
    }
}

ModesComponent_Initialize :: proc(modes_component: ^ModesComponent, control_surface: ^ControlSurface, device_name: string, fe: ^FireEngine) {
    for _, mode in modes_component.modes {
        if mode.initialize != nil {
            mode.initialize(mode, control_surface, device_name, fe)
        }
    }
    if modes_component.onInitialize != nil {
        modes_component.onInitialize(modes_component)
    }
}

ModesComponent_DeInitialize :: proc(modes_component: ^ModesComponent) {
    for _, mode in modes_component.modes {
        if mode.deInitialize != nil {
            mode.deInitialize(mode)
        }
    }
    if modes_component.onDeInitialize != nil {
        modes_component.onDeInitialize(modes_component)
    }
}

ModesComponent_AddMode :: proc(modes_component: ^ModesComponent, mode: ^Mode) {
    modes_component.modes[mode.name] = mode
}


ModesComponent_SwitchMode :: proc(modes_component: ^ModesComponent, mode_name: string) {
    if mode, exists := modes_component.modes[mode_name]; exists {
        if modes_component.current_mode != "" && modes_component.current_mode != mode_name {
            currentMode := modes_component.modes[modes_component.current_mode]
            if currentMode != nil {
                currentMode.deactivate(currentMode)
            }
        }
        mode.activate(mode)
        modes_component.current_mode = mode_name
        signalEmit(modes_component.onModeChange, mode_name)
    }
}

ModesComponent_PushMode :: proc(modes_component: ^ModesComponent, mode_name: string) {
    if mode, exists := modes_component.modes[mode_name]; exists {
        if modes_component.current_mode != "" {
            currentMode := modes_component.modes[modes_component.current_mode]
            if currentMode != nil {
                currentMode.deactivate(currentMode)
            }
            append(&modes_component.mode_stack, modes_component.current_mode)
        }
        mode.activate(mode)
        modes_component.current_mode = mode_name
        signalEmit(modes_component.onModeChange, mode_name)
    }
}

ModesComponent_PopMode :: proc(modes_component: ^ModesComponent) {
    if len(modes_component.mode_stack) > 0 {
        if modes_component.current_mode != "" {
            currentMode := modes_component.modes[modes_component.current_mode]
            if currentMode != nil {
                currentMode.deactivate(currentMode)
            }
        }

        // TODO: Verify mode index logic is correct here. It seems like it should be, but it's worth double checking since stack logic can be tricky and it's important that we don't accidentally pop the wrong mode or cause an out of bounds error.
        last_index := len(modes_component.mode_stack) - 1
        previous_mode_name := modes_component.mode_stack[last_index]
        ordered_remove(&modes_component.mode_stack, last_index)
        if previous_mode, exists := modes_component.modes[previous_mode_name]; exists {
            previous_mode.activate(previous_mode)
            modes_component.current_mode = previous_mode_name
            signalEmit(modes_component.onModeChange, previous_mode_name)
        }
    }
}