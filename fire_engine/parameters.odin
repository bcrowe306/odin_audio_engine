package fire_engine

import "core:encoding/uuid"
import "core:crypto"

Parameter :: struct {
    id: uuid.Identifier,
    controller: ^CommandController,
    inc: proc(param: ^Parameter, multiplier: f32),
    dec: proc(param: ^Parameter, multiplier: f32),
    encoder: proc(param: ^Parameter, multiplier: f32),

}

configureParameter :: proc(parameter: ^Parameter)  {
    context.random_generator = crypto.random_generator()
    parameter.id = uuid.generate_v4()
    parameter.inc = defaultInc
    parameter.dec = defaultDec
    parameter.encoder = defaultEncoder

}

defaultInc :: proc(param: ^Parameter, multiplier: f32) {
    // Default increment behavior can be defined here or in specific parameter types.
}
defaultDec :: proc(param: ^Parameter, multiplier: f32) {
    // Default decrement behavior can be defined here or in specific parameter types.
}

defaultEncoder :: proc(param: ^Parameter, multiplier: f32) {
    // Default encoder behavior can be defined here or in specific parameter types.
}

// Concrete parameter struct must have json tags for fields.
Float32Parameter :: struct {
    using parameter: Parameter,
    name: string,
    value : f32,
    default_value: f32,
    min_value: f32,
    max_value: f32,
    set: proc(param: ^Float32Parameter, new_value: f32),
    get: proc(param: ^Float32Parameter) -> f32,
    onChange: ^Signal,
}

createFloatParameter :: proc(controller: ^CommandController, name: string, default_value: f32, min_value: f32, max_value: f32) -> ^Float32Parameter {
    param := new(Float32Parameter)
    configureParameter(param)
    param.controller = controller
    param.value = default_value
    param.default_value = default_value
    param.name = name
    param.min_value = min_value
    param.max_value = max_value
    param.set = setFloat32ParameterValue
    param.get = getFloat32ParameterValue
    param.onChange = createSignal()

    return param

}

executeFloatParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^Float32Command)cmd_ptr
    param := cast(^Float32Parameter)cmd.user_data
    if param == nil {
        return
    }
    
    param.value = cmd.new_value
    signalEmit(param.onChange, param.value)
}

undoFloatParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^Float32Command)cmd_ptr
    param := cast(^Float32Parameter)cmd.user_data
    if param == nil {
        return
    }
    // print command new and previous values for debugging
    param.value = cmd.new_value
    signalEmit(param.onChange, cmd.previous_value)
}


setFloat32ParameterValue :: proc(param_ptr: ^Float32Parameter, new_value: f32) {
    param := cast(^Float32Parameter)param_ptr
    if param == nil {
        return
    }
    val := clamp(new_value, param.min_value, param.max_value)
    if val != param.value {
        new_cmd := createFloatCommand(
            id = param.id, 
            execute = executeFloatParameterChange, 
            undo = undoFloatParameterChange, 
            new_value = val, 
            previous_value = param.value, 
            user_data = cast(rawptr)param)

        param.controller->executeCommand(param.id, new_cmd)
    }
}
getFloat32ParameterValue :: proc(param_ptr: ^Float32Parameter) -> f32 {
    param := cast(^Float32Parameter)param_ptr
    if param == nil {
        return 0
    }
    return param.value
}

Float64Parameter :: struct {
    using parameter: Parameter,
    name: string,
    value : f64,
    default_value: f64,
    min_value: f64,
    max_value: f64,
    set: proc(param: ^Float64Parameter, new_value: f64),
    get: proc(param: ^Float64Parameter) -> f64,
}
