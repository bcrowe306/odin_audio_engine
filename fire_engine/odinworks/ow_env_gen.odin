package odinworks

// Summary: Enumeration for env gen phase.
ow_env_gen_phase :: enum {
	ow_env_gen_phase_off,
	ow_env_gen_phase_attack,
	ow_env_gen_phase_decay,
	ow_env_gen_phase_sustain,
	ow_env_gen_phase_release,
}

// Summary: Coefficient data for env gen.
ow_env_gen_coeffs :: struct {
	smooth_coeffs: ow_one_pole_coeffs,
	T: f32,

	attack_inc: u32,
	decay_dec: u32,
	sustain_v: u32,
	release_dec: u32,

	attack: f32,
	decay: f32,
	sustain: f32,
	release: f32,
	skip_sustain: bool,
	always_reach_sustain: bool,
	param_changed: u32,
	reset_id: u32,
}

// Summary: Runtime state for env gen.
ow_env_gen_state :: struct {
	phase: ow_env_gen_phase,
	v: u32,
	smooth_state: ow_one_pole_state,
	gate: bool,
	coeffs_reset_id: u32,
}

OW_ENV_GEN_PARAM_ATTACK: u32 : 1
OW_ENV_GEN_PARAM_DECAY: u32 : 1 << 1
OW_ENV_GEN_PARAM_SUSTAIN: u32 : 1 << 2
OW_ENV_GEN_PARAM_RELEASE: u32 : 1 << 3
OW_ENV_GEN_V_MAX: u32 : 4294967040
OW_ENV_GEN_V_INV: f32 : 1.0 / f32(OW_ENV_GEN_V_MAX)

// Summary: Initializes env gen.
ow_env_gen_init :: proc(coeffs: ^ow_env_gen_coeffs) {
	OW_ASSERT(coeffs != nil)

	ow_one_pole_init(&coeffs.smooth_coeffs)
	ow_one_pole_set_tau(&coeffs.smooth_coeffs, 0.05)
	coeffs.attack = 0.0
	coeffs.decay = 0.0
	coeffs.sustain = 1.0
	coeffs.release = 0.0
	coeffs.skip_sustain = false
	coeffs.always_reach_sustain = false
	coeffs.param_changed = 0xFFFF_FFFF
	coeffs.reset_id = 1
}

// Summary: Sets sample rate for env gen.
ow_env_gen_set_sample_rate :: proc(coeffs: ^ow_env_gen_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)

	ow_one_pole_set_sample_rate(&coeffs.smooth_coeffs, sample_rate)
	ow_one_pole_reset_coeffs(&coeffs.smooth_coeffs)
	coeffs.T = 1.0 / sample_rate
}

// Summary: Updates control-rate coefficients for env gen do.
ow_env_gen_do_update_coeffs_ctrl :: proc(coeffs: ^ow_env_gen_coeffs) {
	if coeffs.param_changed == 0 {
		return
	}

	if (coeffs.param_changed & OW_ENV_GEN_PARAM_ATTACK) != 0 {
		if coeffs.attack > coeffs.T {
			coeffs.attack_inc = u32(f32(OW_ENV_GEN_V_MAX) * (coeffs.T * ow_rcpf(coeffs.attack)))
		} else {
			coeffs.attack_inc = OW_ENV_GEN_V_MAX
		}
	}

	if (coeffs.param_changed & (OW_ENV_GEN_PARAM_DECAY | OW_ENV_GEN_PARAM_SUSTAIN)) != 0 {
		if coeffs.decay > coeffs.T {
			coeffs.decay_dec = u32((1.0 - coeffs.sustain) * (f32(OW_ENV_GEN_V_MAX) * (coeffs.T * ow_rcpf(coeffs.decay))))
		} else {
			coeffs.decay_dec = OW_ENV_GEN_V_MAX
		}
	}

	if (coeffs.param_changed & OW_ENV_GEN_PARAM_SUSTAIN) != 0 {
		coeffs.sustain_v = u32(f32(OW_ENV_GEN_V_MAX) * coeffs.sustain)
	}

	if (coeffs.param_changed & (OW_ENV_GEN_PARAM_SUSTAIN | OW_ENV_GEN_PARAM_RELEASE)) != 0 {
		if coeffs.release > coeffs.T {
			coeffs.release_dec = u32(coeffs.sustain * (f32(OW_ENV_GEN_V_MAX) * (coeffs.T * ow_rcpf(coeffs.release))))
		} else {
			coeffs.release_dec = OW_ENV_GEN_V_MAX
		}
	}

	coeffs.param_changed = 0
}

// Summary: Resets coefficients for env gen.
ow_env_gen_reset_coeffs :: proc(coeffs: ^ow_env_gen_coeffs) {
	OW_ASSERT(coeffs != nil)
	coeffs.param_changed = 0xFFFF_FFFF
	ow_env_gen_do_update_coeffs_ctrl(coeffs)
	coeffs.reset_id += 1
}

// Summary: Resets state for env gen.
ow_env_gen_reset_state :: proc(coeffs: ^ow_env_gen_coeffs, state: ^ow_env_gen_state, gate_0: bool) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)

	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &state.smooth_state, coeffs.sustain)
	if gate_0 && !coeffs.skip_sustain {
		state.phase = .ow_env_gen_phase_sustain
		state.v = coeffs.sustain_v
	} else {
		state.phase = .ow_env_gen_phase_off
		state.v = 0
	}
	state.gate = gate_0
	state.coeffs_reset_id = coeffs.reset_id
	return OW_ENV_GEN_V_INV * f32(state.v)
}

// Summary: Resets multi-channel state for env gen.
ow_env_gen_reset_state_multi :: proc(coeffs: ^ow_env_gen_coeffs, state: [^]^ow_env_gen_state, gate_0: [^]bool, y_0: [^]f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(gate_0 != nil)

	for i := 0; i < n_channels; i += 1 {
		if y_0 != nil {
			y_0[i] = ow_env_gen_reset_state(coeffs, state[i], gate_0[i])
		} else {
			_ = ow_env_gen_reset_state(coeffs, state[i], gate_0[i])
		}
	}
}

// Summary: Updates control-rate coefficients for env gen.
ow_env_gen_update_coeffs_ctrl :: proc(coeffs: ^ow_env_gen_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_env_gen_do_update_coeffs_ctrl(coeffs)
}

// Summary: Updates audio-rate coefficients for env gen.
ow_env_gen_update_coeffs_audio :: proc(coeffs: ^ow_env_gen_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Executes env gen process ctrl.
ow_env_gen_process_ctrl :: proc(coeffs: ^ow_env_gen_coeffs, state: ^ow_env_gen_state, gate: bool) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)

	if gate && !state.gate {
		if state.phase == .ow_env_gen_phase_off || state.phase == .ow_env_gen_phase_release {
			state.phase = .ow_env_gen_phase_attack
		}
	} else if !gate {
		if state.phase == .ow_env_gen_phase_sustain || (state.phase != .ow_env_gen_phase_off && !coeffs.always_reach_sustain) {
			state.phase = .ow_env_gen_phase_release
		}
	}
	state.gate = gate
}

// Summary: Processes one sample for env gen.
ow_env_gen_process1 :: proc(coeffs: ^ow_env_gen_coeffs, state: ^ow_env_gen_state) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)

	v: u32 = 0
	switch state.phase {
	case .ow_env_gen_phase_attack:
		v = state.v + coeffs.attack_inc
		if v >= OW_ENV_GEN_V_MAX || v <= state.v {
			v = OW_ENV_GEN_V_MAX
			state.phase = .ow_env_gen_phase_decay
		}
	case .ow_env_gen_phase_decay:
		v = state.v - coeffs.decay_dec
		if v <= coeffs.sustain_v || v >= state.v {
			v = coeffs.sustain_v
			state.phase = .ow_env_gen_phase_sustain
			_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &state.smooth_state, coeffs.sustain)
		}
	case .ow_env_gen_phase_sustain:
		v = u32(f32(OW_ENV_GEN_V_MAX) * ow_clipf(ow_one_pole_process1(&coeffs.smooth_coeffs, &state.smooth_state, coeffs.sustain), 0.0, 1.0))
		if coeffs.skip_sustain {
			state.phase = .ow_env_gen_phase_release
		}
	case .ow_env_gen_phase_release:
		v = state.v - coeffs.release_dec
		if v == 0 || v >= state.v {
			v = 0
			state.phase = .ow_env_gen_phase_off
		}
	case .ow_env_gen_phase_off:
		v = 0
	}

	state.v = v
	y := OW_ENV_GEN_V_INV * f32(v)
	return y
}

// Summary: Processes sample buffers for env gen.
ow_env_gen_process :: proc(coeffs: ^ow_env_gen_coeffs, state: ^ow_env_gen_state, gate: bool, y: [^]f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)

	ow_env_gen_update_coeffs_ctrl(coeffs)
	ow_env_gen_process_ctrl(coeffs, state, gate)
	for i := 0; i < n_samples; i += 1 {
		v := ow_env_gen_process1(coeffs, state)
		if y != nil {
			y[i] = v
		}
	}
}

// Summary: Processes multiple channels for env gen.
ow_env_gen_process_multi :: proc(coeffs: ^ow_env_gen_coeffs, state: [^]^ow_env_gen_state, gate: [^]bool, y: [^][^]f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(gate != nil)

	ow_env_gen_update_coeffs_ctrl(coeffs)
	for ch := 0; ch < n_channels; ch += 1 {
		ow_env_gen_process_ctrl(coeffs, state[ch], gate[ch])
	}

	for i := 0; i < n_samples; i += 1 {
		for ch := 0; ch < n_channels; ch += 1 {
			v := ow_env_gen_process1(coeffs, state[ch])
			if y != nil && y[ch] != nil {
				y[ch][i] = v
			}
		}
	}
}

// Summary: Sets attack for env gen.
ow_env_gen_set_attack :: proc(coeffs: ^ow_env_gen_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0 && value <= 60.0)
	if coeffs.attack != value {
		coeffs.attack = value
		coeffs.param_changed |= OW_ENV_GEN_PARAM_ATTACK
	}
}

// Summary: Sets decay for env gen.
ow_env_gen_set_decay :: proc(coeffs: ^ow_env_gen_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0 && value <= 60.0)
	if coeffs.decay != value {
		coeffs.decay = value
		coeffs.param_changed |= OW_ENV_GEN_PARAM_DECAY
	}
}

// Summary: Sets sustain for env gen.
ow_env_gen_set_sustain :: proc(coeffs: ^ow_env_gen_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0 && value <= 1.0)
	if coeffs.sustain != value {
		coeffs.sustain = value
		coeffs.param_changed |= OW_ENV_GEN_PARAM_SUSTAIN
	}
}

// Summary: Sets release for env gen.
ow_env_gen_set_release :: proc(coeffs: ^ow_env_gen_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0 && value <= 60.0)
	if coeffs.release != value {
		coeffs.release = value
		coeffs.param_changed |= OW_ENV_GEN_PARAM_RELEASE
	}
}

// Summary: Sets skip sustain for env gen.
ow_env_gen_set_skip_sustain :: proc(coeffs: ^ow_env_gen_coeffs, value: bool) {
	OW_ASSERT(coeffs != nil)
	coeffs.skip_sustain = value
}

// Summary: Sets always reach sustain for env gen.
ow_env_gen_set_always_reach_sustain :: proc(coeffs: ^ow_env_gen_coeffs, value: bool) {
	OW_ASSERT(coeffs != nil)
	coeffs.always_reach_sustain = value
}

// Summary: Gets phase from env gen.
ow_env_gen_get_phase :: proc(state: ^ow_env_gen_state) -> ow_env_gen_phase {
	OW_ASSERT(state != nil)
	return state.phase
}

// Summary: Gets y z1 from env gen.
ow_env_gen_get_y_z1 :: proc(state: ^ow_env_gen_state) -> f32 {
	OW_ASSERT(state != nil)
	return OW_ENV_GEN_V_INV * f32(state.v)
}

// Summary: Checks validity of env gen coeffs.
ow_env_gen_coeffs_is_valid :: proc(coeffs: ^ow_env_gen_coeffs) -> bool {
	if coeffs == nil {
		return false
	}
	if !ow_is_finite(coeffs.attack) || coeffs.attack < 0.0 || coeffs.attack > 60.0 {
		return false
	}
	if !ow_is_finite(coeffs.decay) || coeffs.decay < 0.0 || coeffs.decay > 60.0 {
		return false
	}
	if !ow_is_finite(coeffs.sustain) || coeffs.sustain < 0.0 || coeffs.sustain > 1.0 {
		return false
	}
	if !ow_is_finite(coeffs.release) || coeffs.release < 0.0 || coeffs.release > 60.0 {
		return false
	}
	return ow_one_pole_coeffs_is_valid(&coeffs.smooth_coeffs)
}

// Summary: Checks validity of env gen state.
ow_env_gen_state_is_valid :: proc(coeffs: ^ow_env_gen_coeffs, state: ^ow_env_gen_state) -> bool {
	if state == nil {
		return false
	}
	if coeffs != nil && state.coeffs_reset_id != coeffs.reset_id {
		return false
	}
	if state.phase < .ow_env_gen_phase_off || state.phase > .ow_env_gen_phase_release {
		return false
	}
	if coeffs != nil {
		return ow_one_pole_state_is_valid(&coeffs.smooth_coeffs, &state.smooth_state)
	}
	return ow_one_pole_state_is_valid(nil, &state.smooth_state)
}
