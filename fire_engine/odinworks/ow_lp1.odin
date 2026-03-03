package odinworks

// Summary: Coefficient data for lp1.
ow_lp1_coeffs :: struct {
	smooth_coeffs: ow_one_pole_coeffs,
	smooth_cutoff_state: ow_one_pole_state,
	smooth_prewarp_freq_state: ow_one_pole_state,
	t_k: f32,
	t: f32,
	X_x: f32,
	X_X_z1: f32,
	y_X: f32,
	cutoff: f32,
	prewarp_k: f32,
	prewarp_freq: f32,
}

// Summary: Runtime state for lp1.
ow_lp1_state :: struct {
	y_z1: f32,
	X_z1: f32,
}

// Summary: Initializes lp1.
ow_lp1_init :: proc(coeffs: ^ow_lp1_coeffs) {
	OW_ASSERT(coeffs != nil)

	ow_one_pole_init(&coeffs.smooth_coeffs)
	ow_one_pole_set_tau(&coeffs.smooth_coeffs, 0.005)
	ow_one_pole_set_sticky_thresh(&coeffs.smooth_coeffs, 1.0e-3)
	coeffs.cutoff = 1.0e3
	coeffs.prewarp_k = 1.0
	coeffs.prewarp_freq = 1.0e3
}

// Summary: Sets sample rate for lp1.
ow_lp1_set_sample_rate :: proc(coeffs: ^ow_lp1_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)

	ow_one_pole_set_sample_rate(&coeffs.smooth_coeffs, sample_rate)
	ow_one_pole_reset_coeffs(&coeffs.smooth_coeffs)
	coeffs.t_k = 3.141592653589793 / sample_rate
}

// Summary: Executes lp1 do update coeffs.
ow_lp1_do_update_coeffs :: proc(coeffs: ^ow_lp1_coeffs, force: bool) {
	prewarp_freq := coeffs.prewarp_freq + coeffs.prewarp_k*(coeffs.cutoff-coeffs.prewarp_freq)
	prewarp_freq_cur := ow_one_pole_get_y_z1(&coeffs.smooth_prewarp_freq_state)
	cutoff_cur := ow_one_pole_get_y_z1(&coeffs.smooth_cutoff_state)
	prewarp_freq_changed := force || prewarp_freq != prewarp_freq_cur
	cutoff_changed := force || coeffs.cutoff != cutoff_cur

	if prewarp_freq_changed || cutoff_changed {
		if prewarp_freq_changed {
			prewarp_freq_cur = ow_one_pole_process1_sticky_rel(&coeffs.smooth_coeffs, &coeffs.smooth_prewarp_freq_state, prewarp_freq)
			coeffs.t = ow_tanf(ow_minf(coeffs.t_k*prewarp_freq_cur, 1.567654734141306))
		}
		if cutoff_changed {
			cutoff_cur = ow_one_pole_process1_sticky_rel(&coeffs.smooth_coeffs, &coeffs.smooth_cutoff_state, coeffs.cutoff)
			coeffs.y_X = ow_rcpf(cutoff_cur)
		}
		k := cutoff_cur * ow_rcpf(cutoff_cur*coeffs.t+prewarp_freq_cur)
		coeffs.X_x = k * prewarp_freq_cur
		coeffs.X_X_z1 = k * coeffs.t
	}
}

// Summary: Resets coefficients for lp1.
ow_lp1_reset_coeffs :: proc(coeffs: ^ow_lp1_coeffs) {
	OW_ASSERT(coeffs != nil)

	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_cutoff_state, coeffs.cutoff)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_prewarp_freq_state, coeffs.prewarp_freq+coeffs.prewarp_k*(coeffs.cutoff-coeffs.prewarp_freq))
	ow_lp1_do_update_coeffs(coeffs, true)
}

// Summary: Resets state for lp1.
ow_lp1_reset_state :: proc(coeffs: ^ow_lp1_coeffs, state: ^ow_lp1_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))

	state.y_z1 = x_0
	state.X_z1 = 0.0
	return x_0
}

// Summary: Resets multi-channel state for lp1.
ow_lp1_reset_state_multi :: proc(coeffs: ^ow_lp1_coeffs, state: ^^ow_lp1_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)

	states := ([^]^ow_lp1_state)(state)
	x0 := ([^]f32)(x_0)

	if y_0 != nil {
		y0 := ([^]f32)(y_0)
		for i := 0; i < n_channels; i += 1 {
			y0[i] = ow_lp1_reset_state(coeffs, states[i], x0[i])
		}
	} else {
		for i := 0; i < n_channels; i += 1 {
			_ = ow_lp1_reset_state(coeffs, states[i], x0[i])
		}
	}
}

// Summary: Updates control-rate coefficients for lp1.
ow_lp1_update_coeffs_ctrl :: proc(coeffs: ^ow_lp1_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Updates audio-rate coefficients for lp1.
ow_lp1_update_coeffs_audio :: proc(coeffs: ^ow_lp1_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_lp1_do_update_coeffs(coeffs, false)
}

// Summary: Processes one sample for lp1.
ow_lp1_process1 :: proc(coeffs: ^ow_lp1_coeffs, state: ^ow_lp1_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))

	X := coeffs.X_x*(x-state.y_z1) - coeffs.X_X_z1*state.X_z1
	y := x - coeffs.y_X*X
	state.y_z1 = y
	state.X_z1 = X
	return y
}

// Summary: Processes sample buffers for lp1.
ow_lp1_process :: proc(coeffs: ^ow_lp1_coeffs, state: ^ow_lp1_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)

	xm := ([^]f32)(x)
	ym := ([^]f32)(y)

	for i := 0; i < n_samples; i += 1 {
		ow_lp1_update_coeffs_audio(coeffs)
		ym[i] = ow_lp1_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for lp1.
ow_lp1_process_multi :: proc(coeffs: ^ow_lp1_coeffs, state: ^^ow_lp1_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)

	states := ([^]^ow_lp1_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)

	for i := 0; i < n_samples; i += 1 {
		ow_lp1_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_lp1_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets cutoff for lp1.
ow_lp1_set_cutoff :: proc(coeffs: ^ow_lp1_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	OW_ASSERT(value >= 1.0e-6 && value <= 1.0e12)
	coeffs.cutoff = value
}

// Summary: Sets prewarp at cutoff for lp1.
ow_lp1_set_prewarp_at_cutoff :: proc(coeffs: ^ow_lp1_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	coeffs.prewarp_k = 0.0
	if value != 0 {
		coeffs.prewarp_k = 1.0
	}
}

// Summary: Sets prewarp freq for lp1.
ow_lp1_set_prewarp_freq :: proc(coeffs: ^ow_lp1_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	OW_ASSERT(value >= 1.0e-6 && value <= 1.0e12)
	coeffs.prewarp_freq = value
}

// Summary: Checks validity of lp1 coeffs.
ow_lp1_coeffs_is_valid :: proc(coeffs: ^ow_lp1_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.cutoff) || coeffs.cutoff < 1.0e-6 || coeffs.cutoff > 1.0e12 {
		return 0
	}
	if !ow_is_finite(coeffs.prewarp_k) || (coeffs.prewarp_k != 0.0 && coeffs.prewarp_k != 1.0) {
		return 0
	}
	if !ow_is_finite(coeffs.prewarp_freq) || coeffs.prewarp_freq < 1.0e-6 || coeffs.prewarp_freq > 1.0e12 {
		return 0
	}
	if !ow_one_pole_coeffs_is_valid(&coeffs.smooth_coeffs) {
		return 0
	}
	if !ow_one_pole_state_is_valid(&coeffs.smooth_coeffs, &coeffs.smooth_cutoff_state) {
		return 0
	}
	if !ow_one_pole_state_is_valid(&coeffs.smooth_coeffs, &coeffs.smooth_prewarp_freq_state) {
		return 0
	}
	return 1
}

// Summary: Checks validity of lp1 state.
ow_lp1_state_is_valid :: proc(coeffs: ^ow_lp1_coeffs, state: ^ow_lp1_state) -> i8 {
	if state == nil {
		return 0
	}
	if coeffs != nil {
		if ow_lp1_coeffs_is_valid(coeffs) == 0 {
			return 0
		}
	}
	if !ow_is_finite(state.y_z1) || !ow_is_finite(state.X_z1) {
		return 0
	}
	return 1
}
