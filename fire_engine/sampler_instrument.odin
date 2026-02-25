package fire_engine

// Build out sampler instrument.
// TODO: Voice struct
// TODO: Voice Allocator
// EnvGen
// LFO
// Filter
// Unison


SamplerInstrument :: struct {
    using instrument: Instrument,
    file: string,
}


createSamplerDevice :: proc(name: string) -> ^SamplerInstrument {
    new_device := new(SamplerInstrument)
    configureInstrument(&new_device.instrument, name, InstrumentType.Sampler)
    return new_device
}