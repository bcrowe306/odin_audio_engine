package odinworks

// Summary: Coefficient data for balance.
ow_balance_coeffs :: struct {
	l_coeffs: ow_gain_coeffs,
	r_coeffs: ow_gain_coeffs,
	balance: f32,
	balance_prev: f32,
}

// Summary: Initializes balance.
ow_balance_init :: proc(coeffs: ^ow_balance_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_gain_init(&coeffs.l_coeffs)
	ow_gain_init(&coeffs.r_coeffs)
	coeffs.balance = 0.0
	coeffs.balance_prev = 0.0
}

// Summary: Sets sample rate for balance.
ow_balance_set_sample_rate :: proc(coeffs: ^ow_balance_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_gain_set_sample_rate(&coeffs.l_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.r_coeffs, sample_rate)
}

// Summary: Executes balance do update coeffs.
ow_balance_do_update_coeffs :: proc(coeffs: ^ow_balance_coeffs, force: bool) {
	if force || coeffs.balance != coeffs.balance_prev {
		ow_gain_set_gain_lin(&coeffs.l_coeffs, ow_minf(1.0-coeffs.balance, 1.0))
		ow_gain_set_gain_lin(&coeffs.r_coeffs, ow_minf(1.0+coeffs.balance, 1.0))
		coeffs.balance_prev = coeffs.balance
	}
}

// Summary: Resets coefficients for balance.
ow_balance_reset_coeffs :: proc(coeffs: ^ow_balance_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_balance_do_update_coeffs(coeffs, true)
	ow_gain_reset_coeffs(&coeffs.l_coeffs)
	ow_gain_reset_coeffs(&coeffs.r_coeffs)
}

// Summary: Updates control-rate coefficients for balance.
ow_balance_update_coeffs_ctrl :: proc(coeffs: ^ow_balance_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_balance_do_update_coeffs(coeffs, false)
	ow_gain_update_coeffs_ctrl(&coeffs.l_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.r_coeffs)
}

// Summary: Updates audio-rate coefficients for balance.
ow_balance_update_coeffs_audio :: proc(coeffs: ^ow_balance_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_gain_update_coeffs_audio(&coeffs.l_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.r_coeffs)
}

// Summary: Processes one sample for balance.
ow_balance_process1 :: proc(coeffs: ^ow_balance_coeffs, x_l: f32, x_r: f32, y_l: ^f32, y_r: ^f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(y_l != nil)
	OW_ASSERT(y_r != nil)
	y_l^ = ow_gain_process1(&coeffs.l_coeffs, x_l)
	y_r^ = ow_gain_process1(&coeffs.r_coeffs, x_r)
}

// Summary: Processes sample buffers for balance.
ow_balance_process :: proc(coeffs: ^ow_balance_coeffs, x_l: ^f32, x_r: ^f32, y_l: ^f32, y_r: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x_l != nil)
	OW_ASSERT(x_r != nil)
	OW_ASSERT(y_l != nil)
	OW_ASSERT(y_r != nil)

	xl := ([^]f32)(x_l)
	xr := ([^]f32)(x_r)
	yl := ([^]f32)(y_l)
	yr := ([^]f32)(y_r)

	ow_balance_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_balance_update_coeffs_audio(coeffs)
		ow_balance_process1(coeffs, xl[i], xr[i], &yl[i], &yr[i])
	}
}

// Summary: Processes multiple channels for balance.
ow_balance_process_multi :: proc(coeffs: ^ow_balance_coeffs, x_l: ^^f32, x_r: ^^f32, y_l: ^^f32, y_r: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x_l != nil)
	OW_ASSERT(x_r != nil)
	OW_ASSERT(y_l != nil)
	OW_ASSERT(y_r != nil)

	xlm := ([^][^]f32)(x_l)
	xrm := ([^][^]f32)(x_r)
	ylm := ([^][^]f32)(y_l)
	yrm := ([^][^]f32)(y_r)

	ow_balance_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_balance_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ow_balance_process1(coeffs, xlm[ch][i], xrm[ch][i], &ylm[ch][i], &yrm[ch][i])
		}
	}
}

// Summary: Sets balance for balance.
ow_balance_set_balance :: proc(coeffs: ^ow_balance_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= -1.0 && value <= 1.0)
	coeffs.balance = value
}

// Summary: Checks validity of balance coeffs.
ow_balance_coeffs_is_valid :: proc(coeffs: ^ow_balance_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.balance) || coeffs.balance < -1.0 || coeffs.balance > 1.0 {
		return 0
	}
	if !ow_gain_coeffs_is_valid(&coeffs.l_coeffs) || !ow_gain_coeffs_is_valid(&coeffs.r_coeffs) {
		return 0
	}
	return 1
}
