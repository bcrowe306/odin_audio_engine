package odinworks

// Summary: Coefficient data for sampler.
ow_sampler_coeffs :: struct {
	rate: f32,
}

// Summary: Runtime state for sampler.
ow_sampler_state :: struct {
	pos: f32,
	phase: ow_sampler_phase,
}

// Summary: Enumeration for sampler phase.
ow_sampler_phase :: enum {
	ow_sampler_phase_before,
	ow_sampler_phase_playing,
	ow_sampler_phase_done,
}

// Summary: Executes sampler interpolate.
ow_sampler_interpolate :: proc(sample: ^f32, sample_length: int, pos: f32) -> f32 {
	OW_ASSERT(sample != nil)
	OW_ASSERT(sample_length > 0)
	x := ([^]f32)(sample)
	xm1, x0, x1, x2, d: f32
	if pos >= 1.0 {
		p := int(pos)
		if p + 2 < sample_length {
			xm1 = x[p - 1]
			x0 = x[p]
			x1 = x[p + 1]
			x2 = x[p + 2]
		} else if p + 2 == sample_length {
			xm1 = x[p - 1]
			x0 = x[p]
			x1 = x[p + 1]
			x2 = 0.0
		} else if p + 1 == sample_length {
			xm1 = x[p - 1]
			x0 = x[p]
			x1 = 0.0
			x2 = 0.0
		} else if p == sample_length {
			xm1 = x[p - 1]
			x0 = 0.0
			x1 = 0.0
			x2 = 0.0
		} else {
			return 0.0
		}
		d = pos - f32(p)
	} else if pos >= 0.0 {
		xm1 = 0.0
		x0 = x[0]
		if sample_length > 1 {
			x1 = x[1]
			x2 = (sample_length > 2) ? x[2] : 0.0
		} else {
			x1 = 0.0
			x2 = 0.0
		}
		d = pos
	} else if pos >= -1.0 {
		xm1 = 0.0
		x0 = 0.0
		x1 = x[0]
		x2 = (sample_length > 1) ? x[1] : 0.0
		d = pos + 1.0
	} else if pos >= -2.0 {
		xm1 = 0.0
		x0 = 0.0
		x1 = 0.0
		x2 = x[0]
		d = pos + 2.0
	} else {
		return 0.0
	}

	return (d*((0.5-0.1666666666666667*d)*d-0.5)+0.1666666666666667)*xm1 +
		((0.5*d-1.0)*d*d+0.6666666666666666)*x0 +
		(d*((0.5-0.5*d)*d+0.5)+0.1666666666666667)*x1 +
		0.1666666666666667*d*d*d*x2
}

// Summary: Initializes sampler.
ow_sampler_init :: proc(coeffs: ^ow_sampler_coeffs) {
	OW_ASSERT(coeffs != nil)
	coeffs.rate = 1.0
}

// Summary: Sets sample rate for sampler.
ow_sampler_set_sample_rate :: proc(coeffs: ^ow_sampler_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	_ = sample_rate
}

// Summary: Resets coefficients for sampler.
ow_sampler_reset_coeffs :: proc(coeffs: ^ow_sampler_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Resets state for sampler.
ow_sampler_reset_state :: proc(coeffs: ^ow_sampler_coeffs, state: ^ow_sampler_state, sample: ^f32, sample_length: int, pos_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(sample != nil)
	OW_ASSERT(sample_length > 0)
	OW_ASSERT(ow_is_finite(pos_0) && pos_0 >= 0.0)
	_ = coeffs
	state.pos = pos_0
	state.phase = .ow_sampler_phase_before
	return ow_sampler_interpolate(sample, sample_length, pos_0)
}

// Summary: Resets multi-channel state for sampler.
ow_sampler_reset_state_multi :: proc(coeffs: ^ow_sampler_coeffs, state: ^^ow_sampler_state, sample: ^^f32, sample_length: ^int, pos_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(sample != nil)
	OW_ASSERT(sample_length != nil)
	OW_ASSERT(pos_0 != nil)
	states := ([^]^ow_sampler_state)(state)
	samples := ([^][^]f32)(sample)
	lengths := ([^]int)(sample_length)
	pos0 := ([^]f32)(pos_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for ch := 0; ch < n_channels; ch += 1 {
		v := ow_sampler_reset_state(coeffs, states[ch], samples[ch], lengths[ch], pos0[ch])
		if y_0 != nil {
			y0[ch] = v
		}
	}
}

// Summary: Updates control-rate coefficients for sampler.
ow_sampler_update_coeffs_ctrl :: proc(coeffs: ^ow_sampler_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Updates audio-rate coefficients for sampler.
ow_sampler_update_coeffs_audio :: proc(coeffs: ^ow_sampler_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Processes one sample for sampler.
ow_sampler_process1 :: proc(coeffs: ^ow_sampler_coeffs, state: ^ow_sampler_state, sample: ^f32, sample_length: int) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(sample != nil)
	OW_ASSERT(sample_length > 0)
	y: f32
	if state.pos <= f32(sample_length)+2.0 {
		y = ow_sampler_interpolate(sample, sample_length, state.pos)
		state.pos += coeffs.rate
		state.phase = .ow_sampler_phase_playing
	} else {
		y = 0.0
		state.phase = .ow_sampler_phase_done
	}
	return y
}

// Summary: Processes sample buffers for sampler.
ow_sampler_process :: proc(coeffs: ^ow_sampler_coeffs, state: ^ow_sampler_state, sample: ^f32, sample_length: int, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(sample != nil)
	OW_ASSERT(sample_length > 0)
	OW_ASSERT(y != nil)
	ym := ([^]f32)(y)
	for i := 0; i < n_samples; i += 1 {
		ym[i] = ow_sampler_process1(coeffs, state, sample, sample_length)
	}
}

// Summary: Processes multiple channels for sampler.
ow_sampler_process_multi :: proc(coeffs: ^ow_sampler_coeffs, state: ^^ow_sampler_state, sample: ^^f32, sample_length: ^int, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(sample != nil)
	OW_ASSERT(sample_length != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_sampler_state)(state)
	samples := ([^][^]f32)(sample)
	lengths := ([^]int)(sample_length)
	ym := ([^][^]f32)(y)
	for ch := 0; ch < n_channels; ch += 1 {
		for i := 0; i < n_samples; i += 1 {
			ym[ch][i] = ow_sampler_process1(coeffs, states[ch], samples[ch], lengths[ch])
		}
	}
}

// Summary: Sets rate for sampler.
ow_sampler_set_rate :: proc(coeffs: ^ow_sampler_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0)
	coeffs.rate = value
}

// Summary: Gets phase from sampler.
ow_sampler_get_phase :: proc(state: ^ow_sampler_state) -> ow_sampler_phase {
	OW_ASSERT(state != nil)
	return state.phase
}

// Summary: Checks validity of sampler coeffs.
ow_sampler_coeffs_is_valid :: proc(coeffs: ^ow_sampler_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.rate) || coeffs.rate < 0.0 {
		return 0
	}
	return 1
}

// Summary: Checks validity of sampler state.
ow_sampler_state_is_valid :: proc(coeffs: ^ow_sampler_coeffs, state: ^ow_sampler_state) -> i8 {
	if state == nil {
		return 0
	}
	_ = coeffs
	if !ow_is_finite(state.pos) || state.pos < 0.0 {
		return 0
	}
	if state.phase < .ow_sampler_phase_before || state.phase > .ow_sampler_phase_done {
		return 0
	}
	return 1
}
