package odinworks

// Summary: Coefficient data for pink filt.
ow_pink_filt_coeffs :: struct {
	scaling_k: f32,
	sample_rate_scaling: i8,
}

// Summary: Runtime state for pink filt.
ow_pink_filt_state :: struct {
	s1_z1: f32,
	s2_z1: f32,
	s3_z1: f32,
	s4_z1: f32,
}

// Summary: Initializes pink filt.
ow_pink_filt_init :: proc(coeffs: ^ow_pink_filt_coeffs) {
	OW_ASSERT(coeffs != nil)
	coeffs.sample_rate_scaling = 0
}

// Summary: Sets sample rate for pink filt.
ow_pink_filt_set_sample_rate :: proc(coeffs: ^ow_pink_filt_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	coeffs.scaling_k = 210.0 / ow_sqrtf(sample_rate)
}

// Summary: Resets coefficients for pink filt.
ow_pink_filt_reset_coeffs :: proc(coeffs: ^ow_pink_filt_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Resets state for pink filt.
ow_pink_filt_reset_state :: proc(coeffs: ^ow_pink_filt_coeffs, state: ^ow_pink_filt_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	state.s1_z1 = x_0
	state.s2_z1 = x_0
	state.s3_z1 = x_0
	state.s4_z1 = x_0
	if coeffs.sample_rate_scaling != 0 {
		return coeffs.scaling_k * x_0
	}
	return x_0
}

// Summary: Resets multi-channel state for pink filt.
ow_pink_filt_reset_state_multi :: proc(coeffs: ^ow_pink_filt_coeffs, state: ^^ow_pink_filt_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_pink_filt_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_pink_filt_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for pink filt.
ow_pink_filt_update_coeffs_ctrl :: proc(coeffs: ^ow_pink_filt_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Updates audio-rate coefficients for pink filt.
ow_pink_filt_update_coeffs_audio :: proc(coeffs: ^ow_pink_filt_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Processes one sample for pink filt.
ow_pink_filt_process1 :: proc(coeffs: ^ow_pink_filt_coeffs, state: ^ow_pink_filt_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	_ = coeffs
	s1 := 0.320696754235142 * x + state.s1_z1
	state.s1_z1 = 0.999760145116749 * s1 - 0.3204568993518913 * x
	s2 := 0.2870206617007935 * s1 + state.s2_z1
	state.s2_z1 = 0.9974135207366259 * s2 - 0.2844341824374191 * s1
	s3 := 0.2962862885898576 * s2 + state.s3_z1
	state.s3_z1 = 0.9687905029568185 * s3 - 0.265076791546676 * s2
	s4 := 0.3882183163519794 * s3 + state.s4_z1
	state.s4_z1 = 0.6573784623288251 * s4 - 0.04559677868080467 * s3
	return s4
}

// Summary: Executes pink filt process1 scaling.
ow_pink_filt_process1_scaling :: proc(coeffs: ^ow_pink_filt_coeffs, state: ^ow_pink_filt_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	return coeffs.scaling_k * ow_pink_filt_process1(coeffs, state, x)
}

// Summary: Processes sample buffers for pink filt.
ow_pink_filt_process :: proc(coeffs: ^ow_pink_filt_coeffs, state: ^ow_pink_filt_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	if coeffs.sample_rate_scaling != 0 {
		for i := 0; i < n_samples; i += 1 {
			ym[i] = ow_pink_filt_process1_scaling(coeffs, state, xm[i])
		}
	} else {
		for i := 0; i < n_samples; i += 1 {
			ym[i] = ow_pink_filt_process1(coeffs, state, xm[i])
		}
	}
}

// Summary: Processes multiple channels for pink filt.
ow_pink_filt_process_multi :: proc(coeffs: ^ow_pink_filt_coeffs, state: ^^ow_pink_filt_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_pink_filt_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	for ch := 0; ch < n_channels; ch += 1 {
		ow_pink_filt_process(coeffs, states[ch], xm[ch], ym[ch], n_samples)
	}
}

// Summary: Sets sample rate scaling for pink filt.
ow_pink_filt_set_sample_rate_scaling :: proc(coeffs: ^ow_pink_filt_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	coeffs.sample_rate_scaling = value
}

// Summary: Gets scaling k from pink filt.
ow_pink_filt_get_scaling_k :: proc(coeffs: ^ow_pink_filt_coeffs) -> f32 {
	OW_ASSERT(coeffs != nil)
	return coeffs.scaling_k
}

// Summary: Checks validity of pink filt coeffs.
ow_pink_filt_coeffs_is_valid :: proc(coeffs: ^ow_pink_filt_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.scaling_k) || coeffs.scaling_k <= 0.0 {
		return 0
	}
	return 1
}

// Summary: Checks validity of pink filt state.
ow_pink_filt_state_is_valid :: proc(coeffs: ^ow_pink_filt_coeffs, state: ^ow_pink_filt_state) -> i8 {
	if state == nil {
		return 0
	}
	_ = coeffs
	if !ow_is_finite(state.s1_z1) || !ow_is_finite(state.s2_z1) || !ow_is_finite(state.s3_z1) || !ow_is_finite(state.s4_z1) {
		return 0
	}
	return 1
}
