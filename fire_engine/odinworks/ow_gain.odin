package odinworks

// Summary: Enumeration for gain sticky mode.
ow_gain_sticky_mode :: enum {
	abs,
	rel,
}

// Summary: Coefficient data for gain.
ow_gain_coeffs :: struct {
	smooth_coeffs: ow_one_pole_coeffs,
	smooth_state: ow_one_pole_state,
	gain: f32,
}

// Summary: Initializes gain.
ow_gain_init :: proc(coeffs: ^ow_gain_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_init(&coeffs.smooth_coeffs)
	ow_one_pole_set_tau(&coeffs.smooth_coeffs, 0.05)
	coeffs.gain = 1.0
}

// Summary: Sets sample rate for gain.
ow_gain_set_sample_rate :: proc(coeffs: ^ow_gain_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_one_pole_set_sample_rate(&coeffs.smooth_coeffs, sample_rate)
}

// Summary: Resets coefficients for gain.
ow_gain_reset_coeffs :: proc(coeffs: ^ow_gain_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_reset_coeffs(&coeffs.smooth_coeffs)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_state, coeffs.gain)
}

// Summary: Updates control-rate coefficients for gain.
ow_gain_update_coeffs_ctrl :: proc(coeffs: ^ow_gain_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_update_coeffs_ctrl(&coeffs.smooth_coeffs)
}

// Summary: Updates audio-rate coefficients for gain.
ow_gain_update_coeffs_audio :: proc(coeffs: ^ow_gain_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_update_coeffs_audio(&coeffs.smooth_coeffs)
	_ = ow_one_pole_process1(&coeffs.smooth_coeffs, &coeffs.smooth_state, coeffs.gain)
}

// Summary: Executes gain update coeffs audio sticky abs.
ow_gain_update_coeffs_audio_sticky_abs :: proc(coeffs: ^ow_gain_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_update_coeffs_audio(&coeffs.smooth_coeffs)
	_ = ow_one_pole_process1_sticky_abs(&coeffs.smooth_coeffs, &coeffs.smooth_state, coeffs.gain)
}

// Summary: Executes gain update coeffs audio sticky rel.
ow_gain_update_coeffs_audio_sticky_rel :: proc(coeffs: ^ow_gain_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_update_coeffs_audio(&coeffs.smooth_coeffs)
	_ = ow_one_pole_process1_sticky_rel(&coeffs.smooth_coeffs, &coeffs.smooth_state, coeffs.gain)
}

// Summary: Processes one sample for gain.
ow_gain_process1 :: proc(coeffs: ^ow_gain_coeffs, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(x))
	return ow_one_pole_get_y_z1(&coeffs.smooth_state) * x
}

// Summary: Processes sample buffers for gain.
ow_gain_process :: proc(coeffs: ^ow_gain_coeffs, x: [^]f32, y: [^]f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)

	ow_gain_update_coeffs_ctrl(coeffs)
	sticky_thresh := ow_one_pole_get_sticky_thresh(&coeffs.smooth_coeffs)
	sticky_mode := ow_one_pole_get_sticky_mode(&coeffs.smooth_coeffs)

	for i := 0; i < n_samples; i += 1 {
		if sticky_thresh == 0.0 {
			ow_gain_update_coeffs_audio(coeffs)
		} else if sticky_mode == .abs {
			ow_gain_update_coeffs_audio_sticky_abs(coeffs)
		} else {
			ow_gain_update_coeffs_audio_sticky_rel(coeffs)
		}
		y[i] = ow_gain_process1(coeffs, x[i])
	}
}

// Summary: Processes multiple channels for gain.
ow_gain_process_multi :: proc(coeffs: ^ow_gain_coeffs, x: [^][^]f32, y: [^][^]f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)

	ow_gain_update_coeffs_ctrl(coeffs)
	sticky_thresh := ow_one_pole_get_sticky_thresh(&coeffs.smooth_coeffs)
	sticky_mode := ow_one_pole_get_sticky_mode(&coeffs.smooth_coeffs)

	for i := 0; i < n_samples; i += 1 {
		if sticky_thresh == 0.0 {
			ow_gain_update_coeffs_audio(coeffs)
		} else if sticky_mode == .abs {
			ow_gain_update_coeffs_audio_sticky_abs(coeffs)
		} else {
			ow_gain_update_coeffs_audio_sticky_rel(coeffs)
		}

		for ch := 0; ch < n_channels; ch += 1 {
			y[ch][i] = ow_gain_process1(coeffs, x[ch][i])
		}
	}
}

// Summary: Sets gain lin for gain.
ow_gain_set_gain_lin :: proc(coeffs: ^ow_gain_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	coeffs.gain = value
}

// Summary: Sets gain dB for gain.
ow_gain_set_gain_dB :: proc(coeffs: ^ow_gain_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value))
	OW_ASSERT(value <= 770.630)
	coeffs.gain = ow_dB2linf(value)
}

// Summary: Sets smooth tau for gain.
ow_gain_set_smooth_tau :: proc(coeffs: ^ow_gain_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value) && value >= 0.0)
	ow_one_pole_set_tau(&coeffs.smooth_coeffs, value)
}

// Summary: Sets sticky thresh for gain.
ow_gain_set_sticky_thresh :: proc(coeffs: ^ow_gain_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value) && value >= 0.0 && value <= 1.0e18)
	ow_one_pole_set_sticky_thresh(&coeffs.smooth_coeffs, value)
}

// Summary: Sets sticky mode for gain.
ow_gain_set_sticky_mode :: proc(coeffs: ^ow_gain_coeffs, value: ow_gain_sticky_mode) {
	OW_ASSERT(coeffs != nil)
	if value == .abs {
		ow_one_pole_set_sticky_mode(&coeffs.smooth_coeffs, .abs)
	} else {
		ow_one_pole_set_sticky_mode(&coeffs.smooth_coeffs, .rel)
	}
}

// Summary: Gets gain lin from gain.
ow_gain_get_gain_lin :: proc(coeffs: ^ow_gain_coeffs) -> f32 {
	OW_ASSERT(coeffs != nil)
	return coeffs.gain
}

// Summary: Gets gain cur from gain.
ow_gain_get_gain_cur :: proc(coeffs: ^ow_gain_coeffs) -> f32 {
	OW_ASSERT(coeffs != nil)
	return ow_one_pole_get_y_z1(&coeffs.smooth_state)
}

// Summary: Checks validity of gain coeffs.
ow_gain_coeffs_is_valid :: proc(coeffs: ^ow_gain_coeffs) -> bool {
	if coeffs == nil {
		return false
	}
	if !ow_is_finite(coeffs.gain) {
		return false
	}
	if !ow_one_pole_coeffs_is_valid(&coeffs.smooth_coeffs) {
		return false
	}
	if !ow_one_pole_state_is_valid(&coeffs.smooth_coeffs, &coeffs.smooth_state) {
		return false
	}
	return true
}
