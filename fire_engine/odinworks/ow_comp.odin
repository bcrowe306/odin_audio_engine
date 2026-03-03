package odinworks

import "core:math"

// Summary: Coefficient data for comp.
ow_comp_coeffs :: struct {
	env_follow_coeffs: ow_env_follow_coeffs,
	gain_coeffs: ow_gain_coeffs,
	smooth_coeffs: ow_one_pole_coeffs,
	smooth_thresh_state: ow_one_pole_state,
	smooth_ratio_state: ow_one_pole_state,
	kc: f32,
	lt: f32,
	thresh: f32,
	ratio: f32,
}

// Summary: Runtime state for comp.
ow_comp_state :: struct {
	env_follow_state: ow_env_follow_state,
}

// Summary: Updates audio-rate coefficients for comp do.
ow_comp_do_update_coeffs_audio :: proc(coeffs: ^ow_comp_coeffs) {
	ow_env_follow_update_coeffs_audio(&coeffs.env_follow_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.gain_coeffs)
	_ = ow_one_pole_process1(&coeffs.smooth_coeffs, &coeffs.smooth_thresh_state, coeffs.thresh)
	coeffs.kc = 1.0 - ow_one_pole_process1(&coeffs.smooth_coeffs, &coeffs.smooth_ratio_state, coeffs.ratio)
	coeffs.lt = math.log2(ow_one_pole_get_y_z1(&coeffs.smooth_thresh_state))
}

// Summary: Initializes comp.
ow_comp_init :: proc(coeffs: ^ow_comp_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_env_follow_init(&coeffs.env_follow_coeffs)
	ow_gain_init(&coeffs.gain_coeffs)
	ow_one_pole_init(&coeffs.smooth_coeffs)
	ow_one_pole_set_tau(&coeffs.smooth_coeffs, 0.05)
	coeffs.thresh = 1.0
	coeffs.ratio = 1.0
}

// Summary: Sets sample rate for comp.
ow_comp_set_sample_rate :: proc(coeffs: ^ow_comp_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_env_follow_set_sample_rate(&coeffs.env_follow_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.gain_coeffs, sample_rate)
	ow_one_pole_set_sample_rate(&coeffs.smooth_coeffs, sample_rate)
	ow_one_pole_reset_coeffs(&coeffs.smooth_coeffs)
}

// Summary: Resets coefficients for comp.
ow_comp_reset_coeffs :: proc(coeffs: ^ow_comp_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_env_follow_reset_coeffs(&coeffs.env_follow_coeffs)
	ow_gain_reset_coeffs(&coeffs.gain_coeffs)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_thresh_state, coeffs.thresh)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_ratio_state, coeffs.ratio)
	ow_comp_do_update_coeffs_audio(coeffs)
}

// Summary: Resets state for comp.
ow_comp_reset_state :: proc(coeffs: ^ow_comp_coeffs, state: ^ow_comp_state, x_0: f32, x_sc_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	OW_ASSERT(ow_is_finite(x_sc_0))
	env := ow_env_follow_reset_state(&coeffs.env_follow_coeffs, &state.env_follow_state, x_sc_0)
	y := x_0
	if env > ow_one_pole_get_y_z1(&coeffs.smooth_thresh_state) {
		y = ow_pow2f(coeffs.kc*(coeffs.lt-math.log2(env))) * x_0
	}
	y = ow_gain_get_gain_cur(&coeffs.gain_coeffs) * y
	return y
}

// Summary: Resets multi-channel state for comp.
ow_comp_reset_state_multi :: proc(coeffs: ^ow_comp_coeffs, state: ^^ow_comp_state, x_0: ^f32, x_sc_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_comp_state)(state)
	x0 := ([^]f32)(x_0)
	xsc0: [^]f32
	if x_sc_0 != nil {
		xsc0 = ([^]f32)(x_sc_0)
	}
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for ch := 0; ch < n_channels; ch += 1 {
		sc := f32(0.0)
		if x_sc_0 != nil {
			sc = xsc0[ch]
		}
		v := ow_comp_reset_state(coeffs, states[ch], x0[ch], sc)
		if y_0 != nil {
			y0[ch] = v
		}
	}
}

// Summary: Updates control-rate coefficients for comp.
ow_comp_update_coeffs_ctrl :: proc(coeffs: ^ow_comp_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_env_follow_update_coeffs_ctrl(&coeffs.env_follow_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.gain_coeffs)
}

// Summary: Updates audio-rate coefficients for comp.
ow_comp_update_coeffs_audio :: proc(coeffs: ^ow_comp_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_comp_do_update_coeffs_audio(coeffs)
}

// Summary: Processes one sample for comp.
ow_comp_process1 :: proc(coeffs: ^ow_comp_coeffs, state: ^ow_comp_state, x: f32, x_sc: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	OW_ASSERT(ow_is_finite(x_sc))
	env := ow_env_follow_process1(&coeffs.env_follow_coeffs, &state.env_follow_state, x_sc)
	y := x
	if env > ow_one_pole_get_y_z1(&coeffs.smooth_thresh_state) {
		y = ow_pow2f(coeffs.kc*(coeffs.lt-math.log2(env))) * x
	}
	y = ow_gain_process1(&coeffs.gain_coeffs, y)
	return y
}

// Summary: Processes sample buffers for comp.
ow_comp_process :: proc(coeffs: ^ow_comp_coeffs, state: ^ow_comp_state, x: ^f32, x_sc: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	xsc: [^]f32
	if x_sc != nil {
		xsc = ([^]f32)(x_sc)
	}
	ym := ([^]f32)(y)
	ow_comp_update_coeffs_ctrl(coeffs)
	if x_sc != nil {
		for i := 0; i < n_samples; i += 1 {
			ow_comp_update_coeffs_audio(coeffs)
			ym[i] = ow_comp_process1(coeffs, state, xm[i], xsc[i])
		}
	} else {
		for i := 0; i < n_samples; i += 1 {
			ow_comp_update_coeffs_audio(coeffs)
			ym[i] = ow_comp_process1(coeffs, state, xm[i], 0.0)
		}
	}
}

// Summary: Processes multiple channels for comp.
ow_comp_process_multi :: proc(coeffs: ^ow_comp_coeffs, state: ^^ow_comp_state, x: ^^f32, x_sc: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_comp_state)(state)
	xm := ([^][^]f32)(x)
	xsc: [^][^]f32
	if x_sc != nil {
		xsc = ([^][^]f32)(x_sc)
	}
	ym := ([^][^]f32)(y)
	ow_comp_update_coeffs_ctrl(coeffs)
	if x_sc != nil {
		for i := 0; i < n_samples; i += 1 {
			ow_comp_update_coeffs_audio(coeffs)
			for ch := 0; ch < n_channels; ch += 1 {
				sc := f32(0.0)
				if xsc[ch] != nil {
					sc = xsc[ch][i]
				}
				ym[ch][i] = ow_comp_process1(coeffs, states[ch], xm[ch][i], sc)
			}
		}
	} else {
		for i := 0; i < n_samples; i += 1 {
			ow_comp_update_coeffs_audio(coeffs)
			for ch := 0; ch < n_channels; ch += 1 {
				ym[ch][i] = ow_comp_process1(coeffs, states[ch], xm[ch][i], 0.0)
			}
		}
	}
}

// Summary: Sets thresh lin for comp.
ow_comp_set_thresh_lin :: proc(coeffs: ^ow_comp_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1e-20 && value <= 1e20)
	coeffs.thresh = value
}

// Summary: Sets thresh dBFS for comp.
ow_comp_set_thresh_dBFS :: proc(coeffs: ^ow_comp_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= -400.0 && value <= 400.0)
	coeffs.thresh = ow_dB2linf(value)
}

// Summary: Sets ratio for comp.
ow_comp_set_ratio :: proc(coeffs: ^ow_comp_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0 && value <= 1.0)
	coeffs.ratio = value
}

// Summary: Sets attack tau for comp.
ow_comp_set_attack_tau :: proc(coeffs: ^ow_comp_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0)
	ow_env_follow_set_attack_tau(&coeffs.env_follow_coeffs, value)
}

// Summary: Sets release tau for comp.
ow_comp_set_release_tau :: proc(coeffs: ^ow_comp_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0)
	ow_env_follow_set_release_tau(&coeffs.env_follow_coeffs, value)
}

// Summary: Sets gain lin for comp.
ow_comp_set_gain_lin :: proc(coeffs: ^ow_comp_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	ow_gain_set_gain_lin(&coeffs.gain_coeffs, value)
}

// Summary: Sets gain dB for comp.
ow_comp_set_gain_dB :: proc(coeffs: ^ow_comp_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value))
	OW_ASSERT(value <= 770.630)
	ow_gain_set_gain_dB(&coeffs.gain_coeffs, value)
}

// Summary: Checks validity of comp coeffs.
ow_comp_coeffs_is_valid :: proc(coeffs: ^ow_comp_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.thresh) || coeffs.thresh < 1e-20 || coeffs.thresh > 1e20 {
		return 0
	}
	if !ow_is_finite(coeffs.ratio) || coeffs.ratio < 0.0 || coeffs.ratio > 1.0 {
		return 0
	}
	if !ow_one_pole_coeffs_is_valid(&coeffs.smooth_coeffs) {
		return 0
	}
	if !ow_env_follow_coeffs_is_valid(&coeffs.env_follow_coeffs) || !ow_gain_coeffs_is_valid(&coeffs.gain_coeffs) {
		return 0
	}
	return 1
}

// Summary: Checks validity of comp state.
ow_comp_state_is_valid :: proc(coeffs: ^ow_comp_coeffs, state: ^ow_comp_state) -> i8 {
	if state == nil {
		return 0
	}
	if coeffs != nil {
		if !ow_env_follow_state_is_valid(&coeffs.env_follow_coeffs, &state.env_follow_state) {
			return 0
		}
	} else {
		if !ow_env_follow_state_is_valid(nil, &state.env_follow_state) {
			return 0
		}
	}
	return 1
}
