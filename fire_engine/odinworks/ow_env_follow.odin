package odinworks

// Summary: Coefficient data for env follow.
ow_env_follow_coeffs :: struct {
	one_pole_coeffs: ow_one_pole_coeffs,
	reset_id: u32,
}

// Summary: Runtime state for env follow.
ow_env_follow_state :: struct {
	one_pole_state: ow_one_pole_state,
	coeffs_reset_id: u32,
}

// Summary: Initializes env follow.
ow_env_follow_init :: proc(coeffs: ^ow_env_follow_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_init(&coeffs.one_pole_coeffs)
	coeffs.reset_id = 1
}

// Summary: Sets sample rate for env follow.
ow_env_follow_set_sample_rate :: proc(coeffs: ^ow_env_follow_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_one_pole_set_sample_rate(&coeffs.one_pole_coeffs, sample_rate)
}

// Summary: Resets coefficients for env follow.
ow_env_follow_reset_coeffs :: proc(coeffs: ^ow_env_follow_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_reset_coeffs(&coeffs.one_pole_coeffs)
	coeffs.reset_id += 1
}

// Summary: Resets state for env follow.
ow_env_follow_reset_state :: proc(coeffs: ^ow_env_follow_coeffs, state: ^ow_env_follow_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))

	x := ow_absf(x_0)
	y := ow_one_pole_reset_state(&coeffs.one_pole_coeffs, &state.one_pole_state, x)
	state.coeffs_reset_id = coeffs.reset_id
	return y
}

// Summary: Resets multi-channel state for env follow.
ow_env_follow_reset_state_multi :: proc(coeffs: ^ow_env_follow_coeffs, state: [^]^ow_env_follow_state, x_0: [^]f32, y_0: [^]f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)

	for i := 0; i < n_channels; i += 1 {
		if y_0 != nil {
			y_0[i] = ow_env_follow_reset_state(coeffs, state[i], x_0[i])
		} else {
			_ = ow_env_follow_reset_state(coeffs, state[i], x_0[i])
		}
	}
}

// Summary: Updates control-rate coefficients for env follow.
ow_env_follow_update_coeffs_ctrl :: proc(coeffs: ^ow_env_follow_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_update_coeffs_ctrl(&coeffs.one_pole_coeffs)
}

// Summary: Updates audio-rate coefficients for env follow.
ow_env_follow_update_coeffs_audio :: proc(coeffs: ^ow_env_follow_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_update_coeffs_audio(&coeffs.one_pole_coeffs)
}

// Summary: Processes one sample for env follow.
ow_env_follow_process1 :: proc(coeffs: ^ow_env_follow_coeffs, state: ^ow_env_follow_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))

	x_abs := ow_absf(x)
	return ow_one_pole_process1_asym(&coeffs.one_pole_coeffs, &state.one_pole_state, x_abs)
}

// Summary: Processes sample buffers for env follow.
ow_env_follow_process :: proc(coeffs: ^ow_env_follow_coeffs, state: ^ow_env_follow_state, x: [^]f32, y: [^]f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)

	ow_env_follow_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_env_follow_update_coeffs_audio(coeffs)
		v := ow_env_follow_process1(coeffs, state, x[i])
		if y != nil {
			y[i] = v
		}
	}
}

// Summary: Processes multiple channels for env follow.
ow_env_follow_process_multi :: proc(coeffs: ^ow_env_follow_coeffs, state: [^]^ow_env_follow_state, x: [^][^]f32, y: [^][^]f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)

	ow_env_follow_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_env_follow_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			v := ow_env_follow_process1(coeffs, state[ch], x[ch][i])
			if y != nil && y[ch] != nil {
				y[ch][i] = v
			}
		}
	}
}

// Summary: Sets attack tau for env follow.
ow_env_follow_set_attack_tau :: proc(coeffs: ^ow_env_follow_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value) && value >= 0.0)
	ow_one_pole_set_tau_up(&coeffs.one_pole_coeffs, value)
}

// Summary: Sets release tau for env follow.
ow_env_follow_set_release_tau :: proc(coeffs: ^ow_env_follow_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value) && value >= 0.0)
	ow_one_pole_set_tau_down(&coeffs.one_pole_coeffs, value)
}

// Summary: Gets y z1 from env follow.
ow_env_follow_get_y_z1 :: proc(state: ^ow_env_follow_state) -> f32 {
	OW_ASSERT(state != nil)
	return ow_one_pole_get_y_z1(&state.one_pole_state)
}

// Summary: Checks validity of env follow coeffs.
ow_env_follow_coeffs_is_valid :: proc(coeffs: ^ow_env_follow_coeffs) -> bool {
	if coeffs == nil {
		return false
	}
	return ow_one_pole_coeffs_is_valid(&coeffs.one_pole_coeffs)
}

// Summary: Checks validity of env follow state.
ow_env_follow_state_is_valid :: proc(coeffs: ^ow_env_follow_coeffs, state: ^ow_env_follow_state) -> bool {
	if state == nil {
		return false
	}
	if coeffs != nil && state.coeffs_reset_id != coeffs.reset_id {
		return false
	}
	if coeffs != nil {
		return ow_one_pole_state_is_valid(&coeffs.one_pole_coeffs, &state.one_pole_state)
	}
	return ow_one_pole_state_is_valid(nil, &state.one_pole_state)
}
