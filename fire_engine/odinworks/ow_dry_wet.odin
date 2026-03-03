package odinworks

// Summary: Coefficient data for dry wet.
ow_dry_wet_coeffs :: struct {
	gain_coeffs: ow_gain_coeffs,
}

// Summary: Initializes dry wet.
ow_dry_wet_init :: proc(coeffs: ^ow_dry_wet_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_gain_init(&coeffs.gain_coeffs)
}

// Summary: Sets sample rate for dry wet.
ow_dry_wet_set_sample_rate :: proc(coeffs: ^ow_dry_wet_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_gain_set_sample_rate(&coeffs.gain_coeffs, sample_rate)
}

// Summary: Resets coefficients for dry wet.
ow_dry_wet_reset_coeffs :: proc(coeffs: ^ow_dry_wet_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_gain_reset_coeffs(&coeffs.gain_coeffs)
}

// Summary: Updates control-rate coefficients for dry wet.
ow_dry_wet_update_coeffs_ctrl :: proc(coeffs: ^ow_dry_wet_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_gain_update_coeffs_ctrl(&coeffs.gain_coeffs)
}

// Summary: Updates audio-rate coefficients for dry wet.
ow_dry_wet_update_coeffs_audio :: proc(coeffs: ^ow_dry_wet_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_gain_update_coeffs_audio(&coeffs.gain_coeffs)
}

// Summary: Processes one sample for dry wet.
ow_dry_wet_process1 :: proc(coeffs: ^ow_dry_wet_coeffs, x_dry: f32, x_wet: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	return ow_gain_process1(&coeffs.gain_coeffs, x_wet-x_dry) + x_dry
}

// Summary: Processes sample buffers for dry wet.
ow_dry_wet_process :: proc(coeffs: ^ow_dry_wet_coeffs, x_dry: ^f32, x_wet: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x_dry != nil)
	OW_ASSERT(x_wet != nil)
	OW_ASSERT(y != nil)

	xd := ([^]f32)(x_dry)
	xw := ([^]f32)(x_wet)
	ym := ([^]f32)(y)

	ow_dry_wet_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_dry_wet_update_coeffs_audio(coeffs)
		ym[i] = ow_dry_wet_process1(coeffs, xd[i], xw[i])
	}
}

// Summary: Processes multiple channels for dry wet.
ow_dry_wet_process_multi :: proc(coeffs: ^ow_dry_wet_coeffs, x_dry: ^^f32, x_wet: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x_dry != nil)
	OW_ASSERT(x_wet != nil)
	OW_ASSERT(y != nil)

	xdm := ([^][^]f32)(x_dry)
	xwm := ([^][^]f32)(x_wet)
	ym := ([^][^]f32)(y)

	ow_dry_wet_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_dry_wet_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_dry_wet_process1(coeffs, xdm[ch][i], xwm[ch][i])
		}
	}
}

// Summary: Sets wet for dry wet.
ow_dry_wet_set_wet :: proc(coeffs: ^ow_dry_wet_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0 && value <= 1.0)
	ow_gain_set_gain_lin(&coeffs.gain_coeffs, value)
}

// Summary: Sets smooth tau for dry wet.
ow_dry_wet_set_smooth_tau :: proc(coeffs: ^ow_dry_wet_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0)
	ow_gain_set_smooth_tau(&coeffs.gain_coeffs, value)
}

// Summary: Gets wet from dry wet.
ow_dry_wet_get_wet :: proc(coeffs: ^ow_dry_wet_coeffs) -> f32 {
	OW_ASSERT(coeffs != nil)
	return ow_gain_get_gain_lin(&coeffs.gain_coeffs)
}

// Summary: Gets wet cur from dry wet.
ow_dry_wet_get_wet_cur :: proc(coeffs: ^ow_dry_wet_coeffs) -> f32 {
	OW_ASSERT(coeffs != nil)
	return ow_gain_get_gain_cur(&coeffs.gain_coeffs)
}

// Summary: Checks validity of dry wet coeffs.
ow_dry_wet_coeffs_is_valid :: proc(coeffs: ^ow_dry_wet_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_gain_coeffs_is_valid(&coeffs.gain_coeffs) {
		return 0
	}
	return 1
}
