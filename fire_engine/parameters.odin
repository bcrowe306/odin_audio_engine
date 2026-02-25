package fire_engine

import "core:encoding/uuid"
import "core:crypto"

Parameter :: struct {
    id: uuid.Identifier,
    controller: ^CommandController,
    inc: proc(param: ^Parameter, multiplier: f32),
    dec: proc(param: ^Parameter, multiplier: f32),
    encoder: proc(param: ^Parameter, multiplier: f32),
    onChange: ^Signal,
    getUnitValue : proc(param: ^Parameter) -> f32,

}

configureParameter :: proc(parameter: ^Parameter)  {
    context.random_generator = crypto.random_generator()
    parameter.id = uuid.generate_v4()
    parameter.onChange = createSignal()
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
    name: string `json:"name"`, 
    value : f32 `json:"value"`,
    default_value: f32 `json:"default_value"`,
    min_value: f32 `json:"min_value"`,
    max_value: f32 `json:"max_value"`,
    set: proc(param: ^Float32Parameter, new_value: f32),
    get: proc(param: ^Float32Parameter) -> f32,
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

    return param

}

getFloat32UnitValue :: proc(param_ptr: ^Float32Parameter) -> f32 {
    param := cast(^Float32Parameter)param_ptr
    if param == nil {
        return 0
    }
    // Convert the parameter value to a unit value between 0 and 1 based on its min and max range.
    return (param.value - param.min_value) / (param.max_value - param.min_value)
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
    name: string `json:"name"`,
    value : f64 `json:"value"`,
    default_value: f64 `json:"default_value"`,
    min_value: f64 `json:"min_value"`,
    max_value: f64 `json:"max_value"`,
    set: proc(param: ^Float64Parameter, new_value: f64),
    get: proc(param: ^Float64Parameter) -> f64,
}

createFloat64Parameter :: proc(controller: ^CommandController, name: string, default_value: f64, min_value: f64, max_value: f64) -> ^Float64Parameter {
    param := new(Float64Parameter)
    configureParameter(param)
    param.controller = controller
    param.value = default_value
    param.default_value = default_value
    param.name = name
    param.min_value = min_value
    param.max_value = max_value
    param.set = setFloat64ParameterValue
    param.get = getFloat64ParameterValue

    return param

}

setFloat64ParameterValue :: proc(param_ptr: ^Float64Parameter, new_value: f64) {
    param := cast(^Float64Parameter)param_ptr
    if param == nil {
        return
    }
    val := clamp(new_value, param.min_value, param.max_value)
    if val != param.value {
        new_cmd := createFloat64Command(
            id = param.id, 
            execute = executeFloat64ParameterChange, 
            undo = undoFloat64ParameterChange, 
            new_value = val, 
            previous_value = param.value, 
            user_data = cast(rawptr)param)

        param.controller->executeCommand(param.id, new_cmd)
    }
}
getFloat64ParameterValue :: proc(param_ptr: ^Float64Parameter) -> f64 {
    param := cast(^Float64Parameter)param_ptr
    if param == nil {
        return 0
    }
    return param.value
}

executeFloat64ParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^Float64Command)cmd_ptr
    param := cast(^Float64Parameter)cmd.user_data
    if param == nil {
        return
    }
    
    param.value = cmd.new_value
    signalEmit(param.onChange, param.value)
}
undoFloat64ParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^Float64Command)cmd_ptr
    param := cast(^Float64Parameter)cmd.user_data
    if param == nil {
        return
    }
    // print command new and previous values for debugging
    param.value = cmd.new_value
    signalEmit(param.onChange, param.value)
}

IntParameter :: struct {
    using parameter: Parameter,
    name: string `json:"name"`,
    value : int `json:"value"`,
    default_value: int `json:"default_value"`,
    min_value: int `json:"min_value"`,
    max_value: int `json:"max_value"`,
    set: proc(param: ^IntParameter, new_value: int),
    get: proc(param: ^IntParameter) -> int,
}

createIntParameter :: proc(controller: ^CommandController, name: string, default_value: int, min_value: int, max_value: int) -> ^IntParameter {
    param := new(IntParameter)
    configureParameter(param)
    param.controller = controller
    param.value = default_value
    param.default_value = default_value
    param.name = name
    param.min_value = min_value
    param.max_value = max_value
    param.set = setIntParameterValue
    param.get = getIntParameterValue 

    return param
}

setIntParameterValue :: proc(param_ptr: ^IntParameter, new_value: int) {
    param := cast(^IntParameter)param_ptr
    if param == nil {
        return
    }
    val := clamp(new_value, param.min_value, param.max_value)
    if val != param.value {
        new_cmd := createIntCommand(
            id = param.id, 
            execute = executeIntParameterChange, 
            undo = undoIntParameterChange, 
            new_value = val, 
            previous_value = param.value, 
            user_data = cast(rawptr)param)

        param.controller->executeCommand(param.id, new_cmd)
    }
}
getIntParameterValue :: proc(param_ptr: ^IntParameter) -> int {
    param := cast(^IntParameter)param_ptr
    if param == nil {
        return 0
    }
    return param.value

}

executeIntParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^IntCommand)cmd_ptr
    param := cast(^IntParameter)cmd.user_data
    if param == nil {
        return
    }
    
    param.value = cmd.new_value
    signalEmit(param.onChange, param.value)
}
undoIntParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^IntCommand)cmd_ptr
    param := cast(^IntParameter)cmd.user_data
    if param == nil {
        return
    }
    // print command new and previous values for debugging
    param.value = cmd.new_value
    signalEmit(param.onChange, param.value)
}


BoolParameter :: struct {
    using parameter: Parameter,
    name: string `json:"name"`,
    value : bool `json:"value"`,
    default_value: bool `json:"default_value"`,
    set: proc(param: ^BoolParameter, new_value: bool),
    get: proc(param: ^BoolParameter) -> bool,
}

createBoolParameter :: proc(controller: ^CommandController, name: string, default_value: bool) -> ^BoolParameter {
    param := new(BoolParameter)
    configureParameter(param)
    param.controller = controller
    param.value = default_value
    param.default_value = default_value
    param.name = name
    param.set = setBoolParameterValue
    param.get = getBoolParameterValue

    return param

}

setBoolParameterValue :: proc(param_ptr: ^BoolParameter, new_value: bool) {
    param := cast(^BoolParameter)param_ptr
    if param == nil {
        return
    }
    if new_value != param.value {
        new_cmd := createBoolCommand(
            id = param.id, 
            execute = executeBoolParameterChange, 
            undo = undoBoolParameterChange, 
            new_value = new_value, 
            previous_value = param.value, 
            user_data = cast(rawptr)param)

        param.controller->executeCommand(param.id, new_cmd)
    }
}
getBoolParameterValue :: proc(param_ptr: ^BoolParameter) -> bool {
    param := cast(^BoolParameter)param_ptr
    if param == nil {
        return false
    }
    return param.value
}

executeBoolParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^BoolCommand)cmd_ptr
    param := cast(^BoolParameter)cmd.user_data
    if param == nil {
        return
    }
    
    param.value = cmd.new_value
    signalEmit(param.onChange, param.value)
}
undoBoolParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^BoolCommand)cmd_ptr
    param := cast(^BoolParameter)cmd.user_data
    if param == nil {
        return
    }
    // print command new and previous values for debugging
    param.value = cmd.new_value
    signalEmit(param.onChange, param.value) 
}