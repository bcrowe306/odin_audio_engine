package odinworks

// Summary: Coefficient data for fuzz.
ow_fuzz_coeffs :: struct {
	hp1_in_coeffs: ow_hp1_coeffs,
	lp2_coeffs: ow_svf_coeffs,
	peak_coeffs: ow_peak_coeffs,
	satur_coeffs: ow_satur_coeffs,
	hp1_out_coeffs: ow_hp1_coeffs,
	gain_coeffs: ow_gain_coeffs,
}

// Summary: Runtime state for fuzz.
ow_fuzz_state :: struct {
	hp1_in_state: ow_hp1_state,
	lp2_1_state: ow_svf_state,
	lp2_2_state: ow_svf_state,
	peak_state: ow_peak_state,
	satur_state: ow_satur_state,
	hp1_out_state: ow_hp1_state,
}

// Summary: Initializes fuzz.
ow_fuzz_init :: proc(coeffs: ^ow_fuzz_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_hp1_init(&coeffs.hp1_in_coeffs)
	ow_svf_init(&coeffs.lp2_coeffs)
	ow_peak_init(&coeffs.peak_coeffs)
	ow_satur_init(&coeffs.satur_coeffs)
	ow_hp1_init(&coeffs.hp1_out_coeffs)
	ow_gain_init(&coeffs.gain_coeffs)
	ow_hp1_set_cutoff(&coeffs.hp1_in_coeffs, 4.0)
	ow_svf_set_cutoff(&coeffs.lp2_coeffs, 7.0e3)
	ow_peak_set_cutoff(&coeffs.peak_coeffs, 500.0)
	ow_peak_set_bandwidth(&coeffs.peak_coeffs, 6.6)
	ow_satur_set_bias(&coeffs.satur_coeffs, 0.145)
	ow_hp1_set_cutoff(&coeffs.hp1_out_coeffs, 30.0)
}

// Summary: Sets sample rate for fuzz.
ow_fuzz_set_sample_rate :: proc(coeffs: ^ow_fuzz_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_hp1_set_sample_rate(&coeffs.hp1_in_coeffs, sample_rate)
	ow_svf_set_sample_rate(&coeffs.lp2_coeffs, sample_rate)
	ow_peak_set_sample_rate(&coeffs.peak_coeffs, sample_rate)
	ow_satur_set_sample_rate(&coeffs.satur_coeffs, sample_rate)
	ow_hp1_set_sample_rate(&coeffs.hp1_out_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.gain_coeffs, sample_rate)
	ow_hp1_reset_coeffs(&coeffs.hp1_in_coeffs)
	ow_svf_reset_coeffs(&coeffs.lp2_coeffs)
	ow_satur_reset_coeffs(&coeffs.satur_coeffs)
	ow_hp1_reset_coeffs(&coeffs.hp1_out_coeffs)
}

// Summary: Resets coefficients for fuzz.
ow_fuzz_reset_coeffs :: proc(coeffs: ^ow_fuzz_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_peak_reset_coeffs(&coeffs.peak_coeffs)
	ow_gain_reset_coeffs(&coeffs.gain_coeffs)
}

// Summary: Resets state for fuzz.
ow_fuzz_reset_state :: proc(coeffs: ^ow_fuzz_coeffs, state: ^ow_fuzz_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	y := ow_hp1_reset_state(&coeffs.hp1_in_coeffs, &state.hp1_in_state, x_0)
	v_lp, v_bp, v_hp: f32
	ow_svf_reset_state(&coeffs.lp2_coeffs, &state.lp2_1_state, y, &v_lp, &v_bp, &v_hp)
	ow_svf_reset_state(&coeffs.lp2_coeffs, &state.lp2_2_state, v_lp, &v_lp, &v_bp, &v_hp)
	y = ow_peak_reset_state(&coeffs.peak_coeffs, &state.peak_state, v_lp)
	y = ow_satur_reset_state(&coeffs.satur_coeffs, &state.satur_state, y)
	y = ow_hp1_reset_state(&coeffs.hp1_out_coeffs, &state.hp1_out_state, y)
	y = ow_gain_get_gain_cur(&coeffs.gain_coeffs) * y
	return y
}

// Summary: Resets multi-channel state for fuzz.
ow_fuzz_reset_state_multi :: proc(coeffs: ^ow_fuzz_coeffs, state: ^^ow_fuzz_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_fuzz_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_fuzz_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for fuzz.
ow_fuzz_update_coeffs_ctrl :: proc(coeffs: ^ow_fuzz_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_peak_update_coeffs_ctrl(&coeffs.peak_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.gain_coeffs)
}

// Summary: Updates audio-rate coefficients for fuzz.
ow_fuzz_update_coeffs_audio :: proc(coeffs: ^ow_fuzz_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_peak_update_coeffs_audio(&coeffs.peak_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.gain_coeffs)
}

// Summary: Processes one sample for fuzz.
ow_fuzz_process1 :: proc(coeffs: ^ow_fuzz_coeffs, state: ^ow_fuzz_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	y := ow_hp1_process1(&coeffs.hp1_in_coeffs, &state.hp1_in_state, x)
	v_lp, v_bp, v_hp: f32
	ow_svf_process1(&coeffs.lp2_coeffs, &state.lp2_1_state, y, &v_lp, &v_bp, &v_hp)
	ow_svf_process1(&coeffs.lp2_coeffs, &state.lp2_2_state, v_lp, &v_lp, &v_bp, &v_hp)
	y = ow_peak_process1(&coeffs.peak_coeffs, &state.peak_state, v_lp)
	y = ow_satur_process1(&coeffs.satur_coeffs, &state.satur_state, y)
	y = ow_hp1_process1(&coeffs.hp1_out_coeffs, &state.hp1_out_state, y)
	y = ow_gain_process1(&coeffs.gain_coeffs, y)
	return y
}

// Summary: Processes sample buffers for fuzz.
ow_fuzz_process :: proc(coeffs: ^ow_fuzz_coeffs, state: ^ow_fuzz_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	ow_fuzz_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_fuzz_update_coeffs_audio(coeffs)
		ym[i] = ow_fuzz_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for fuzz.
ow_fuzz_process_multi :: proc(coeffs: ^ow_fuzz_coeffs, state: ^^ow_fuzz_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_fuzz_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_fuzz_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_fuzz_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_fuzz_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets fuzz for fuzz.
ow_fuzz_set_fuzz :: proc(coeffs: ^ow_fuzz_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	OW_ASSERT(value >= 0.0 && value <= 1.0)
	ow_peak_set_peak_gain_dB(&coeffs.peak_coeffs, 30.0*value)
}

// Summary: Sets volume for fuzz.
ow_fuzz_set_volume :: proc(coeffs: ^ow_fuzz_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	OW_ASSERT(value >= 0.0 && value <= 1.0)
	ow_gain_set_gain_lin(&coeffs.gain_coeffs, value*value*value)
}

// Summary: Checks validity of fuzz coeffs.
ow_fuzz_coeffs_is_valid :: proc(coeffs: ^ow_fuzz_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if ow_hp1_coeffs_is_valid(&coeffs.hp1_in_coeffs) == 0 {
		return 0
	}
	if ow_svf_coeffs_is_valid(&coeffs.lp2_coeffs) == 0 {
		return 0
	}
	if ow_peak_coeffs_is_valid(&coeffs.peak_coeffs) == 0 {
		return 0
	}
	if ow_satur_coeffs_is_valid(&coeffs.satur_coeffs) == 0 {
		return 0
	}
	if ow_hp1_coeffs_is_valid(&coeffs.hp1_out_coeffs) == 0 {
		return 0
	}
	if !ow_gain_coeffs_is_valid(&coeffs.gain_coeffs) {
		return 0
	}
	return 1
}

// Summary: Checks validity of fuzz state.
ow_fuzz_state_is_valid :: proc(coeffs: ^ow_fuzz_coeffs, state: ^ow_fuzz_state) -> i8 {
	if state == nil {
		return 0
	}
	hp1_in_coeffs: ^ow_hp1_coeffs
	lp2_coeffs: ^ow_svf_coeffs
	peak_coeffs: ^ow_peak_coeffs
	satur_coeffs: ^ow_satur_coeffs
	hp1_out_coeffs: ^ow_hp1_coeffs
	if coeffs != nil {
		hp1_in_coeffs = &coeffs.hp1_in_coeffs
		lp2_coeffs = &coeffs.lp2_coeffs
		peak_coeffs = &coeffs.peak_coeffs
		satur_coeffs = &coeffs.satur_coeffs
		hp1_out_coeffs = &coeffs.hp1_out_coeffs
	}
	if ow_hp1_state_is_valid(hp1_in_coeffs, &state.hp1_in_state) == 0 {
		return 0
	}
	if ow_svf_state_is_valid(lp2_coeffs, &state.lp2_1_state) == 0 {
		return 0
	}
	if ow_svf_state_is_valid(lp2_coeffs, &state.lp2_2_state) == 0 {
		return 0
	}
	if ow_peak_state_is_valid(peak_coeffs, &state.peak_state) == 0 {
		return 0
	}
	if ow_satur_state_is_valid(satur_coeffs, &state.satur_state) == 0 {
		return 0
	}
	if ow_hp1_state_is_valid(hp1_out_coeffs, &state.hp1_out_state) == 0 {
		return 0
	}
	return 1
}
