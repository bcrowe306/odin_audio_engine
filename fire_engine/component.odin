package fire_engine 

import "core:encoding/uuid"
import "core:crypto"


// Component is base struct for all Control Surfaces Components. It provides a common interface for managing controls, activation, and initialization.
Component :: struct {
    id: uuid.Identifier,
    name: string,
    active: bool,
    initialized: bool,
    enabled: bool,
    fe: ^FireEngine,
    control_surface: ^ControlSurface,
    controls: map[string]rawptr,
    connections: [dynamic]^SignalConnection,
    
    // Adds a control to the component. The control is stored in the controls map using its name as the key.
    addControl: proc(component_ptr: rawptr, control: rawptr),

    // Removes a control from the component. The control is removed from the controls map based on its name.
    removeControl: proc(component_ptr: rawptr, control: rawptr),
    
    activate: proc(component_ptr: rawptr),
    deactivate: proc(component_ptr: rawptr),
    initialize: proc(component_ptr: rawptr, fe: ^FireEngine, control_surface: ^ControlSurface),
    deInitialize: proc(component_ptr: rawptr),

    // Override to perform custom actions when the component is activated. This is the place call the components' addConnections function to add signal connections that should be active while the component is active.
    onActivate: proc(component_ptr: rawptr),

    // Override to perform custom actions when the component is deactivated.
    onDeactivate: proc(component_ptr: rawptr),

    // Override to perform custom actions when the component is initialized.
    onInitialize: proc(component_ptr: rawptr),

    // Override to perform custom actions when the component is de-initialized.
    onDeInitialize: proc(component_ptr: rawptr),


    // Function to add signal connections that will be automatically disconnected when the component is deactivated. This is useful for managing signal connections that should only be active while the component is active.
    addConnection: proc(component: ^Component, signal: ^Signal, observer: proc (value: any, user_data: rawptr)) -> ^SignalConnection,
    
}

    

createComponent :: proc(name: string) -> ^Component {
    context.random_generator = crypto.random_generator()
    component := new(Component)
    configureComponent(component, name)
    return component
}

configureComponent :: proc(component: ^Component, name: string) {
    component.name = name
    component.id = uuid.generate_v4()
    component.enabled = true
    component.active = false
    component.initialized = false
    component.initialize = initializeComponent
    component.deInitialize = deInitializeComponent
    component.addControl = component_addControl
    component.activate = activateComponent
    component.deactivate = deactivateComponent
    component.removeControl = component_removeControl
    component.addConnection = componentAddConnection
}

componentAddConnection :: proc(component: ^Component, signal: ^Signal, observer: proc (value: any, user_data: rawptr)) -> ^SignalConnection {
    connection := signalConnect(signal, observer, cast(rawptr)component)
    append(&component.connections, connection)
    return connection
}

activateComponent :: proc(component_ptr: rawptr) {
    component := cast(^Component)component_ptr
    for control_name, control_ptr in component.controls {
        control := cast(^Control)control_ptr
        control.active = true
        if control.onActivate != nil {
            control.onActivate(control_ptr)
        }
    }
    component.active = true
    if component.onActivate != nil {
        component.onActivate(component_ptr)
    }
}

deactivateComponent :: proc(component_ptr: rawptr) {
    component := cast(^Component)component_ptr
    for connection in component.connections {
        signalDisconnect(connection)
    }
    clear(&component.connections)
    
    for _, control in component.controls {
        control := cast(^Control)control
        control.active = false
        if control.onDeactivate != nil {
            control.onDeactivate(cast(rawptr)control)
        }
    }

    component.active = false
    if component.onDeactivate != nil {
        component.onDeactivate(component_ptr)
    }
    
}

initializeComponent :: proc(component_ptr: rawptr, fe: ^FireEngine, control_surface: ^ControlSurface) {
    component := cast(^Component)component_ptr
    component.control_surface = control_surface
    component.fe = fe
    component.initialized = true
    if component.onInitialize != nil {
        component.onInitialize(component_ptr)
    }
    
}

deInitializeComponent :: proc(component_ptr: rawptr) {
    component := cast(^Component)component_ptr
    component.initialized = false
    if component.onDeInitialize != nil {
        component.onDeInitialize(component_ptr)
    }
}

component_addControl :: proc(component_ptr: rawptr, control:rawptr) {
    component := cast(^Component)component_ptr
    // Process additions
    control := cast(^Control)control
    component.controls[control.name] = control

}

component_removeControl :: proc(component_ptr: rawptr, control_to_remove: rawptr) {
    component := cast(^Component)component_ptr
    control_to_remove := cast(^Control)control_to_remove
    // Process removals

    for control_name, control_ptr in component.controls {
        control := cast(^Control)control_ptr
        if control.id == control_to_remove.id {
            delete_key(&component.controls, control_name)
            break
        }
    }
}


