package odinworks

OW_SLEW_LIM_PRACTICAL_INFINITY: f32 : 1.0e30

// Summary: Coefficient data for slew lim.
ow_slew_lim_coeffs :: struct {
	T: f32,
	max_inc: f32,
	max_dec: f32,
	max_rate_up: f32,
	max_rate_down: f32,
}

// Summary: Runtime state for slew lim.
ow_slew_lim_state :: struct {
	y_z1: f32,
}

// Summary: Initializes slew lim.
ow_slew_lim_init :: proc(coeffs: ^ow_slew_lim_coeffs) {
	OW_ASSERT(coeffs != nil)
	coeffs.max_rate_up = OW_SLEW_LIM_PRACTICAL_INFINITY
	coeffs.max_rate_down = OW_SLEW_LIM_PRACTICAL_INFINITY
}

// Summary: Sets sample rate for slew lim.
ow_slew_lim_set_sample_rate :: proc(coeffs: ^ow_slew_lim_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	coeffs.T = 1.0 / sample_rate
}

// Summary: Updates control-rate coefficients for slew lim do.
ow_slew_lim_do_update_coeffs_ctrl :: proc(coeffs: ^ow_slew_lim_coeffs) {
	coeffs.max_inc = coeffs.T * coeffs.max_rate_up
	coeffs.max_dec = coeffs.T * coeffs.max_rate_down
}

// Summary: Resets coefficients for slew lim.
ow_slew_lim_reset_coeffs :: proc(coeffs: ^ow_slew_lim_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_slew_lim_do_update_coeffs_ctrl(coeffs)
}

// Summary: Resets state for slew lim.
ow_slew_lim_reset_state :: proc(coeffs: ^ow_slew_lim_coeffs, state: ^ow_slew_lim_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	state.y_z1 = x_0
	return x_0
}

// Summary: Resets multi-channel state for slew lim.
ow_slew_lim_reset_state_multi :: proc(coeffs: ^ow_slew_lim_coeffs, state: ^^ow_slew_lim_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_slew_lim_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_slew_lim_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for slew lim.
ow_slew_lim_update_coeffs_ctrl :: proc(coeffs: ^ow_slew_lim_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_slew_lim_do_update_coeffs_ctrl(coeffs)
}

// Summary: Updates audio-rate coefficients for slew lim.
ow_slew_lim_update_coeffs_audio :: proc(coeffs: ^ow_slew_lim_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Processes one sample for slew lim.
ow_slew_lim_process1 :: proc(coeffs: ^ow_slew_lim_coeffs, state: ^ow_slew_lim_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	y := ow_clipf(x, state.y_z1-coeffs.max_dec, state.y_z1+coeffs.max_inc)
	state.y_z1 = y
	return y
}

// Summary: Executes slew lim process1 up.
ow_slew_lim_process1_up :: proc(coeffs: ^ow_slew_lim_coeffs, state: ^ow_slew_lim_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	y := ow_minf(x, state.y_z1+coeffs.max_inc)
	state.y_z1 = y
	return y
}

// Summary: Executes slew lim process1 down.
ow_slew_lim_process1_down :: proc(coeffs: ^ow_slew_lim_coeffs, state: ^ow_slew_lim_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	y := ow_maxf(x, state.y_z1-coeffs.max_dec)
	state.y_z1 = y
	return y
}

// Summary: Executes slew lim process1 none.
ow_slew_lim_process1_none :: proc(coeffs: ^ow_slew_lim_coeffs, state: ^ow_slew_lim_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	state.y_z1 = x
	return x
}

// Summary: Processes sample buffers for slew lim.
ow_slew_lim_process :: proc(coeffs: ^ow_slew_lim_coeffs, state: ^ow_slew_lim_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	xm := ([^]f32)(x)
	ym: [^]f32
	if y != nil {
		ym = ([^]f32)(y)
	}
	ow_slew_lim_update_coeffs_ctrl(coeffs)
	up_finite := ow_is_finite(coeffs.max_rate_up) && coeffs.max_rate_up < OW_SLEW_LIM_PRACTICAL_INFINITY
	down_finite := ow_is_finite(coeffs.max_rate_down) && coeffs.max_rate_down < OW_SLEW_LIM_PRACTICAL_INFINITY

	if y != nil {
		if up_finite {
			if down_finite {
				for i := 0; i < n_samples; i += 1 {
					ym[i] = ow_slew_lim_process1(coeffs, state, xm[i])
				}
			} else {
				for i := 0; i < n_samples; i += 1 {
					ym[i] = ow_slew_lim_process1_up(coeffs, state, xm[i])
				}
			}
		} else {
			if down_finite {
				for i := 0; i < n_samples; i += 1 {
					ym[i] = ow_slew_lim_process1_down(coeffs, state, xm[i])
				}
			} else {
				for i := 0; i < n_samples; i += 1 {
					ym[i] = xm[i]
				}
				if n_samples > 0 {
					state.y_z1 = xm[n_samples-1]
				}
			}
		}
	} else {
		if up_finite {
			if down_finite {
				for i := 0; i < n_samples; i += 1 {
					_ = ow_slew_lim_process1(coeffs, state, xm[i])
				}
			} else {
				for i := 0; i < n_samples; i += 1 {
					_ = ow_slew_lim_process1_up(coeffs, state, xm[i])
				}
			}
		} else {
			if down_finite {
				for i := 0; i < n_samples; i += 1 {
					_ = ow_slew_lim_process1_down(coeffs, state, xm[i])
				}
			} else if n_samples > 0 {
				state.y_z1 = xm[n_samples-1]
			}
		}
	}
}

// Summary: Processes multiple channels for slew lim.
ow_slew_lim_process_multi :: proc(coeffs: ^ow_slew_lim_coeffs, state: ^^ow_slew_lim_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	states := ([^]^ow_slew_lim_state)(state)
	xm := ([^][^]f32)(x)
	ym: [^][^]f32
	if y != nil {
		ym = ([^][^]f32)(y)
	}
	ow_slew_lim_update_coeffs_ctrl(coeffs)
	for ch := 0; ch < n_channels; ch += 1 {
		y_ch: ^f32
		if y != nil {
			y_ch = ym[ch]
		}
		ow_slew_lim_process(coeffs, states[ch], xm[ch], y_ch, n_samples)
	}
}

// Summary: Sets max rate for slew lim.
ow_slew_lim_set_max_rate :: proc(coeffs: ^ow_slew_lim_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value) && value >= 0.0)
	ow_slew_lim_set_max_rate_up(coeffs, value)
	ow_slew_lim_set_max_rate_down(coeffs, value)
}

// Summary: Sets max rate up for slew lim.
ow_slew_lim_set_max_rate_up :: proc(coeffs: ^ow_slew_lim_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value) && value >= 0.0)
	coeffs.max_rate_up = value
}

// Summary: Sets max rate down for slew lim.
ow_slew_lim_set_max_rate_down :: proc(coeffs: ^ow_slew_lim_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value) && value >= 0.0)
	coeffs.max_rate_down = value
}

// Summary: Gets y z1 from slew lim.
ow_slew_lim_get_y_z1 :: proc(state: ^ow_slew_lim_state) -> f32 {
	OW_ASSERT(state != nil)
	return state.y_z1
}

// Summary: Checks validity of slew lim coeffs.
ow_slew_lim_coeffs_is_valid :: proc(coeffs: ^ow_slew_lim_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if ow_is_nan(coeffs.max_rate_up) || coeffs.max_rate_up < 0.0 {
		return 0
	}
	if ow_is_nan(coeffs.max_rate_down) || coeffs.max_rate_down < 0.0 {
		return 0
	}
	return 1
}

// Summary: Checks validity of slew lim state.
ow_slew_lim_state_is_valid :: proc(coeffs: ^ow_slew_lim_coeffs, state: ^ow_slew_lim_state) -> i8 {
	if state == nil {
		return 0
	}
	_ = coeffs
	if !ow_is_finite(state.y_z1) {
		return 0
	}
	return 1
}
