package fire_engine 

import "core:encoding/uuid"
import "core:crypto"

Component :: struct {
    using control : Control,
    addControl: proc(component: ^Component, control: rawptr, control_name: string = ""),
    controls_map: map[string]rawptr,
    removeControl: proc(component: ^Component, control: rawptr),
    controls : [dynamic]rawptr,
    activate: proc(ptr: rawptr),
    connections: [dynamic]^SignalConnection,

    // Function to add signal connections that will be automatically disconnected when the component is left
    addConnection: proc(page: ^Component, signal: ^Signal, observer: proc (value: any, user_data: rawptr)) -> ^SignalConnection,
    
}

    

createComponent :: proc(name: string) -> ^Component {
    context.random_generator = crypto.random_generator()
    component := new(Component)
    component.id = uuid.generate_v4()
    component.name = name
    component.enabled = true
    component.active = false
    component.initialize = initializeComponent
    component.handleInput = defaultComponentInputHandler
    component.addControl = component_addControl
    component.removeControl = component_removeControl
    component.activate = activateComponent
    component.deactivate = deactivateComponent
    component.addConnection = componentAddConnection
    return component
}

componentAddConnection :: proc(page: ^Component, signal: ^Signal, observer: proc (value: any, user_data: rawptr)) -> ^SignalConnection {
    connection := signalConnect(signal, observer, cast(rawptr)page)
    append(&page.connections, connection)
    return connection
}

activateComponent :: proc(ptr: rawptr) {
    component := cast(^Component)ptr
    comp_control := cast(^Control)ptr
    component.active = true
    for control_ptr in component.controls {
        control := cast(^Control)control_ptr
        control.active = true
    }
    if component.onActivate != nil {
        component.onActivate(ptr)
    }
}

deactivateComponent :: proc(ptr: rawptr) {
    component := cast(^Component)ptr
    for connection in component.connections {
        signalDisconnect(connection)
    }
    clear(&component.connections)
    
    for control_ptr in component.controls {
        control := cast(^Control)control_ptr
        control.active = false
        if control.deactivate != nil {
            control.deactivate(control_ptr)
        }
    }
    if component.onDeInitialize != nil {
        component.onDeInitialize(ptr)
    }
    component.active = false
}

initializeComponent :: proc(ptr: rawptr, control_surface: ^ControlSurface, device_name: string, fe: ^FireEngine) {
    component := cast(^Component)ptr
    component.control_surface = control_surface
    component.device_name = device_name
    component.fe = fe
    for control_ptr in component.controls {
        control := cast(^Control)control_ptr
        if control.initialize != nil {
            control.initialize(control_ptr, control_surface, component.device_name, fe)
        }
    }
    if component.onInitialize != nil {
        component.onInitialize(ptr)
    }
    component.initialized = true
}

deInitializeComponent :: proc(ptr: rawptr) {
    component := cast(^Component)ptr
    for control_ptr in component.controls {
        control := cast(^Control)control_ptr
        if control.deInitialize != nil {
            control.deInitialize(control_ptr)
        }
    }
    if component.onDeInitialize != nil {
        component.onDeInitialize(ptr)
    }
    component.initialized = false
}

defaultComponentInputHandler :: proc(component_ptr: rawptr, msg: ^ShortMessage) -> bool {
    handled := false
    component := cast(^Component)component_ptr

    if !component.active || !component.enabled {
        return false
    }

    for control_ptr in component.controls {
        control := cast(^Control)control_ptr
        if control.enabled && control.active && control.handleInput != nil {
            if control.handleInput(control_ptr, msg) {
                handled = true
            }
        }   
    }
    return handled
}


component_addControl :: proc(component: ^Component, control:rawptr, control_name: string = "") {
    // Process additions
    exists := false
    new := cast(^Control)control
    for ptr in component.controls {
        existing_control := cast(^Control)ptr
        if new.id == existing_control.id {
            exists = true
            break
        }
    }
    if !exists {
        n := new.name
        if control_name != "" {
            n = control_name
        }
        append(&component.controls, control)

        if n != "" {
            component.controls_map[n] = control
        }
    }
}

component_removeControl :: proc(component: ^Component, control_to_remove: rawptr) {
    control_to_remove := cast(^Control)control_to_remove
    // Process removals
    for ptr, index in component.controls {
        control := cast(^Control)ptr
        if control.id == control_to_remove.id {
            ordered_remove(&component.controls, index)
            break
        }
    }
}


