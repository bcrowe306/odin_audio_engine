package odinworks

// Summary: Coefficient data for phaser.
ow_phaser_coeffs :: struct {
	phase_gen_coeffs: ow_phase_gen_coeffs,
	phase_gen_state: ow_phase_gen_state,
	ap1_coeffs: ow_ap1_coeffs,
	center: f32,
	amount: f32,
}

// Summary: Runtime state for phaser.
ow_phaser_state :: struct {
	ap1_state: [4]ow_ap1_state,
}

// Summary: Initializes phaser.
ow_phaser_init :: proc(coeffs: ^ow_phaser_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_phase_gen_init(&coeffs.phase_gen_coeffs)
	ow_ap1_init(&coeffs.ap1_coeffs)
	coeffs.center = 1.0e3
	coeffs.amount = 1.0
}

// Summary: Sets sample rate for phaser.
ow_phaser_set_sample_rate :: proc(coeffs: ^ow_phaser_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_phase_gen_set_sample_rate(&coeffs.phase_gen_coeffs, sample_rate)
	ow_ap1_set_sample_rate(&coeffs.ap1_coeffs, sample_rate)
}

// Summary: Resets coefficients for phaser.
ow_phaser_reset_coeffs :: proc(coeffs: ^ow_phaser_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_phase_gen_reset_coeffs(&coeffs.phase_gen_coeffs)
	p, inc: f32
	ow_phase_gen_reset_state(&coeffs.phase_gen_coeffs, &coeffs.phase_gen_state, 0.0, &p, &inc)
	ow_ap1_set_cutoff(&coeffs.ap1_coeffs, coeffs.center)
	ow_ap1_reset_coeffs(&coeffs.ap1_coeffs)
}

// Summary: Resets state for phaser.
ow_phaser_reset_state :: proc(coeffs: ^ow_phaser_coeffs, state: ^ow_phaser_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	y := ow_ap1_reset_state(&coeffs.ap1_coeffs, &state.ap1_state[0], x_0)
	y = ow_ap1_reset_state(&coeffs.ap1_coeffs, &state.ap1_state[1], y)
	y = ow_ap1_reset_state(&coeffs.ap1_coeffs, &state.ap1_state[2], y)
	y = x_0 + ow_ap1_reset_state(&coeffs.ap1_coeffs, &state.ap1_state[3], y)
	return y
}

// Summary: Resets multi-channel state for phaser.
ow_phaser_reset_state_multi :: proc(coeffs: ^ow_phaser_coeffs, state: ^^ow_phaser_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_phaser_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_phaser_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for phaser.
ow_phaser_update_coeffs_ctrl :: proc(coeffs: ^ow_phaser_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_phase_gen_update_coeffs_ctrl(&coeffs.phase_gen_coeffs)
}

// Summary: Updates audio-rate coefficients for phaser.
ow_phaser_update_coeffs_audio :: proc(coeffs: ^ow_phaser_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_phase_gen_update_coeffs_audio(&coeffs.phase_gen_coeffs)
	p, pi: f32
	ow_phase_gen_process1(&coeffs.phase_gen_coeffs, &coeffs.phase_gen_state, &p, &pi)
	m := coeffs.amount * ow_osc_sin_process1(p)
	ow_ap1_set_cutoff(&coeffs.ap1_coeffs, coeffs.center*ow_pow2f(m))
	ow_ap1_update_coeffs_ctrl(&coeffs.ap1_coeffs)
	ow_ap1_update_coeffs_audio(&coeffs.ap1_coeffs)
}

// Summary: Processes one sample for phaser.
ow_phaser_process1 :: proc(coeffs: ^ow_phaser_coeffs, state: ^ow_phaser_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	y := ow_ap1_process1(&coeffs.ap1_coeffs, &state.ap1_state[0], x)
	y = ow_ap1_process1(&coeffs.ap1_coeffs, &state.ap1_state[1], y)
	y = ow_ap1_process1(&coeffs.ap1_coeffs, &state.ap1_state[2], y)
	y = x + ow_ap1_process1(&coeffs.ap1_coeffs, &state.ap1_state[3], y)
	return y
}

// Summary: Processes sample buffers for phaser.
ow_phaser_process :: proc(coeffs: ^ow_phaser_coeffs, state: ^ow_phaser_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	ow_phaser_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_phaser_update_coeffs_audio(coeffs)
		ym[i] = ow_phaser_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for phaser.
ow_phaser_process_multi :: proc(coeffs: ^ow_phaser_coeffs, state: ^^ow_phaser_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_phaser_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_phaser_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_phaser_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_phaser_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets rate for phaser.
ow_phaser_set_rate :: proc(coeffs: ^ow_phaser_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	ow_phase_gen_set_frequency(&coeffs.phase_gen_coeffs, value)
}

// Summary: Sets center for phaser.
ow_phaser_set_center :: proc(coeffs: ^ow_phaser_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 1.0e-6 && value <= 1.0e12)
	coeffs.center = value
}

// Summary: Sets amount for phaser.
ow_phaser_set_amount :: proc(coeffs: ^ow_phaser_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0)
	coeffs.amount = value
}

// Summary: Checks validity of phaser coeffs.
ow_phaser_coeffs_is_valid :: proc(coeffs: ^ow_phaser_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.center) || coeffs.center < 1.0e-6 || coeffs.center > 1.0e12 {
		return 0
	}
	if !ow_is_finite(coeffs.amount) || coeffs.amount < 0.0 {
		return 0
	}
	if !ow_phase_gen_coeffs_is_valid(&coeffs.phase_gen_coeffs) {
		return 0
	}
	if ow_ap1_coeffs_is_valid(&coeffs.ap1_coeffs) == 0 {
		return 0
	}
	return 1
}

// Summary: Checks validity of phaser state.
ow_phaser_state_is_valid :: proc(coeffs: ^ow_phaser_coeffs, state: ^ow_phaser_state) -> i8 {
	if state == nil {
		return 0
	}
	ap1_coeffs: ^ow_ap1_coeffs
	if coeffs != nil {
		ap1_coeffs = &coeffs.ap1_coeffs
	}
	if ow_ap1_state_is_valid(ap1_coeffs, &state.ap1_state[0]) == 0 {
		return 0
	}
	if ow_ap1_state_is_valid(ap1_coeffs, &state.ap1_state[1]) == 0 {
		return 0
	}
	if ow_ap1_state_is_valid(ap1_coeffs, &state.ap1_state[2]) == 0 {
		return 0
	}
	if ow_ap1_state_is_valid(ap1_coeffs, &state.ap1_state[3]) == 0 {
		return 0
	}
	return 1
}
