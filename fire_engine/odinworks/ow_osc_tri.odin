package odinworks

// Summary: Coefficient data for osc tri.
ow_osc_tri_coeffs :: struct {
	smooth_coeffs: ow_one_pole_coeffs,
	smooth_state: ow_one_pole_state,
	antialiasing: bool,
	slope: f32,
}

// Summary: Initializes osc tri.
ow_osc_tri_init :: proc(coeffs: ^ow_osc_tri_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_init(&coeffs.smooth_coeffs)
	ow_one_pole_set_tau(&coeffs.smooth_coeffs, 0.005)
	coeffs.antialiasing = false
	coeffs.slope = 0.5
}

// Summary: Sets sample rate for osc tri.
ow_osc_tri_set_sample_rate :: proc(coeffs: ^ow_osc_tri_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_one_pole_set_sample_rate(&coeffs.smooth_coeffs, sample_rate)
	ow_one_pole_reset_coeffs(&coeffs.smooth_coeffs)
}

// Summary: Resets coefficients for osc tri.
ow_osc_tri_reset_coeffs :: proc(coeffs: ^ow_osc_tri_coeffs) {
	OW_ASSERT(coeffs != nil)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_state, coeffs.slope)
}

// Summary: Updates control-rate coefficients for osc tri.
ow_osc_tri_update_coeffs_ctrl :: proc(coeffs: ^ow_osc_tri_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Updates audio-rate coefficients for osc tri.
ow_osc_tri_update_coeffs_audio :: proc(coeffs: ^ow_osc_tri_coeffs) {
	OW_ASSERT(coeffs != nil)
	_ = ow_one_pole_process1(&coeffs.smooth_coeffs, &coeffs.smooth_state, coeffs.slope)
}

// Summary: Processes one sample for osc tri.
ow_osc_tri_process1 :: proc(coeffs: ^ow_osc_tri_coeffs, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(x) && x >= 0.0 && x < 1.0)

	slope := ow_one_pole_get_y_z1(&coeffs.smooth_state)
	phase_d := x + x
	if x < slope {
		return (phase_d - slope) * ow_rcpf(slope)
	}
	return (1.0 + slope - phase_d) * ow_rcpf(1.0 - slope)
}

// Summary: Executes osc tri blamp diff.
ow_osc_tri_blamp_diff :: proc(x: f32) -> f32 {
	if x < 1.0 {
		return x*(x*((0.05*x-0.1666666666666667)*x*x+0.6666666666666666)-1.0)+0.4666666666666667
	}
	return x*(x*(x*((0.1666666666666667-0.01666666666666667*x)*x-0.6666666666666666)+1.333333333333333)-1.333333333333333)+0.5333333333333333
}

// Summary: Executes osc tri process1 antialias.
ow_osc_tri_process1_antialias :: proc(coeffs: ^ow_osc_tri_coeffs, x: f32, x_inc: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(x) && x >= 0.0 && x < 1.0)
	OW_ASSERT(ow_is_finite(x_inc) && x_inc >= -0.5 && x_inc <= 0.5)

	slope := ow_one_pole_get_y_z1(&coeffs.smooth_state)
	s_1_p_slope := 1.0 + slope
	s_1_m_slope := 1.0 - slope
	phase_d := x + x
	v := f32(0.0)
	if x < slope {
		v = (phase_d - slope) * ow_rcpf(slope)
	} else {
		v = (s_1_p_slope - phase_d) * ow_rcpf(s_1_m_slope)
	}

	a_inc := ow_absf(x_inc)
	if a_inc > 1.0e-6 {
		phase_inc_2 := a_inc + a_inc
		phase_inc_rcp := ow_rcpf(a_inc)
		slope_m_phase := slope - x
		phase_2 := ow_copysignf(0.5, slope_m_phase) + 0.5 - slope_m_phase
		s_1_m_phase := 1.0 - x
		s_1_m_phase_2 := 1.0 - phase_2
		blamp := f32(0.0)
		if s_1_m_phase_2 < phase_inc_2 {
			blamp += ow_osc_tri_blamp_diff(s_1_m_phase_2 * phase_inc_rcp)
		}
		if s_1_m_phase < phase_inc_2 {
			blamp -= ow_osc_tri_blamp_diff(s_1_m_phase * phase_inc_rcp)
		}
		if x < phase_inc_2 {
			blamp -= ow_osc_tri_blamp_diff(x * phase_inc_rcp)
		}
		if phase_2 < phase_inc_2 {
			blamp += ow_osc_tri_blamp_diff(phase_2 * phase_inc_rcp)
		}
		v -= ow_rcpf(slope*s_1_m_slope) * a_inc * blamp
	}

	return v
}

// Summary: Processes sample buffers for osc tri.
ow_osc_tri_process :: proc(coeffs: ^ow_osc_tri_coeffs, x: [^]f32, x_inc: [^]f32, y: [^]f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	if coeffs.antialiasing {
		OW_ASSERT(x_inc != nil)
	}

	if coeffs.antialiasing {
		for i := 0; i < n_samples; i += 1 {
			ow_osc_tri_update_coeffs_audio(coeffs)
			y[i] = ow_osc_tri_process1_antialias(coeffs, x[i], x_inc[i])
		}
	} else {
		for i := 0; i < n_samples; i += 1 {
			ow_osc_tri_update_coeffs_audio(coeffs)
			y[i] = ow_osc_tri_process1(coeffs, x[i])
		}
	}
}

// Summary: Processes multiple channels for osc tri.
ow_osc_tri_process_multi :: proc(coeffs: ^ow_osc_tri_coeffs, x: [^][^]f32, x_inc: [^][^]f32, y: [^][^]f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)

	if coeffs.antialiasing {
		OW_ASSERT(x_inc != nil)
		for i := 0; i < n_samples; i += 1 {
			ow_osc_tri_update_coeffs_audio(coeffs)
			for ch := 0; ch < n_channels; ch += 1 {
				y[ch][i] = ow_osc_tri_process1_antialias(coeffs, x[ch][i], x_inc[ch][i])
			}
		}
	} else {
		for i := 0; i < n_samples; i += 1 {
			ow_osc_tri_update_coeffs_audio(coeffs)
			for ch := 0; ch < n_channels; ch += 1 {
				y[ch][i] = ow_osc_tri_process1(coeffs, x[ch][i])
			}
		}
	}
}

// Summary: Sets antialiasing for osc tri.
ow_osc_tri_set_antialiasing :: proc(coeffs: ^ow_osc_tri_coeffs, value: bool) {
	OW_ASSERT(coeffs != nil)
	coeffs.antialiasing = value
}

// Summary: Sets slope for osc tri.
ow_osc_tri_set_slope :: proc(coeffs: ^ow_osc_tri_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.001 && value <= 0.999)
	coeffs.slope = value
}

// Summary: Checks validity of osc tri coeffs.
ow_osc_tri_coeffs_is_valid :: proc(coeffs: ^ow_osc_tri_coeffs) -> bool {
	if coeffs == nil {
		return false
	}
	if !ow_is_finite(coeffs.slope) || coeffs.slope < 0.001 || coeffs.slope > 0.999 {
		return false
	}
	if !ow_one_pole_coeffs_is_valid(&coeffs.smooth_coeffs) {
		return false
	}
	if !ow_one_pole_state_is_valid(&coeffs.smooth_coeffs, &coeffs.smooth_state) {
		return false
	}
	return true
}
