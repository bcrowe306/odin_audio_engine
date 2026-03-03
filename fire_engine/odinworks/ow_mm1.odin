package odinworks

// Summary: Coefficient data for mm1.
ow_mm1_coeffs :: struct {
	lp1_coeffs: ow_lp1_coeffs,
	gain_x_coeffs: ow_gain_coeffs,
	gain_lp_coeffs: ow_gain_coeffs,
}

// Summary: Runtime state for mm1.
ow_mm1_state :: struct {
	lp1_state: ow_lp1_state,
}

// Summary: Initializes mm1.
ow_mm1_init :: proc(coeffs: ^ow_mm1_coeffs) {
	OW_ASSERT(coeffs != nil)

	ow_lp1_init(&coeffs.lp1_coeffs)
	ow_gain_init(&coeffs.gain_x_coeffs)
	ow_gain_init(&coeffs.gain_lp_coeffs)
	ow_gain_set_smooth_tau(&coeffs.gain_x_coeffs, 0.005)
	ow_gain_set_smooth_tau(&coeffs.gain_lp_coeffs, 0.005)
	ow_gain_set_gain_lin(&coeffs.gain_x_coeffs, 1.0)
	ow_gain_set_gain_lin(&coeffs.gain_lp_coeffs, 0.0)
}

// Summary: Sets sample rate for mm1.
ow_mm1_set_sample_rate :: proc(coeffs: ^ow_mm1_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)

	ow_lp1_set_sample_rate(&coeffs.lp1_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.gain_x_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.gain_lp_coeffs, sample_rate)
}

// Summary: Resets coefficients for mm1.
ow_mm1_reset_coeffs :: proc(coeffs: ^ow_mm1_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_lp1_reset_coeffs(&coeffs.lp1_coeffs)
	ow_gain_reset_coeffs(&coeffs.gain_x_coeffs)
	ow_gain_reset_coeffs(&coeffs.gain_lp_coeffs)
}

// Summary: Resets state for mm1.
ow_mm1_reset_state :: proc(coeffs: ^ow_mm1_coeffs, state: ^ow_mm1_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))

	lp := ow_lp1_reset_state(&coeffs.lp1_coeffs, &state.lp1_state, x_0)
	return ow_gain_get_gain_cur(&coeffs.gain_x_coeffs)*x_0 + ow_gain_get_gain_cur(&coeffs.gain_lp_coeffs)*lp
}

// Summary: Resets multi-channel state for mm1.
ow_mm1_reset_state_multi :: proc(coeffs: ^ow_mm1_coeffs, state: ^^ow_mm1_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)

	states := ([^]^ow_mm1_state)(state)
	x0 := ([^]f32)(x_0)

	if y_0 != nil {
		y0 := ([^]f32)(y_0)
		for i := 0; i < n_channels; i += 1 {
			y0[i] = ow_mm1_reset_state(coeffs, states[i], x0[i])
		}
	} else {
		for i := 0; i < n_channels; i += 1 {
			_ = ow_mm1_reset_state(coeffs, states[i], x0[i])
		}
	}
}

// Summary: Updates control-rate coefficients for mm1.
ow_mm1_update_coeffs_ctrl :: proc(coeffs: ^ow_mm1_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_lp1_update_coeffs_ctrl(&coeffs.lp1_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.gain_x_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.gain_lp_coeffs)
}

// Summary: Updates audio-rate coefficients for mm1.
ow_mm1_update_coeffs_audio :: proc(coeffs: ^ow_mm1_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_lp1_update_coeffs_audio(&coeffs.lp1_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.gain_x_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.gain_lp_coeffs)
}

// Summary: Processes one sample for mm1.
ow_mm1_process1 :: proc(coeffs: ^ow_mm1_coeffs, state: ^ow_mm1_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))

	lp := ow_lp1_process1(&coeffs.lp1_coeffs, &state.lp1_state, x)
	vx := ow_gain_process1(&coeffs.gain_x_coeffs, x)
	vlp := ow_gain_process1(&coeffs.gain_lp_coeffs, lp)
	return vx + vlp
}

// Summary: Processes sample buffers for mm1.
ow_mm1_process :: proc(coeffs: ^ow_mm1_coeffs, state: ^ow_mm1_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)

	xm := ([^]f32)(x)
	ym := ([^]f32)(y)

	ow_mm1_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_mm1_update_coeffs_audio(coeffs)
		ym[i] = ow_mm1_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for mm1.
ow_mm1_process_multi :: proc(coeffs: ^ow_mm1_coeffs, state: ^^ow_mm1_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)

	states := ([^]^ow_mm1_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)

	ow_mm1_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_mm1_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_mm1_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets cutoff for mm1.
ow_mm1_set_cutoff :: proc(coeffs: ^ow_mm1_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	ow_lp1_set_cutoff(&coeffs.lp1_coeffs, value)
}

// Summary: Sets prewarp at cutoff for mm1.
ow_mm1_set_prewarp_at_cutoff :: proc(coeffs: ^ow_mm1_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	ow_lp1_set_prewarp_at_cutoff(&coeffs.lp1_coeffs, value)
}

// Summary: Sets prewarp freq for mm1.
ow_mm1_set_prewarp_freq :: proc(coeffs: ^ow_mm1_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	ow_lp1_set_prewarp_freq(&coeffs.lp1_coeffs, value)
}

// Summary: Sets coeff x for mm1.
ow_mm1_set_coeff_x :: proc(coeffs: ^ow_mm1_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	ow_gain_set_gain_lin(&coeffs.gain_x_coeffs, value)
}

// Summary: Sets coeff lp for mm1.
ow_mm1_set_coeff_lp :: proc(coeffs: ^ow_mm1_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	ow_gain_set_gain_lin(&coeffs.gain_lp_coeffs, value)
}

// Summary: Checks validity of mm1 coeffs.
ow_mm1_coeffs_is_valid :: proc(coeffs: ^ow_mm1_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if ow_lp1_coeffs_is_valid(&coeffs.lp1_coeffs) == 0 {
		return 0
	}
	if !ow_gain_coeffs_is_valid(&coeffs.gain_x_coeffs) {
		return 0
	}
	if !ow_gain_coeffs_is_valid(&coeffs.gain_lp_coeffs) {
		return 0
	}
	return 1
}

// Summary: Checks validity of mm1 state.
ow_mm1_state_is_valid :: proc(coeffs: ^ow_mm1_coeffs, state: ^ow_mm1_state) -> i8 {
	if state == nil {
		return 0
	}
	if coeffs != nil {
		return ow_lp1_state_is_valid(&coeffs.lp1_coeffs, &state.lp1_state)
	}
	return ow_lp1_state_is_valid(nil, &state.lp1_state)
}
