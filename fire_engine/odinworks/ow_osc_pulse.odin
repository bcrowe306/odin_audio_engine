package odinworks

// Summary: Coefficient data for osc pulse.
ow_osc_pulse_coeffs :: struct {
	smooth_coeffs: ow_one_pole_coeffs,
	smooth_state: ow_one_pole_state,
	antialiasing: i8,
	pulse_width: f32,
}

// Summary: Initializes osc pulse.
ow_osc_pulse_init :: proc(coeffs: ^ow_osc_pulse_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_init(&coeffs.smooth_coeffs)
	ow_one_pole_set_tau(&coeffs.smooth_coeffs, 0.005)
	coeffs.antialiasing = 0
	coeffs.pulse_width = 0.5
}

// Summary: Sets sample rate for osc pulse.
ow_osc_pulse_set_sample_rate :: proc(coeffs: ^ow_osc_pulse_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_one_pole_set_sample_rate(&coeffs.smooth_coeffs, sample_rate)
	ow_one_pole_reset_coeffs(&coeffs.smooth_coeffs)
}

// Summary: Resets coefficients for osc pulse.
ow_osc_pulse_reset_coeffs :: proc(coeffs: ^ow_osc_pulse_coeffs) {
	OW_ASSERT(coeffs != nil)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_state, coeffs.pulse_width)
}

// Summary: Updates control-rate coefficients for osc pulse.
ow_osc_pulse_update_coeffs_ctrl :: proc(coeffs: ^ow_osc_pulse_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Updates audio-rate coefficients for osc pulse.
ow_osc_pulse_update_coeffs_audio :: proc(coeffs: ^ow_osc_pulse_coeffs) {
	OW_ASSERT(coeffs != nil)
	_ = ow_one_pole_process1(&coeffs.smooth_coeffs, &coeffs.smooth_state, coeffs.pulse_width)
}

// Summary: Processes one sample for osc pulse.
ow_osc_pulse_process1 :: proc(coeffs: ^ow_osc_pulse_coeffs, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(x))
	OW_ASSERT(x >= 0.0 && x < 1.0)
	pw := ow_one_pole_get_y_z1(&coeffs.smooth_state)
	if pw >= x {
		return 1.0
	}
	return -1.0
}

// Summary: Executes osc pulse blep diff.
ow_osc_pulse_blep_diff :: proc(x: f32) -> f32 {
	if x < 1.0 {
		return x*((0.25*x-0.6666666666666666)*x*x+1.333333333333333) - 1.0
	}
	return x*(x*((0.6666666666666666-0.08333333333333333*x)*x-2.0)+2.666666666666667) - 1.333333333333333
}

// Summary: Executes osc pulse process1 antialias.
ow_osc_pulse_process1_antialias :: proc(coeffs: ^ow_osc_pulse_coeffs, x: f32, x_inc: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(x) && x >= 0.0 && x < 1.0)
	OW_ASSERT(ow_is_finite(x_inc) && x_inc >= -0.5 && x_inc <= 0.5)

	pw := ow_one_pole_get_y_z1(&coeffs.smooth_state)
	pw_m_phase := pw - x
	v := ow_copysignf(1.0, pw_m_phase)
	a_inc := ow_absf(x_inc)
	if a_inc > 1.0e-6 {
		phase_inc_2 := a_inc + a_inc
		phase_inc_rcp := ow_rcpf(a_inc)
		phase_2 := 0.5*v + 0.5 - pw_m_phase
		s_1_m_phase := 1.0 - x
		s_1_m_phase_2 := 1.0 - phase_2
		if s_1_m_phase < phase_inc_2 {
			v -= ow_osc_pulse_blep_diff(s_1_m_phase * phase_inc_rcp)
		}
		if s_1_m_phase_2 < phase_inc_2 {
			v += ow_osc_pulse_blep_diff(s_1_m_phase_2 * phase_inc_rcp)
		}
		if x < phase_inc_2 {
			v += ow_osc_pulse_blep_diff(x * phase_inc_rcp)
		}
		if phase_2 < phase_inc_2 {
			v -= ow_osc_pulse_blep_diff(phase_2 * phase_inc_rcp)
		}
	}
	return v
}

// Summary: Processes sample buffers for osc pulse.
ow_osc_pulse_process :: proc(coeffs: ^ow_osc_pulse_coeffs, x: ^f32, x_inc: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	if coeffs.antialiasing != 0 {
		OW_ASSERT(x_inc != nil)
	}
	xm := ([^]f32)(x)
	xinc: [^]f32
	if x_inc != nil {
		xinc = ([^]f32)(x_inc)
	}
	ym := ([^]f32)(y)

	if coeffs.antialiasing != 0 {
		for i := 0; i < n_samples; i += 1 {
			ow_osc_pulse_update_coeffs_audio(coeffs)
			ym[i] = ow_osc_pulse_process1_antialias(coeffs, xm[i], xinc[i])
		}
	} else {
		for i := 0; i < n_samples; i += 1 {
			ow_osc_pulse_update_coeffs_audio(coeffs)
			ym[i] = ow_osc_pulse_process1(coeffs, xm[i])
		}
	}
}

// Summary: Processes multiple channels for osc pulse.
ow_osc_pulse_process_multi :: proc(coeffs: ^ow_osc_pulse_coeffs, x: ^^f32, x_inc: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	if coeffs.antialiasing != 0 {
		OW_ASSERT(x_inc != nil)
	}
	xm := ([^][^]f32)(x)
	xincm: [^][^]f32
	if x_inc != nil {
		xincm = ([^][^]f32)(x_inc)
	}
	ym := ([^][^]f32)(y)

	if coeffs.antialiasing != 0 {
		for i := 0; i < n_samples; i += 1 {
			ow_osc_pulse_update_coeffs_audio(coeffs)
			for ch := 0; ch < n_channels; ch += 1 {
				ym[ch][i] = ow_osc_pulse_process1_antialias(coeffs, xm[ch][i], xincm[ch][i])
			}
		}
	} else {
		for i := 0; i < n_samples; i += 1 {
			ow_osc_pulse_update_coeffs_audio(coeffs)
			for ch := 0; ch < n_channels; ch += 1 {
				ym[ch][i] = ow_osc_pulse_process1(coeffs, xm[ch][i])
			}
		}
	}
}

// Summary: Sets antialiasing for osc pulse.
ow_osc_pulse_set_antialiasing :: proc(coeffs: ^ow_osc_pulse_coeffs, value: i8) {
	OW_ASSERT(coeffs != nil)
	coeffs.antialiasing = value
}

// Summary: Sets pulse width for osc pulse.
ow_osc_pulse_set_pulse_width :: proc(coeffs: ^ow_osc_pulse_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	OW_ASSERT(value >= 0.0 && value <= 1.0)
	coeffs.pulse_width = value
}

// Summary: Checks validity of osc pulse coeffs.
ow_osc_pulse_coeffs_is_valid :: proc(coeffs: ^ow_osc_pulse_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.pulse_width) || coeffs.pulse_width < 0.0 || coeffs.pulse_width > 1.0 {
		return 0
	}
	if !ow_one_pole_coeffs_is_valid(&coeffs.smooth_coeffs) {
		return 0
	}
	return 1
}
