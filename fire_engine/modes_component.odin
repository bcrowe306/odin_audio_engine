package fire_engine

import "core:fmt"

Mode :: struct {
    name: string,
    components: [dynamic]rawptr,
    active: bool,
    addComponent: proc(mode: ^Mode, component_ptr: rawptr),
    removeComponent: proc(mode: ^Mode, component_ptr: rawptr),
}


Mode_AddComponent :: proc(mode: ^Mode, component_ptr: rawptr) {
    append(&mode.components, component_ptr)
}

Mode_RemoveComponent :: proc(mode: ^Mode, component_ptr: rawptr) {
    for comp_ptr, i in mode.components {
        if comp_ptr == component_ptr {
            ordered_remove(&mode.components, i)
            break
        }
    }
}

createMode :: proc(name: string) -> ^Mode {
    mode := new(Mode)
    mode.name = name
    mode.active = false
    mode.addComponent = Mode_AddComponent
    mode.removeComponent = Mode_RemoveComponent
    return mode
}


ModesComponent :: struct {
    using component: Component,
    modes: map[string]^Mode,
    current_mode: string,
    default_mode: string,
    mode_stack: [dynamic]string,
    
    addMode: proc(modes_component: ^ModesComponent, mode: ^Mode),
    addModes: proc(modes_component: ^ModesComponent, modes: ..^Mode),
    switchMode: proc(modes_component: ^ModesComponent, mode_name: string),
    pushMode: proc(modes_component: ^ModesComponent, mode_name: string),
    popMode: proc(modes_component: ^ModesComponent),
    onModeChange: ^Signal,
}

createModesComponent :: proc(name: string, default_mode: string = "") -> ^ModesComponent {
    modes_component := new(ModesComponent)
    configureComponent(modes_component, name)
    modes_component.name = name
    modes_component.current_mode = default_mode
    modes_component.onModeChange = createSignal()
    modes_component.activate = ModesComponent_Activate
    modes_component.deactivate = ModesComponent_Deactivate
    modes_component.initialize = ModesComponent_Initialize
    modes_component.deInitialize = ModesComponent_DeInitialize
    modes_component.addMode = ModesComponent_AddMode
    modes_component.switchMode = ModesComponent_SwitchMode
    modes_component.pushMode = ModesComponent_PushMode
    modes_component.popMode = ModesComponent_PopMode
    modes_component.addModes = ModesComponent_AddModes
    return modes_component
}

ModesComponent_Activate :: proc(modes_component_ptr: rawptr) {
    modes_component := cast(^ModesComponent)modes_component_ptr
    fmt.println("Activating ModesComponent: ", modes_component.name)
    fmt.printfln("Current mode: %s", modes_component.current_mode)
    if modes_component.current_mode != "" {
        currentMode := modes_component.modes[modes_component.current_mode]
        for comp_ptr in currentMode.components {
            component := cast(^Component)comp_ptr
            component.activate(cast(rawptr)component)
        }
    }
    if modes_component.onActivate != nil {
        modes_component.onActivate(modes_component)
    }
}

ModesComponent_Deactivate :: proc(modes_component_ptr: rawptr) {
    modes_component := cast(^ModesComponent)modes_component_ptr
    if modes_component.current_mode != "" {
        currentMode := modes_component.modes[modes_component.current_mode]
        if currentMode != nil {
            for comp_ptr in currentMode.components {
                component := cast(^Component)comp_ptr
                component.deactivate(cast(rawptr)component)
            }
        }
    }
    if modes_component.onDeactivate != nil {
        modes_component.onDeactivate(modes_component_ptr)
    }
}

ModesComponent_Initialize :: proc(modes_component_ptr: rawptr, fe: ^FireEngine, control_surface: ^ControlSurface) {
    modes_component := cast(^ModesComponent)modes_component_ptr
    for _, mode in modes_component.modes {
        for comp_ptr in mode.components {
            component := cast(^Component)comp_ptr
            component.initialize(cast(rawptr)component, fe, control_surface)
        }
    }

    if modes_component.onInitialize != nil {
        modes_component.onInitialize(modes_component_ptr)
    }
}

ModesComponent_DeInitialize :: proc(modes_component_ptr: rawptr) {
    modes_component := cast(^ModesComponent)modes_component_ptr
    for _, mode in modes_component.modes {
        for comp_ptr in mode.components {
            component := cast(^Component)comp_ptr
            component.deInitialize(cast(rawptr)component)
        }
    }
    if modes_component.onDeInitialize != nil {
        modes_component.onDeInitialize(modes_component_ptr)
    }
}

ModesComponent_AddMode :: proc(modes_component: ^ModesComponent, mode: ^Mode) {
    modes_component.modes[mode.name] = mode
}

ModesComponent_AddModes :: proc(modes_component: ^ModesComponent, modes: ..^Mode) {
   for mode in modes {
        modes_component.modes[mode.name] = mode
   }
}

ModesComponent_SwitchMode :: proc(modes_component: ^ModesComponent, mode_name: string) {
    if mode, exists := modes_component.modes[mode_name]; exists {
        if modes_component.current_mode != "" && modes_component.current_mode != mode_name {
            currentMode := modes_component.modes[modes_component.current_mode]
            for comp_ptr in currentMode.components {
                component := cast(^Component)comp_ptr
                component.deactivate(cast(rawptr)component)
            }
        }

        for comp_ptr in mode.components {
            component := cast(^Component)comp_ptr
            component.activate(cast(rawptr)component)
        }
        modes_component.current_mode = mode_name
        signalEmit(modes_component.onModeChange, mode_name)
    }
}

ModesComponent_PushMode :: proc(modes_component: ^ModesComponent, mode_name: string) {
    if mode, exists := modes_component.modes[mode_name]; exists {
        if modes_component.current_mode != "" {
            currentMode := modes_component.modes[modes_component.current_mode]
            if currentMode != nil {
                for comp_ptr in currentMode.components {
                    component := cast(^Component)comp_ptr
                    component.deactivate(cast(rawptr)component)
                }
            }
            append(&modes_component.mode_stack, modes_component.current_mode)
        }
        for comp_ptr in mode.components {
            component := cast(^Component)comp_ptr
            component.activate(cast(rawptr)component)
        }
        modes_component.current_mode = mode_name
        signalEmit(modes_component.onModeChange, mode_name)
    }
}

ModesComponent_PopMode :: proc(modes_component: ^ModesComponent) {
    if len(modes_component.mode_stack) > 0 {
        if modes_component.current_mode != "" {
            currentMode := modes_component.modes[modes_component.current_mode]
            if currentMode != nil {
                for comp_ptr in currentMode.components {
                    component := cast(^Component)comp_ptr
                    component.deactivate(cast(rawptr)component)
                }
            }
        }

        // TODO: Verify mode index logic is correct here. It seems like it should be, but it's worth double checking since stack logic can be tricky and it's important that we don't accidentally pop the wrong mode or cause an out of bounds error.
        last_index := len(modes_component.mode_stack) - 1
        previous_mode_name := modes_component.mode_stack[last_index]
        ordered_remove(&modes_component.mode_stack, last_index)
        if previous_mode, exists := modes_component.modes[previous_mode_name]; exists {
            for comp_ptr in previous_mode.components {
                component := cast(^Component)comp_ptr
                component.activate(cast(rawptr)component)
            }
            modes_component.current_mode = previous_mode_name
            signalEmit(modes_component.onModeChange, previous_mode_name)
        }
    }
}