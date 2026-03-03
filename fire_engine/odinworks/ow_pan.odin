package odinworks

// Summary: Coefficient data for pan.
ow_pan_coeffs :: struct {
	l_coeffs: ow_gain_coeffs,
	r_coeffs: ow_gain_coeffs,
	pan: f32,
	pan_prev: f32,
}

// Summary: Initializes pan.
ow_pan_init :: proc(coeffs: ^ow_pan_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_gain_init(&coeffs.l_coeffs)
	ow_gain_init(&coeffs.r_coeffs)
	coeffs.pan = 0.0
	coeffs.pan_prev = 0.0
}

// Summary: Sets sample rate for pan.
ow_pan_set_sample_rate :: proc(coeffs: ^ow_pan_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_gain_set_sample_rate(&coeffs.l_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.r_coeffs, sample_rate)
}

// Summary: Executes pan do update coeffs.
ow_pan_do_update_coeffs :: proc(coeffs: ^ow_pan_coeffs, force: bool) {
	if force || coeffs.pan != coeffs.pan_prev {
		l := 0.7071067811865477 + coeffs.pan*(-0.5+coeffs.pan*-0.20710678118654768)
		ow_gain_set_gain_lin(&coeffs.l_coeffs, l)
		ow_gain_set_gain_lin(&coeffs.r_coeffs, l+coeffs.pan)
		coeffs.pan_prev = coeffs.pan
	}
}

// Summary: Resets coefficients for pan.
ow_pan_reset_coeffs :: proc(coeffs: ^ow_pan_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_pan_do_update_coeffs(coeffs, true)
	ow_gain_reset_coeffs(&coeffs.l_coeffs)
	ow_gain_reset_coeffs(&coeffs.r_coeffs)
}

// Summary: Updates control-rate coefficients for pan.
ow_pan_update_coeffs_ctrl :: proc(coeffs: ^ow_pan_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_pan_do_update_coeffs(coeffs, false)
	ow_gain_update_coeffs_ctrl(&coeffs.l_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.r_coeffs)
}

// Summary: Updates audio-rate coefficients for pan.
ow_pan_update_coeffs_audio :: proc(coeffs: ^ow_pan_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_gain_update_coeffs_audio(&coeffs.l_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.r_coeffs)
}

// Summary: Processes one sample for pan.
ow_pan_process1 :: proc(coeffs: ^ow_pan_coeffs, x: f32, y_l: ^f32, y_r: ^f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(y_l != nil)
	OW_ASSERT(y_r != nil)
	y_l^ = ow_gain_process1(&coeffs.l_coeffs, x)
	y_r^ = ow_gain_process1(&coeffs.r_coeffs, x)
}

// Summary: Processes sample buffers for pan.
ow_pan_process :: proc(coeffs: ^ow_pan_coeffs, x: ^f32, y_l: ^f32, y_r: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y_l != nil)
	OW_ASSERT(y_r != nil)

	xm := ([^]f32)(x)
	ylm := ([^]f32)(y_l)
	yrm := ([^]f32)(y_r)

	ow_pan_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_pan_update_coeffs_audio(coeffs)
		ow_pan_process1(coeffs, xm[i], &ylm[i], &yrm[i])
	}
}

// Summary: Processes multiple channels for pan.
ow_pan_process_multi :: proc(coeffs: ^ow_pan_coeffs, x: ^^f32, y_l: ^^f32, y_r: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y_l != nil)
	OW_ASSERT(y_r != nil)

	xm := ([^][^]f32)(x)
	ylm := ([^][^]f32)(y_l)
	yrm := ([^][^]f32)(y_r)

	ow_pan_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_pan_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ow_pan_process1(coeffs, xm[ch][i], &ylm[ch][i], &yrm[ch][i])
		}
	}
}

// Summary: Sets pan for pan.
ow_pan_set_pan :: proc(coeffs: ^ow_pan_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= -1.0 && value <= 1.0)
	coeffs.pan = value
}

// Summary: Checks validity of pan coeffs.
ow_pan_coeffs_is_valid :: proc(coeffs: ^ow_pan_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.pan) || coeffs.pan < -1.0 || coeffs.pan > 1.0 {
		return 0
	}
	if !ow_is_finite(coeffs.pan_prev) || coeffs.pan_prev < -1.0 || coeffs.pan_prev > 1.0 {
		return 0
	}
	if !ow_gain_coeffs_is_valid(&coeffs.l_coeffs) || !ow_gain_coeffs_is_valid(&coeffs.r_coeffs) {
		return 0
	}
	return 1
}
