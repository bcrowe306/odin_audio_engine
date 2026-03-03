package odinworks

// Summary: Coefficient data for ring mod.
ow_ring_mod_coeffs :: struct {
	smooth_coeffs: ow_one_pole_coeffs,
	smooth_state: ow_one_pole_state,
	mod_amount: f32,
}

// Summary: Initializes ring mod.
ow_ring_mod_init :: proc(coeffs: ^ow_ring_mod_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_init(&coeffs.smooth_coeffs)
	ow_one_pole_set_tau(&coeffs.smooth_coeffs, 0.05)
	coeffs.mod_amount = 1.0
}

// Summary: Sets sample rate for ring mod.
ow_ring_mod_set_sample_rate :: proc(coeffs: ^ow_ring_mod_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_one_pole_set_sample_rate(&coeffs.smooth_coeffs, sample_rate)
	ow_one_pole_reset_coeffs(&coeffs.smooth_coeffs)
}

// Summary: Resets coefficients for ring mod.
ow_ring_mod_reset_coeffs :: proc(coeffs: ^ow_ring_mod_coeffs) {
	OW_ASSERT(coeffs != nil)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_state, coeffs.mod_amount)
}

// Summary: Updates control-rate coefficients for ring mod.
ow_ring_mod_update_coeffs_ctrl :: proc(coeffs: ^ow_ring_mod_coeffs) {
	OW_ASSERT(coeffs != nil)
	_ = coeffs
}

// Summary: Updates audio-rate coefficients for ring mod.
ow_ring_mod_update_coeffs_audio :: proc(coeffs: ^ow_ring_mod_coeffs) {
	OW_ASSERT(coeffs != nil)
	_ = ow_one_pole_process1(&coeffs.smooth_coeffs, &coeffs.smooth_state, coeffs.mod_amount)
}

// Summary: Processes one sample for ring mod.
ow_ring_mod_process1 :: proc(coeffs: ^ow_ring_mod_coeffs, x_mod: f32, x_car: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(x_mod))
	OW_ASSERT(ow_is_finite(x_car))
	k := ow_one_pole_get_y_z1(&coeffs.smooth_state)
	return (k*x_car-ow_absf(k))*x_mod + x_mod
}

// Summary: Processes sample buffers for ring mod.
ow_ring_mod_process :: proc(coeffs: ^ow_ring_mod_coeffs, x_mod: ^f32, x_car: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x_mod != nil)
	OW_ASSERT(x_car != nil)
	OW_ASSERT(y != nil)

	xm := ([^]f32)(x_mod)
	xc := ([^]f32)(x_car)
	ym := ([^]f32)(y)

	for i := 0; i < n_samples; i += 1 {
		ow_ring_mod_update_coeffs_audio(coeffs)
		ym[i] = ow_ring_mod_process1(coeffs, xm[i], xc[i])
	}
}

// Summary: Processes multiple channels for ring mod.
ow_ring_mod_process_multi :: proc(coeffs: ^ow_ring_mod_coeffs, x_mod: ^^f32, x_car: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x_mod != nil)
	OW_ASSERT(x_car != nil)
	OW_ASSERT(y != nil)

	xm := ([^][^]f32)(x_mod)
	xc := ([^][^]f32)(x_car)
	ym := ([^][^]f32)(y)

	for i := 0; i < n_samples; i += 1 {
		ow_ring_mod_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_ring_mod_process1(coeffs, xm[ch][i], xc[ch][i])
		}
	}
}

// Summary: Sets amount for ring mod.
ow_ring_mod_set_amount :: proc(coeffs: ^ow_ring_mod_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= -1.0 && value <= 1.0)
	coeffs.mod_amount = value
}

// Summary: Checks validity of ring mod coeffs.
ow_ring_mod_coeffs_is_valid :: proc(coeffs: ^ow_ring_mod_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.mod_amount) || coeffs.mod_amount < -1.0 || coeffs.mod_amount > 1.0 {
		return 0
	}
	if !ow_one_pole_coeffs_is_valid(&coeffs.smooth_coeffs) {
		return 0
	}
	if !ow_one_pole_state_is_valid(&coeffs.smooth_coeffs, &coeffs.smooth_state) {
		return 0
	}
	return 1
}
