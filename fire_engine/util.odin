package fire_engine

import "core:math"
import "core:fmt"


logToNormal_f32 :: proc(value: f32, min: f32, max: f32) -> f32 {
    // Convert a logarithmic value to a normalized 0-1 range
  
    return math.log(value / min, math.E) / math.log(max / min, math.E)
}

normalToLog_f32 :: proc(normalized_value: f32, min: f32, max: f32) -> f32 {
    return min * math.pow_f32(max / min, normalized_value)
}

frequencyToNormal :: proc(frequency: f32, min: f32 = 20.0, max: f32 = 20000.0) -> f32 {
    return logToNormal_f32(frequency, min, max)
}

normalToFrequency :: proc(normalized_value: f32, min: f32 = 20.0, max: f32 = 20000.0) -> f32 {
    return normalToLog_f32(normalized_value, min, max)
}

midiToNormal :: proc(midi_value: u8) -> f32 {
    return f32(midi_value) / 127.0
}

timeMsToNormal :: proc(time_ms: f32, min_time: f32 = 0.0, max_time: f32 = 10000.0) -> f32 {
    return logToNormal_f32(time_ms, min_time, max_time)
}

normalToTimeMs :: proc(normalized_value: f32, min_time: f32 = 0.0, max_time: f32 = 10000.0) -> f32 {
    return normalToLog_f32(normalized_value, min_time, max_time)
}


timeSecToNormal :: proc(time_sec: f32, min_time: f32 = 0.0, max_time: f32 = 20.0) -> f32 {
    return logToNormal_f32(time_sec, min_time, max_time)
}

normalToTimeSec :: proc(normalized_value: f32, min_time: f32 = 0.0, max_time: f32 = 20.0) -> f32 {
    return normalToLog_f32(normalized_value, min_time, max_time)
}
normalize :: proc(value: $T, min: T, max: T) -> T {
    return (value - min) / (max - min)
}
normalize_f32 :: proc(value: f32, min: f32, max: f32) -> f32 {
    return (value - min) / (max - min)
}

denormalize_f32 :: proc(normalized_value: f32, min: f32, max: f32) -> f32 {
    return normalized_value * (max - min) + min
}

formatFrequency :: proc(frequency: f32) -> string {
    if frequency >= 1000.0 {
        return fmt.tprintf("%.2f kHz", frequency / 1000.0)
    } else {
        return fmt.tprintf("%.2f Hz", frequency)
    }
}

formatDecibels :: proc(db: f32) -> string {
    return fmt.tprintf("%.2f dB", db)
}

formatTime :: proc(time_sec: f32) -> string {
    if time_sec >= 1.0 {
        return fmt.tprintf("%.2f s", time_sec)
    } else {
        return fmt.tprintf("%.2f ms", time_sec * 1000.0)
    }
}


dBToLinear_f32 :: proc(db: f32) -> f32 {
    return math.pow_f32(10.0, db / 20.0)
}

linearToDB_f32 :: proc(linearValue: f32) -> f32 {
    if linearValue <= 0.00001 {
        return -100.0
    }
    return 20.0 * math.log(linearValue, 10.0)
}

midiNoteToFrequency :: proc(midi_note: $T) -> T {
    
	return MIDI_FREQ_A4 * math.pow(2.0, (midi_note-MIDI_NOTE_A4)/12.0)
}

rateFromBaseNote :: proc(base_note: i32, target_note: i32) -> f32 {
    return math.pow_f32(2.0, (f32(target_note) - f32(base_note)) / 12.0)
}

detuneRateByCents :: proc(rate: f32, cents: f32) -> f32 {
    return rate * math.pow_f32(2.0, cents / 1200.0)
}

applyBasicPanning :: proc(sample: ^[2]f32, pan: f32) {
    t := (pan + 1.0) * 0.5
    left_gain := math.cos(f64(t) * math.PI / 2.0)
    right_gain := math.sin(f64(t) * math.PI / 2.0)
    sample[0] *= auto_cast left_gain
    sample[1] *= auto_cast right_gain
}

applyBasicGain :: proc(sample: ^[2]f32, gain: f32) {
    sample[0] *= auto_cast gain
    sample[1] *= auto_cast gain
}