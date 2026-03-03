package odinworks

// Summary: Coefficient data for clip.
ow_clip_coeffs :: struct {
	smooth_coeffs: ow_one_pole_coeffs,
	smooth_bias_state: ow_one_pole_state,
	smooth_gain_state: ow_one_pole_state,
	bias_dc: f32,
	inv_gain: f32,
	bias: f32,
	gain: f32,
	gain_compensation: bool,
}

// Summary: Runtime state for clip.
ow_clip_state :: struct {
	x_z1: f32,
	F_z1: f32,
}

// Summary: Initializes clip.
ow_clip_init :: proc(coeffs: ^ow_clip_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_init(&coeffs.smooth_coeffs)
	ow_one_pole_set_tau(&coeffs.smooth_coeffs, 0.005)
	ow_one_pole_set_sticky_thresh(&coeffs.smooth_coeffs, 1.0e-3)
	coeffs.bias = 0.0
	coeffs.gain = 1.0
	coeffs.gain_compensation = false
}

// Summary: Sets sample rate for clip.
ow_clip_set_sample_rate :: proc(coeffs: ^ow_clip_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_one_pole_set_sample_rate(&coeffs.smooth_coeffs, sample_rate)
	ow_one_pole_reset_coeffs(&coeffs.smooth_coeffs)
}

// Summary: Executes clip do update coeffs.
ow_clip_do_update_coeffs :: proc(coeffs: ^ow_clip_coeffs, force: bool) {
	bias_cur := ow_one_pole_get_y_z1(&coeffs.smooth_bias_state)
	if force || coeffs.bias != bias_cur {
		bias_cur = ow_one_pole_process1_sticky_abs(&coeffs.smooth_coeffs, &coeffs.smooth_bias_state, coeffs.bias)
		coeffs.bias_dc = ow_clipf(bias_cur, -1.0, 1.0)
	}
	gain_cur := ow_one_pole_get_y_z1(&coeffs.smooth_gain_state)
	if force || coeffs.gain != gain_cur {
		gain_cur = ow_one_pole_process1_sticky_rel(&coeffs.smooth_coeffs, &coeffs.smooth_gain_state, coeffs.gain)
		coeffs.inv_gain = ow_rcpf(gain_cur)
	}
}

// Summary: Resets coefficients for clip.
ow_clip_reset_coeffs :: proc(coeffs: ^ow_clip_coeffs) {
	OW_ASSERT(coeffs != nil)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_bias_state, coeffs.bias)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_gain_state, coeffs.gain)
	ow_clip_do_update_coeffs(coeffs, true)
}

// Summary: Resets state for clip.
ow_clip_reset_state :: proc(coeffs: ^ow_clip_coeffs, state: ^ow_clip_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	x := ow_one_pole_get_y_z1(&coeffs.smooth_gain_state)*x_0 + ow_one_pole_get_y_z1(&coeffs.smooth_bias_state)
	a := ow_absf(x)
	F := 0.5 * a * a
	if a > 1.0 {
		F = a - 0.5
	}
	yb := ow_clipf(x, -1.0, 1.0)
	y := (1.0) * (yb - coeffs.bias_dc)
	if coeffs.gain_compensation {
		y = coeffs.inv_gain * (yb - coeffs.bias_dc)
	}
	state.x_z1 = x
	state.F_z1 = F
	return y
}

// Summary: Resets multi-channel state for clip.
ow_clip_reset_state_multi :: proc(coeffs: ^ow_clip_coeffs, state: ^^ow_clip_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_clip_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_clip_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for clip.
ow_clip_update_coeffs_ctrl :: proc(coeffs: ^ow_clip_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Updates audio-rate coefficients for clip.
ow_clip_update_coeffs_audio :: proc(coeffs: ^ow_clip_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_clip_do_update_coeffs(coeffs, false)
}

// Summary: Processes one sample for clip.
ow_clip_process1 :: proc(coeffs: ^ow_clip_coeffs, state: ^ow_clip_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	xv := ow_one_pole_get_y_z1(&coeffs.smooth_gain_state)*x + ow_one_pole_get_y_z1(&coeffs.smooth_bias_state)
	a := ow_absf(xv)
	F := 0.5 * a * a
	if a > 1.0 {
		F = a - 0.5
	}
	d := xv - state.x_z1
	yb: f32
	if d*d < 1.0e-6 {
		yb = ow_clipf(0.5*(xv+state.x_z1), -1.0, 1.0)
	} else {
		yb = (F - state.F_z1) * ow_rcpf(d)
	}
	y := yb - coeffs.bias_dc
	state.x_z1 = xv
	state.F_z1 = F
	return y
}

// Summary: Executes clip process1 comp.
ow_clip_process1_comp :: proc(coeffs: ^ow_clip_coeffs, state: ^ow_clip_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	return coeffs.inv_gain * ow_clip_process1(coeffs, state, x)
}

// Summary: Processes sample buffers for clip.
ow_clip_process :: proc(coeffs: ^ow_clip_coeffs, state: ^ow_clip_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	if coeffs.gain_compensation {
		for i := 0; i < n_samples; i += 1 {
			ow_clip_update_coeffs_audio(coeffs)
			ym[i] = ow_clip_process1_comp(coeffs, state, xm[i])
		}
	} else {
		for i := 0; i < n_samples; i += 1 {
			ow_clip_update_coeffs_audio(coeffs)
			ym[i] = ow_clip_process1(coeffs, state, xm[i])
		}
	}
}

// Summary: Processes multiple channels for clip.
ow_clip_process_multi :: proc(coeffs: ^ow_clip_coeffs, state: ^^ow_clip_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_clip_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	if coeffs.gain_compensation {
		for i := 0; i < n_samples; i += 1 {
			ow_clip_update_coeffs_audio(coeffs)
			for ch := 0; ch < n_channels; ch += 1 {
				ym[ch][i] = ow_clip_process1_comp(coeffs, states[ch], xm[ch][i])
			}
		}
	} else {
		for i := 0; i < n_samples; i += 1 {
			ow_clip_update_coeffs_audio(coeffs)
			for ch := 0; ch < n_channels; ch += 1 {
				ym[ch][i] = ow_clip_process1(coeffs, states[ch], xm[ch][i])
			}
		}
	}
}

// Summary: Sets bias for clip.
ow_clip_set_bias :: proc(coeffs: ^ow_clip_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= -1.0e12 && value <= 1.0e12)
	coeffs.bias = value
}

// Summary: Sets gain for clip.
ow_clip_set_gain :: proc(coeffs: ^ow_clip_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-12 && value <= 1.0e12)
	coeffs.gain = value
}

// Summary: Sets gain compensation for clip.
ow_clip_set_gain_compensation :: proc(coeffs: ^ow_clip_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	coeffs.gain_compensation = value != 0
}

// Summary: Checks validity of clip coeffs.
ow_clip_coeffs_is_valid :: proc(coeffs: ^ow_clip_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.bias) || coeffs.bias < -1.0e12 || coeffs.bias > 1.0e12 {
		return 0
	}
	if !ow_is_finite(coeffs.gain) || coeffs.gain < 1.0e-12 || coeffs.gain > 1.0e12 {
		return 0
	}
	if !ow_one_pole_coeffs_is_valid(&coeffs.smooth_coeffs) {
		return 0
	}
	return 1
}

// Summary: Checks validity of clip state.
ow_clip_state_is_valid :: proc(coeffs: ^ow_clip_coeffs, state: ^ow_clip_state) -> i8 {
	_ = coeffs
	if state == nil {
		return 0
	}
	if !ow_is_finite(state.x_z1) || !ow_is_finite(state.F_z1) {
		return 0
	}
	return 1
}
