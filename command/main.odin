package main
import "core:fmt"
import "core:encoding/uuid"
import "core:crypto"


CommandExecProc:: proc(cmd: ^Command)
CommandUndoProc:: proc(cmd: ^Command)

CommandController :: struct {
    undo_stack: [dynamic]^Command,
    redo_stack: [dynamic]^Command,
    // commands_map: map[uuid.Identifier]Command,
    executeCommand: proc(controller: ^CommandController, id: uuid.Identifier, cmd: ^Command),
    undoCommand: proc(controller: ^CommandController),
    redoCommand: proc(controller: ^CommandController),
}

createController :: proc() -> ^CommandController {
    controller := new(CommandController)
    controller.executeCommand = executeCommand
    controller.undoCommand = undoCommand
    controller.redoCommand = redoCommand
    return controller
}

destroyController :: proc(controller: ^CommandController) {
    clear(&controller.undo_stack)
    clear(&controller.redo_stack)
    // clear(&controller.commands_map)
    free(controller)
}

executeCommand :: proc(controller: ^CommandController, id: uuid.Identifier, cmd: ^Command) {
    // TODO: Implement command mapping for debouncing and coalescing of commands.
    new_cmd := cast(^Command)cmd
    new_cmd->execute()
    append(&controller.undo_stack, new_cmd)
    clear(&controller.redo_stack)
}

undoCommand :: proc(controller: ^CommandController) {
    if len(controller.undo_stack) == 0 {
        return
    }
    undo_command_index := len(controller.undo_stack) - 1
    cmd := controller.undo_stack[undo_command_index]
    cmd.undo(cmd)
    append(&controller.redo_stack, cmd)
    ordered_remove(&controller.undo_stack, undo_command_index)
}

redoCommand :: proc(controller: ^CommandController) {
    if len(controller.redo_stack) == 0 {
        return
    }
    redo_command_index := len(controller.redo_stack) - 1  
    cmd := cast(^Command)controller.redo_stack[redo_command_index]
    cmd.execute(cmd)
    append(&controller.undo_stack, cmd)
    ordered_remove(&controller.redo_stack, redo_command_index)
}

Command :: struct {
    id: uuid.Identifier,
    execute: proc(cmd: ^Command),
    undo: proc(cmd: ^Command),
    user_data: rawptr,
    
}

Float32Command :: struct {
    using command: Command,
    new_value: f32,
    previous_value: f32,
}

Float64Command :: struct {
    using command: Command,
    new_value: f64,
    previous_value: f64,
}

IntCommand :: struct {
    using command: Command,
    new_value: int,
    previous_value: int,
}

UInt32Command :: struct {
    using command: Command,
    new_value: u32,
    previous_value: u32,
}

UInt64Command :: struct {
    using command: Command,
    new_value: u64,
    previous_value: u64,
}

BoolCommand :: struct {
    using command: Command,
    new_value: bool,
    previous_value: bool,
}

I32Command :: struct {
    using command: Command,
    new_value: i32,
    previous_value: i32,
}

I64Command :: struct {
    using command: Command,
    new_value: i64,
    previous_value: i64,
}

StringCommand :: struct {
    using command: Command,
    new_value: string,
    previous_value: string,
}

Vector32Command :: struct {
    using command: Command,
    new_value: []f32,
    previous_value: []f32,
}

Vector64Command :: struct {
    using command: Command,
    new_value: []f64,
    previous_value: []f64,
}

VectorIntCommand :: struct {
    using command: Command,
    new_value: []int,
    previous_value: []int,
}

VectorUInt32Command :: struct {
    using command: Command,
    new_value: []u32,
    previous_value: []u32,
}

VectorUInt64Command :: struct {
    using command: Command,
    new_value: []u64,
    previous_value: []u64,
}


createFloatCommand :: proc(id: uuid.Identifier, execute: proc(cmd: ^Command), undo: proc(cmd: ^Command), new_value: f32, previous_value: f32, user_data: rawptr) -> ^Float32Command {
    cmd := new(Float32Command)
    cmd.id = id
    cmd.execute = execute
    cmd.undo = undo
    cmd.new_value = new_value
    cmd.previous_value = previous_value
    cmd.user_data = user_data
    return cmd
}

Parameter :: struct {
    id: uuid.Identifier,
    controller: ^CommandController,
    listeners: [dynamic]proc(new_value: any), // TODO: will be signals instead of listeners.

    addListener: proc(param: ^Parameter, listener: proc(new_value: any)),
    removeListener: proc(param: ^Parameter, listener: proc(new_value: any)),

}

addListener :: proc(param: ^Parameter, listener: proc(new_value: any)) {
    append(&param.listeners, listener)
}

removeListener :: proc(param: ^Parameter, listener: proc(new_value: any)) {
    for existing_listener, index in param.listeners {
        if existing_listener == listener {
            ordered_remove(&param.listeners, index)
            break
        }
    }
}


configureParameter :: proc(parameter: ^Parameter)  {
    context.random_generator = crypto.random_generator()
    parameter.id = uuid.generate_v4()
    parameter.addListener = addListener
    parameter.removeListener = removeListener
}

// Concrete parameter struct must have json tags for fields.
FloatParameter :: struct {
    using parameter: Parameter,
    name: string,
    value : f32,
    default_value: f32,
    min_value: f32,
    max_value: f32,
    set: proc(param: ^FloatParameter, new_value: f32),
    get: proc(param: ^FloatParameter) -> f32,
}




createFloatParameter :: proc(controller: ^CommandController, name: string, default_value: f32, min_value: f32, max_value: f32) -> ^FloatParameter {
    param := new(FloatParameter)
    configureParameter(param)
    param.controller = controller
    param.value = default_value
    param.default_value = default_value
    param.name = name
    param.min_value = min_value
    param.max_value = max_value
    param.set = setFloatParameterValue
    param.get = getFloatParameterValue

    return param

}

executeFloatParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^Float32Command)cmd_ptr
    param := cast(^FloatParameter)cmd.user_data
    if param == nil {
        return
    }
    
    param.value = cmd.new_value
    for listener in param.listeners {
        listener(cmd.new_value)
    }
}

undoFloatParameterChange :: proc(cmd_ptr: ^Command) {
    cmd := cast(^Float32Command)cmd_ptr
    param := cast(^FloatParameter)cmd.user_data
    if param == nil {
        return
    }
    // print command new and previous values for debugging
    param.value = cmd.new_value
    for listener in param.listeners {
        listener(cmd.previous_value)
    }
}


setFloatParameterValue :: proc(param_ptr: ^FloatParameter, new_value: f32) {
    param := cast(^FloatParameter)param_ptr
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
getFloatParameterValue :: proc(param_ptr: ^FloatParameter) -> f32 {
    param := cast(^FloatParameter)param_ptr
    if param == nil {
        return 0
    }
    return param.value
}


main :: proc() {
    controller := createController()
    defer destroyController(controller)

    volume_param := createFloatParameter(controller, "Volume", 0.5, 0.0, 1.0)
    volume_param->addListener(proc(new_value: any) {
        fmt.printfln("Volume changed to: %f", new_value.(f32))
    })
    volume_param->set(0.8)
    volume_param->set(0.3)
    controller->undoCommand()

}