package odinworks

// Summary: Coefficient data for osc saw.
ow_osc_saw_coeffs :: struct {
	antialiasing: bool,
}

// Summary: Initializes osc saw.
ow_osc_saw_init :: proc(coeffs: ^ow_osc_saw_coeffs) {
	OW_ASSERT(coeffs != nil)
	coeffs.antialiasing = false
}

// Summary: Sets sample rate for osc saw.
ow_osc_saw_set_sample_rate :: proc(coeffs: ^ow_osc_saw_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
}

// Summary: Resets coefficients for osc saw.
ow_osc_saw_reset_coeffs :: proc(coeffs: ^ow_osc_saw_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Updates control-rate coefficients for osc saw.
ow_osc_saw_update_coeffs_ctrl :: proc(coeffs: ^ow_osc_saw_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Updates audio-rate coefficients for osc saw.
ow_osc_saw_update_coeffs_audio :: proc(coeffs: ^ow_osc_saw_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Processes one sample for osc saw.
ow_osc_saw_process1 :: proc(coeffs: ^ow_osc_saw_coeffs, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(x))
	OW_ASSERT(x >= 0.0 && x < 1.0)
	return x + x - 1.0
}

// Summary: Executes osc saw blep diff.
ow_osc_saw_blep_diff :: proc(x: f32) -> f32 {
	if x < 1.0 {
		return x*((0.25*x-0.6666666666666666)*x*x+1.333333333333333) - 1.0
	}
	return x*(x*((0.6666666666666666-0.08333333333333333*x)*x-2.0)+2.666666666666667) - 1.333333333333333
}

// Summary: Executes osc saw process1 antialias.
ow_osc_saw_process1_antialias :: proc(coeffs: ^ow_osc_saw_coeffs, x: f32, x_inc: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(x) && x >= 0.0 && x < 1.0)
	OW_ASSERT(ow_is_finite(x_inc) && x_inc >= -0.5 && x_inc <= 0.5)

	s_1_m_phase := 1.0 - x
	v := x - s_1_m_phase
	a_inc := ow_absf(x_inc)
	if a_inc > 1.0e-6 {
		a_inc_2 := a_inc + a_inc
		a_inc_rcp := ow_rcpf(a_inc)
		if s_1_m_phase < a_inc_2 {
			v += ow_osc_saw_blep_diff(s_1_m_phase * a_inc_rcp)
		}
		if x < a_inc_2 {
			v -= ow_osc_saw_blep_diff(x * a_inc_rcp)
		}
	}
	return v
}

// Summary: Processes sample buffers for osc saw.
ow_osc_saw_process :: proc(coeffs: ^ow_osc_saw_coeffs, x: [^]f32, x_inc: [^]f32, y: [^]f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	if coeffs.antialiasing {
		OW_ASSERT(x_inc != nil)
	}

	if coeffs.antialiasing {
		for i := 0; i < n_samples; i += 1 {
			y[i] = ow_osc_saw_process1_antialias(coeffs, x[i], x_inc[i])
		}
	} else {
		for i := 0; i < n_samples; i += 1 {
			y[i] = ow_osc_saw_process1(coeffs, x[i])
		}
	}
}

// Summary: Processes multiple channels for osc saw.
ow_osc_saw_process_multi :: proc(coeffs: ^ow_osc_saw_coeffs, x: [^][^]f32, x_inc: [^][^]f32, y: [^][^]f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)

	if x_inc != nil {
		for ch := 0; ch < n_channels; ch += 1 {
			ow_osc_saw_process(coeffs, x[ch], x_inc[ch], y[ch], n_samples)
		}
	} else {
		for ch := 0; ch < n_channels; ch += 1 {
			ow_osc_saw_process(coeffs, x[ch], nil, y[ch], n_samples)
		}
	}
}

// Summary: Sets antialiasing for osc saw.
ow_osc_saw_set_antialiasing :: proc(coeffs: ^ow_osc_saw_coeffs, value: bool) {
	OW_ASSERT(coeffs != nil)
	coeffs.antialiasing = value
}

// Summary: Checks validity of osc saw coeffs.
ow_osc_saw_coeffs_is_valid :: proc(coeffs: ^ow_osc_saw_coeffs) -> bool {
	return coeffs != nil
}
