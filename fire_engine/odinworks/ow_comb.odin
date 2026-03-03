package odinworks

// Summary: Coefficient data for comb.
ow_comb_coeffs :: struct {
	delay_coeffs: ow_delay_coeffs,
	blend_coeffs: ow_gain_coeffs,
	ff_coeffs: ow_gain_coeffs,
	fb_coeffs: ow_gain_coeffs,
	smooth_coeffs: ow_one_pole_coeffs,
	smooth_delay_ff_state: ow_one_pole_state,
	smooth_delay_fb_state: ow_one_pole_state,
	fs: f32,
	dffi: int,
	dfff: f32,
	dfbi: int,
	dfbf: f32,
	delay_ff: f32,
	delay_fb: f32,
}

// Summary: Runtime state for comb.
ow_comb_state :: struct {
	delay_state: ow_delay_state,
}

// Summary: Initializes comb.
ow_comb_init :: proc(coeffs: ^ow_comb_coeffs, max_delay: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(max_delay) && max_delay >= 0.0)
	ow_delay_init(&coeffs.delay_coeffs, max_delay)
	ow_gain_init(&coeffs.blend_coeffs)
	ow_gain_init(&coeffs.ff_coeffs)
	ow_gain_init(&coeffs.fb_coeffs)
	ow_one_pole_init(&coeffs.smooth_coeffs)
	ow_one_pole_set_tau(&coeffs.smooth_coeffs, 0.05)
	ow_one_pole_set_sticky_thresh(&coeffs.smooth_coeffs, 1.0e-6)
	ow_gain_set_gain_lin(&coeffs.ff_coeffs, 0.0)
	ow_gain_set_gain_lin(&coeffs.fb_coeffs, 0.0)
	coeffs.delay_ff = 0.0
	coeffs.delay_fb = 0.0
}

// Summary: Sets sample rate for comb.
ow_comb_set_sample_rate :: proc(coeffs: ^ow_comb_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_delay_set_sample_rate(&coeffs.delay_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.blend_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.ff_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.fb_coeffs, sample_rate)
	ow_one_pole_set_sample_rate(&coeffs.smooth_coeffs, sample_rate)
	ow_one_pole_reset_coeffs(&coeffs.smooth_coeffs)
	coeffs.fs = sample_rate
}

// Summary: Executes comb mem req.
ow_comb_mem_req :: proc(coeffs: ^ow_comb_coeffs) -> int {
	OW_ASSERT(coeffs != nil)
	return ow_delay_mem_req(&coeffs.delay_coeffs)
}

// Summary: Executes comb mem set.
ow_comb_mem_set :: proc(coeffs: ^ow_comb_coeffs, state: ^ow_comb_state, mem: rawptr) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(mem != nil)
	ow_delay_mem_set(&coeffs.delay_coeffs, &state.delay_state, mem)
}

// Summary: Executes comb do update coeffs.
ow_comb_do_update_coeffs :: proc(coeffs: ^ow_comb_coeffs, force: bool) {
	delay_ff_cur := ow_one_pole_get_y_z1(&coeffs.smooth_delay_ff_state)
	delay_fb_cur := ow_one_pole_get_y_z1(&coeffs.smooth_delay_fb_state)
	if force || delay_ff_cur != coeffs.delay_ff {
		delay_ff_cur = ow_one_pole_process1_sticky_abs(&coeffs.smooth_coeffs, &coeffs.smooth_delay_ff_state, coeffs.delay_ff)
		len := ow_delay_get_length(&coeffs.delay_coeffs)
		dff := ow_maxf(coeffs.fs*delay_ff_cur, 0.0)
		dffif := ow_floorf(dff)
		coeffs.dfff = dff - dffif
		coeffs.dffi = int(dffif)
		if coeffs.dffi >= len {
			coeffs.dffi = len
			coeffs.dfff = 0.0
		}
	}
	if force || delay_fb_cur != coeffs.delay_fb {
		delay_fb_cur = ow_one_pole_process1_sticky_abs(&coeffs.smooth_coeffs, &coeffs.smooth_delay_fb_state, coeffs.delay_fb)
		len := ow_delay_get_length(&coeffs.delay_coeffs)
		dfb := ow_maxf(coeffs.fs*delay_fb_cur, 1.0) - 1.0
		dfbif := ow_floorf(dfb)
		coeffs.dfbf = dfb - dfbif
		coeffs.dfbi = int(dfbif)
		if coeffs.dfbi >= len {
			coeffs.dfbi = len
			coeffs.dfbf = 0.0
		}
	}
}

// Summary: Resets coefficients for comb.
ow_comb_reset_coeffs :: proc(coeffs: ^ow_comb_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_delay_reset_coeffs(&coeffs.delay_coeffs)
	ow_gain_reset_coeffs(&coeffs.blend_coeffs)
	ow_gain_reset_coeffs(&coeffs.ff_coeffs)
	ow_gain_reset_coeffs(&coeffs.fb_coeffs)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_delay_ff_state, coeffs.delay_ff)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_delay_fb_state, coeffs.delay_fb)
	ow_comb_do_update_coeffs(coeffs, true)
}

// Summary: Resets state for comb.
ow_comb_reset_state :: proc(coeffs: ^ow_comb_coeffs, state: ^ow_comb_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	fb := ow_gain_get_gain_cur(&coeffs.fb_coeffs)
	y: f32
	if fb == -1.0 || fb == 1.0 {
		_ = ow_delay_reset_state(&coeffs.delay_coeffs, &state.delay_state, 0.0)
		y = 0.0
	} else {
		v := x_0 / (1.0 - fb)
		_ = ow_delay_reset_state(&coeffs.delay_coeffs, &state.delay_state, v)
		y = (ow_gain_get_gain_cur(&coeffs.ff_coeffs)+ow_gain_get_gain_cur(&coeffs.blend_coeffs)) * v
	}
	return y
}

// Summary: Resets multi-channel state for comb.
ow_comb_reset_state_multi :: proc(coeffs: ^ow_comb_coeffs, state: ^^ow_comb_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_comb_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_comb_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for comb.
ow_comb_update_coeffs_ctrl :: proc(coeffs: ^ow_comb_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_gain_update_coeffs_ctrl(&coeffs.blend_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.ff_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.fb_coeffs)
}

// Summary: Updates audio-rate coefficients for comb.
ow_comb_update_coeffs_audio :: proc(coeffs: ^ow_comb_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_gain_update_coeffs_audio(&coeffs.blend_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.ff_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.fb_coeffs)
	ow_comb_do_update_coeffs(coeffs, false)
}

// Summary: Processes one sample for comb.
ow_comb_process1 :: proc(coeffs: ^ow_comb_coeffs, state: ^ow_comb_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	fb := ow_delay_read(&coeffs.delay_coeffs, &state.delay_state, coeffs.dfbi, coeffs.dfbf)
	v := x + ow_gain_process1(&coeffs.fb_coeffs, fb)
	ow_delay_write(&coeffs.delay_coeffs, &state.delay_state, v)
	ff := ow_delay_read(&coeffs.delay_coeffs, &state.delay_state, coeffs.dffi, coeffs.dfff)
	y := ow_gain_process1(&coeffs.blend_coeffs, v) + ow_gain_process1(&coeffs.ff_coeffs, ff)
	return y
}

// Summary: Processes sample buffers for comb.
ow_comb_process :: proc(coeffs: ^ow_comb_coeffs, state: ^ow_comb_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	ow_comb_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_comb_update_coeffs_audio(coeffs)
		ym[i] = ow_comb_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for comb.
ow_comb_process_multi :: proc(coeffs: ^ow_comb_coeffs, state: ^^ow_comb_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_comb_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_comb_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_comb_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_comb_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets delay ff for comb.
ow_comb_set_delay_ff :: proc(coeffs: ^ow_comb_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	coeffs.delay_ff = value
}

// Summary: Sets delay fb for comb.
ow_comb_set_delay_fb :: proc(coeffs: ^ow_comb_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	coeffs.delay_fb = value
}

// Summary: Sets coeff blend for comb.
ow_comb_set_coeff_blend :: proc(coeffs: ^ow_comb_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	ow_gain_set_gain_lin(&coeffs.blend_coeffs, value)
}

// Summary: Sets coeff ff for comb.
ow_comb_set_coeff_ff :: proc(coeffs: ^ow_comb_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	ow_gain_set_gain_lin(&coeffs.ff_coeffs, value)
}

// Summary: Sets coeff fb for comb.
ow_comb_set_coeff_fb :: proc(coeffs: ^ow_comb_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= -1.0 && value <= 1.0)
	ow_gain_set_gain_lin(&coeffs.fb_coeffs, value)
}

// Summary: Checks validity of comb coeffs.
ow_comb_coeffs_is_valid :: proc(coeffs: ^ow_comb_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.delay_ff) {
		return 0
	}
	if !ow_is_finite(coeffs.delay_fb) {
		return 0
	}
	if ow_delay_coeffs_is_valid(&coeffs.delay_coeffs) == 0 {
		return 0
	}
	if !ow_one_pole_coeffs_is_valid(&coeffs.smooth_coeffs) {
		return 0
	}
	if !ow_gain_coeffs_is_valid(&coeffs.blend_coeffs) {
		return 0
	}
	if !ow_gain_coeffs_is_valid(&coeffs.ff_coeffs) {
		return 0
	}
	if !ow_gain_coeffs_is_valid(&coeffs.fb_coeffs) {
		return 0
	}
	return 1
}

// Summary: Checks validity of comb state.
ow_comb_state_is_valid :: proc(coeffs: ^ow_comb_coeffs, state: ^ow_comb_state) -> i8 {
	if state == nil {
		return 0
	}
	delay_coeffs: ^ow_delay_coeffs
	if coeffs != nil {
		delay_coeffs = &coeffs.delay_coeffs
	}
	return ow_delay_state_is_valid(delay_coeffs, &state.delay_state)
}
