package fire_engine

import "core:encoding/uuid"
import "core:crypto"

// TODO: Build out default node graph structure for tracks
// TODO: Complete midi routing. Need to route midi to tracks and tracks to instruments. 
// TODO: Could arm track on selection and insure track is selected on pad press before sending midi messages to the track's instrument. This will likely require a more robust node graph structure for tracks and instruments, as well as a way to route midi messages to specific tracks and instruments.
// This will likely require a more robust node graph structure for tracks and instruments, as well as a way to route midi messages to specific tracks and instruments.

TrackType :: enum {
    Audio,
    Midi,
    Instrument,
}

Track :: struct {
    id: uuid.Identifier,
    name: string,
    type: TrackType,
    parameters: []^Parameter,
    device: ^Instrument,
    volume: ^Float32Parameter,
    pan: ^Float32Parameter,
    mute: ^BoolParameter,
    solo: ^BoolParameter,
    arm: ^BoolParameter,
}


createTrack :: proc(fe: ^FireEngine, name: string, type: TrackType = TrackType.Instrument) -> ^Track {
    context.random_generator = crypto.random_generator()
    new_track := new(Track)
    new_track.id = uuid.generate_v4()
    new_track.name = name
    new_track.type = type
    new_track.volume = createFloatParameter(fe.command_controller, "Volume", 0.0, -60.0, 6.0)
    new_track.pan = createFloatParameter(fe.command_controller, "Pan", 0.0, -1.0, 1.0)
    new_track.mute = createBoolParameter(fe.command_controller, "Mute", false)
    new_track.solo = createBoolParameter(fe.command_controller, "Solo", false)
    new_track.arm = createBoolParameter(fe.command_controller, "Arm", false)
    new_track.parameters = []^Parameter{
        new_track.volume, 
        new_track.pan, 
        new_track.mute, 
        new_track.solo,
        new_track.arm,
    }
    return new_track
}