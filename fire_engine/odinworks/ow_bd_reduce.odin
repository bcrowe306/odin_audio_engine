package odinworks

// Summary: Coefficient data for bd reduce.
ow_bd_reduce_coeffs :: struct {
	ki: f32,
	k: f32,
	ko: f32,
	max: f32,
	gate: f32,
	bit_depth: i8,
	bit_depth_prev: i8,
}

// Summary: Initializes bd reduce.
ow_bd_reduce_init :: proc(coeffs: ^ow_bd_reduce_coeffs) {
	OW_ASSERT(coeffs != nil)
	coeffs.bit_depth = 16
	coeffs.ko = 0.5
	coeffs.gate = 0.0
}

// Summary: Sets sample rate for bd reduce.
ow_bd_reduce_set_sample_rate :: proc(coeffs: ^ow_bd_reduce_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	_ = sample_rate
}

// Summary: Updates control-rate coefficients for bd reduce do.
ow_bd_reduce_do_update_coeffs_ctrl :: proc(coeffs: ^ow_bd_reduce_coeffs) {
	if coeffs.bit_depth_prev != coeffs.bit_depth {
		coeffs.k = ow_pow2f(f32(coeffs.bit_depth - 1))
		coeffs.ki = ow_rcpf(coeffs.k)
		coeffs.max = 1.0 - 0.5*coeffs.ki
		coeffs.bit_depth_prev = coeffs.bit_depth
	}
}

// Summary: Resets coefficients for bd reduce.
ow_bd_reduce_reset_coeffs :: proc(coeffs: ^ow_bd_reduce_coeffs) {
	OW_ASSERT(coeffs != nil)
	coeffs.bit_depth_prev = 0
	ow_bd_reduce_do_update_coeffs_ctrl(coeffs)
}

// Summary: Updates control-rate coefficients for bd reduce.
ow_bd_reduce_update_coeffs_ctrl :: proc(coeffs: ^ow_bd_reduce_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_bd_reduce_do_update_coeffs_ctrl(coeffs)
}

// Summary: Updates audio-rate coefficients for bd reduce.
ow_bd_reduce_update_coeffs_audio :: proc(coeffs: ^ow_bd_reduce_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Processes one sample for bd reduce.
ow_bd_reduce_process1 :: proc(coeffs: ^ow_bd_reduce_coeffs, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(x))
	v := x
	if ow_absf(v) < coeffs.gate {
		v = 0.0
	}
	return coeffs.ki * (ow_floorf(coeffs.k*ow_clipf(v, -coeffs.max, coeffs.max)) + coeffs.ko)
}

// Summary: Processes sample buffers for bd reduce.
ow_bd_reduce_process :: proc(coeffs: ^ow_bd_reduce_coeffs, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	ow_bd_reduce_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ym[i] = ow_bd_reduce_process1(coeffs, xm[i])
	}
}

// Summary: Processes multiple channels for bd reduce.
ow_bd_reduce_process_multi :: proc(coeffs: ^ow_bd_reduce_coeffs, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_bd_reduce_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_bd_reduce_process1(coeffs, xm[ch][i])
		}
	}
}

// Summary: Sets bit depth for bd reduce.
ow_bd_reduce_set_bit_depth :: proc(coeffs: ^ow_bd_reduce_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(value >= 1 && value <= 64)
	coeffs.bit_depth = value
}

// Summary: Sets silence dc for bd reduce.
ow_bd_reduce_set_silence_dc :: proc(coeffs: ^ow_bd_reduce_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	if value != 0 {
		coeffs.ko = 0.5
	} else {
		coeffs.ko = 0.0
	}
}

// Summary: Sets gate lin for bd reduce.
ow_bd_reduce_set_gate_lin :: proc(coeffs: ^ow_bd_reduce_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	OW_ASSERT(value >= 0.0 && value <= 1.0)
	coeffs.gate = value
}

// Summary: Sets gate dBFS for bd reduce.
ow_bd_reduce_set_gate_dBFS :: proc(coeffs: ^ow_bd_reduce_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	OW_ASSERT(value <= 0.0)
	coeffs.gate = ow_dB2linf(value)
}

// Summary: Checks validity of bd reduce coeffs.
ow_bd_reduce_coeffs_is_valid :: proc(coeffs: ^ow_bd_reduce_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if coeffs.bit_depth < 1 || coeffs.bit_depth > 64 {
		return 0
	}
	if coeffs.ko != 0.0 && coeffs.ko != 0.5 {
		return 0
	}
	if !ow_is_finite(coeffs.gate) || coeffs.gate < 0.0 || coeffs.gate > 1.0 {
		return 0
	}
	return 1
}
