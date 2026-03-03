package odinworks

// Summary: Coefficient data for noise gen.
ow_noise_gen_coeffs :: struct {
	scaling_k: f32,
	rand_state: ^u64,
	sample_rate_scaling: bool,
}

NOISE_SCALE_COEFF: f32 : 0.004761904761904762

// Summary: Initializes noise gen.
ow_noise_gen_init :: proc(coeffs: ^ow_noise_gen_coeffs, state: ^u64) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	coeffs.rand_state = state
	coeffs.sample_rate_scaling = false
	coeffs.scaling_k = 1.0
}

// Summary: Sets sample rate for noise gen.
ow_noise_gen_set_sample_rate :: proc(coeffs: ^ow_noise_gen_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	coeffs.scaling_k = NOISE_SCALE_COEFF * ow_sqrtf(sample_rate)
}

// Summary: Resets coefficients for noise gen.
ow_noise_gen_reset_coeffs :: proc(coeffs: ^ow_noise_gen_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Updates control-rate coefficients for noise gen.
ow_noise_gen_update_coeffs_ctrl :: proc(coeffs: ^ow_noise_gen_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Updates audio-rate coefficients for noise gen.
ow_noise_gen_update_coeffs_audio :: proc(coeffs: ^ow_noise_gen_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Processes one sample for noise gen.
ow_noise_gen_process1 :: proc(coeffs: ^ow_noise_gen_coeffs) -> f32 {
	OW_ASSERT(coeffs != nil)
	return ow_randf(coeffs.rand_state)
}

// Summary: Executes noise gen process1 scaling.
ow_noise_gen_process1_scaling :: proc(coeffs: ^ow_noise_gen_coeffs) -> f32 {
	OW_ASSERT(coeffs != nil)
	return coeffs.scaling_k * ow_randf(coeffs.rand_state)
}

// Summary: Processes sample buffers for noise gen.
ow_noise_gen_process :: proc(coeffs: ^ow_noise_gen_coeffs, y: [^]f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(y != nil)

	if coeffs.sample_rate_scaling {
		for i := 0; i < n_samples; i += 1 {
			y[i] = ow_noise_gen_process1_scaling(coeffs)
		}
	} else {
		for i := 0; i < n_samples; i += 1 {
			y[i] = ow_noise_gen_process1(coeffs)
		}
	}
}

// Summary: Processes multiple channels for noise gen.
ow_noise_gen_process_multi :: proc(coeffs: ^ow_noise_gen_coeffs, y: [^][^]f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(y != nil)

	for ch := 0; ch < n_channels; ch += 1 {
		ow_noise_gen_process(coeffs, y[ch], n_samples)
	}
}

// Summary: Sets sample rate scaling for noise gen.
ow_noise_gen_set_sample_rate_scaling :: proc(coeffs: ^ow_noise_gen_coeffs, value: bool) {
	OW_ASSERT(coeffs != nil)
	coeffs.sample_rate_scaling = value
}

// Summary: Gets scaling k from noise gen.
ow_noise_gen_get_scaling_k :: proc(coeffs: ^ow_noise_gen_coeffs) -> f32 {
	OW_ASSERT(coeffs != nil)
	return coeffs.scaling_k
}

// Summary: Checks validity of noise gen coeffs.
ow_noise_gen_coeffs_is_valid :: proc(coeffs: ^ow_noise_gen_coeffs) -> bool {
	if coeffs == nil {
		return false
	}
	if coeffs.rand_state == nil {
		return false
	}
	if !ow_is_finite(coeffs.scaling_k) || coeffs.scaling_k <= 0.0 {
		return false
	}
	return true
}
