package odinworks

// Summary: Coefficient data for chorus.
ow_chorus_coeffs :: struct {
	phase_gen_coeffs: ow_phase_gen_coeffs,
	phase_gen_state: ow_phase_gen_state,
	comb_coeffs: ow_comb_coeffs,
	delay: f32,
	amount: f32,
}

// Summary: Runtime state for chorus.
ow_chorus_state :: struct {
	comb_state: ow_comb_state,
}

// Summary: Initializes chorus.
ow_chorus_init :: proc(coeffs: ^ow_chorus_coeffs, max_delay: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(max_delay) && max_delay >= 0.0)
	ow_phase_gen_init(&coeffs.phase_gen_coeffs)
	ow_comb_init(&coeffs.comb_coeffs, max_delay)
	coeffs.delay = 0.0
	coeffs.amount = 0.0
}

// Summary: Sets sample rate for chorus.
ow_chorus_set_sample_rate :: proc(coeffs: ^ow_chorus_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_phase_gen_set_sample_rate(&coeffs.phase_gen_coeffs, sample_rate)
	ow_comb_set_sample_rate(&coeffs.comb_coeffs, sample_rate)
}

// Summary: Executes chorus mem req.
ow_chorus_mem_req :: proc(coeffs: ^ow_chorus_coeffs) -> int {
	OW_ASSERT(coeffs != nil)
	return ow_comb_mem_req(&coeffs.comb_coeffs)
}

// Summary: Executes chorus mem set.
ow_chorus_mem_set :: proc(coeffs: ^ow_chorus_coeffs, state: ^ow_chorus_state, mem: rawptr) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(mem != nil)
	ow_comb_mem_set(&coeffs.comb_coeffs, &state.comb_state, mem)
}

// Summary: Resets coefficients for chorus.
ow_chorus_reset_coeffs :: proc(coeffs: ^ow_chorus_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_phase_gen_reset_coeffs(&coeffs.phase_gen_coeffs)
	p, pi: f32
	ow_phase_gen_reset_state(&coeffs.phase_gen_coeffs, &coeffs.phase_gen_state, 0.0, &p, &pi)
	mod := coeffs.delay + coeffs.amount*ow_osc_sin_process1(p)
	ow_comb_set_delay_ff(&coeffs.comb_coeffs, mod)
	ow_comb_reset_coeffs(&coeffs.comb_coeffs)
}

// Summary: Resets state for chorus.
ow_chorus_reset_state :: proc(coeffs: ^ow_chorus_coeffs, state: ^ow_chorus_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	return ow_comb_reset_state(&coeffs.comb_coeffs, &state.comb_state, x_0)
}

// Summary: Resets multi-channel state for chorus.
ow_chorus_reset_state_multi :: proc(coeffs: ^ow_chorus_coeffs, state: ^^ow_chorus_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_chorus_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_chorus_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for chorus.
ow_chorus_update_coeffs_ctrl :: proc(coeffs: ^ow_chorus_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_phase_gen_update_coeffs_ctrl(&coeffs.phase_gen_coeffs)
	ow_comb_update_coeffs_ctrl(&coeffs.comb_coeffs)
}

// Summary: Updates audio-rate coefficients for chorus.
ow_chorus_update_coeffs_audio :: proc(coeffs: ^ow_chorus_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_phase_gen_update_coeffs_audio(&coeffs.phase_gen_coeffs)
	p, pi: f32
	ow_phase_gen_process1(&coeffs.phase_gen_coeffs, &coeffs.phase_gen_state, &p, &pi)
	mod := coeffs.delay + coeffs.amount*ow_osc_sin_process1(p)
	ow_comb_set_delay_ff(&coeffs.comb_coeffs, mod)
	ow_comb_update_coeffs_ctrl(&coeffs.comb_coeffs)
	ow_comb_update_coeffs_audio(&coeffs.comb_coeffs)
}

// Summary: Processes one sample for chorus.
ow_chorus_process1 :: proc(coeffs: ^ow_chorus_coeffs, state: ^ow_chorus_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	return ow_comb_process1(&coeffs.comb_coeffs, &state.comb_state, x)
}

// Summary: Processes sample buffers for chorus.
ow_chorus_process :: proc(coeffs: ^ow_chorus_coeffs, state: ^ow_chorus_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	ow_chorus_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_chorus_update_coeffs_audio(coeffs)
		ym[i] = ow_chorus_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for chorus.
ow_chorus_process_multi :: proc(coeffs: ^ow_chorus_coeffs, state: ^^ow_chorus_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_chorus_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_chorus_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_chorus_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_chorus_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets rate for chorus.
ow_chorus_set_rate :: proc(coeffs: ^ow_chorus_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	ow_phase_gen_set_frequency(&coeffs.phase_gen_coeffs, value)
}

// Summary: Sets delay for chorus.
ow_chorus_set_delay :: proc(coeffs: ^ow_chorus_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	ow_comb_set_delay_fb(&coeffs.comb_coeffs, value)
	coeffs.delay = value
}

// Summary: Sets amount for chorus.
ow_chorus_set_amount :: proc(coeffs: ^ow_chorus_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	coeffs.amount = value
}

// Summary: Sets coeff x for chorus.
ow_chorus_set_coeff_x :: proc(coeffs: ^ow_chorus_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	ow_comb_set_coeff_blend(&coeffs.comb_coeffs, value)
}

// Summary: Sets coeff mod for chorus.
ow_chorus_set_coeff_mod :: proc(coeffs: ^ow_chorus_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	ow_comb_set_coeff_ff(&coeffs.comb_coeffs, value)
}

// Summary: Sets coeff fb for chorus.
ow_chorus_set_coeff_fb :: proc(coeffs: ^ow_chorus_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= -1.0 && value <= 1.0)
	ow_comb_set_coeff_fb(&coeffs.comb_coeffs, value)
}

// Summary: Checks validity of chorus coeffs.
ow_chorus_coeffs_is_valid :: proc(coeffs: ^ow_chorus_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.delay) {
		return 0
	}
	if !ow_is_finite(coeffs.amount) {
		return 0
	}
	if !ow_phase_gen_coeffs_is_valid(&coeffs.phase_gen_coeffs) {
		return 0
	}
	if ow_comb_coeffs_is_valid(&coeffs.comb_coeffs) == 0 {
		return 0
	}
	return 1
}

// Summary: Checks validity of chorus state.
ow_chorus_state_is_valid :: proc(coeffs: ^ow_chorus_coeffs, state: ^ow_chorus_state) -> i8 {
	if state == nil {
		return 0
	}
	comb_coeffs: ^ow_comb_coeffs
	if coeffs != nil {
		comb_coeffs = &coeffs.comb_coeffs
	}
	return ow_comb_state_is_valid(comb_coeffs, &state.comb_state)
}
