package odinworks

// Summary: Coefficient data for mm2.
ow_mm2_coeffs :: struct {
	svf_coeffs: ow_svf_coeffs,
	gain_x_coeffs: ow_gain_coeffs,
	gain_lp_coeffs: ow_gain_coeffs,
	gain_bp_coeffs: ow_gain_coeffs,
	gain_hp_coeffs: ow_gain_coeffs,
}

// Summary: Runtime state for mm2.
ow_mm2_state :: struct {
	svf_state: ow_svf_state,
}

// Summary: Initializes mm2.
ow_mm2_init :: proc(coeffs: ^ow_mm2_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_init(&coeffs.svf_coeffs)
	ow_gain_init(&coeffs.gain_x_coeffs)
	ow_gain_init(&coeffs.gain_lp_coeffs)
	ow_gain_init(&coeffs.gain_bp_coeffs)
	ow_gain_init(&coeffs.gain_hp_coeffs)
	ow_gain_set_smooth_tau(&coeffs.gain_x_coeffs, 0.005)
	ow_gain_set_smooth_tau(&coeffs.gain_lp_coeffs, 0.005)
	ow_gain_set_smooth_tau(&coeffs.gain_bp_coeffs, 0.005)
	ow_gain_set_smooth_tau(&coeffs.gain_hp_coeffs, 0.005)
	ow_gain_set_gain_lin(&coeffs.gain_x_coeffs, 1.0)
	ow_gain_set_gain_lin(&coeffs.gain_lp_coeffs, 0.0)
	ow_gain_set_gain_lin(&coeffs.gain_bp_coeffs, 0.0)
	ow_gain_set_gain_lin(&coeffs.gain_hp_coeffs, 0.0)
}

// Summary: Sets sample rate for mm2.
ow_mm2_set_sample_rate :: proc(coeffs: ^ow_mm2_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_svf_set_sample_rate(&coeffs.svf_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.gain_x_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.gain_lp_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.gain_bp_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.gain_hp_coeffs, sample_rate)
}

// Summary: Resets coefficients for mm2.
ow_mm2_reset_coeffs :: proc(coeffs: ^ow_mm2_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_reset_coeffs(&coeffs.svf_coeffs)
	ow_gain_reset_coeffs(&coeffs.gain_x_coeffs)
	ow_gain_reset_coeffs(&coeffs.gain_lp_coeffs)
	ow_gain_reset_coeffs(&coeffs.gain_bp_coeffs)
	ow_gain_reset_coeffs(&coeffs.gain_hp_coeffs)
}

// Summary: Resets state for mm2.
ow_mm2_reset_state :: proc(coeffs: ^ow_mm2_coeffs, state: ^ow_mm2_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	lp, bp, hp: f32
	ow_svf_reset_state(&coeffs.svf_coeffs, &state.svf_state, x_0, &lp, &bp, &hp)
	return ow_gain_get_gain_cur(&coeffs.gain_x_coeffs)*x_0 +
		ow_gain_get_gain_cur(&coeffs.gain_lp_coeffs)*lp +
		ow_gain_get_gain_cur(&coeffs.gain_bp_coeffs)*bp +
		ow_gain_get_gain_cur(&coeffs.gain_hp_coeffs)*hp
}

// Summary: Resets multi-channel state for mm2.
ow_mm2_reset_state_multi :: proc(coeffs: ^ow_mm2_coeffs, state: ^^ow_mm2_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_mm2_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_mm2_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for mm2.
ow_mm2_update_coeffs_ctrl :: proc(coeffs: ^ow_mm2_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_update_coeffs_ctrl(&coeffs.svf_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.gain_x_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.gain_lp_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.gain_bp_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.gain_hp_coeffs)
}

// Summary: Updates audio-rate coefficients for mm2.
ow_mm2_update_coeffs_audio :: proc(coeffs: ^ow_mm2_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_update_coeffs_audio(&coeffs.svf_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.gain_x_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.gain_lp_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.gain_bp_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.gain_hp_coeffs)
}

// Summary: Processes one sample for mm2.
ow_mm2_process1 :: proc(coeffs: ^ow_mm2_coeffs, state: ^ow_mm2_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	lp, bp, hp: f32
	ow_svf_process1(&coeffs.svf_coeffs, &state.svf_state, x, &lp, &bp, &hp)
	vx := ow_gain_process1(&coeffs.gain_x_coeffs, x)
	vlp := ow_gain_process1(&coeffs.gain_lp_coeffs, lp)
	vbp := ow_gain_process1(&coeffs.gain_bp_coeffs, bp)
	vhp := ow_gain_process1(&coeffs.gain_hp_coeffs, hp)
	return vx + vlp + vbp + vhp
}

// Summary: Processes sample buffers for mm2.
ow_mm2_process :: proc(coeffs: ^ow_mm2_coeffs, state: ^ow_mm2_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	ow_mm2_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_mm2_update_coeffs_audio(coeffs)
		ym[i] = ow_mm2_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for mm2.
ow_mm2_process_multi :: proc(coeffs: ^ow_mm2_coeffs, state: ^^ow_mm2_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_mm2_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_mm2_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_mm2_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_mm2_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets cutoff for mm2.
ow_mm2_set_cutoff :: proc(coeffs: ^ow_mm2_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-6 && value <= 1.0e12)
	ow_svf_set_cutoff(&coeffs.svf_coeffs, value)
}

// Summary: Sets Q for mm2.
ow_mm2_set_Q :: proc(coeffs: ^ow_mm2_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-6 && value <= 1.0e6)
	ow_svf_set_Q(&coeffs.svf_coeffs, value)
}

// Summary: Sets prewarp at cutoff for mm2.
ow_mm2_set_prewarp_at_cutoff :: proc(coeffs: ^ow_mm2_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	ow_svf_set_prewarp_at_cutoff(&coeffs.svf_coeffs, value)
}

// Summary: Sets prewarp freq for mm2.
ow_mm2_set_prewarp_freq :: proc(coeffs: ^ow_mm2_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-6 && value <= 1.0e12)
	ow_svf_set_prewarp_freq(&coeffs.svf_coeffs, value)
}

// Summary: Sets coeff x for mm2.
ow_mm2_set_coeff_x :: proc(coeffs: ^ow_mm2_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	ow_gain_set_gain_lin(&coeffs.gain_x_coeffs, value)
}

// Summary: Sets coeff lp for mm2.
ow_mm2_set_coeff_lp :: proc(coeffs: ^ow_mm2_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	ow_gain_set_gain_lin(&coeffs.gain_lp_coeffs, value)
}

// Summary: Sets coeff bp for mm2.
ow_mm2_set_coeff_bp :: proc(coeffs: ^ow_mm2_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	ow_gain_set_gain_lin(&coeffs.gain_bp_coeffs, value)
}

// Summary: Sets coeff hp for mm2.
ow_mm2_set_coeff_hp :: proc(coeffs: ^ow_mm2_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	ow_gain_set_gain_lin(&coeffs.gain_hp_coeffs, value)
}

// Summary: Checks validity of mm2 coeffs.
ow_mm2_coeffs_is_valid :: proc(coeffs: ^ow_mm2_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if ow_svf_coeffs_is_valid(&coeffs.svf_coeffs) == 0 {
		return 0
	}
	if !ow_gain_coeffs_is_valid(&coeffs.gain_x_coeffs) {
		return 0
	}
	if !ow_gain_coeffs_is_valid(&coeffs.gain_lp_coeffs) {
		return 0
	}
	if !ow_gain_coeffs_is_valid(&coeffs.gain_bp_coeffs) {
		return 0
	}
	if !ow_gain_coeffs_is_valid(&coeffs.gain_hp_coeffs) {
		return 0
	}
	return 1
}

// Summary: Checks validity of mm2 state.
ow_mm2_state_is_valid :: proc(coeffs: ^ow_mm2_coeffs, state: ^ow_mm2_state) -> i8 {
	if state == nil {
		return 0
	}
	if coeffs != nil {
		return ow_svf_state_is_valid(&coeffs.svf_coeffs, &state.svf_state)
	}
	return ow_svf_state_is_valid(nil, &state.svf_state)
}
