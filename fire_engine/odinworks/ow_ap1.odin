package odinworks

// Summary: Coefficient data for ap1.
ow_ap1_coeffs :: struct {
	lp1_coeffs: ow_lp1_coeffs,
}

// Summary: Runtime state for ap1.
ow_ap1_state :: struct {
	lp1_state: ow_lp1_state,
}

// Summary: Initializes ap1.
ow_ap1_init :: proc(coeffs: ^ow_ap1_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_lp1_init(&coeffs.lp1_coeffs)
}

// Summary: Sets sample rate for ap1.
ow_ap1_set_sample_rate :: proc(coeffs: ^ow_ap1_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_lp1_set_sample_rate(&coeffs.lp1_coeffs, sample_rate)
}

// Summary: Resets coefficients for ap1.
ow_ap1_reset_coeffs :: proc(coeffs: ^ow_ap1_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_lp1_reset_coeffs(&coeffs.lp1_coeffs)
}

// Summary: Resets state for ap1.
ow_ap1_reset_state :: proc(coeffs: ^ow_ap1_coeffs, state: ^ow_ap1_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	lp := ow_lp1_reset_state(&coeffs.lp1_coeffs, &state.lp1_state, x_0)
	return lp + lp - x_0
}

// Summary: Resets multi-channel state for ap1.
ow_ap1_reset_state_multi :: proc(coeffs: ^ow_ap1_coeffs, state: ^^ow_ap1_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)

	states := ([^]^ow_ap1_state)(state)
	x0 := ([^]f32)(x_0)

	if y_0 != nil {
		y0 := ([^]f32)(y_0)
		for i := 0; i < n_channels; i += 1 {
			y0[i] = ow_ap1_reset_state(coeffs, states[i], x0[i])
		}
	} else {
		for i := 0; i < n_channels; i += 1 {
			_ = ow_ap1_reset_state(coeffs, states[i], x0[i])
		}
	}
}

// Summary: Updates control-rate coefficients for ap1.
ow_ap1_update_coeffs_ctrl :: proc(coeffs: ^ow_ap1_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_lp1_update_coeffs_ctrl(&coeffs.lp1_coeffs)
}

// Summary: Updates audio-rate coefficients for ap1.
ow_ap1_update_coeffs_audio :: proc(coeffs: ^ow_ap1_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_lp1_update_coeffs_audio(&coeffs.lp1_coeffs)
}

// Summary: Processes one sample for ap1.
ow_ap1_process1 :: proc(coeffs: ^ow_ap1_coeffs, state: ^ow_ap1_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	lp := ow_lp1_process1(&coeffs.lp1_coeffs, &state.lp1_state, x)
	return lp + lp - x
}

// Summary: Processes sample buffers for ap1.
ow_ap1_process :: proc(coeffs: ^ow_ap1_coeffs, state: ^ow_ap1_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)

	xm := ([^]f32)(x)
	ym := ([^]f32)(y)

	ow_ap1_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_ap1_update_coeffs_audio(coeffs)
		ym[i] = ow_ap1_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for ap1.
ow_ap1_process_multi :: proc(coeffs: ^ow_ap1_coeffs, state: ^^ow_ap1_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)

	states := ([^]^ow_ap1_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)

	ow_ap1_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_ap1_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_ap1_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets cutoff for ap1.
ow_ap1_set_cutoff :: proc(coeffs: ^ow_ap1_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	ow_lp1_set_cutoff(&coeffs.lp1_coeffs, value)
}

// Summary: Sets prewarp at cutoff for ap1.
ow_ap1_set_prewarp_at_cutoff :: proc(coeffs: ^ow_ap1_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	ow_lp1_set_prewarp_at_cutoff(&coeffs.lp1_coeffs, value)
}

// Summary: Sets prewarp freq for ap1.
ow_ap1_set_prewarp_freq :: proc(coeffs: ^ow_ap1_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	ow_lp1_set_prewarp_freq(&coeffs.lp1_coeffs, value)
}

// Summary: Checks validity of ap1 coeffs.
ow_ap1_coeffs_is_valid :: proc(coeffs: ^ow_ap1_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	return ow_lp1_coeffs_is_valid(&coeffs.lp1_coeffs)
}

// Summary: Checks validity of ap1 state.
ow_ap1_state_is_valid :: proc(coeffs: ^ow_ap1_coeffs, state: ^ow_ap1_state) -> i8 {
	if state == nil {
		return 0
	}
	if coeffs != nil {
		return ow_lp1_state_is_valid(&coeffs.lp1_coeffs, &state.lp1_state)
	}
	return ow_lp1_state_is_valid(nil, &state.lp1_state)
}
