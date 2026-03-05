package fire_engine

import "core:encoding/uuid"
import "core:crypto"


InstrumentType :: enum {
    Sampler,
    Synth,
}

Instrument :: struct {
    fe: ^FireEngine,
    id: uuid.Identifier,
    type: InstrumentType,
    name: string,
    parameters: []^Parameter,
    output_node: ^LevelsNode,
}

configureInstrument :: proc(fe: ^FireEngine, device: ^Instrument, name: string, type: InstrumentType) {
    context.random_generator = crypto.random_generator()
    device.fe = fe
    device.id = uuid.generate_v4()
    device.name = name
    device.type = type
    device.output_node = new(LevelsNode)
}