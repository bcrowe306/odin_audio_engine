package odinworks

import "core:math"

// Summary: Coefficient data for ppm.
ow_ppm_coeffs :: struct {
	env_follow_coeffs: ow_env_follow_coeffs,
}

// Summary: Runtime state for ppm.
ow_ppm_state :: struct {
	env_follow_state: ow_env_follow_state,
	y_z1: f32,
}

// Summary: Executes ppm lin2dBf.
ow_ppm_lin2dBf :: proc(value: f32) -> f32 {
	return 20.0 * math.log10(value)
}

// Summary: Initializes ppm.
ow_ppm_init :: proc(coeffs: ^ow_ppm_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_env_follow_init(&coeffs.env_follow_coeffs)
	ow_env_follow_set_release_tau(&coeffs.env_follow_coeffs, 0.738300619235528)
}

// Summary: Sets sample rate for ppm.
ow_ppm_set_sample_rate :: proc(coeffs: ^ow_ppm_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_env_follow_set_sample_rate(&coeffs.env_follow_coeffs, sample_rate)
}

// Summary: Resets coefficients for ppm.
ow_ppm_reset_coeffs :: proc(coeffs: ^ow_ppm_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_env_follow_reset_coeffs(&coeffs.env_follow_coeffs)
}

// Summary: Resets state for ppm.
ow_ppm_reset_state :: proc(coeffs: ^ow_ppm_coeffs, state: ^ow_ppm_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	yl := ow_env_follow_reset_state(&coeffs.env_follow_coeffs, &state.env_follow_state, x_0)
	y := f32(-600.0)
	if yl >= 1.0e-30 {
		y = ow_ppm_lin2dBf(yl)
	}
	state.y_z1 = y
	return y
}

// Summary: Resets multi-channel state for ppm.
ow_ppm_reset_state_multi :: proc(coeffs: ^ow_ppm_coeffs, state: ^^ow_ppm_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_ppm_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_ppm_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Updates control-rate coefficients for ppm.
ow_ppm_update_coeffs_ctrl :: proc(coeffs: ^ow_ppm_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_env_follow_update_coeffs_ctrl(&coeffs.env_follow_coeffs)
}

// Summary: Updates audio-rate coefficients for ppm.
ow_ppm_update_coeffs_audio :: proc(coeffs: ^ow_ppm_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_env_follow_update_coeffs_audio(&coeffs.env_follow_coeffs)
}

// Summary: Processes one sample for ppm.
ow_ppm_process1 :: proc(coeffs: ^ow_ppm_coeffs, state: ^ow_ppm_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	yl := ow_env_follow_process1(&coeffs.env_follow_coeffs, &state.env_follow_state, x)
	y := f32(-600.0)
	if yl >= 1.0e-30 {
		y = ow_ppm_lin2dBf(yl)
	}
	state.y_z1 = y
	return y
}

// Summary: Processes sample buffers for ppm.
ow_ppm_process :: proc(coeffs: ^ow_ppm_coeffs, state: ^ow_ppm_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	xm := ([^]f32)(x)
	ym: [^]f32
	if y != nil {
		ym = ([^]f32)(y)
	}
	ow_ppm_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_ppm_update_coeffs_audio(coeffs)
		v := ow_ppm_process1(coeffs, state, xm[i])
		if y != nil {
			ym[i] = v
		}
	}
}

// Summary: Processes multiple channels for ppm.
ow_ppm_process_multi :: proc(coeffs: ^ow_ppm_coeffs, state: ^^ow_ppm_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	states := ([^]^ow_ppm_state)(state)
	xm := ([^][^]f32)(x)
	ym: [^][^]f32
	if y != nil {
		ym = ([^][^]f32)(y)
	}
	ow_ppm_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_ppm_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			v := ow_ppm_process1(coeffs, states[ch], xm[ch][i])
			if y != nil && ym[ch] != nil {
				ym[ch][i] = v
			}
		}
	}
}

// Summary: Sets integration tau for ppm.
ow_ppm_set_integration_tau :: proc(coeffs: ^ow_ppm_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value) && value >= 0.0)
	ow_env_follow_set_attack_tau(&coeffs.env_follow_coeffs, value)
}

// Summary: Gets y z1 from ppm.
ow_ppm_get_y_z1 :: proc(state: ^ow_ppm_state) -> f32 {
	OW_ASSERT(state != nil)
	return state.y_z1
}

// Summary: Checks validity of ppm coeffs.
ow_ppm_coeffs_is_valid :: proc(coeffs: ^ow_ppm_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_env_follow_coeffs_is_valid(&coeffs.env_follow_coeffs) {
		return 0
	}
	return 1
}

// Summary: Checks validity of ppm state.
ow_ppm_state_is_valid :: proc(coeffs: ^ow_ppm_coeffs, state: ^ow_ppm_state) -> i8 {
	if state == nil {
		return 0
	}
	if !ow_is_finite(state.y_z1) || state.y_z1 < -600.0 {
		return 0
	}
	env_coeffs: ^ow_env_follow_coeffs
	if coeffs != nil {
		env_coeffs = &coeffs.env_follow_coeffs
	}
	if !ow_env_follow_state_is_valid(env_coeffs, &state.env_follow_state) {
		return 0
	}
	return 1
}
