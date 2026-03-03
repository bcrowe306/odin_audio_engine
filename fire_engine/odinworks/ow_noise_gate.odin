package odinworks

import "core:math"

OW_NOISE_GATE_PRACTICAL_INFINITY: f32 : 1.0e30

// Summary: Coefficient data for noise gate.
ow_noise_gate_coeffs :: struct {
	env_follow_coeffs: ow_env_follow_coeffs,
	smooth_coeffs: ow_one_pole_coeffs,
	smooth_thresh_state: ow_one_pole_state,
	smooth_ratio_state: ow_one_pole_state,
	kc: f32,
	lt: f32,
	thresh: f32,
	ratio: f32,
}

// Summary: Runtime state for noise gate.
ow_noise_gate_state :: struct {
	env_follow_state: ow_env_follow_state,
}

// Summary: Initializes noise gate.
ow_noise_gate_init :: proc(coeffs: ^ow_noise_gate_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_env_follow_init(&coeffs.env_follow_coeffs)
	ow_one_pole_init(&coeffs.smooth_coeffs)
	ow_one_pole_set_tau(&coeffs.smooth_coeffs, 0.05)
	coeffs.thresh = 1.0
	coeffs.ratio = 1.0
}

// Summary: Sets sample rate for noise gate.
ow_noise_gate_set_sample_rate :: proc(coeffs: ^ow_noise_gate_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_env_follow_set_sample_rate(&coeffs.env_follow_coeffs, sample_rate)
	ow_one_pole_set_sample_rate(&coeffs.smooth_coeffs, sample_rate)
	ow_one_pole_reset_coeffs(&coeffs.smooth_coeffs)
}

// Summary: Updates audio-rate coefficients for noise gate do.
ow_noise_gate_do_update_coeffs_audio :: proc(coeffs: ^ow_noise_gate_coeffs) {
	ow_env_follow_update_coeffs_audio(&coeffs.env_follow_coeffs)
	_ = ow_one_pole_process1(&coeffs.smooth_coeffs, &coeffs.smooth_thresh_state, coeffs.thresh)
	rev_target: f32
	if coeffs.ratio > 1.0e12 {
		rev_target = 0.0
	} else {
		rev_target = ow_rcpf(coeffs.ratio)
	}
	rev_ratio := ow_one_pole_process1(&coeffs.smooth_coeffs, &coeffs.smooth_ratio_state, rev_target)
	if rev_ratio < 1.0e-12 {
		coeffs.kc = -OW_NOISE_GATE_PRACTICAL_INFINITY
	} else {
		coeffs.kc = 1.0 - ow_rcpf(rev_ratio)
	}
	coeffs.lt = math.log2(ow_one_pole_get_y_z1(&coeffs.smooth_thresh_state))
}

// Summary: Resets coefficients for noise gate.
ow_noise_gate_reset_coeffs :: proc(coeffs: ^ow_noise_gate_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_env_follow_reset_coeffs(&coeffs.env_follow_coeffs)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_thresh_state, coeffs.thresh)
	rev: f32
	if coeffs.ratio > 1.0e12 {
		rev = 0.0
	} else {
		rev = ow_rcpf(coeffs.ratio)
	}
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_ratio_state, rev)
	ow_noise_gate_do_update_coeffs_audio(coeffs)
}

// Summary: Resets state for noise gate.
ow_noise_gate_reset_state :: proc(coeffs: ^ow_noise_gate_coeffs, state: ^ow_noise_gate_state, x_0: f32, x_sc_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	OW_ASSERT(ow_is_finite(x_sc_0))
	env := ow_env_follow_reset_state(&coeffs.env_follow_coeffs, &state.env_follow_state, x_sc_0)
	thresh_cur := ow_one_pole_get_y_z1(&coeffs.smooth_thresh_state)
	if env < thresh_cur {
		if env >= 1.0e-30 {
			return ow_pow2f(coeffs.kc*(coeffs.lt-math.log2(env))) * x_0
		}
		return 0.0
	}
	return x_0
}

// Summary: Resets multi-channel state for noise gate.
ow_noise_gate_reset_state_multi :: proc(coeffs: ^ow_noise_gate_coeffs, state: ^^ow_noise_gate_state, x_0: ^f32, x_sc_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_noise_gate_state)(state)
	x0 := ([^]f32)(x_0)
	xsc0: [^]f32
	y0: [^]f32
	if x_sc_0 != nil {
		xsc0 = ([^]f32)(x_sc_0)
	}
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		sc0: f32 = 0.0
		if x_sc_0 != nil {
			sc0 = xsc0[i]
		}
		v := ow_noise_gate_reset_state(coeffs, states[i], x0[i], sc0)
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for noise gate.
ow_noise_gate_update_coeffs_ctrl :: proc(coeffs: ^ow_noise_gate_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_env_follow_update_coeffs_ctrl(&coeffs.env_follow_coeffs)
}

// Summary: Updates audio-rate coefficients for noise gate.
ow_noise_gate_update_coeffs_audio :: proc(coeffs: ^ow_noise_gate_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_noise_gate_do_update_coeffs_audio(coeffs)
}

// Summary: Processes one sample for noise gate.
ow_noise_gate_process1 :: proc(coeffs: ^ow_noise_gate_coeffs, state: ^ow_noise_gate_state, x: f32, x_sc: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	OW_ASSERT(ow_is_finite(x_sc))
	env := ow_env_follow_process1(&coeffs.env_follow_coeffs, &state.env_follow_state, x_sc)
	thresh_cur := ow_one_pole_get_y_z1(&coeffs.smooth_thresh_state)
	if env < thresh_cur {
		if env >= 1.0e-30 {
			return ow_pow2f(coeffs.kc*(coeffs.lt-math.log2(env))) * x
		}
		return 0.0
	}
	return x
}

// Summary: Processes sample buffers for noise gate.
ow_noise_gate_process :: proc(coeffs: ^ow_noise_gate_coeffs, state: ^ow_noise_gate_state, x: ^f32, x_sc: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	xsc: [^]f32
	if x_sc != nil {
		xsc = ([^]f32)(x_sc)
	}
	ow_noise_gate_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_noise_gate_update_coeffs_audio(coeffs)
		sc := f32(0.0)
		if x_sc != nil {
			sc = xsc[i]
		}
		ym[i] = ow_noise_gate_process1(coeffs, state, xm[i], sc)
	}
}

// Summary: Processes multiple channels for noise gate.
ow_noise_gate_process_multi :: proc(coeffs: ^ow_noise_gate_coeffs, state: ^^ow_noise_gate_state, x: ^^f32, x_sc: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_noise_gate_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	xscm: [^][^]f32
	if x_sc != nil {
		xscm = ([^][^]f32)(x_sc)
	}
	ow_noise_gate_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_noise_gate_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			sc := f32(0.0)
			if x_sc != nil && xscm[ch] != nil {
				sc = xscm[ch][i]
			}
			ym[ch][i] = ow_noise_gate_process1(coeffs, states[ch], xm[ch][i], sc)
		}
	}
}

// Summary: Sets thresh lin for noise gate.
ow_noise_gate_set_thresh_lin :: proc(coeffs: ^ow_noise_gate_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	OW_ASSERT(value >= 1.0e-20 && value <= 1.0e20)
	coeffs.thresh = value
}

// Summary: Sets thresh dBFS for noise gate.
ow_noise_gate_set_thresh_dBFS :: proc(coeffs: ^ow_noise_gate_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	OW_ASSERT(value >= -400.0 && value <= 400.0)
	coeffs.thresh = ow_dB2linf(value)
}

// Summary: Sets ratio for noise gate.
ow_noise_gate_set_ratio :: proc(coeffs: ^ow_noise_gate_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value))
	OW_ASSERT(value >= 1.0)
	coeffs.ratio = value
}

// Summary: Sets attack tau for noise gate.
ow_noise_gate_set_attack_tau :: proc(coeffs: ^ow_noise_gate_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value) && value >= 0.0)
	ow_env_follow_set_attack_tau(&coeffs.env_follow_coeffs, value)
}

// Summary: Sets release tau for noise gate.
ow_noise_gate_set_release_tau :: proc(coeffs: ^ow_noise_gate_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value) && value >= 0.0)
	ow_env_follow_set_release_tau(&coeffs.env_follow_coeffs, value)
}

// Summary: Checks validity of noise gate coeffs.
ow_noise_gate_coeffs_is_valid :: proc(coeffs: ^ow_noise_gate_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.thresh) || coeffs.thresh < 1.0e-20 || coeffs.thresh > 1.0e20 {
		return 0
	}
	if ow_is_nan(coeffs.ratio) || coeffs.ratio < 1.0 {
		return 0
	}
	if !ow_one_pole_coeffs_is_valid(&coeffs.smooth_coeffs) {
		return 0
	}
	if !ow_env_follow_coeffs_is_valid(&coeffs.env_follow_coeffs) {
		return 0
	}
	return 1
}

// Summary: Checks validity of noise gate state.
ow_noise_gate_state_is_valid :: proc(coeffs: ^ow_noise_gate_coeffs, state: ^ow_noise_gate_state) -> i8 {
	if state == nil {
		return 0
	}
	env_coeffs: ^ow_env_follow_coeffs
	if coeffs != nil {
		env_coeffs = &coeffs.env_follow_coeffs
	}
	if !ow_env_follow_state_is_valid(env_coeffs, &state.env_follow_state) {
		return 0
	}
	return 1
}
