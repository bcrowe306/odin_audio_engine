package odinworks

// Summary: Coefficient data for svf.
ow_svf_coeffs :: struct {
	smooth_coeffs: ow_one_pole_coeffs,
	smooth_cutoff_state: ow_one_pole_state,
	smooth_Q_state: ow_one_pole_state,
	smooth_prewarp_freq_state: ow_one_pole_state,
	t_k: f32,
	prewarp_freq_max: f32,
	kf: f32,
	kbl: f32,
	k: f32,
	hp_hb: f32,
	hp_x: f32,
	cutoff: f32,
	Q: f32,
	prewarp_k: f32,
	prewarp_freq: f32,
}

// Summary: Runtime state for svf.
ow_svf_state :: struct {
	hp_z1: f32,
	lp_z1: f32,
	bp_z1: f32,
	cutoff_z1: f32,
}

// Summary: Initializes svf.
ow_svf_init :: proc(coeffs: ^ow_svf_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_init(&coeffs.smooth_coeffs)
	ow_one_pole_set_tau(&coeffs.smooth_coeffs, 0.005)
	ow_one_pole_set_sticky_thresh(&coeffs.smooth_coeffs, 1.0e-3)
	coeffs.cutoff = 1.0e3
	coeffs.Q = 0.5
	coeffs.prewarp_freq = 1.0e3
	coeffs.prewarp_k = 1.0
}

// Summary: Sets sample rate for svf.
ow_svf_set_sample_rate :: proc(coeffs: ^ow_svf_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_one_pole_set_sample_rate(&coeffs.smooth_coeffs, sample_rate)
	ow_one_pole_reset_coeffs(&coeffs.smooth_coeffs)
	coeffs.t_k = 3.141592653589793 / sample_rate
	coeffs.prewarp_freq_max = 0.499 * sample_rate
}

// Summary: Executes svf do update coeffs.
ow_svf_do_update_coeffs :: proc(coeffs: ^ow_svf_coeffs, force: bool) {
	prewarp_freq := coeffs.prewarp_freq + coeffs.prewarp_k*(coeffs.cutoff-coeffs.prewarp_freq)
	cutoff_cur := ow_one_pole_get_y_z1(&coeffs.smooth_cutoff_state)
	prewarp_freq_cur := ow_one_pole_get_y_z1(&coeffs.smooth_prewarp_freq_state)
	Q_cur := ow_one_pole_get_y_z1(&coeffs.smooth_Q_state)
	cutoff_changed := force || coeffs.cutoff != cutoff_cur
	prewarp_freq_changed := force || prewarp_freq != prewarp_freq_cur
	Q_changed := force || coeffs.Q != Q_cur

	if cutoff_changed || prewarp_freq_changed || Q_changed {
		if cutoff_changed || prewarp_freq_changed {
			if cutoff_changed {
				cutoff_cur = ow_one_pole_process1_sticky_rel(&coeffs.smooth_coeffs, &coeffs.smooth_cutoff_state, coeffs.cutoff)
			}
			if prewarp_freq_changed {
				prewarp_freq_cur = ow_one_pole_process1_sticky_rel(&coeffs.smooth_coeffs, &coeffs.smooth_prewarp_freq_state, prewarp_freq)
				f := ow_minf(prewarp_freq_cur, coeffs.prewarp_freq_max)
				coeffs.kf = ow_tanf(coeffs.t_k*f) * ow_rcpf(f)
			}
			coeffs.kbl = coeffs.kf * cutoff_cur
		}
		if Q_changed {
			Q_cur = ow_one_pole_process1_sticky_abs(&coeffs.smooth_coeffs, &coeffs.smooth_Q_state, coeffs.Q)
			coeffs.k = ow_rcpf(Q_cur)
		}
		coeffs.hp_hb = coeffs.k + coeffs.kbl
		coeffs.hp_x = ow_rcpf(1.0 + coeffs.kbl*coeffs.hp_hb)
	}
}

// Summary: Resets coefficients for svf.
ow_svf_reset_coeffs :: proc(coeffs: ^ow_svf_coeffs) {
	OW_ASSERT(coeffs != nil)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_cutoff_state, coeffs.cutoff)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_Q_state, coeffs.Q)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_prewarp_freq_state, coeffs.prewarp_freq+coeffs.prewarp_k*(coeffs.cutoff-coeffs.prewarp_freq))
	ow_svf_do_update_coeffs(coeffs, true)
}

// Summary: Resets state for svf.
ow_svf_reset_state :: proc(coeffs: ^ow_svf_coeffs, state: ^ow_svf_state, x_0: f32, y_lp_0: ^f32, y_bp_0: ^f32, y_hp_0: ^f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	OW_ASSERT(y_lp_0 != nil)
	OW_ASSERT(y_bp_0 != nil)
	OW_ASSERT(y_hp_0 != nil)

	state.hp_z1 = 0.0
	state.lp_z1 = x_0
	state.bp_z1 = 0.0
	state.cutoff_z1 = coeffs.cutoff
	y_lp_0^ = x_0
	y_bp_0^ = 0.0
	y_hp_0^ = 0.0
}

// Summary: Resets multi-channel state for svf.
ow_svf_reset_state_multi :: proc(coeffs: ^ow_svf_coeffs, state: ^^ow_svf_state, x_0: ^f32, y_lp_0: ^f32, y_bp_0: ^f32, y_hp_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)

	states := ([^]^ow_svf_state)(state)
	x0 := ([^]f32)(x_0)
	ylp0: [^]f32
	ybp0: [^]f32
	yhp0: [^]f32
	if y_lp_0 != nil {
		ylp0 = ([^]f32)(y_lp_0)
	}
	if y_bp_0 != nil {
		ybp0 = ([^]f32)(y_bp_0)
	}
	if y_hp_0 != nil {
		yhp0 = ([^]f32)(y_hp_0)
	}

	for i := 0; i < n_channels; i += 1 {
		v_lp, v_bp, v_hp: f32
		ow_svf_reset_state(coeffs, states[i], x0[i], &v_lp, &v_bp, &v_hp)
		if y_lp_0 != nil {
			ylp0[i] = v_lp
		}
		if y_bp_0 != nil {
			ybp0[i] = v_bp
		}
		if y_hp_0 != nil {
			yhp0[i] = v_hp
		}
	}
}

// Summary: Updates control-rate coefficients for svf.
ow_svf_update_coeffs_ctrl :: proc(coeffs: ^ow_svf_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Updates audio-rate coefficients for svf.
ow_svf_update_coeffs_audio :: proc(coeffs: ^ow_svf_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_do_update_coeffs(coeffs, false)
}

// Summary: Processes one sample for svf.
ow_svf_process1 :: proc(coeffs: ^ow_svf_coeffs, state: ^ow_svf_state, x: f32, y_lp: ^f32, y_bp: ^f32, y_hp: ^f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	OW_ASSERT(y_lp != nil)
	OW_ASSERT(y_bp != nil)
	OW_ASSERT(y_hp != nil)

	kk := coeffs.kf * state.cutoff_z1
	lp_xz1 := state.lp_z1 + kk*state.bp_z1
	bp_xz1 := state.bp_z1 + kk*state.hp_z1
	y_hp^ = coeffs.hp_x * (x - coeffs.hp_hb*bp_xz1 - lp_xz1)
	y_bp^ = bp_xz1 + coeffs.kbl*y_hp^
	y_lp^ = lp_xz1 + coeffs.kbl*y_bp^

	state.hp_z1 = y_hp^
	state.lp_z1 = y_lp^
	state.bp_z1 = y_bp^
	state.cutoff_z1 = ow_one_pole_get_y_z1(&coeffs.smooth_cutoff_state)
}

// Summary: Processes sample buffers for svf.
ow_svf_process :: proc(coeffs: ^ow_svf_coeffs, state: ^ow_svf_state, x: ^f32, y_lp: ^f32, y_bp: ^f32, y_hp: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)

	xm := ([^]f32)(x)
	ylp: [^]f32
	ybp: [^]f32
	yhp: [^]f32
	if y_lp != nil {
		ylp = ([^]f32)(y_lp)
	}
	if y_bp != nil {
		ybp = ([^]f32)(y_bp)
	}
	if y_hp != nil {
		yhp = ([^]f32)(y_hp)
	}

	for i := 0; i < n_samples; i += 1 {
		ow_svf_update_coeffs_audio(coeffs)
		v_lp, v_bp, v_hp: f32
		ow_svf_process1(coeffs, state, xm[i], &v_lp, &v_bp, &v_hp)
		if y_lp != nil {
			ylp[i] = v_lp
		}
		if y_bp != nil {
			ybp[i] = v_bp
		}
		if y_hp != nil {
			yhp[i] = v_hp
		}
	}
}

// Summary: Processes multiple channels for svf.
ow_svf_process_multi :: proc(coeffs: ^ow_svf_coeffs, state: ^^ow_svf_state, x: ^^f32, y_lp: ^^f32, y_bp: ^^f32, y_hp: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)

	states := ([^]^ow_svf_state)(state)
	xm := ([^][^]f32)(x)
	ylpm: [^][^]f32
	ybpm: [^][^]f32
	yhpm: [^][^]f32
	if y_lp != nil {
		ylpm = ([^][^]f32)(y_lp)
	}
	if y_bp != nil {
		ybpm = ([^][^]f32)(y_bp)
	}
	if y_hp != nil {
		yhpm = ([^][^]f32)(y_hp)
	}

	for i := 0; i < n_samples; i += 1 {
		ow_svf_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			v_lp, v_bp, v_hp: f32
			ow_svf_process1(coeffs, states[ch], xm[ch][i], &v_lp, &v_bp, &v_hp)
			if y_lp != nil && ylpm[ch] != nil {
				ylpm[ch][i] = v_lp
			}
			if y_bp != nil && ybpm[ch] != nil {
				ybpm[ch][i] = v_bp
			}
			if y_hp != nil && yhpm[ch] != nil {
				yhpm[ch][i] = v_hp
			}
		}
	}
}

// Summary: Sets cutoff for svf.
ow_svf_set_cutoff :: proc(coeffs: ^ow_svf_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	OW_ASSERT(value >= 1.0e-6 && value <= 1.0e12)
	coeffs.cutoff = value
}

// Summary: Sets Q for svf.
ow_svf_set_Q :: proc(coeffs: ^ow_svf_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	OW_ASSERT(value >= 1.0e-6 && value <= 1.0e6)
	coeffs.Q = value
}

// Summary: Sets prewarp at cutoff for svf.
ow_svf_set_prewarp_at_cutoff :: proc(coeffs: ^ow_svf_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	coeffs.prewarp_k = 0.0
	if value != 0 {
		coeffs.prewarp_k = 1.0
	}
}

// Summary: Sets prewarp freq for svf.
ow_svf_set_prewarp_freq :: proc(coeffs: ^ow_svf_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	OW_ASSERT(value >= 1.0e-6 && value <= 1.0e12)
	coeffs.prewarp_freq = value
}

// Summary: Checks validity of svf coeffs.
ow_svf_coeffs_is_valid :: proc(coeffs: ^ow_svf_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.cutoff) || coeffs.cutoff < 1.0e-6 || coeffs.cutoff > 1.0e12 {
		return 0
	}
	if !ow_is_finite(coeffs.Q) || coeffs.Q < 1.0e-6 || coeffs.Q > 1.0e6 {
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
	if !ow_one_pole_state_is_valid(&coeffs.smooth_coeffs, &coeffs.smooth_Q_state) {
		return 0
	}
	if !ow_one_pole_state_is_valid(&coeffs.smooth_coeffs, &coeffs.smooth_prewarp_freq_state) {
		return 0
	}
	return 1
}

// Summary: Checks validity of svf state.
ow_svf_state_is_valid :: proc(coeffs: ^ow_svf_coeffs, state: ^ow_svf_state) -> i8 {
	if state == nil {
		return 0
	}
	_ = coeffs
	if !ow_is_finite(state.hp_z1) || !ow_is_finite(state.lp_z1) || !ow_is_finite(state.bp_z1) {
		return 0
	}
	if !ow_is_finite(state.cutoff_z1) || state.cutoff_z1 < 1.0e-6 || state.cutoff_z1 > 1.0e12 {
		return 0
	}
	return 1
}
