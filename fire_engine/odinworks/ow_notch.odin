package odinworks

// Summary: Coefficient data for notch.
ow_notch_coeffs :: struct {
	svf_coeffs: ow_svf_coeffs,
}

// Summary: Runtime state for notch.
ow_notch_state :: struct {
	svf_state: ow_svf_state,
}

// Summary: Initializes notch.
ow_notch_init :: proc(coeffs: ^ow_notch_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_init(&coeffs.svf_coeffs)
}

// Summary: Sets sample rate for notch.
ow_notch_set_sample_rate :: proc(coeffs: ^ow_notch_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	ow_svf_set_sample_rate(&coeffs.svf_coeffs, sample_rate)
}

// Summary: Resets coefficients for notch.
ow_notch_reset_coeffs :: proc(coeffs: ^ow_notch_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_reset_coeffs(&coeffs.svf_coeffs)
}

// Summary: Resets state for notch.
ow_notch_reset_state :: proc(coeffs: ^ow_notch_coeffs, state: ^ow_notch_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	lp, bp, hp: f32
	ow_svf_reset_state(&coeffs.svf_coeffs, &state.svf_state, x_0, &lp, &bp, &hp)
	_ = bp
	return lp + hp
}

// Summary: Resets multi-channel state for notch.
ow_notch_reset_state_multi :: proc(coeffs: ^ow_notch_coeffs, state: ^^ow_notch_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_notch_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_notch_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for notch.
ow_notch_update_coeffs_ctrl :: proc(coeffs: ^ow_notch_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_update_coeffs_ctrl(&coeffs.svf_coeffs)
}

// Summary: Updates audio-rate coefficients for notch.
ow_notch_update_coeffs_audio :: proc(coeffs: ^ow_notch_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_update_coeffs_audio(&coeffs.svf_coeffs)
}

// Summary: Processes one sample for notch.
ow_notch_process1 :: proc(coeffs: ^ow_notch_coeffs, state: ^ow_notch_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	lp, bp, hp: f32
	ow_svf_process1(&coeffs.svf_coeffs, &state.svf_state, x, &lp, &bp, &hp)
	_ = bp
	return lp + hp
}

// Summary: Processes sample buffers for notch.
ow_notch_process :: proc(coeffs: ^ow_notch_coeffs, state: ^ow_notch_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	ow_notch_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_notch_update_coeffs_audio(coeffs)
		ym[i] = ow_notch_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for notch.
ow_notch_process_multi :: proc(coeffs: ^ow_notch_coeffs, state: ^^ow_notch_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_notch_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_notch_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_notch_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_notch_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets cutoff for notch.
ow_notch_set_cutoff :: proc(coeffs: ^ow_notch_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	ow_svf_set_cutoff(&coeffs.svf_coeffs, value)
}

// Summary: Sets Q for notch.
ow_notch_set_Q :: proc(coeffs: ^ow_notch_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	ow_svf_set_Q(&coeffs.svf_coeffs, value)
}

// Summary: Sets prewarp at cutoff for notch.
ow_notch_set_prewarp_at_cutoff :: proc(coeffs: ^ow_notch_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	ow_svf_set_prewarp_at_cutoff(&coeffs.svf_coeffs, value)
}

// Summary: Sets prewarp freq for notch.
ow_notch_set_prewarp_freq :: proc(coeffs: ^ow_notch_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	ow_svf_set_prewarp_freq(&coeffs.svf_coeffs, value)
}

// Summary: Checks validity of notch coeffs.
ow_notch_coeffs_is_valid :: proc(coeffs: ^ow_notch_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	return ow_svf_coeffs_is_valid(&coeffs.svf_coeffs)
}

// Summary: Checks validity of notch state.
ow_notch_state_is_valid :: proc(coeffs: ^ow_notch_coeffs, state: ^ow_notch_state) -> i8 {
	if state == nil {
		return 0
	}
	if coeffs != nil {
		return ow_svf_state_is_valid(&coeffs.svf_coeffs, &state.svf_state)
	}
	return ow_svf_state_is_valid(nil, &state.svf_state)
}
