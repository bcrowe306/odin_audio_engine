package odinworks

// Summary: Coefficient data for hs1.
ow_hs1_coeffs :: struct {
	mm1_coeffs: ow_mm1_coeffs,
	cutoff: f32,
	prewarp_k: f32,
	prewarp_freq: f32,
	high_gain: f32,
	update: bool,
}

// Summary: Runtime state for hs1.
ow_hs1_state :: struct {
	mm1_state: ow_mm1_state,
}

// Summary: Initializes hs1.
ow_hs1_init :: proc(coeffs: ^ow_hs1_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_mm1_init(&coeffs.mm1_coeffs)
	ow_mm1_set_prewarp_at_cutoff(&coeffs.mm1_coeffs, 0)
	ow_mm1_set_coeff_x(&coeffs.mm1_coeffs, 1.0)
	ow_mm1_set_coeff_lp(&coeffs.mm1_coeffs, 0.0)
	coeffs.cutoff = 1.0e3
	coeffs.prewarp_k = 1.0
	coeffs.prewarp_freq = 1.0e3
	coeffs.high_gain = 1.0
	coeffs.update = true
}

// Summary: Sets sample rate for hs1.
ow_hs1_set_sample_rate :: proc(coeffs: ^ow_hs1_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	ow_mm1_set_sample_rate(&coeffs.mm1_coeffs, sample_rate)
}

// Summary: Executes hs1 update mm1 params.
ow_hs1_update_mm1_params :: proc(coeffs: ^ow_hs1_coeffs) {
	ow_mm1_set_prewarp_freq(&coeffs.mm1_coeffs, coeffs.prewarp_freq+coeffs.prewarp_k*(coeffs.cutoff-coeffs.prewarp_freq))
	if coeffs.update {
		ow_mm1_set_cutoff(&coeffs.mm1_coeffs, coeffs.cutoff*ow_sqrtf(coeffs.high_gain))
		ow_mm1_set_coeff_x(&coeffs.mm1_coeffs, coeffs.high_gain)
		ow_mm1_set_coeff_lp(&coeffs.mm1_coeffs, 1.0-coeffs.high_gain)
		coeffs.update = false
	}
}

// Summary: Resets coefficients for hs1.
ow_hs1_reset_coeffs :: proc(coeffs: ^ow_hs1_coeffs) {
	OW_ASSERT(coeffs != nil)
	coeffs.update = true
	ow_hs1_update_mm1_params(coeffs)
	ow_mm1_reset_coeffs(&coeffs.mm1_coeffs)
}

// Summary: Resets state for hs1.
ow_hs1_reset_state :: proc(coeffs: ^ow_hs1_coeffs, state: ^ow_hs1_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	return ow_mm1_reset_state(&coeffs.mm1_coeffs, &state.mm1_state, x_0)
}

// Summary: Resets multi-channel state for hs1.
ow_hs1_reset_state_multi :: proc(coeffs: ^ow_hs1_coeffs, state: ^^ow_hs1_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_hs1_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_hs1_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for hs1.
ow_hs1_update_coeffs_ctrl :: proc(coeffs: ^ow_hs1_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_hs1_update_mm1_params(coeffs)
	ow_mm1_update_coeffs_ctrl(&coeffs.mm1_coeffs)
}

// Summary: Updates audio-rate coefficients for hs1.
ow_hs1_update_coeffs_audio :: proc(coeffs: ^ow_hs1_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_mm1_update_coeffs_audio(&coeffs.mm1_coeffs)
}

// Summary: Processes one sample for hs1.
ow_hs1_process1 :: proc(coeffs: ^ow_hs1_coeffs, state: ^ow_hs1_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	return ow_mm1_process1(&coeffs.mm1_coeffs, &state.mm1_state, x)
}

// Summary: Processes sample buffers for hs1.
ow_hs1_process :: proc(coeffs: ^ow_hs1_coeffs, state: ^ow_hs1_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	ow_hs1_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_hs1_update_coeffs_audio(coeffs)
		ym[i] = ow_hs1_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for hs1.
ow_hs1_process_multi :: proc(coeffs: ^ow_hs1_coeffs, state: ^^ow_hs1_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_hs1_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_hs1_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_hs1_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_hs1_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets cutoff for hs1.
ow_hs1_set_cutoff :: proc(coeffs: ^ow_hs1_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value > 0.0)
	if value != coeffs.cutoff {
		coeffs.cutoff = value
		coeffs.update = true
	}
}

// Summary: Sets prewarp at cutoff for hs1.
ow_hs1_set_prewarp_at_cutoff :: proc(coeffs: ^ow_hs1_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	coeffs.prewarp_k = 0.0
	if value != 0 {
		coeffs.prewarp_k = 1.0
	}
}

// Summary: Sets prewarp freq for hs1.
ow_hs1_set_prewarp_freq :: proc(coeffs: ^ow_hs1_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-6 && value <= 1.0e12)
	coeffs.prewarp_freq = value
}

// Summary: Sets high gain lin for hs1.
ow_hs1_set_high_gain_lin :: proc(coeffs: ^ow_hs1_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-30 && value <= 1.0e30)
	if value != coeffs.high_gain {
		coeffs.high_gain = value
		coeffs.update = true
	}
}

// Summary: Sets high gain dB for hs1.
ow_hs1_set_high_gain_dB :: proc(coeffs: ^ow_hs1_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= -600.0 && value <= 600.0)
	ow_hs1_set_high_gain_lin(coeffs, ow_dB2linf(value))
}

// Summary: Checks validity of hs1 coeffs.
ow_hs1_coeffs_is_valid :: proc(coeffs: ^ow_hs1_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.cutoff) || coeffs.cutoff <= 0.0 {
		return 0
	}
	if !ow_is_finite(coeffs.prewarp_k) || (coeffs.prewarp_k != 0.0 && coeffs.prewarp_k != 1.0) {
		return 0
	}
	if !ow_is_finite(coeffs.prewarp_freq) || coeffs.prewarp_freq < 1.0e-6 || coeffs.prewarp_freq > 1.0e12 {
		return 0
	}
	if !ow_is_finite(coeffs.high_gain) || coeffs.high_gain < 1.0e-30 || coeffs.high_gain > 1.0e30 {
		return 0
	}
	return ow_mm1_coeffs_is_valid(&coeffs.mm1_coeffs)
}

// Summary: Checks validity of hs1 state.
ow_hs1_state_is_valid :: proc(coeffs: ^ow_hs1_coeffs, state: ^ow_hs1_state) -> i8 {
	if state == nil {
		return 0
	}
	if coeffs != nil {
		return ow_mm1_state_is_valid(&coeffs.mm1_coeffs, &state.mm1_state)
	}
	return ow_mm1_state_is_valid(nil, &state.mm1_state)
}
