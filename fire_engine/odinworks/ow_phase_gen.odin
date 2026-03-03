package odinworks

// Summary: Coefficient data for phase gen.
ow_phase_gen_coeffs :: struct {
	portamento_coeffs: ow_one_pole_coeffs,
	portamento_state: ow_one_pole_state,

	T: f32,
	portamento_target: f32,

	frequency: f32,
	phase_inc_min: f32,
	phase_inc_max: f32,
	frequency_prev: f32,
	reset_id: u32,
}

// Summary: Runtime state for phase gen.
ow_phase_gen_state :: struct {
	phase: f32,
	coeffs_reset_id: u32,
}

PHASE_TINY_INC_SUPPRESS: f32 : 6.0e-8
PHASE_PRACTICAL_INFINITY: f32 : 1.0e30

// Summary: Initializes phase gen.
ow_phase_gen_init :: proc(coeffs: ^ow_phase_gen_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_init(&coeffs.portamento_coeffs)
	coeffs.frequency = 1.0
	coeffs.phase_inc_min = -PHASE_PRACTICAL_INFINITY
	coeffs.phase_inc_max = PHASE_PRACTICAL_INFINITY
	coeffs.frequency_prev = coeffs.frequency
	coeffs.reset_id = 1
}

// Summary: Sets sample rate for phase gen.
ow_phase_gen_set_sample_rate :: proc(coeffs: ^ow_phase_gen_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)

	ow_one_pole_set_sample_rate(&coeffs.portamento_coeffs, sample_rate)
	coeffs.T = 1.0 / sample_rate
}

// Summary: Updates control-rate coefficients for phase gen do.
ow_phase_gen_do_update_coeffs_ctrl :: proc(coeffs: ^ow_phase_gen_coeffs, force: bool) {
	ow_one_pole_update_coeffs_ctrl(&coeffs.portamento_coeffs)
	if force || coeffs.frequency != coeffs.frequency_prev {
		coeffs.portamento_target = coeffs.T * coeffs.frequency
		coeffs.frequency_prev = coeffs.frequency
	}
}

// Summary: Resets coefficients for phase gen.
ow_phase_gen_reset_coeffs :: proc(coeffs: ^ow_phase_gen_coeffs) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(coeffs.phase_inc_min < coeffs.phase_inc_max)

	ow_one_pole_reset_coeffs(&coeffs.portamento_coeffs)
	ow_phase_gen_do_update_coeffs_ctrl(coeffs, true)
	_ = ow_one_pole_reset_state(&coeffs.portamento_coeffs, &coeffs.portamento_state, coeffs.portamento_target)
	coeffs.reset_id += 1
}

// Summary: Resets state for phase gen.
ow_phase_gen_reset_state :: proc(coeffs: ^ow_phase_gen_coeffs, state: ^ow_phase_gen_state, phase_0: f32, y_0: ^f32, y_inc_0: ^f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(phase_0) && phase_0 >= 0.0 && phase_0 < 1.0)
	OW_ASSERT(y_0 != nil)
	OW_ASSERT(y_inc_0 != nil)
	OW_ASSERT(y_0 != y_inc_0)

	state.phase = phase_0
	y_inc_0^ = ow_clipf(ow_one_pole_get_y_z1(&coeffs.portamento_state), coeffs.phase_inc_min, coeffs.phase_inc_max)
	if ow_absf(y_inc_0^) < PHASE_TINY_INC_SUPPRESS {
		y_inc_0^ = 0.0
	}
	y_0^ = phase_0
	state.coeffs_reset_id = coeffs.reset_id
}

// Summary: Resets multi-channel state for phase gen.
ow_phase_gen_reset_state_multi :: proc(coeffs: ^ow_phase_gen_coeffs, state: [^]^ow_phase_gen_state, phase_0: [^]f32, y_0: [^]f32, y_inc_0: [^]f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(phase_0 != nil)

	for i := 0; i < n_channels; i += 1 {
		v: f32
		v_inc: f32
		y_ptr: ^f32 = &v
		y_inc_ptr: ^f32 = &v_inc
		if y_0 != nil {
			y_ptr = &y_0[i]
		}
		if y_inc_0 != nil {
			y_inc_ptr = &y_inc_0[i]
		}
		ow_phase_gen_reset_state(coeffs, state[i], phase_0[i], y_ptr, y_inc_ptr)
	}
}

// Summary: Updates control-rate coefficients for phase gen.
ow_phase_gen_update_coeffs_ctrl :: proc(coeffs: ^ow_phase_gen_coeffs) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(coeffs.phase_inc_min < coeffs.phase_inc_max)
	ow_phase_gen_do_update_coeffs_ctrl(coeffs, false)
}

// Summary: Updates audio-rate coefficients for phase gen.
ow_phase_gen_update_coeffs_audio :: proc(coeffs: ^ow_phase_gen_coeffs) {
	OW_ASSERT(coeffs != nil)
	_ = ow_one_pole_process1(&coeffs.portamento_coeffs, &coeffs.portamento_state, coeffs.portamento_target)
}

// Summary: Executes phase gen update phase.
ow_phase_gen_update_phase :: proc(state: ^ow_phase_gen_state, inc: ^f32) -> f32 {
	if ow_absf(inc^) < PHASE_TINY_INC_SUPPRESS {
		inc^ = 0.0
	}
	state.phase += inc^
	state.phase -= ow_floorf(state.phase)
	return state.phase
}

// Summary: Processes one sample for phase gen.
ow_phase_gen_process1 :: proc(coeffs: ^ow_phase_gen_coeffs, state: ^ow_phase_gen_state, y: ^f32, y_inc: ^f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(y != nil)
	OW_ASSERT(y_inc != nil)
	OW_ASSERT(y != y_inc)

	y_inc^ = ow_clipf(ow_one_pole_get_y_z1(&coeffs.portamento_state), coeffs.phase_inc_min, coeffs.phase_inc_max)
	y^ = ow_phase_gen_update_phase(state, y_inc)
}

// Summary: Executes phase gen process1 mod.
ow_phase_gen_process1_mod :: proc(coeffs: ^ow_phase_gen_coeffs, state: ^ow_phase_gen_state, x_mod: f32, y: ^f32, y_inc: ^f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(y != nil)
	OW_ASSERT(y_inc != nil)
	OW_ASSERT(y != y_inc)

	y_inc^ = ow_clipf(ow_one_pole_get_y_z1(&coeffs.portamento_state)*ow_pow2f(x_mod), coeffs.phase_inc_min, coeffs.phase_inc_max)
	y^ = ow_phase_gen_update_phase(state, y_inc)
}

// Summary: Processes sample buffers for phase gen.
ow_phase_gen_process :: proc(coeffs: ^ow_phase_gen_coeffs, state: ^ow_phase_gen_state, x_mod: [^]f32, y: [^]f32, y_inc: [^]f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)

	ow_phase_gen_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_phase_gen_update_coeffs_audio(coeffs)

		v: f32
		v_inc: f32
		y_ptr: ^f32 = &v
		y_inc_ptr: ^f32 = &v_inc
		if y != nil {
			y_ptr = &y[i]
		}
		if y_inc != nil {
			y_inc_ptr = &y_inc[i]
		}

		if x_mod != nil {
			ow_phase_gen_process1_mod(coeffs, state, x_mod[i], y_ptr, y_inc_ptr)
		} else {
			ow_phase_gen_process1(coeffs, state, y_ptr, y_inc_ptr)
		}
	}
}

// Summary: Processes multiple channels for phase gen.
ow_phase_gen_process_multi :: proc(coeffs: ^ow_phase_gen_coeffs, state: [^]^ow_phase_gen_state, x_mod: [^][^]f32, y: [^][^]f32, y_inc: [^][^]f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)

	ow_phase_gen_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_phase_gen_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			v: f32
			v_inc: f32
			y_ptr: ^f32 = &v
			y_inc_ptr: ^f32 = &v_inc

			if y != nil && y[ch] != nil {
				y_ptr = &y[ch][i]
			}
			if y_inc != nil && y_inc[ch] != nil {
				y_inc_ptr = &y_inc[ch][i]
			}

			if x_mod != nil && x_mod[ch] != nil {
				ow_phase_gen_process1_mod(coeffs, state[ch], x_mod[ch][i], y_ptr, y_inc_ptr)
			} else {
				ow_phase_gen_process1(coeffs, state[ch], y_ptr, y_inc_ptr)
			}
		}
	}
}

// Summary: Sets frequency for phase gen.
ow_phase_gen_set_frequency :: proc(coeffs: ^ow_phase_gen_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	coeffs.frequency = value
}

// Summary: Sets portamento tau for phase gen.
ow_phase_gen_set_portamento_tau :: proc(coeffs: ^ow_phase_gen_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0)
	ow_one_pole_set_tau(&coeffs.portamento_coeffs, value)
}

// Summary: Sets phase inc min for phase gen.
ow_phase_gen_set_phase_inc_min :: proc(coeffs: ^ow_phase_gen_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value))
	coeffs.phase_inc_min = value
}

// Summary: Sets phase inc max for phase gen.
ow_phase_gen_set_phase_inc_max :: proc(coeffs: ^ow_phase_gen_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value))
	coeffs.phase_inc_max = value
}

// Summary: Checks validity of phase gen coeffs.
ow_phase_gen_coeffs_is_valid :: proc(coeffs: ^ow_phase_gen_coeffs) -> bool {
	if coeffs == nil {
		return false
	}
	if !ow_is_finite(coeffs.frequency) {
		return false
	}
	if !ow_one_pole_coeffs_is_valid(&coeffs.portamento_coeffs) {
		return false
	}
	if ow_is_nan(coeffs.phase_inc_min) || ow_is_nan(coeffs.phase_inc_max) {
		return false
	}
	if coeffs.phase_inc_min >= coeffs.phase_inc_max {
		return false
	}
	return true
}

// Summary: Checks validity of phase gen state.
ow_phase_gen_state_is_valid :: proc(coeffs: ^ow_phase_gen_coeffs, state: ^ow_phase_gen_state) -> bool {
	if state == nil {
		return false
	}
	if coeffs != nil && state.coeffs_reset_id != coeffs.reset_id {
		return false
	}
	return ow_is_finite(state.phase) && state.phase >= 0.0 && state.phase < 1.0
}
