package main

FloatParam :: struct {
    value: f64,
    min: f64,
    max: f64,
    step: f64,
    small_step: f64,
    large_step: f64,
    default_value: f64,
    name: string,
    setValue: proc(p: ^FloatParam, newValue: f64),
    increment: proc(p: ^FloatParam),
    decrement: proc(p: ^FloatParam),
    getLinearValue: proc(p: ^FloatParam) -> f64,
    getValue : proc(p: ^FloatParam) -> f64,
    getLogValue : proc(p: ^FloatParam) -> f64,
    _internalMin: f64,
    _internalMax: f64,

}

floatParamSetValue :: proc(p: ^FloatParam, newValue: f64) {
    if newValue < p.min {
        p.value = p.min
    } else if newValue > p.max {
        p.value = p.max
    } else {
        p.value = newValue
    }
}

AudioParam :: struct {
    value: f64,
    target: f64,
    min: f64,
    max: f64,
    default_value: f64,
    ramp_remaining: u64,
    ramp_step: f64,
}

audioParamInit :: proc(min: f64, max: f64, default_value: f64) -> AudioParam {
    value := clampParamValue(default_value, min, max)
    return AudioParam{
        value = value,
        target = value,
        min = min,
        max = max,
        default_value = value,
    }
}

audioParamResetDefault :: proc(p: ^AudioParam) {
    audioParamSetImmediate(p, p.default_value)
}

audioParamSetImmediate :: proc(p: ^AudioParam, newValue: f64) {
    value := clampParamValue(newValue, p.min, p.max)
    p.value = value
    p.target = value
    p.ramp_remaining = 0
    p.ramp_step = 0
}

audioParamSetRampSamples :: proc(p: ^AudioParam, newValue: f64, rampSamples: u64) {
    target := clampParamValue(newValue, p.min, p.max)
    if rampSamples == 0 {
        audioParamSetImmediate(p, target)
        return
    }
    p.target = target
    p.ramp_remaining = rampSamples
    p.ramp_step = (p.target - p.value) / f64(rampSamples)
}

audioParamSetRampSeconds :: proc(p: ^AudioParam, newValue: f64, seconds: f64, sampleRate: f64) {
    if seconds <= 0 {
        audioParamSetImmediate(p, newValue)
        return
    }
    rampSamples := u64(seconds * sampleRate)
    audioParamSetRampSamples(p, newValue, rampSamples)
}

audioParamNextValue :: proc(p: ^AudioParam) -> f64 {
    if p.ramp_remaining > 0 {
        p.value += p.ramp_step
        p.ramp_remaining -= 1
        if p.ramp_remaining == 0 {
            p.value = p.target
        }
    }
    return p.value
}

audioParamFillBlock :: proc(p: ^AudioParam, dst: []f64) {
    for i in 0..<len(dst) {
        dst[i] = audioParamNextValue(p)
    }
}

clampParamValue :: proc(value: f64, min: f64, max: f64) -> f64 {
    if value < min {
        return min
    } else if value > max {
        return max
    }
    return value
}