package fire_engine

import "core:encoding/uuid"
import "core:crypto"
import "core:math"

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
    parameter.getUnitValue = defaultGetUnitValue

}

defaultGetUnitValue :: proc(param: ^Parameter) -> f32 {
    return 0.0
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
    step: f32 `json:"step"`,
    small_step: f32 `json:"small_step"`,
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
    param.step = (max_value - min_value) / 100.0
    param.small_step = (max_value - min_value) / 1000.0
    param.set = setFloat32ParameterValue
    param.get = getFloat32ParameterValue
    param.getUnitValue = getFloat32UnitValue
    param.inc = incFloat32Parameter
    param.dec = decFloat32Parameter
    param.encoder = encoderFloat32Parameter

    return param

}

getFloat32UnitValue :: proc(param_ptr: ^Parameter) -> f32 {
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

incFloat32Parameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^Float32Parameter)param_ptr
    if param == nil {
        return
    }
    step := param.step * abs(multiplier)
    setFloat32ParameterValue(param, param.value + step)
}

decFloat32Parameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^Float32Parameter)param_ptr
    if param == nil {
        return
    }
    step := param.step * abs(multiplier)
    setFloat32ParameterValue(param, param.value - step)
}

encoderFloat32Parameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^Float32Parameter)param_ptr
    if param == nil {
        return
    }
    step := param.step * multiplier
    setFloat32ParameterValue(param, param.value + step)
}

DbParameter :: struct {
    using parameter: Parameter,
    name: string `json:"name"`,
    value : f32 `json:"value"`,
    default_value: f32 `json:"default_value"`,
    min_value: f32 `json:"min_value"`,
    max_value: f32 `json:"max_value"`,
    set: proc(param: ^DbParameter, new_value: f32),
    get: proc(param: ^DbParameter) -> f32,
    step: f32 `json:"step"`,
    small_step: f32 `json:"small_step"`,
}

dbToUnit_f32 :: proc(db: f32, max_db: f32) -> f32 {
    if db == -math.INF_F32 {
        return 0.0
    }
    max_linear := dBToLinear_f32(max_db)
    linear := dBToLinear_f32(db)
    return clamp(linear / max_linear, 0.0, 1.0)
}

unitToDb_f32 :: proc(unit: f32, max_db: f32) -> f32 {
    clamped_unit := clamp(unit, 0.0, 1.0)
    if clamped_unit <= 0.0 {
        return -math.INF_F32
    }
    max_linear := dBToLinear_f32(max_db)
    linear := clamped_unit * max_linear
    return 20.0 * math.log(linear, 10.0)
}

createDbParameter :: proc(controller: ^CommandController, name: string, default_value: f32 = 0.0, max_value: f32 = 6.0) -> ^DbParameter {
    param := new(DbParameter)
    configureParameter(param)
    param.controller = controller
    param.value = min(default_value, max_value)
    param.default_value = min(default_value, max_value)
    param.name = name
    param.min_value = -math.INF_F32
    param.max_value = max_value
    param.step = 0.01
    param.small_step = 0.001
    param.set = setDbParameterValue
    param.get = getDbParameterValue
    param.getUnitValue = getDbUnitValue
    param.inc = incDbParameter
    param.dec = decDbParameter
    param.encoder = encoderDbParameter

    return param
}

createGainDbParameter :: proc(controller: ^CommandController, name: string = "Gain", default_value: f32 = 0.0) -> ^DbParameter {
    return createDbParameter(controller, name, default_value, 6.0)
}

FrequencyParameter :: struct {
    using parameter: Parameter,
    name: string `json:"name"`,
    value : f32 `json:"value"`,
    default_value: f32 `json:"default_value"`,
    min_value: f32 `json:"min_value"`,
    max_value: f32 `json:"max_value"`,
    set: proc(param: ^FrequencyParameter, new_value: f32),
    get: proc(param: ^FrequencyParameter) -> f32,
    step: f32 `json:"step"`,
    small_step: f32 `json:"small_step"`,
}

createFrequencyParameter :: proc(controller: ^CommandController, name: string = "Frequency", default_value: f32 = 440.0, min_value: f32 = 20.0, max_value: f32 = 20000.0) -> ^FrequencyParameter {
    param := new(FrequencyParameter)
    configureParameter(param)
    param.controller = controller
    param.value = clamp(default_value, min_value, max_value)
    param.default_value = clamp(default_value, min_value, max_value)
    param.name = name
    param.min_value = min_value
    param.max_value = max_value
    param.step = 0.01
    param.small_step = 0.001
    param.set = setFrequencyParameterValue
    param.get = getFrequencyParameterValue
    param.getUnitValue = getFrequencyUnitValue
    param.inc = incFrequencyParameter
    param.dec = decFrequencyParameter
    param.encoder = encoderFrequencyParameter

    return param
}

getFrequencyUnitValue :: proc(param_ptr: ^Parameter) -> f32 {
    param := cast(^FrequencyParameter)param_ptr
    if param == nil {
        return 0
    }
    return frequencyToNormal(param.value, param.min_value, param.max_value)
}

executeFrequencyParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^Float32Command)cmd_ptr
    param := cast(^FrequencyParameter)cmd.user_data
    if param == nil {
        return
    }

    param.value = cmd.new_value
    signalEmit(param.onChange, param.value)
}

undoFrequencyParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^Float32Command)cmd_ptr
    param := cast(^FrequencyParameter)cmd.user_data
    if param == nil {
        return
    }

    param.value = cmd.new_value
    signalEmit(param.onChange, cmd.previous_value)
}

setFrequencyParameterValue :: proc(param_ptr: ^FrequencyParameter, new_value: f32) {
    param := cast(^FrequencyParameter)param_ptr
    if param == nil {
        return
    }
    val := clamp(new_value, param.min_value, param.max_value)
    if val != param.value {
        new_cmd := createFloatCommand(
            id = param.id,
            execute = executeFrequencyParameterChange,
            undo = undoFrequencyParameterChange,
            new_value = val,
            previous_value = param.value,
            user_data = cast(rawptr)param)

        param.controller->executeCommand(param.id, new_cmd)
    }
}

getFrequencyParameterValue :: proc(param_ptr: ^FrequencyParameter) -> f32 {
    param := cast(^FrequencyParameter)param_ptr
    if param == nil {
        return 0
    }
    return param.value
}

incFrequencyParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^FrequencyParameter)param_ptr
    if param == nil {
        return
    }
    unit_step := param.step * abs(multiplier)
    unit_value := getFrequencyUnitValue(param_ptr)
    setFrequencyParameterValue(param, normalToFrequency(unit_value + unit_step, param.min_value, param.max_value))
}

decFrequencyParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^FrequencyParameter)param_ptr
    if param == nil {
        return
    }
    unit_step := param.step * abs(multiplier)
    unit_value := getFrequencyUnitValue(param_ptr)
    setFrequencyParameterValue(param, normalToFrequency(unit_value - unit_step, param.min_value, param.max_value))
}

encoderFrequencyParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^FrequencyParameter)param_ptr
    if param == nil {
        return
    }
    unit_step := param.step * multiplier
    unit_value := getFrequencyUnitValue(param_ptr)
    setFrequencyParameterValue(param, normalToFrequency(unit_value + unit_step, param.min_value, param.max_value))
}

TimeParameter :: struct {
    using parameter: Parameter,
    name: string `json:"name"`,
    value : f32 `json:"value"`,
    default_value: f32 `json:"default_value"`,
    min_value: f32 `json:"min_value"`,
    max_value: f32 `json:"max_value"`,
    set: proc(param: ^TimeParameter, new_value: f32),
    get: proc(param: ^TimeParameter) -> f32,
    step: f32 `json:"step"`,
    small_step: f32 `json:"small_step"`,
}

timeToUnitLog_f32 :: proc(value: f32, min_time: f32, max_time: f32) -> f32 {
    if max_time <= min_time {
        return 0.0
    }
    if value <= min_time {
        return 0.0
    }

    effective_min := min_time
    if effective_min <= 0.0 {
        effective_min = 0.0001
    }

    clamped_value := clamp(value, effective_min, max_time)
    return clamp(logToNormal_f32(clamped_value, effective_min, max_time), 0.0, 1.0)
}

unitToTimeLog_f32 :: proc(unit: f32, min_time: f32, max_time: f32) -> f32 {
    if max_time <= min_time {
        return min_time
    }

    clamped_unit := clamp(unit, 0.0, 1.0)
    if clamped_unit <= 0.0 {
        return min_time
    }

    effective_min := min_time
    if effective_min <= 0.0 {
        effective_min = 0.0001
    }

    time := normalToLog_f32(clamped_unit, effective_min, max_time)
    return clamp(time, min_time, max_time)
}

createTimeParameter :: proc(controller: ^CommandController, name: string = "Time", default_value: f32 = 0.0, min_value: f32 = 0.0, max_value: f32 = 20.0) -> ^TimeParameter {
    param := new(TimeParameter)
    configureParameter(param)
    param.controller = controller
    param.value = clamp(default_value, min_value, max_value)
    param.default_value = clamp(default_value, min_value, max_value)
    param.name = name
    param.min_value = min_value
    param.max_value = max_value
    param.step = 0.01
    param.small_step = 0.001
    param.set = setTimeParameterValue
    param.get = getTimeParameterValue
    param.getUnitValue = getTimeUnitValue
    param.inc = incTimeParameter
    param.dec = decTimeParameter
    param.encoder = encoderTimeParameter

    return param
}

getTimeUnitValue :: proc(param_ptr: ^Parameter) -> f32 {
    param := cast(^TimeParameter)param_ptr
    if param == nil {
        return 0
    }
    return timeToUnitLog_f32(param.value, param.min_value, param.max_value)
}

executeTimeParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^Float32Command)cmd_ptr
    param := cast(^TimeParameter)cmd.user_data
    if param == nil {
        return
    }

    param.value = cmd.new_value
    signalEmit(param.onChange, param.value)
}

undoTimeParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^Float32Command)cmd_ptr
    param := cast(^TimeParameter)cmd.user_data
    if param == nil {
        return
    }

    param.value = cmd.new_value
    signalEmit(param.onChange, cmd.previous_value)
}

setTimeParameterValue :: proc(param_ptr: ^TimeParameter, new_value: f32) {
    param := cast(^TimeParameter)param_ptr
    if param == nil {
        return
    }
    val := clamp(new_value, param.min_value, param.max_value)
    if val != param.value {
        new_cmd := createFloatCommand(
            id = param.id,
            execute = executeTimeParameterChange,
            undo = undoTimeParameterChange,
            new_value = val,
            previous_value = param.value,
            user_data = cast(rawptr)param)

        param.controller->executeCommand(param.id, new_cmd)
    }
}

getTimeParameterValue :: proc(param_ptr: ^TimeParameter) -> f32 {
    param := cast(^TimeParameter)param_ptr
    if param == nil {
        return 0
    }
    return param.value
}

incTimeParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^TimeParameter)param_ptr
    if param == nil {
        return
    }
    unit_step := param.step * abs(multiplier)
    unit_value := getTimeUnitValue(param_ptr)
    setTimeParameterValue(param, unitToTimeLog_f32(unit_value + unit_step, param.min_value, param.max_value))
}

decTimeParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^TimeParameter)param_ptr
    if param == nil {
        return
    }
    unit_step := param.step * abs(multiplier)
    unit_value := getTimeUnitValue(param_ptr)
    setTimeParameterValue(param, unitToTimeLog_f32(unit_value - unit_step, param.min_value, param.max_value))
}

encoderTimeParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^TimeParameter)param_ptr
    if param == nil {
        return
    }
    unit_step := param.step * multiplier
    unit_value := getTimeUnitValue(param_ptr)
    setTimeParameterValue(param, unitToTimeLog_f32(unit_value + unit_step, param.min_value, param.max_value))
}

getDbUnitValue :: proc(param_ptr: ^Parameter) -> f32 {
    param := cast(^DbParameter)param_ptr
    if param == nil {
        return 0
    }
    return dbToUnit_f32(param.value, param.max_value)
}

executeDbParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^Float32Command)cmd_ptr
    param := cast(^DbParameter)cmd.user_data
    if param == nil {
        return
    }

    param.value = cmd.new_value
    signalEmit(param.onChange, param.value)
}

undoDbParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^Float32Command)cmd_ptr
    param := cast(^DbParameter)cmd.user_data
    if param == nil {
        return
    }

    param.value = cmd.new_value
    signalEmit(param.onChange, cmd.previous_value)
}

setDbParameterValue :: proc(param_ptr: ^DbParameter, new_value: f32) {
    param := cast(^DbParameter)param_ptr
    if param == nil {
        return
    }
    val := min(new_value, param.max_value)
    if val != param.value {
        new_cmd := createFloatCommand(
            id = param.id,
            execute = executeDbParameterChange,
            undo = undoDbParameterChange,
            new_value = val,
            previous_value = param.value,
            user_data = cast(rawptr)param)

        param.controller->executeCommand(param.id, new_cmd)
    }
}

getDbParameterValue :: proc(param_ptr: ^DbParameter) -> f32 {
    param := cast(^DbParameter)param_ptr
    if param == nil {
        return 0
    }
    return param.value
}

incDbParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^DbParameter)param_ptr
    if param == nil {
        return
    }
    unit_step := param.step * abs(multiplier)
    unit_value := getDbUnitValue(param_ptr)
    setDbParameterValue(param, unitToDb_f32(unit_value + unit_step, param.max_value))
}

decDbParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^DbParameter)param_ptr
    if param == nil {
        return
    }
    unit_step := param.step * abs(multiplier)
    unit_value := getDbUnitValue(param_ptr)
    setDbParameterValue(param, unitToDb_f32(unit_value - unit_step, param.max_value))
}

encoderDbParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^DbParameter)param_ptr
    if param == nil {
        return
    }
    unit_step := param.step * multiplier
    unit_value := getDbUnitValue(param_ptr)
    setDbParameterValue(param, unitToDb_f32(unit_value + unit_step, param.max_value))
}


// For simplicity, Float64Parameter can have the same structure and behavior as Float32Parameter, but with f64 types. In a real implementation, you might want to optimize or handle them differently based on precision requirements.
Float64Parameter :: struct {
    using parameter: Parameter,
    name: string `json:"name"`,
    value : f64 `json:"value"`,
    default_value: f64 `json:"default_value"`,
    min_value: f64 `json:"min_value"`,
    max_value: f64 `json:"max_value"`,
    set: proc(param: ^Float64Parameter, new_value: f64),
    get: proc(param: ^Float64Parameter) -> f64,
    step: f64 `json:"step"`,
    small_step: f64 `json:"small_step"`,
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
    param.step = (max_value - min_value) / 100.0
    param.small_step = (max_value - min_value) / 1000.0
    param.getUnitValue = getFloat64UnitValue
    param.inc = incFloat64Parameter
    param.dec = decFloat64Parameter
    param.encoder = encoderFloat64Parameter

    return param

}

getFloat64UnitValue :: proc(param_ptr: ^Parameter) -> f32 {
    param := cast(^Float64Parameter)param_ptr
    if param == nil {
        return 0
    }
    // Convert the parameter value to a unit value between 0 and 1 based on its min and max range.
    return auto_cast normalize(param.value, param.min_value, param.max_value)
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

incFloat64Parameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^Float64Parameter)param_ptr
    if param == nil {
        return
    }
    step := param.step * auto_cast abs(multiplier)
    setFloat64ParameterValue(param, param.value + step)
}

decFloat64Parameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^Float64Parameter)param_ptr
    if param == nil {
        return
    }
    step := param.step * auto_cast abs(multiplier)
    setFloat64ParameterValue(param, param.value - step)
}

encoderFloat64Parameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^Float64Parameter)param_ptr
    if param == nil {
        return
    }
    step := param.step * auto_cast multiplier
    setFloat64ParameterValue(param, param.value + step)
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
    step: int `json:"step"`,
    small_step: int `json:"small_step"`,
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
    param.step = 1
    param.small_step = 1
    param.getUnitValue = getIntUnitValue
    param.inc = incIntParameter
    param.dec = decIntParameter
    param.encoder = encoderIntParameter

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

incIntParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^IntParameter)param_ptr
    if param == nil {
        return
    }
    step := param.step * int(abs(multiplier))
    if step < param.step {
        step = param.step
    }
    setIntParameterValue(param, param.value + step)
}

decIntParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^IntParameter)param_ptr
    if param == nil {
        return
    }
    step := param.step * int(abs(multiplier))
    if step < param.step {
        step = param.step
    }
    setIntParameterValue(param, param.value - step)
}

encoderIntParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^IntParameter)param_ptr
    if param == nil {
        return
    }
    step := int(f32(param.step) * multiplier)
    if step == 0 {
        if multiplier > 0 {
            step = param.step
        } else if multiplier < 0 {
            step = -param.step
        } else {
            return
        }
    }
    setIntParameterValue(param, param.value + step)
}

OptionsParameter :: struct {
    using parameter: Parameter,
    name: string `json:"name"`,
    value : int `json:"value"`,
    default_value: int `json:"default_value"`,
    options: []string `json:"options"`,
    set: proc(param: ^OptionsParameter, new_value: int),
    get: proc(param: ^OptionsParameter) -> int,
    step: int `json:"step"`,
    small_step: int `json:"small_step"`,
}

createOptionsParameter :: proc(controller: ^CommandController, name: string, options: []string, default_index: int = 0) -> ^OptionsParameter {
    param := new(OptionsParameter)
    configureParameter(param)
    param.controller = controller
    param.options = options
    param.value = clamp(default_index, 0, max(0, len(options) - 1))
    param.default_value = param.value
    param.name = name
    param.set = setOptionsParameterValue
    param.get = getOptionsParameterValue
    param.step = 1
    param.small_step = 1
    param.getUnitValue = getOptionsUnitValue
    param.inc = incOptionsParameter
    param.dec = decOptionsParameter
    param.encoder = encoderOptionsParameter

    return param
}

optionsCycleIndex :: proc(current: int, delta: int, count: int) -> int {
    if count <= 0 {
        return 0
    }
    next := (current + delta) % count
    if next < 0 {
        next += count
    }
    return next
}

optionsStepFromMultiplier :: proc(multiplier: f32) -> int {
    step := int(abs(multiplier))
    if step < 1 {
        step = 1
    }
    return step
}

getOptionsUnitValue :: proc(param_ptr: ^Parameter) -> f32 {
    param := cast(^OptionsParameter)param_ptr
    if param == nil {
        return 0
    }
    count := len(param.options)
    if count <= 1 {
        return 0
    }
    return clamp(f32(param.value) / f32(count - 1), 0.0, 1.0)
}

executeOptionsParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^IntCommand)cmd_ptr
    param := cast(^OptionsParameter)cmd.user_data
    if param == nil {
        return
    }

    param.value = cmd.new_value
    signalEmit(param.onChange, param.value)
}

undoOptionsParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^IntCommand)cmd_ptr
    param := cast(^OptionsParameter)cmd.user_data
    if param == nil {
        return
    }

    param.value = cmd.new_value
    signalEmit(param.onChange, param.value)
}

setOptionsParameterValue :: proc(param_ptr: ^OptionsParameter, new_value: int) {
    param := cast(^OptionsParameter)param_ptr
    if param == nil {
        return
    }

    count := len(param.options)
    max_index := max(0, count - 1)
    val := clamp(new_value, 0, max_index)
    if val != param.value {
        new_cmd := createIntCommand(
            id = param.id,
            execute = executeOptionsParameterChange,
            undo = undoOptionsParameterChange,
            new_value = val,
            previous_value = param.value,
            user_data = cast(rawptr)param)

        param.controller->executeCommand(param.id, new_cmd)
    }
}

getOptionsParameterValue :: proc(param_ptr: ^OptionsParameter) -> int {
    param := cast(^OptionsParameter)param_ptr
    if param == nil {
        return 0
    }
    return param.value
}

getIntUnitValue :: proc(param_ptr: ^Parameter) -> f32 {
    param := cast(^IntParameter)param_ptr
    if param == nil {
        return 0
    }
    range := param.max_value - param.min_value
    if range <= 0 {
        return 0
    }
    return clamp(f32(param.value - param.min_value) / f32(range), 0.0, 1.0)
}

getOptionsParameterLabel :: proc(param_ptr: ^OptionsParameter) -> string {
    param := cast(^OptionsParameter)param_ptr
    if param == nil {
        return ""
    }
    count := len(param.options)
    if count <= 0 {
        return ""
    }
    index := clamp(param.value, 0, count - 1)
    return param.options[index]
}

incOptionsParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^OptionsParameter)param_ptr
    if param == nil {
        return
    }
    count := len(param.options)
    if count <= 0 {
        return
    }
    delta := optionsStepFromMultiplier(multiplier)
    next := optionsCycleIndex(param.value, delta, count)
    setOptionsParameterValue(param, next)
}

decOptionsParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^OptionsParameter)param_ptr
    if param == nil {
        return
    }
    count := len(param.options)
    if count <= 0 {
        return
    }
    delta := -optionsStepFromMultiplier(multiplier)
    next := optionsCycleIndex(param.value, delta, count)
    setOptionsParameterValue(param, next)
}

encoderOptionsParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^OptionsParameter)param_ptr
    if param == nil {
        return
    }
    count := len(param.options)
    if count <= 0 || multiplier == 0 {
        return
    }

    step := optionsStepFromMultiplier(multiplier)
    delta := step
    if multiplier < 0 {
        delta = -step
    }

    next := optionsCycleIndex(param.value, delta, count)
    setOptionsParameterValue(param, next)
}


BoolParameter :: struct {
    using parameter: Parameter,
    name: string `json:"name"`,
    value : bool `json:"value"`,
    default_value: bool `json:"default_value"`,
    set: proc(param: ^BoolParameter, new_value: bool),
    get: proc(param: ^BoolParameter) -> bool,
    step: f32 `json:"step"`,
    small_step: f32 `json:"small_step"`,
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
    param.step = 1.0
    param.small_step = 1.0
    param.getUnitValue = getBoolUnitValue
    param.inc = incBoolParameter
    param.dec = decBoolParameter
    param.encoder = encoderBoolParameter

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

getBoolUnitValue :: proc(param_ptr: ^Parameter) -> f32 {
    param := cast(^BoolParameter)param_ptr
    if param == nil {
        return 0
    }
    if param.value {
        return 1.0
    }
    return 0.0
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

incBoolParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^BoolParameter)param_ptr
    if param == nil {
        return
    }
    setBoolParameterValue(param, true)
}

decBoolParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^BoolParameter)param_ptr
    if param == nil {
        return
    }
    setBoolParameterValue(param, false)
}

encoderBoolParameter :: proc(param_ptr: ^Parameter, multiplier: f32) {
    param := cast(^BoolParameter)param_ptr
    if param == nil {
        return
    }
    if multiplier > 0 {
        setBoolParameterValue(param, true)
    } else if multiplier < 0 {
        setBoolParameterValue(param, false)
    }
}