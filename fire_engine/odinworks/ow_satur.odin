package odinworks

// Summary: Coefficient data for satur.
ow_satur_coeffs :: struct {
	smooth_coeffs: ow_one_pole_coeffs,
	smooth_bias_state: ow_one_pole_state,
	smooth_gain_state: ow_one_pole_state,
	bias_dc: f32,
	inv_gain: f32,
	bias: f32,
	gain: f32,
	gain_compensation: bool,
}

// Summary: Runtime state for satur.
ow_satur_state :: struct {
	x_z1: f32,
	F_z1: f32,
}

// Summary: Executes satur tanhf.
ow_satur_tanhf :: proc(x: f32) -> f32 {
	xm := ow_clipf(x, -2.115287308554551, 2.115287308554551)
	axm := ow_absf(xm)
	return xm*axm*(0.01218073260037716*axm-0.2750231331124371) + xm
}

// Summary: Initializes satur.
ow_satur_init :: proc(coeffs: ^ow_satur_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_init(&coeffs.smooth_coeffs)
	ow_one_pole_set_tau(&coeffs.smooth_coeffs, 0.005)
	ow_one_pole_set_sticky_thresh(&coeffs.smooth_coeffs, 1.0e-3)
	coeffs.bias = 0.0
	coeffs.gain = 1.0
	coeffs.gain_compensation = false
}

// Summary: Sets sample rate for satur.
ow_satur_set_sample_rate :: proc(coeffs: ^ow_satur_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_one_pole_set_sample_rate(&coeffs.smooth_coeffs, sample_rate)
	ow_one_pole_reset_coeffs(&coeffs.smooth_coeffs)
}

// Summary: Executes satur do update coeffs.
ow_satur_do_update_coeffs :: proc(coeffs: ^ow_satur_coeffs, force: bool) {
	bias_cur := ow_one_pole_get_y_z1(&coeffs.smooth_bias_state)
	if force || coeffs.bias != bias_cur {
		bias_cur = ow_one_pole_process1_sticky_abs(&coeffs.smooth_coeffs, &coeffs.smooth_bias_state, coeffs.bias)
		coeffs.bias_dc = ow_satur_tanhf(bias_cur)
	}
	gain_cur := ow_one_pole_get_y_z1(&coeffs.smooth_gain_state)
	if force || coeffs.gain != gain_cur {
		gain_cur = ow_one_pole_process1_sticky_rel(&coeffs.smooth_coeffs, &coeffs.smooth_gain_state, coeffs.gain)
		coeffs.inv_gain = ow_rcpf(gain_cur)
	}
}

// Summary: Resets coefficients for satur.
ow_satur_reset_coeffs :: proc(coeffs: ^ow_satur_coeffs) {
	OW_ASSERT(coeffs != nil)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_bias_state, coeffs.bias)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_gain_state, coeffs.gain)
	ow_satur_do_update_coeffs(coeffs, true)
}

// Summary: Resets state for satur.
ow_satur_reset_state :: proc(coeffs: ^ow_satur_coeffs, state: ^ow_satur_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	x := ow_one_pole_get_y_z1(&coeffs.smooth_gain_state)*x_0 + ow_one_pole_get_y_z1(&coeffs.smooth_bias_state)
	ax := ow_absf(x)
	F := ax*ax*((0.00304518315009429*ax-0.09167437770414569)*ax + 0.5)
	if ax >= 2.115287308554551 {
		F = ax - 0.6847736211329452
	}
	yb := ow_satur_tanhf(x)
	y := yb - coeffs.bias_dc
	if coeffs.gain_compensation {
		y = coeffs.inv_gain * (yb - coeffs.bias_dc)
	}
	state.x_z1 = x
	state.F_z1 = F
	return y
}

// Summary: Resets multi-channel state for satur.
ow_satur_reset_state_multi :: proc(coeffs: ^ow_satur_coeffs, state: ^^ow_satur_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_satur_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_satur_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for satur.
ow_satur_update_coeffs_ctrl :: proc(coeffs: ^ow_satur_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Updates audio-rate coefficients for satur.
ow_satur_update_coeffs_audio :: proc(coeffs: ^ow_satur_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_satur_do_update_coeffs(coeffs, false)
}

// Summary: Processes one sample for satur.
ow_satur_process1 :: proc(coeffs: ^ow_satur_coeffs, state: ^ow_satur_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	xv := ow_one_pole_get_y_z1(&coeffs.smooth_gain_state)*x + ow_one_pole_get_y_z1(&coeffs.smooth_bias_state)
	ax := ow_absf(xv)
	F := ax*ax*((0.00304518315009429*ax-0.09167437770414569)*ax + 0.5)
	if ax >= 2.115287308554551 {
		F = ax - 0.6847736211329452
	}
	d := xv - state.x_z1
	yb: f32
	if d*d < 1.0e-6 {
		yb = ow_satur_tanhf(0.5 * (xv + state.x_z1))
	} else {
		yb = (F - state.F_z1) * ow_rcpf(d)
	}
	y := yb - coeffs.bias_dc
	state.x_z1 = xv
	state.F_z1 = F
	return y
}

// Summary: Executes satur process1 comp.
ow_satur_process1_comp :: proc(coeffs: ^ow_satur_coeffs, state: ^ow_satur_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	return coeffs.inv_gain * ow_satur_process1(coeffs, state, x)
}

// Summary: Processes sample buffers for satur.
ow_satur_process :: proc(coeffs: ^ow_satur_coeffs, state: ^ow_satur_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	if coeffs.gain_compensation {
		for i := 0; i < n_samples; i += 1 {
			ow_satur_update_coeffs_audio(coeffs)
			ym[i] = ow_satur_process1_comp(coeffs, state, xm[i])
		}
	} else {
		for i := 0; i < n_samples; i += 1 {
			ow_satur_update_coeffs_audio(coeffs)
			ym[i] = ow_satur_process1(coeffs, state, xm[i])
		}
	}
}

// Summary: Processes multiple channels for satur.
ow_satur_process_multi :: proc(coeffs: ^ow_satur_coeffs, state: ^^ow_satur_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_satur_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_satur_update_coeffs_ctrl(coeffs)
	if coeffs.gain_compensation {
		for i := 0; i < n_samples; i += 1 {
			ow_satur_update_coeffs_audio(coeffs)
			for ch := 0; ch < n_channels; ch += 1 {
				ym[ch][i] = ow_satur_process1_comp(coeffs, states[ch], xm[ch][i])
			}
		}
	} else {
		for i := 0; i < n_samples; i += 1 {
			ow_satur_update_coeffs_audio(coeffs)
			for ch := 0; ch < n_channels; ch += 1 {
				ym[ch][i] = ow_satur_process1(coeffs, states[ch], xm[ch][i])
			}
		}
	}
}

// Summary: Sets bias for satur.
ow_satur_set_bias :: proc(coeffs: ^ow_satur_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= -1.0e12 && value <= 1.0e12)
	coeffs.bias = value
}

// Summary: Sets gain for satur.
ow_satur_set_gain :: proc(coeffs: ^ow_satur_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-12 && value <= 1.0e12)
	coeffs.gain = value
}

// Summary: Sets gain compensation for satur.
ow_satur_set_gain_compensation :: proc(coeffs: ^ow_satur_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	coeffs.gain_compensation = value != 0
}

// Summary: Checks validity of satur coeffs.
ow_satur_coeffs_is_valid :: proc(coeffs: ^ow_satur_coeffs) -> i8 {
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

// Summary: Checks validity of satur state.
ow_satur_state_is_valid :: proc(coeffs: ^ow_satur_coeffs, state: ^ow_satur_state) -> i8 {
	_ = coeffs
	if state == nil {
		return 0
	}
	if !ow_is_finite(state.x_z1) || !ow_is_finite(state.F_z1) {
		return 0
	}
	return 1
}
