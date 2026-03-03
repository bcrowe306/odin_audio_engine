package odinworks

// Summary: Coefficient data for cab.
ow_cab_coeffs :: struct {
	lp_coeffs: ow_svf_coeffs,
	hp_coeffs: ow_svf_coeffs,
	bpl_coeffs: ow_svf_coeffs,
	bph_coeffs: ow_svf_coeffs,
	gain_bpl_coeffs: ow_gain_coeffs,
	gain_bph_coeffs: ow_gain_coeffs,
}

// Summary: Runtime state for cab.
ow_cab_state :: struct {
	lp_state: ow_svf_state,
	hp_state: ow_svf_state,
	bpl_state: ow_svf_state,
	bph_state: ow_svf_state,
}

// Summary: Initializes cab.
ow_cab_init :: proc(coeffs: ^ow_cab_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_init(&coeffs.lp_coeffs)
	ow_svf_init(&coeffs.hp_coeffs)
	ow_svf_init(&coeffs.bpl_coeffs)
	ow_svf_init(&coeffs.bph_coeffs)
	ow_gain_init(&coeffs.gain_bpl_coeffs)
	ow_gain_init(&coeffs.gain_bph_coeffs)

	ow_svf_set_cutoff(&coeffs.lp_coeffs, 4e3)
	ow_svf_set_cutoff(&coeffs.hp_coeffs, 100.0)
	ow_svf_set_cutoff(&coeffs.bpl_coeffs, 100.0)
	ow_svf_set_cutoff(&coeffs.bph_coeffs, 4e3)
	ow_gain_set_gain_lin(&coeffs.gain_bpl_coeffs, 2.25)
	ow_gain_set_gain_lin(&coeffs.gain_bph_coeffs, 3.75)
}

// Summary: Sets sample rate for cab.
ow_cab_set_sample_rate :: proc(coeffs: ^ow_cab_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_svf_set_sample_rate(&coeffs.lp_coeffs, sample_rate)
	ow_svf_set_sample_rate(&coeffs.hp_coeffs, sample_rate)
	ow_svf_set_sample_rate(&coeffs.bpl_coeffs, sample_rate)
	ow_svf_set_sample_rate(&coeffs.bph_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.gain_bpl_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.gain_bph_coeffs, sample_rate)
}

// Summary: Resets coefficients for cab.
ow_cab_reset_coeffs :: proc(coeffs: ^ow_cab_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_reset_coeffs(&coeffs.lp_coeffs)
	ow_svf_reset_coeffs(&coeffs.hp_coeffs)
	ow_svf_reset_coeffs(&coeffs.bpl_coeffs)
	ow_svf_reset_coeffs(&coeffs.bph_coeffs)
	ow_gain_reset_coeffs(&coeffs.gain_bpl_coeffs)
	ow_gain_reset_coeffs(&coeffs.gain_bph_coeffs)
}

// Summary: Resets state for cab.
ow_cab_reset_state :: proc(coeffs: ^ow_cab_coeffs, state: ^ow_cab_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	v_lp, v_bp, v_hp: f32
	ow_svf_reset_state(&coeffs.lp_coeffs, &state.lp_state, x_0, &v_lp, &v_bp, &v_hp)
	ow_svf_reset_state(&coeffs.hp_coeffs, &state.hp_state, v_lp, &v_lp, &v_bp, &v_hp)
	v_bpl, v_bph: f32
	y := v_hp
	ow_svf_reset_state(&coeffs.bpl_coeffs, &state.bpl_state, y, &v_lp, &v_bpl, &v_hp)
	ow_svf_reset_state(&coeffs.bph_coeffs, &state.bph_state, y, &v_lp, &v_bph, &v_hp)
	y = ow_gain_get_gain_cur(&coeffs.gain_bpl_coeffs) * v_bpl + ow_gain_get_gain_cur(&coeffs.gain_bph_coeffs) * v_bph + 0.45*y
	return y
}

// Summary: Resets multi-channel state for cab.
ow_cab_reset_state_multi :: proc(coeffs: ^ow_cab_coeffs, state: ^^ow_cab_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_cab_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for ch := 0; ch < n_channels; ch += 1 {
		v := ow_cab_reset_state(coeffs, states[ch], x0[ch])
		if y_0 != nil {
			y0[ch] = v
		}
	}
}

// Summary: Updates control-rate coefficients for cab.
ow_cab_update_coeffs_ctrl :: proc(coeffs: ^ow_cab_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_update_coeffs_ctrl(&coeffs.lp_coeffs)
	ow_svf_update_coeffs_ctrl(&coeffs.hp_coeffs)
	ow_svf_update_coeffs_ctrl(&coeffs.bpl_coeffs)
	ow_svf_update_coeffs_ctrl(&coeffs.bph_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.gain_bpl_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.gain_bph_coeffs)
}

// Summary: Updates audio-rate coefficients for cab.
ow_cab_update_coeffs_audio :: proc(coeffs: ^ow_cab_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_update_coeffs_audio(&coeffs.lp_coeffs)
	ow_svf_update_coeffs_audio(&coeffs.hp_coeffs)
	ow_svf_update_coeffs_audio(&coeffs.bpl_coeffs)
	ow_svf_update_coeffs_audio(&coeffs.bph_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.gain_bpl_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.gain_bph_coeffs)
}

// Summary: Processes one sample for cab.
ow_cab_process1 :: proc(coeffs: ^ow_cab_coeffs, state: ^ow_cab_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	v_lp, v_bp, v_hp: f32
	ow_svf_process1(&coeffs.lp_coeffs, &state.lp_state, x, &v_lp, &v_bp, &v_hp)
	ow_svf_process1(&coeffs.hp_coeffs, &state.hp_state, v_lp, &v_lp, &v_bp, &v_hp)
	v_bpl, v_bph: f32
	y := v_hp
	ow_svf_process1(&coeffs.bpl_coeffs, &state.bpl_state, y, &v_lp, &v_bpl, &v_hp)
	ow_svf_process1(&coeffs.bph_coeffs, &state.bph_state, y, &v_lp, &v_bph, &v_hp)
	y = ow_gain_process1(&coeffs.gain_bpl_coeffs, v_bpl) + ow_gain_process1(&coeffs.gain_bph_coeffs, v_bph) + 0.45*y
	return y
}

// Summary: Processes sample buffers for cab.
ow_cab_process :: proc(coeffs: ^ow_cab_coeffs, state: ^ow_cab_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	ow_cab_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_cab_update_coeffs_audio(coeffs)
		ym[i] = ow_cab_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for cab.
ow_cab_process_multi :: proc(coeffs: ^ow_cab_coeffs, state: ^^ow_cab_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_cab_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_cab_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_cab_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_cab_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets cutoff low for cab.
ow_cab_set_cutoff_low :: proc(coeffs: ^ow_cab_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0 && value <= 1.0)
	f := 50.0 + value*(50.0+100.0*value)
	ow_svf_set_cutoff(&coeffs.hp_coeffs, f)
	ow_svf_set_cutoff(&coeffs.bpl_coeffs, f)
}

// Summary: Sets cutoff high for cab.
ow_cab_set_cutoff_high :: proc(coeffs: ^ow_cab_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0 && value <= 1.0)
	f := 2e3 + value*(2e3+4e3*value)
	ow_svf_set_cutoff(&coeffs.lp_coeffs, f)
	ow_svf_set_cutoff(&coeffs.bph_coeffs, f)
}

// Summary: Sets tone for cab.
ow_cab_set_tone :: proc(coeffs: ^ow_cab_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0 && value <= 1.0)
	ow_gain_set_gain_lin(&coeffs.gain_bpl_coeffs, 3.0-1.5*value)
	ow_gain_set_gain_lin(&coeffs.gain_bph_coeffs, 3.0+1.5*value)
}

// Summary: Checks validity of cab coeffs.
ow_cab_coeffs_is_valid :: proc(coeffs: ^ow_cab_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if ow_svf_coeffs_is_valid(&coeffs.lp_coeffs) == 0 ||
		ow_svf_coeffs_is_valid(&coeffs.hp_coeffs) == 0 ||
		ow_svf_coeffs_is_valid(&coeffs.bpl_coeffs) == 0 ||
		ow_svf_coeffs_is_valid(&coeffs.bph_coeffs) == 0 ||
		!ow_gain_coeffs_is_valid(&coeffs.gain_bpl_coeffs) ||
		!ow_gain_coeffs_is_valid(&coeffs.gain_bph_coeffs) {
		return 0
	}
	return 1
}

// Summary: Checks validity of cab state.
ow_cab_state_is_valid :: proc(coeffs: ^ow_cab_coeffs, state: ^ow_cab_state) -> i8 {
	if state == nil {
		return 0
	}
	if coeffs != nil {
		if ow_svf_state_is_valid(&coeffs.lp_coeffs, &state.lp_state) == 0 ||
			ow_svf_state_is_valid(&coeffs.hp_coeffs, &state.hp_state) == 0 ||
			ow_svf_state_is_valid(&coeffs.bpl_coeffs, &state.bpl_state) == 0 ||
			ow_svf_state_is_valid(&coeffs.bph_coeffs, &state.bph_state) == 0 {
			return 0
		}
	} else {
		if ow_svf_state_is_valid(nil, &state.lp_state) == 0 ||
			ow_svf_state_is_valid(nil, &state.hp_state) == 0 ||
			ow_svf_state_is_valid(nil, &state.bpl_state) == 0 ||
			ow_svf_state_is_valid(nil, &state.bph_state) == 0 {
			return 0
		}
	}
	return 1
}
