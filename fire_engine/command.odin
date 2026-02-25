package fire_engine

import "core:c"
import "core:encoding/uuid"

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

createFloat64Command :: proc(id: uuid.Identifier, execute: proc(cmd: ^Command), undo: proc(cmd: ^Command), new_value: f64, previous_value: f64, user_data: rawptr) -> ^Float64Command {
    cmd := new(Float64Command)
    cmd.id = id
    cmd.execute = execute
    cmd.undo = undo
    cmd.new_value = new_value
    cmd.previous_value = previous_value
    cmd.user_data = user_data
    return cmd
}

createIntCommand :: proc(id: uuid.Identifier, execute: proc(cmd: ^Command), undo: proc(cmd: ^Command), new_value: int, previous_value: int, user_data: rawptr) -> ^IntCommand {
    cmd := new(IntCommand)
    cmd.id = id
    cmd.execute = execute
    cmd.undo = undo
    cmd.new_value = new_value
    cmd.previous_value = previous_value
    cmd.user_data = user_data
    return cmd
}

createUInt32Command :: proc(id: uuid.Identifier, execute: proc(cmd: ^Command), undo: proc(cmd: ^Command), new_value: u32, previous_value: u32, user_data: rawptr) -> ^UInt32Command {
    cmd := new(UInt32Command)
    cmd.id = id
    cmd.execute = execute
    cmd.undo = undo
    cmd.new_value = new_value
    cmd.previous_value = previous_value
    cmd.user_data = user_data
    return cmd
}

createUInt64Command :: proc(id: uuid.Identifier, execute: proc(cmd: ^Command), undo: proc(cmd: ^Command), new_value: u64, previous_value: u64, user_data: rawptr) -> ^UInt64Command {
    cmd := new(UInt64Command)
    cmd.id = id
    cmd.execute = execute
    cmd.undo = undo
    cmd.new_value = new_value
    cmd.previous_value = previous_value
    cmd.user_data = user_data
    return cmd
}

createBoolCommand :: proc(id: uuid.Identifier, execute: proc(cmd: ^Command), undo: proc(cmd: ^Command), new_value: bool, previous_value: bool, user_data: rawptr) -> ^BoolCommand {
    cmd := new(BoolCommand)
    cmd.id = id
    cmd.execute = execute
    cmd.undo = undo
    cmd.new_value = new_value
    cmd.previous_value = previous_value
    cmd.user_data = user_data
    return cmd
}

createI32Command :: proc(id: uuid.Identifier, execute: proc(cmd: ^Command), undo: proc(cmd: ^Command), new_value: i32, previous_value: i32, user_data: rawptr) -> ^I32Command {
    cmd := new(I32Command)
    cmd.id = id
    cmd.execute = execute
    cmd.undo = undo
    cmd.new_value = new_value
    cmd.previous_value = previous_value
    cmd.user_data = user_data
    return cmd
}

createI64Command :: proc(id: uuid.Identifier, execute: proc(cmd: ^Command), undo: proc(cmd: ^Command), new_value: i64, previous_value: i64, user_data: rawptr) -> ^I64Command {
    cmd := new(I64Command)
    cmd.id = id
    cmd.execute = execute
    cmd.undo = undo
    cmd.new_value = new_value
    cmd.previous_value = previous_value
    cmd.user_data = user_data
    return cmd
}

createStringCommand :: proc(id: uuid.Identifier, execute: proc(cmd: ^Command), undo: proc(cmd: ^Command), new_value: string, previous_value: string, user_data: rawptr) -> ^StringCommand {
    cmd := new(StringCommand)
    cmd.id = id
    cmd.execute = execute
    cmd.undo = undo
    cmd.new_value = new_value
    cmd.previous_value = previous_value
    cmd.user_data = user_data
    return cmd
}

createVector32Command :: proc(id: uuid.Identifier, execute: proc(cmd: ^Command), undo: proc(cmd: ^Command), new_value: []f32, previous_value: []f32, user_data: rawptr) -> ^Vector32Command {
    cmd := new(Vector32Command)
    cmd.id = id
    cmd.execute = execute
    cmd.undo = undo
    cmd.new_value = new_value
    cmd.previous_value = previous_value
    cmd.user_data = user_data
    return cmd
}

createVector64Command :: proc(id: uuid.Identifier, execute: proc(cmd: ^Command), undo: proc(cmd: ^Command), new_value: []f64, previous_value: []f64, user_data: rawptr) -> ^Vector64Command {
    cmd := new(Vector64Command)
    cmd.id = id
    cmd.execute = execute
    cmd.undo = undo
    cmd.new_value = new_value
    cmd.previous_value = previous_value
    cmd.user_data = user_data
    return cmd
}

createVectorIntCommand :: proc(id: uuid.Identifier, execute: proc(cmd: ^Command), undo: proc(cmd: ^Command), new_value: []int, previous_value: []int, user_data: rawptr) -> ^VectorIntCommand {
    cmd := new(VectorIntCommand)
    cmd.id = id
    cmd.execute = execute
    cmd.undo = undo
    cmd.new_value = new_value
    cmd.previous_value = previous_value
    cmd.user_data = user_data
    return cmd
}

createVectorUInt32Command :: proc(id: uuid.Identifier, execute: proc(cmd: ^Command), undo: proc(cmd: ^Command), new_value: []u32, previous_value: []u32, user_data: rawptr) -> ^VectorUInt32Command {
    cmd := new(VectorUInt32Command)
    cmd.id = id
    cmd.execute = execute
    cmd.undo = undo
    cmd.new_value = new_value
    cmd.previous_value = previous_value
    cmd.user_data = user_data
    return cmd
}

createVectorUInt64Command :: proc(id: uuid.Identifier, execute: proc(cmd: ^Command), undo: proc(cmd: ^Command), new_value: []u64, previous_value: []u64, user_data: rawptr) -> ^VectorUInt64Command {
    cmd := new(VectorUInt64Command)
    cmd.id = id
    cmd.execute = execute
    cmd.undo = undo
    cmd.new_value = new_value
    cmd.previous_value = previous_value
    cmd.user_data = user_data
    return cmd
}

