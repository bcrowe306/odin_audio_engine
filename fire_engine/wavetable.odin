package fire_engine
import "core:math"
import "core:math/rand"
import "core:crypto"

WAVETABLE_SIZE :: 2048

WaveTableType :: enum {
    Sine,
    Square,
    Saw,
    Triangle,
    ReverseSaw,
    Noise,
}

WaveTable :: struct {
    samples: [WAVETABLE_SIZE]f32,
    type: WaveTableType,
    sample_rate: u32,
}


generateWaveTable :: proc(type: WaveTableType, sample_rate: u32) -> WaveTable {
    table := WaveTable{type = type, sample_rate = sample_rate}
    for i in 0..<WAVETABLE_SIZE {
        phase := f32(i) / f32(WAVETABLE_SIZE)
        switch type {
            case .Sine:
                table.samples[i] = math.sin(2.0 * math.PI * phase)
            case .Square:
                if phase < 0.5 { 
                    table.samples[i] = 1.0
                } else {
                    table.samples[i] = -1.0
                }
            case .Saw:
                table.samples[i] = 2.0 * phase - 1.0
            case .Triangle:
                if phase < 0.5 { 
                    table.samples[i] = 4.0 * phase - 1.0
                } else {
                    table.samples[i] = 3.0 - 4.0 * phase
                }
            case .ReverseSaw:
                table.samples[i] = 1.0 - 2.0 * phase
            case .Noise:
                context.random_generator = crypto.random_generator()
                table.samples[i] = clamp(rand.float32(), -1.0, 1.0)
        }
    }
    return table
}

WaveTables :: struct {
    sine: WaveTable,
    square: WaveTable,
    saw: WaveTable,
    triangle: WaveTable,
    reverse_saw: WaveTable,
    noise: WaveTable,

    type: WaveTableType,
    cursor: f32,
    rate: f32,

    // Methods

    // retrieves the sample at the specified position in the wavetable, where position is an integer index between 0 and WAVETABLE_SIZE-1. If the position is out of bounds, it should return 0 or some default value.
    get: proc(wt: ^WaveTables, position: i32) -> f32,

    // reads the sample at the internal cursor position without advancing the cursor
    read: proc(wt: ^WaveTables) -> f32,

    // reads the sample at the internal cursor position and advances by rate, wrapping around at the end of the table
    // rate is interpreted as frequency in Hz (1.0 = 1 cycle/second)
    // if override_rate_hz >= 0, it is used (in Hz) for this read/advance call only
    readAdvance : proc(wt: ^WaveTables, override_rate_hz: f32 = -1) -> f32,

    // resets the internal cursor to the beginning of the table
    reset: proc(wt: ^WaveTables),

    // Interpolates the sample at the given cursor position, which can be a fractional value between 0 and WAVETABLE_SIZE-1. The integer part of the cursor is used to determine the two samples to interpolate between, and the fractional part is used as the interpolation factor.
    interpolate: proc(wt: ^WaveTables, cursor: f32) -> f32,

    // Set the cursor position to a specific value, allowing for non-linear traversal of the wavetable
    setCursor: proc(wt: ^WaveTables, position: f32),

    // Set/read oscillator frequency in Hz used when advancing cursor in readAdvance
    setRate: proc(wt: ^WaveTables, rate: f32),
    setRateFromMidiNote: proc(wt: ^WaveTables, midi_note: f32) -> f32,
    getMidiNoteFromRate: proc(wt: ^WaveTables, rate_hz: f32 = -1) -> f32,
    getRate: proc(wt: ^WaveTables) -> f32,

}

createWaveTables :: proc(sample_rate: u32, type: WaveTableType = .Sine, rate: f32 = 220.0) -> WaveTables {
    return WaveTables{
        sine = generateWaveTable(.Sine, sample_rate),
        square = generateWaveTable(.Square, sample_rate),
        saw = generateWaveTable(.Saw, sample_rate),
        triangle = generateWaveTable(.Triangle, sample_rate),
        reverse_saw = generateWaveTable(.ReverseSaw, sample_rate),
        noise = generateWaveTable(.Noise, sample_rate),
            type = type,
            cursor = 0,
            rate = rate,
            get = waveTableGet,
            read = waveTablesRead,
            readAdvance = waveTablesReadAdvance,
            reset = waveTablesReset,
            interpolate = waveTablesInterpolate,
            setCursor = waveTablesSetCursor,
            setRate = waveTablesSetRate,
            setRateFromMidiNote = waveTablesSetRateFromMidiNote,
            getMidiNoteFromRate = waveTablesGetMidiNoteFromRate,
            getRate = waveTablesGetRate,
    }
}

waveTableGet :: proc(wt: ^WaveTables, position: i32) -> f32 {
    if position < 0 || position >= WAVETABLE_SIZE {
        return 0.0
    }
    switch wt.type {
        case .Sine:
            return wt.sine.samples[position]
        case .Square:
            return wt.square.samples[position]
        case .Saw:
            return wt.saw.samples[position]
        case .Triangle:
            return wt.triangle.samples[position]
        case .ReverseSaw:
            return wt.reverse_saw.samples[position]
        case .Noise:
            return wt.noise.samples[position]
    }
    return 0.0
}

waveTablesRead :: proc(wt: ^WaveTables) -> f32 {
    return waveTablesInterpolate(wt, wt.cursor)
}

waveTablesReadAdvance :: proc(wt: ^WaveTables, override_rate_hz: f32 = -1) -> f32 {
    value := waveTablesInterpolate(wt, wt.cursor)
    rate_hz := wt.rate
    if override_rate_hz >= 0 {
        rate_hz = override_rate_hz
    }
    step := waveTableStepFromHz(wt, rate_hz)
    wt.cursor = wrapWaveCursor(wt.cursor + step)
    return value
}

waveTablesReset :: proc(wt: ^WaveTables) {
    wt.cursor = 0
}

waveTablesInterpolate :: proc(wt: ^WaveTables, cursor: f32) -> f32 {
    wrapped_cursor := wrapWaveCursor(cursor)
    int_pos := i32(math.floor(f64(wrapped_cursor)))
    frac := wrapped_cursor - f32(int_pos)
    next_pos := (int_pos + 1) % WAVETABLE_SIZE

    sample1 := waveTableGet(wt, int_pos)
    sample2 := waveTableGet(wt, next_pos)

    return math.lerp(sample1, sample2, frac)

    // return sample1 * (1.0 - frac) + sample2 * frac
}

waveTablesSetCursor :: proc(wt: ^WaveTables, position: f32) {
    wt.cursor = wrapWaveCursor(position)
}

waveTablesSetRate :: proc(wt: ^WaveTables, rate: f32) {
    if rate < 0 {
        wt.rate = 0
        return
    }
    wt.rate = rate
}

waveTablesGetRate :: proc(wt: ^WaveTables) -> f32 {
    return wt.rate
}

waveTablesSetRateFromMidiNote :: proc(wt: ^WaveTables, midi_note: f32) -> f32 {
    hz := 440.0 * f32(math.pow(2.0, f64((midi_note-69.0)/12.0)))
    waveTablesSetRate(wt, hz)
    return wt.rate
}

waveTablesGetMidiNoteFromRate :: proc(wt: ^WaveTables, rate_hz: f32 = -1) -> f32 {
    hz := wt.rate
    if rate_hz >= 0 {
        hz = rate_hz
    }
    if hz <= 0 {
        return 0
    }
    return 69.0 + 12.0 * f32(math.log(f64(hz/440.0), 2.0))
}

wrapWaveCursor :: proc(cursor: f32) -> f32 {
    size := f32(WAVETABLE_SIZE)
    wrapped := math.mod_f32(cursor, size)
    if wrapped < 0 {
        wrapped += size
    }
    return wrapped
}

waveTableStepFromHz :: proc(wt: ^WaveTables, hz: f32) -> f32 {
    if hz <= 0 {
        return 0
    }
    sample_rate := f32(wt.sine.sample_rate)
    if sample_rate <= 0 {
        return 0
    }
    return hz * (f32(WAVETABLE_SIZE) / sample_rate)
}
