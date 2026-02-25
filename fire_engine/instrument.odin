package fire_engine

import "core:encoding/uuid"
import "core:crypto"


InstrumentType :: enum {
    Sampler,
    Synth,
}

Instrument :: struct {
    id: uuid.Identifier,
    type: InstrumentType,
    name: string,
    parameters: []^Parameter,
}

configureInstrument :: proc(device: ^Instrument, name: string, type: InstrumentType) {
    context.random_generator = crypto.random_generator()
    device.id = uuid.generate_v4()
    device.name = name
    device.type = type
}