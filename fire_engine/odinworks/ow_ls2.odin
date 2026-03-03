package odinworks

OW_LS2_PARAM_CUTOFF :: 1
OW_LS2_PARAM_DC_GAIN :: 1 << 1

// Summary: Coefficient data for ls2.
ow_ls2_coeffs :: struct {
	mm2_coeffs: ow_mm2_coeffs,
	sg: f32,
	issg: f32,
	cutoff: f32,
	prewarp_k: f32,
	prewarp_freq: f32,
	dc_gain: f32,
	param_changed: int,
}

// Summary: Runtime state for ls2.
ow_ls2_state :: struct {
	mm2_state: ow_mm2_state,
}

// Summary: Initializes ls2.
ow_ls2_init :: proc(coeffs: ^ow_ls2_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_mm2_init(&coeffs.mm2_coeffs)
	ow_mm2_set_prewarp_at_cutoff(&coeffs.mm2_coeffs, 0)
	coeffs.cutoff = 1.0e3
	coeffs.prewarp_k = 1.0
	coeffs.prewarp_freq = 1.0
	coeffs.dc_gain = 1.0
	coeffs.param_changed = -1
}

// Summary: Sets sample rate for ls2.
ow_ls2_set_sample_rate :: proc(coeffs: ^ow_ls2_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	ow_mm2_set_sample_rate(&coeffs.mm2_coeffs, sample_rate)
}

// Summary: Executes ls2 update mm2 params.
ow_ls2_update_mm2_params :: proc(coeffs: ^ow_ls2_coeffs) {
	ow_mm2_set_prewarp_freq(&coeffs.mm2_coeffs, coeffs.prewarp_freq+coeffs.prewarp_k*(coeffs.cutoff-coeffs.prewarp_freq))
	if coeffs.param_changed != 0 {
		if (coeffs.param_changed & OW_LS2_PARAM_DC_GAIN) != 0 {
			coeffs.sg = ow_sqrtf(coeffs.dc_gain)
			coeffs.issg = ow_rcpf(ow_sqrtf(coeffs.sg))
			ow_mm2_set_coeff_x(&coeffs.mm2_coeffs, coeffs.sg)
			ow_mm2_set_coeff_lp(&coeffs.mm2_coeffs, coeffs.dc_gain-coeffs.sg)
			ow_mm2_set_coeff_hp(&coeffs.mm2_coeffs, 1.0-coeffs.sg)
		}
		ow_mm2_set_cutoff(&coeffs.mm2_coeffs, coeffs.cutoff*coeffs.issg)
		coeffs.param_changed = 0
	}
}

// Summary: Resets coefficients for ls2.
ow_ls2_reset_coeffs :: proc(coeffs: ^ow_ls2_coeffs) {
	OW_ASSERT(coeffs != nil)
	coeffs.param_changed = -1
	ow_ls2_update_mm2_params(coeffs)
	ow_mm2_reset_coeffs(&coeffs.mm2_coeffs)
}

// Summary: Resets state for ls2.
ow_ls2_reset_state :: proc(coeffs: ^ow_ls2_coeffs, state: ^ow_ls2_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	return ow_mm2_reset_state(&coeffs.mm2_coeffs, &state.mm2_state, x_0)
}

// Summary: Resets multi-channel state for ls2.
ow_ls2_reset_state_multi :: proc(coeffs: ^ow_ls2_coeffs, state: ^^ow_ls2_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_ls2_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_ls2_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for ls2.
ow_ls2_update_coeffs_ctrl :: proc(coeffs: ^ow_ls2_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_ls2_update_mm2_params(coeffs)
	ow_mm2_update_coeffs_ctrl(&coeffs.mm2_coeffs)
}

// Summary: Updates audio-rate coefficients for ls2.
ow_ls2_update_coeffs_audio :: proc(coeffs: ^ow_ls2_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_mm2_update_coeffs_audio(&coeffs.mm2_coeffs)
}

// Summary: Processes one sample for ls2.
ow_ls2_process1 :: proc(coeffs: ^ow_ls2_coeffs, state: ^ow_ls2_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	return ow_mm2_process1(&coeffs.mm2_coeffs, &state.mm2_state, x)
}

// Summary: Processes sample buffers for ls2.
ow_ls2_process :: proc(coeffs: ^ow_ls2_coeffs, state: ^ow_ls2_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	ow_ls2_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_ls2_update_coeffs_audio(coeffs)
		ym[i] = ow_ls2_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for ls2.
ow_ls2_process_multi :: proc(coeffs: ^ow_ls2_coeffs, state: ^^ow_ls2_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_ls2_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_ls2_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_ls2_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_ls2_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets cutoff for ls2.
ow_ls2_set_cutoff :: proc(coeffs: ^ow_ls2_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value > 0.0)
	if coeffs.cutoff != value {
		coeffs.cutoff = value
		coeffs.param_changed |= OW_LS2_PARAM_CUTOFF
	}
}

// Summary: Sets Q for ls2.
ow_ls2_set_Q :: proc(coeffs: ^ow_ls2_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-6 && value <= 1.0e6)
	ow_mm2_set_Q(&coeffs.mm2_coeffs, value)
}

// Summary: Sets prewarp at cutoff for ls2.
ow_ls2_set_prewarp_at_cutoff :: proc(coeffs: ^ow_ls2_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	ow_mm2_set_prewarp_at_cutoff(&coeffs.mm2_coeffs, value)
}

// Summary: Sets prewarp freq for ls2.
ow_ls2_set_prewarp_freq :: proc(coeffs: ^ow_ls2_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-6 && value <= 1.0e12)
	coeffs.prewarp_freq = value
}

// Summary: Sets dc gain lin for ls2.
ow_ls2_set_dc_gain_lin :: proc(coeffs: ^ow_ls2_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-30 && value <= 1.0e30)
	if coeffs.dc_gain != value {
		coeffs.dc_gain = value
		coeffs.param_changed |= OW_LS2_PARAM_DC_GAIN
	}
}

// Summary: Sets dc gain dB for ls2.
ow_ls2_set_dc_gain_dB :: proc(coeffs: ^ow_ls2_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= -600.0 && value <= 600.0)
	ow_ls2_set_dc_gain_lin(coeffs, ow_dB2linf(value))
}

// Summary: Checks validity of ls2 coeffs.
ow_ls2_coeffs_is_valid :: proc(coeffs: ^ow_ls2_coeffs) -> i8 {
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
	if !ow_is_finite(coeffs.dc_gain) || coeffs.dc_gain < 1.0e-30 || coeffs.dc_gain > 1.0e30 {
		return 0
	}
	return ow_mm2_coeffs_is_valid(&coeffs.mm2_coeffs)
}

// Summary: Checks validity of ls2 state.
ow_ls2_state_is_valid :: proc(coeffs: ^ow_ls2_coeffs, state: ^ow_ls2_state) -> i8 {
	if state == nil {
		return 0
	}
	if coeffs != nil {
		return ow_mm2_state_is_valid(&coeffs.mm2_coeffs, &state.mm2_state)
	}
	return ow_mm2_state_is_valid(nil, &state.mm2_state)
}
