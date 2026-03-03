package odinworks

// Summary: Coefficient data for wah.
ow_wah_coeffs :: struct {
	svf_coeffs: ow_svf_coeffs,
}

// Summary: Runtime state for wah.
ow_wah_state :: struct {
	svf_state: ow_svf_state,
}

// Summary: Initializes wah.
ow_wah_init :: proc(coeffs: ^ow_wah_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_init(&coeffs.svf_coeffs)
	ow_svf_set_cutoff(&coeffs.svf_coeffs, 600.0)
	ow_svf_set_Q(&coeffs.svf_coeffs, 9.0)
}

// Summary: Sets sample rate for wah.
ow_wah_set_sample_rate :: proc(coeffs: ^ow_wah_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_svf_set_sample_rate(&coeffs.svf_coeffs, sample_rate)
}

// Summary: Resets coefficients for wah.
ow_wah_reset_coeffs :: proc(coeffs: ^ow_wah_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_reset_coeffs(&coeffs.svf_coeffs)
}

// Summary: Resets state for wah.
ow_wah_reset_state :: proc(coeffs: ^ow_wah_coeffs, state: ^ow_wah_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	v_lp, v_bp, v_hp: f32
	ow_svf_reset_state(&coeffs.svf_coeffs, &state.svf_state, x_0, &v_lp, &v_bp, &v_hp)
	return v_bp
}

// Summary: Resets multi-channel state for wah.
ow_wah_reset_state_multi :: proc(coeffs: ^ow_wah_coeffs, state: ^^ow_wah_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_wah_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_wah_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for wah.
ow_wah_update_coeffs_ctrl :: proc(coeffs: ^ow_wah_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_update_coeffs_ctrl(&coeffs.svf_coeffs)
}

// Summary: Updates audio-rate coefficients for wah.
ow_wah_update_coeffs_audio :: proc(coeffs: ^ow_wah_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_svf_update_coeffs_audio(&coeffs.svf_coeffs)
}

// Summary: Processes one sample for wah.
ow_wah_process1 :: proc(coeffs: ^ow_wah_coeffs, state: ^ow_wah_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	v_lp, v_bp, v_hp: f32
	ow_svf_process1(&coeffs.svf_coeffs, &state.svf_state, x, &v_lp, &v_bp, &v_hp)
	return v_bp
}

// Summary: Processes sample buffers for wah.
ow_wah_process :: proc(coeffs: ^ow_wah_coeffs, state: ^ow_wah_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	ow_wah_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_wah_update_coeffs_audio(coeffs)
		ym[i] = ow_wah_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for wah.
ow_wah_process_multi :: proc(coeffs: ^ow_wah_coeffs, state: ^^ow_wah_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_wah_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_wah_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_wah_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_wah_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets wah for wah.
ow_wah_set_wah :: proc(coeffs: ^ow_wah_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	OW_ASSERT(value >= 0.0 && value <= 1.0)
	v3 := value * value * value
	ow_svf_set_cutoff(&coeffs.svf_coeffs, 400.0+(2.0e3-400.0)*v3)
}

// Summary: Checks validity of wah coeffs.
ow_wah_coeffs_is_valid :: proc(coeffs: ^ow_wah_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	return ow_svf_coeffs_is_valid(&coeffs.svf_coeffs)
}

// Summary: Checks validity of wah state.
ow_wah_state_is_valid :: proc(coeffs: ^ow_wah_coeffs, state: ^ow_wah_state) -> i8 {
	if state == nil {
		return 0
	}
	svf_coeffs: ^ow_svf_coeffs
	if coeffs != nil {
		svf_coeffs = &coeffs.svf_coeffs
	}
	return ow_svf_state_is_valid(svf_coeffs, &state.svf_state)
}
