package fire_engine


SynthInstrument :: struct {
    using instrument: Instrument,
    file: string,
}

createSynthInstrument :: proc(fe: ^FireEngine, name: string) -> ^SynthInstrument {
    new_ins := new(SynthInstrument)
    configureInstrument(fe, &new_ins.instrument, name, InstrumentType.Synth)
    return new_ins
}