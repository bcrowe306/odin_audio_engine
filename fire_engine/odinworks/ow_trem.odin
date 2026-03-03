package odinworks

// Summary: Coefficient data for trem.
ow_trem_coeffs :: struct {
	phase_gen_coeffs: ow_phase_gen_coeffs,
	ring_mod_coeffs: ow_ring_mod_coeffs,
}

// Summary: Runtime state for trem.
ow_trem_state :: struct {
	phase_gen_state: ow_phase_gen_state,
}

// Summary: Initializes trem.
ow_trem_init :: proc(coeffs: ^ow_trem_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_phase_gen_init(&coeffs.phase_gen_coeffs)
	ow_ring_mod_init(&coeffs.ring_mod_coeffs)
}

// Summary: Sets sample rate for trem.
ow_trem_set_sample_rate :: proc(coeffs: ^ow_trem_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_phase_gen_set_sample_rate(&coeffs.phase_gen_coeffs, sample_rate)
	ow_ring_mod_set_sample_rate(&coeffs.ring_mod_coeffs, sample_rate)
}

// Summary: Resets coefficients for trem.
ow_trem_reset_coeffs :: proc(coeffs: ^ow_trem_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_phase_gen_reset_coeffs(&coeffs.phase_gen_coeffs)
	ow_ring_mod_reset_coeffs(&coeffs.ring_mod_coeffs)
}

// Summary: Resets state for trem.
ow_trem_reset_state :: proc(coeffs: ^ow_trem_coeffs, state: ^ow_trem_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	p, pi: f32
	ow_phase_gen_reset_state(&coeffs.phase_gen_coeffs, &state.phase_gen_state, 0.0, &p, &pi)
	c := ow_osc_sin_process1(p)
	return ow_ring_mod_process1(&coeffs.ring_mod_coeffs, x_0, 1.0+c)
}

// Summary: Resets multi-channel state for trem.
ow_trem_reset_state_multi :: proc(coeffs: ^ow_trem_coeffs, state: ^^ow_trem_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_trem_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_trem_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for trem.
ow_trem_update_coeffs_ctrl :: proc(coeffs: ^ow_trem_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_phase_gen_update_coeffs_ctrl(&coeffs.phase_gen_coeffs)
	ow_ring_mod_update_coeffs_ctrl(&coeffs.ring_mod_coeffs)
}

// Summary: Updates audio-rate coefficients for trem.
ow_trem_update_coeffs_audio :: proc(coeffs: ^ow_trem_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_phase_gen_update_coeffs_audio(&coeffs.phase_gen_coeffs)
	ow_ring_mod_update_coeffs_audio(&coeffs.ring_mod_coeffs)
}

// Summary: Processes one sample for trem.
ow_trem_process1 :: proc(coeffs: ^ow_trem_coeffs, state: ^ow_trem_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	p, pi: f32
	ow_phase_gen_process1(&coeffs.phase_gen_coeffs, &state.phase_gen_state, &p, &pi)
	c := ow_osc_sin_process1(p)
	return ow_ring_mod_process1(&coeffs.ring_mod_coeffs, x, 1.0+c)
}

// Summary: Processes sample buffers for trem.
ow_trem_process :: proc(coeffs: ^ow_trem_coeffs, state: ^ow_trem_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	ow_trem_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_trem_update_coeffs_audio(coeffs)
		ym[i] = ow_trem_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for trem.
ow_trem_process_multi :: proc(coeffs: ^ow_trem_coeffs, state: ^^ow_trem_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_trem_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_trem_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_trem_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_trem_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets rate for trem.
ow_trem_set_rate :: proc(coeffs: ^ow_trem_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	ow_phase_gen_set_frequency(&coeffs.phase_gen_coeffs, value)
}

// Summary: Sets amount for trem.
ow_trem_set_amount :: proc(coeffs: ^ow_trem_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= -1.0 && value <= 1.0)
	ow_ring_mod_set_amount(&coeffs.ring_mod_coeffs, value)
}

// Summary: Checks validity of trem coeffs.
ow_trem_coeffs_is_valid :: proc(coeffs: ^ow_trem_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_phase_gen_coeffs_is_valid(&coeffs.phase_gen_coeffs) {
		return 0
	}
	if ow_ring_mod_coeffs_is_valid(&coeffs.ring_mod_coeffs) == 0 {
		return 0
	}
	return 1
}

// Summary: Checks validity of trem state.
ow_trem_state_is_valid :: proc(coeffs: ^ow_trem_coeffs, state: ^ow_trem_state) -> i8 {
	if state == nil {
		return 0
	}
	phase_gen_coeffs: ^ow_phase_gen_coeffs
	if coeffs != nil {
		phase_gen_coeffs = &coeffs.phase_gen_coeffs
	}
	if !ow_phase_gen_state_is_valid(phase_gen_coeffs, &state.phase_gen_state) {
		return 0
	}
	return 1
}
