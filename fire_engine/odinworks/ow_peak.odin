package odinworks

OW_PEAK_PARAM_Q :: 1
OW_PEAK_PARAM_PEAK_GAIN :: 1 << 1
OW_PEAK_PARAM_BANDWIDTH :: 1 << 2

// Summary: Coefficient data for peak.
ow_peak_coeffs :: struct {
	mm2_coeffs: ow_mm2_coeffs,
	bw_k: f32,
	Q: f32,
	peak_gain: f32,
	bandwidth: f32,
	use_bandwidth: bool,
	param_changed: int,
}

// Summary: Runtime state for peak.
ow_peak_state :: struct {
	mm2_state: ow_mm2_state,
}

// Summary: Initializes peak.
ow_peak_init :: proc(coeffs: ^ow_peak_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_mm2_init(&coeffs.mm2_coeffs)
	coeffs.Q = 0.5
	coeffs.peak_gain = 1.0
	coeffs.bandwidth = 2.543106606327224
	coeffs.use_bandwidth = true
	coeffs.param_changed = -1
}

// Summary: Sets sample rate for peak.
ow_peak_set_sample_rate :: proc(coeffs: ^ow_peak_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	ow_mm2_set_sample_rate(&coeffs.mm2_coeffs, sample_rate)
}

// Summary: Executes peak update mm2 params.
ow_peak_update_mm2_params :: proc(coeffs: ^ow_peak_coeffs) {
	if coeffs.param_changed != 0 {
		if (coeffs.param_changed & OW_PEAK_PARAM_PEAK_GAIN) != 0 {
			ow_mm2_set_coeff_x(&coeffs.mm2_coeffs, coeffs.peak_gain)
			k := 1.0 - coeffs.peak_gain
			ow_mm2_set_coeff_lp(&coeffs.mm2_coeffs, k)
			ow_mm2_set_coeff_hp(&coeffs.mm2_coeffs, k)
		}
		if coeffs.use_bandwidth {
			if (coeffs.param_changed & (OW_PEAK_PARAM_PEAK_GAIN | OW_PEAK_PARAM_BANDWIDTH)) != 0 {
				if (coeffs.param_changed & OW_PEAK_PARAM_BANDWIDTH) != 0 {
					coeffs.bw_k = ow_pow2f(coeffs.bandwidth)
				}
				Q := ow_sqrtf(coeffs.bw_k*coeffs.peak_gain) * ow_rcpf(coeffs.bw_k-1.0)
				ow_mm2_set_Q(&coeffs.mm2_coeffs, Q)
			}
		} else {
			if (coeffs.param_changed & OW_PEAK_PARAM_Q) != 0 {
				ow_mm2_set_Q(&coeffs.mm2_coeffs, coeffs.Q)
			}
		}
		coeffs.param_changed = 0
	}
}

// Summary: Resets coefficients for peak.
ow_peak_reset_coeffs :: proc(coeffs: ^ow_peak_coeffs) {
	OW_ASSERT(coeffs != nil)
	coeffs.param_changed = -1
	ow_peak_update_mm2_params(coeffs)
	ow_mm2_reset_coeffs(&coeffs.mm2_coeffs)
}

// Summary: Resets state for peak.
ow_peak_reset_state :: proc(coeffs: ^ow_peak_coeffs, state: ^ow_peak_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	return ow_mm2_reset_state(&coeffs.mm2_coeffs, &state.mm2_state, x_0)
}

// Summary: Resets multi-channel state for peak.
ow_peak_reset_state_multi :: proc(coeffs: ^ow_peak_coeffs, state: ^^ow_peak_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_peak_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_peak_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for peak.
ow_peak_update_coeffs_ctrl :: proc(coeffs: ^ow_peak_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_peak_update_mm2_params(coeffs)
	ow_mm2_update_coeffs_ctrl(&coeffs.mm2_coeffs)
}

// Summary: Updates audio-rate coefficients for peak.
ow_peak_update_coeffs_audio :: proc(coeffs: ^ow_peak_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_mm2_update_coeffs_audio(&coeffs.mm2_coeffs)
}

// Summary: Processes one sample for peak.
ow_peak_process1 :: proc(coeffs: ^ow_peak_coeffs, state: ^ow_peak_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	return ow_mm2_process1(&coeffs.mm2_coeffs, &state.mm2_state, x)
}

// Summary: Processes sample buffers for peak.
ow_peak_process :: proc(coeffs: ^ow_peak_coeffs, state: ^ow_peak_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	ow_peak_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_peak_update_coeffs_audio(coeffs)
		ym[i] = ow_peak_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for peak.
ow_peak_process_multi :: proc(coeffs: ^ow_peak_coeffs, state: ^^ow_peak_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_peak_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_peak_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_peak_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_peak_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets cutoff for peak.
ow_peak_set_cutoff :: proc(coeffs: ^ow_peak_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-6 && value <= 1.0e12)
	ow_mm2_set_cutoff(&coeffs.mm2_coeffs, value)
}

// Summary: Sets Q for peak.
ow_peak_set_Q :: proc(coeffs: ^ow_peak_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-6 && value <= 1.0e6)
	if coeffs.Q != value {
		coeffs.Q = value
		coeffs.param_changed |= OW_PEAK_PARAM_Q
	}
}

// Summary: Sets prewarp at cutoff for peak.
ow_peak_set_prewarp_at_cutoff :: proc(coeffs: ^ow_peak_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	ow_mm2_set_prewarp_at_cutoff(&coeffs.mm2_coeffs, value)
}

// Summary: Sets prewarp freq for peak.
ow_peak_set_prewarp_freq :: proc(coeffs: ^ow_peak_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-6 && value <= 1.0e12)
	ow_mm2_set_prewarp_freq(&coeffs.mm2_coeffs, value)
}

// Summary: Sets peak gain lin for peak.
ow_peak_set_peak_gain_lin :: proc(coeffs: ^ow_peak_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-30 && value <= 1.0e30)
	if coeffs.peak_gain != value {
		coeffs.peak_gain = value
		coeffs.param_changed |= OW_PEAK_PARAM_PEAK_GAIN
	}
}

// Summary: Sets peak gain dB for peak.
ow_peak_set_peak_gain_dB :: proc(coeffs: ^ow_peak_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= -600.0 && value <= 600.0)
	ow_peak_set_peak_gain_lin(coeffs, ow_dB2linf(value))
}

// Summary: Sets bandwidth for peak.
ow_peak_set_bandwidth :: proc(coeffs: ^ow_peak_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-6 && value <= 90.0)
	if coeffs.bandwidth != value {
		coeffs.bandwidth = value
		coeffs.param_changed |= OW_PEAK_PARAM_BANDWIDTH
	}
}

// Summary: Sets use bandwidth for peak.
ow_peak_set_use_bandwidth :: proc(coeffs: ^ow_peak_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	b := value != 0
	if coeffs.use_bandwidth != b {
		coeffs.use_bandwidth = b
		coeffs.param_changed |= OW_PEAK_PARAM_Q | OW_PEAK_PARAM_BANDWIDTH
	}
}

// Summary: Checks validity of peak coeffs.
ow_peak_coeffs_is_valid :: proc(coeffs: ^ow_peak_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.Q) || coeffs.Q < 1.0e-6 || coeffs.Q > 1.0e6 {
		return 0
	}
	if !ow_is_finite(coeffs.peak_gain) || coeffs.peak_gain < 1.0e-30 || coeffs.peak_gain > 1.0e30 {
		return 0
	}
	if !ow_is_finite(coeffs.bandwidth) || coeffs.bandwidth < 1.0e-6 || coeffs.bandwidth > 90.0 {
		return 0
	}
	return ow_mm2_coeffs_is_valid(&coeffs.mm2_coeffs)
}

// Summary: Checks validity of peak state.
ow_peak_state_is_valid :: proc(coeffs: ^ow_peak_coeffs, state: ^ow_peak_state) -> i8 {
	if state == nil {
		return 0
	}
	if coeffs != nil {
		return ow_mm2_state_is_valid(&coeffs.mm2_coeffs, &state.mm2_state)
	}
	return ow_mm2_state_is_valid(nil, &state.mm2_state)
}
