package odinworks

// Summary: Coefficient data for sr reduce.
ow_sr_reduce_coeffs :: struct {
	ratio: f32,
}

// Summary: Runtime state for sr reduce.
ow_sr_reduce_state :: struct {
	phase: f32,
	y_z1: f32,
}

// Summary: Initializes sr reduce.
ow_sr_reduce_init :: proc(coeffs: ^ow_sr_reduce_coeffs) {
	OW_ASSERT(coeffs != nil)
	coeffs.ratio = 1.0
}

// Summary: Sets sample rate for sr reduce.
ow_sr_reduce_set_sample_rate :: proc(coeffs: ^ow_sr_reduce_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	_ = sample_rate
}

// Summary: Resets coefficients for sr reduce.
ow_sr_reduce_reset_coeffs :: proc(coeffs: ^ow_sr_reduce_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Resets state for sr reduce.
ow_sr_reduce_reset_state :: proc(coeffs: ^ow_sr_reduce_coeffs, state: ^ow_sr_reduce_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	state.y_z1 = x_0
	state.phase = 1.0
	return x_0
}

// Summary: Resets multi-channel state for sr reduce.
ow_sr_reduce_reset_state_multi :: proc(coeffs: ^ow_sr_reduce_coeffs, state: ^^ow_sr_reduce_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_sr_reduce_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_sr_reduce_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for sr reduce.
ow_sr_reduce_update_coeffs_ctrl :: proc(coeffs: ^ow_sr_reduce_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Updates audio-rate coefficients for sr reduce.
ow_sr_reduce_update_coeffs_audio :: proc(coeffs: ^ow_sr_reduce_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Processes one sample for sr reduce.
ow_sr_reduce_process1 :: proc(coeffs: ^ow_sr_reduce_coeffs, state: ^ow_sr_reduce_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	state.phase += coeffs.ratio
	if state.phase >= 1.0 {
		state.y_z1 = x
		state.phase -= ow_floorf(state.phase)
	}
	return state.y_z1
}

// Summary: Processes sample buffers for sr reduce.
ow_sr_reduce_process :: proc(coeffs: ^ow_sr_reduce_coeffs, state: ^ow_sr_reduce_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	for i := 0; i < n_samples; i += 1 {
		ym[i] = ow_sr_reduce_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for sr reduce.
ow_sr_reduce_process_multi :: proc(coeffs: ^ow_sr_reduce_coeffs, state: ^^ow_sr_reduce_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_sr_reduce_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	for ch := 0; ch < n_channels; ch += 1 {
		ow_sr_reduce_process(coeffs, states[ch], xm[ch], ym[ch], n_samples)
	}
}

// Summary: Sets ratio for sr reduce.
ow_sr_reduce_set_ratio :: proc(coeffs: ^ow_sr_reduce_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	OW_ASSERT(value >= 0.0 && value <= 1.0)
	coeffs.ratio = value
}

// Summary: Checks validity of sr reduce coeffs.
ow_sr_reduce_coeffs_is_valid :: proc(coeffs: ^ow_sr_reduce_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.ratio) || coeffs.ratio < 0.0 || coeffs.ratio > 1.0 {
		return 0
	}
	return 1
}

// Summary: Checks validity of sr reduce state.
ow_sr_reduce_state_is_valid :: proc(coeffs: ^ow_sr_reduce_coeffs, state: ^ow_sr_reduce_state) -> i8 {
	if state == nil {
		return 0
	}
	_ = coeffs
	if !ow_is_finite(state.phase) || state.phase < 0.0 {
		return 0
	}
	if !ow_is_finite(state.y_z1) {
		return 0
	}
	return 1
}
