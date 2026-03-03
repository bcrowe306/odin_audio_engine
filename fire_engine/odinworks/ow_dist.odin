package odinworks

// Summary: Coefficient data for dist.
ow_dist_coeffs :: struct {
	hp1_coeffs: ow_hp1_coeffs,
	peak_coeffs: ow_peak_coeffs,
	clip_coeffs: ow_clip_coeffs,
	satur_coeffs: ow_satur_coeffs,
	lp1_coeffs: ow_lp1_coeffs,
	gain_coeffs: ow_gain_coeffs,
}

// Summary: Runtime state for dist.
ow_dist_state :: struct {
	hp1_state: ow_hp1_state,
	peak_state: ow_peak_state,
	clip_state: ow_clip_state,
	satur_state: ow_satur_state,
	lp1_state: ow_lp1_state,
}

// Summary: Initializes dist.
ow_dist_init :: proc(coeffs: ^ow_dist_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_hp1_init(&coeffs.hp1_coeffs)
	ow_peak_init(&coeffs.peak_coeffs)
	ow_clip_init(&coeffs.clip_coeffs)
	ow_satur_init(&coeffs.satur_coeffs)
	ow_lp1_init(&coeffs.lp1_coeffs)
	ow_gain_init(&coeffs.gain_coeffs)
	ow_hp1_set_cutoff(&coeffs.hp1_coeffs, 7.0)
	ow_peak_set_cutoff(&coeffs.peak_coeffs, 2.0e3)
	ow_peak_set_bandwidth(&coeffs.peak_coeffs, 10.0)
	ow_clip_set_bias(&coeffs.clip_coeffs, 0.75/4.25)
	ow_clip_set_gain(&coeffs.clip_coeffs, 1.0/4.25)
	ow_clip_set_gain_compensation(&coeffs.clip_coeffs, 1)
	ow_satur_set_gain(&coeffs.satur_coeffs, 1.0/0.7)
	ow_satur_set_gain_compensation(&coeffs.satur_coeffs, 1)
	ow_lp1_set_cutoff(&coeffs.lp1_coeffs, 475.0+(20.0e3-475.0)*0.125)
}

// Summary: Sets sample rate for dist.
ow_dist_set_sample_rate :: proc(coeffs: ^ow_dist_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_hp1_set_sample_rate(&coeffs.hp1_coeffs, sample_rate)
	ow_peak_set_sample_rate(&coeffs.peak_coeffs, sample_rate)
	ow_clip_set_sample_rate(&coeffs.clip_coeffs, sample_rate)
	ow_satur_set_sample_rate(&coeffs.satur_coeffs, sample_rate)
	ow_lp1_set_sample_rate(&coeffs.lp1_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.gain_coeffs, sample_rate)
	ow_hp1_reset_coeffs(&coeffs.hp1_coeffs)
	ow_clip_reset_coeffs(&coeffs.clip_coeffs)
	ow_satur_reset_coeffs(&coeffs.satur_coeffs)
}

// Summary: Resets coefficients for dist.
ow_dist_reset_coeffs :: proc(coeffs: ^ow_dist_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_peak_reset_coeffs(&coeffs.peak_coeffs)
	ow_lp1_reset_coeffs(&coeffs.lp1_coeffs)
	ow_gain_reset_coeffs(&coeffs.gain_coeffs)
}

// Summary: Resets state for dist.
ow_dist_reset_state :: proc(coeffs: ^ow_dist_coeffs, state: ^ow_dist_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	y := ow_hp1_reset_state(&coeffs.hp1_coeffs, &state.hp1_state, x_0)
	y = ow_peak_reset_state(&coeffs.peak_coeffs, &state.peak_state, y)
	y = ow_clip_reset_state(&coeffs.clip_coeffs, &state.clip_state, y)
	y = ow_satur_reset_state(&coeffs.satur_coeffs, &state.satur_state, y)
	y = ow_lp1_reset_state(&coeffs.lp1_coeffs, &state.lp1_state, y)
	y = ow_gain_get_gain_cur(&coeffs.gain_coeffs) * y
	return y
}

// Summary: Resets multi-channel state for dist.
ow_dist_reset_state_multi :: proc(coeffs: ^ow_dist_coeffs, state: ^^ow_dist_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_dist_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_dist_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for dist.
ow_dist_update_coeffs_ctrl :: proc(coeffs: ^ow_dist_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_peak_update_coeffs_ctrl(&coeffs.peak_coeffs)
	ow_lp1_update_coeffs_ctrl(&coeffs.lp1_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.gain_coeffs)
}

// Summary: Updates audio-rate coefficients for dist.
ow_dist_update_coeffs_audio :: proc(coeffs: ^ow_dist_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_peak_update_coeffs_audio(&coeffs.peak_coeffs)
	ow_lp1_update_coeffs_audio(&coeffs.lp1_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.gain_coeffs)
}

// Summary: Processes one sample for dist.
ow_dist_process1 :: proc(coeffs: ^ow_dist_coeffs, state: ^ow_dist_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	y := ow_hp1_process1(&coeffs.hp1_coeffs, &state.hp1_state, x)
	y = ow_peak_process1(&coeffs.peak_coeffs, &state.peak_state, y)
	y = ow_clip_process1_comp(&coeffs.clip_coeffs, &state.clip_state, y)
	y = ow_satur_process1_comp(&coeffs.satur_coeffs, &state.satur_state, y)
	y = ow_lp1_process1(&coeffs.lp1_coeffs, &state.lp1_state, y)
	y = ow_gain_process1(&coeffs.gain_coeffs, y)
	return y
}

// Summary: Processes sample buffers for dist.
ow_dist_process :: proc(coeffs: ^ow_dist_coeffs, state: ^ow_dist_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	ow_dist_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_dist_update_coeffs_audio(coeffs)
		ym[i] = ow_dist_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for dist.
ow_dist_process_multi :: proc(coeffs: ^ow_dist_coeffs, state: ^^ow_dist_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_dist_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_dist_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_dist_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_dist_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets distortion for dist.
ow_dist_set_distortion :: proc(coeffs: ^ow_dist_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0 && value <= 1.0)
	ow_peak_set_peak_gain_dB(&coeffs.peak_coeffs, 60.0*value)
}

// Summary: Sets tone for dist.
ow_dist_set_tone :: proc(coeffs: ^ow_dist_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0 && value <= 1.0)
	ow_lp1_set_cutoff(&coeffs.lp1_coeffs, 475.0+(20.0e3-475.0)*value*value*value)
}

// Summary: Sets volume for dist.
ow_dist_set_volume :: proc(coeffs: ^ow_dist_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0 && value <= 1.0)
	ow_gain_set_gain_lin(&coeffs.gain_coeffs, value*value*value)
}

// Summary: Checks validity of dist coeffs.
ow_dist_coeffs_is_valid :: proc(coeffs: ^ow_dist_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if ow_hp1_coeffs_is_valid(&coeffs.hp1_coeffs) == 0 {
		return 0
	}
	if ow_peak_coeffs_is_valid(&coeffs.peak_coeffs) == 0 {
		return 0
	}
	if ow_clip_coeffs_is_valid(&coeffs.clip_coeffs) == 0 {
		return 0
	}
	if ow_satur_coeffs_is_valid(&coeffs.satur_coeffs) == 0 {
		return 0
	}
	if ow_lp1_coeffs_is_valid(&coeffs.lp1_coeffs) == 0 {
		return 0
	}
	if !ow_gain_coeffs_is_valid(&coeffs.gain_coeffs) {
		return 0
	}
	return 1
}

// Summary: Checks validity of dist state.
ow_dist_state_is_valid :: proc(coeffs: ^ow_dist_coeffs, state: ^ow_dist_state) -> i8 {
	if state == nil {
		return 0
	}
	hp1_coeffs: ^ow_hp1_coeffs
	peak_coeffs: ^ow_peak_coeffs
	clip_coeffs: ^ow_clip_coeffs
	satur_coeffs: ^ow_satur_coeffs
	lp1_coeffs: ^ow_lp1_coeffs
	if coeffs != nil {
		hp1_coeffs = &coeffs.hp1_coeffs
		peak_coeffs = &coeffs.peak_coeffs
		clip_coeffs = &coeffs.clip_coeffs
		satur_coeffs = &coeffs.satur_coeffs
		lp1_coeffs = &coeffs.lp1_coeffs
	}
	if ow_hp1_state_is_valid(hp1_coeffs, &state.hp1_state) == 0 {
		return 0
	}
	if ow_peak_state_is_valid(peak_coeffs, &state.peak_state) == 0 {
		return 0
	}
	if ow_clip_state_is_valid(clip_coeffs, &state.clip_state) == 0 {
		return 0
	}
	if ow_satur_state_is_valid(satur_coeffs, &state.satur_state) == 0 {
		return 0
	}
	if ow_lp1_state_is_valid(lp1_coeffs, &state.lp1_state) == 0 {
		return 0
	}
	return 1
}
