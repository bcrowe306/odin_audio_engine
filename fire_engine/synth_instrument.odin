package fire_engine


SynthInstrument :: struct {
    using instrument: Instrument,
    file: string,
}

createSynthInstrument :: proc(name: string) -> ^SynthInstrument {
    new_ins := new(SynthInstrument)
    configureInstrument(&new_ins.instrument, name, InstrumentType.Synth)
    return new_ins
}