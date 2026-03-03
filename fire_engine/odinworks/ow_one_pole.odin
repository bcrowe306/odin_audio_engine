package odinworks

// Summary: Enumeration for one pole sticky mode.
ow_one_pole_sticky_mode :: enum {
	abs,
	rel,
}

// Summary: Coefficient data for one pole.
ow_one_pole_coeffs :: struct {
	fs_2pi: f32,
	mA1u: f32,
	mA1d: f32,
	st2: f32,

	cutoff_up: f32,
	cutoff_down: f32,
	sticky_thresh: f32,
	sticky_mode: ow_one_pole_sticky_mode,
	param_changed: u32,
	reset_id: u32,
}

// Summary: Runtime state for one pole.
ow_one_pole_state :: struct {
	y_z1: f32,
	coeffs_reset_id: u32,
}

OW_ONE_POLE_PARAM_CUTOFF_UP: u32 : 1
OW_ONE_POLE_PARAM_CUTOFF_DOWN: u32 : 1 << 1
OW_ONE_POLE_PARAM_STICKY_THRESH: u32 : 1 << 2

ONE_OVER_2PI_F32: f32 : 0.15915494309189535
INSTANT_CUTOFF_LIMIT: f32 : 1.591549430918953e8
TAU_MIN_SECONDS: f32 : 1.0e-9
PRACTICAL_INFINITY: f32 : 1.0e30

// Summary: Initializes one pole.
ow_one_pole_init :: proc(coeffs: ^ow_one_pole_coeffs) {
	OW_ASSERT(coeffs != nil)

	coeffs.cutoff_up = PRACTICAL_INFINITY
	coeffs.cutoff_down = PRACTICAL_INFINITY
	coeffs.sticky_thresh = 0.0
	coeffs.sticky_mode = .abs
	coeffs.param_changed = 0xFFFF_FFFF
	coeffs.reset_id = 1
}

// Summary: Sets sample rate for one pole.
ow_one_pole_set_sample_rate :: proc(coeffs: ^ow_one_pole_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)

	coeffs.fs_2pi = ONE_OVER_2PI_F32 * sample_rate
}

// Summary: Updates control-rate coefficients for one pole do.
ow_one_pole_do_update_coeffs_ctrl :: proc(coeffs: ^ow_one_pole_coeffs) {
	if coeffs.param_changed == 0 {
		return
	}

	if (coeffs.param_changed & OW_ONE_POLE_PARAM_CUTOFF_UP) != 0 {
		if coeffs.cutoff_up > INSTANT_CUTOFF_LIMIT {
			coeffs.mA1u = 0.0
		} else {
			coeffs.mA1u = coeffs.fs_2pi * ow_rcpf(coeffs.fs_2pi + coeffs.cutoff_up)
		}
	}

	if (coeffs.param_changed & OW_ONE_POLE_PARAM_CUTOFF_DOWN) != 0 {
		if coeffs.cutoff_down > INSTANT_CUTOFF_LIMIT {
			coeffs.mA1d = 0.0
		} else {
			coeffs.mA1d = coeffs.fs_2pi * ow_rcpf(coeffs.fs_2pi + coeffs.cutoff_down)
		}
	}

	if (coeffs.param_changed & OW_ONE_POLE_PARAM_STICKY_THRESH) != 0 {
		coeffs.st2 = coeffs.sticky_thresh * coeffs.sticky_thresh
	}

	coeffs.param_changed = 0
}

// Summary: Resets coefficients for one pole.
ow_one_pole_reset_coeffs :: proc(coeffs: ^ow_one_pole_coeffs) {
	OW_ASSERT(coeffs != nil)
	coeffs.param_changed = 0xFFFF_FFFF
	ow_one_pole_do_update_coeffs_ctrl(coeffs)
	coeffs.reset_id += 1
}

// Summary: Resets state for one pole.
ow_one_pole_reset_state :: proc(coeffs: ^ow_one_pole_coeffs, state: ^ow_one_pole_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))

	state.y_z1 = x_0
	state.coeffs_reset_id = coeffs.reset_id
	return x_0
}

// Summary: Resets multi-channel state for one pole.
ow_one_pole_reset_state_multi :: proc(coeffs: ^ow_one_pole_coeffs, state: [^]^ow_one_pole_state, x_0: [^]f32, y_0: [^]f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)

	for i := 0; i < n_channels; i += 1 {
		OW_ASSERT(state[i] != nil)
		if y_0 != nil {
			y_0[i] = ow_one_pole_reset_state(coeffs, state[i], x_0[i])
		} else {
			_ = ow_one_pole_reset_state(coeffs, state[i], x_0[i])
		}
	}
}

// Summary: Updates control-rate coefficients for one pole.
ow_one_pole_update_coeffs_ctrl :: proc(coeffs: ^ow_one_pole_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_one_pole_do_update_coeffs_ctrl(coeffs)
}

// Summary: Updates audio-rate coefficients for one pole.
ow_one_pole_update_coeffs_audio :: proc(coeffs: ^ow_one_pole_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Processes one sample for one pole.
ow_one_pole_process1 :: proc(coeffs: ^ow_one_pole_coeffs, state: ^ow_one_pole_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))

	y := x + coeffs.mA1u*(state.y_z1-x)
	state.y_z1 = y
	return y
}

// Summary: Executes one pole process1 sticky abs.
ow_one_pole_process1_sticky_abs :: proc(coeffs: ^ow_one_pole_coeffs, state: ^ow_one_pole_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))

	y := x + coeffs.mA1u*(state.y_z1-x)
	d := y - x
	if d*d <= coeffs.st2 {
		y = x
	}
	state.y_z1 = y
	return y
}

// Summary: Executes one pole process1 sticky rel.
ow_one_pole_process1_sticky_rel :: proc(coeffs: ^ow_one_pole_coeffs, state: ^ow_one_pole_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))

	y := x + coeffs.mA1u*(state.y_z1-x)
	d := y - x
	if d*d <= coeffs.st2*x*x {
		y = x
	}
	state.y_z1 = y
	return y
}

// Summary: Executes one pole process1 asym.
ow_one_pole_process1_asym :: proc(coeffs: ^ow_one_pole_coeffs, state: ^ow_one_pole_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))

	mA1 := coeffs.mA1d
	if x >= state.y_z1 {
		mA1 = coeffs.mA1u
	}
	y := x + mA1*(state.y_z1-x)
	state.y_z1 = y
	return y
}

// Summary: Executes one pole process1 asym sticky abs.
ow_one_pole_process1_asym_sticky_abs :: proc(coeffs: ^ow_one_pole_coeffs, state: ^ow_one_pole_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))

	mA1 := coeffs.mA1d
	if x >= state.y_z1 {
		mA1 = coeffs.mA1u
	}
	y := x + mA1*(state.y_z1-x)
	d := y - x
	if d*d <= coeffs.st2 {
		y = x
	}
	state.y_z1 = y
	return y
}

// Summary: Executes one pole process1 asym sticky rel.
ow_one_pole_process1_asym_sticky_rel :: proc(coeffs: ^ow_one_pole_coeffs, state: ^ow_one_pole_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))

	mA1 := coeffs.mA1d
	if x >= state.y_z1 {
		mA1 = coeffs.mA1u
	}
	y := x + mA1*(state.y_z1-x)
	d := y - x
	if d*d <= coeffs.st2*x*x {
		y = x
	}
	state.y_z1 = y
	return y
}

// Summary: Processes sample buffers for one pole.
ow_one_pole_process :: proc(coeffs: ^ow_one_pole_coeffs, state: ^ow_one_pole_state, x: [^]f32, y: [^]f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)

	ow_one_pole_update_coeffs_ctrl(coeffs)

	for i := 0; i < n_samples; i += 1 {
		out: f32
		if coeffs.mA1u != coeffs.mA1d {
			if coeffs.st2 != 0.0 {
				if coeffs.sticky_mode == .abs {
					out = ow_one_pole_process1_asym_sticky_abs(coeffs, state, x[i])
				} else {
					out = ow_one_pole_process1_asym_sticky_rel(coeffs, state, x[i])
				}
			} else {
				out = ow_one_pole_process1_asym(coeffs, state, x[i])
			}
		} else {
			if coeffs.st2 != 0.0 {
				if coeffs.sticky_mode == .abs {
					out = ow_one_pole_process1_sticky_abs(coeffs, state, x[i])
				} else {
					out = ow_one_pole_process1_sticky_rel(coeffs, state, x[i])
				}
			} else {
				out = ow_one_pole_process1(coeffs, state, x[i])
			}
		}

		if y != nil {
			y[i] = out
		}
	}
}

// Summary: Processes multiple channels for one pole.
ow_one_pole_process_multi :: proc(coeffs: ^ow_one_pole_coeffs, state: [^]^ow_one_pole_state, x: [^][^]f32, y: [^][^]f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)

	ow_one_pole_update_coeffs_ctrl(coeffs)

	for ch := 0; ch < n_channels; ch += 1 {
		OW_ASSERT(state[ch] != nil)
		OW_ASSERT(x[ch] != nil)
		y_ch: [^]f32 = nil
		if y != nil {
			y_ch = y[ch]
		}
		ow_one_pole_process(coeffs, state[ch], x[ch], y_ch, n_samples)
	}
}

// Summary: Sets cutoff for one pole.
ow_one_pole_set_cutoff :: proc(coeffs: ^ow_one_pole_coeffs, value: f32) {
	ow_one_pole_set_cutoff_up(coeffs, value)
	ow_one_pole_set_cutoff_down(coeffs, value)
}

// Summary: Sets cutoff up for one pole.
ow_one_pole_set_cutoff_up :: proc(coeffs: ^ow_one_pole_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value))
	OW_ASSERT(value >= 0.0)

	if coeffs.cutoff_up != value {
		coeffs.cutoff_up = value
		coeffs.param_changed |= OW_ONE_POLE_PARAM_CUTOFF_UP
	}
}

// Summary: Sets cutoff down for one pole.
ow_one_pole_set_cutoff_down :: proc(coeffs: ^ow_one_pole_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value))
	OW_ASSERT(value >= 0.0)

	if coeffs.cutoff_down != value {
		coeffs.cutoff_down = value
		coeffs.param_changed |= OW_ONE_POLE_PARAM_CUTOFF_DOWN
	}
}

// Summary: Sets tau for one pole.
ow_one_pole_set_tau :: proc(coeffs: ^ow_one_pole_coeffs, value: f32) {
	ow_one_pole_set_tau_up(coeffs, value)
	ow_one_pole_set_tau_down(coeffs, value)
}

// Summary: Sets tau up for one pole.
ow_one_pole_set_tau_up :: proc(coeffs: ^ow_one_pole_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value))
	OW_ASSERT(value >= 0.0)

	if value < TAU_MIN_SECONDS {
		ow_one_pole_set_cutoff_up(coeffs, PRACTICAL_INFINITY)
	} else {
		ow_one_pole_set_cutoff_up(coeffs, ONE_OVER_2PI_F32*ow_rcpf(value))
	}
}

// Summary: Sets tau down for one pole.
ow_one_pole_set_tau_down :: proc(coeffs: ^ow_one_pole_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value))
	OW_ASSERT(value >= 0.0)

	if value < TAU_MIN_SECONDS {
		ow_one_pole_set_cutoff_down(coeffs, PRACTICAL_INFINITY)
	} else {
		ow_one_pole_set_cutoff_down(coeffs, ONE_OVER_2PI_F32*ow_rcpf(value))
	}
}

// Summary: Sets sticky thresh for one pole.
ow_one_pole_set_sticky_thresh :: proc(coeffs: ^ow_one_pole_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(!ow_is_nan(value))
	OW_ASSERT(value >= 0.0 && value <= 1.0e18)

	if coeffs.sticky_thresh != value {
		coeffs.sticky_thresh = value
		coeffs.param_changed |= OW_ONE_POLE_PARAM_STICKY_THRESH
	}
}

// Summary: Sets sticky mode for one pole.
ow_one_pole_set_sticky_mode :: proc(coeffs: ^ow_one_pole_coeffs, value: ow_one_pole_sticky_mode) {
	OW_ASSERT(coeffs != nil)
	coeffs.sticky_mode = value
}

// Summary: Gets sticky thresh from one pole.
ow_one_pole_get_sticky_thresh :: proc(coeffs: ^ow_one_pole_coeffs) -> f32 {
	OW_ASSERT(coeffs != nil)
	return coeffs.sticky_thresh
}

// Summary: Gets sticky mode from one pole.
ow_one_pole_get_sticky_mode :: proc(coeffs: ^ow_one_pole_coeffs) -> ow_one_pole_sticky_mode {
	OW_ASSERT(coeffs != nil)
	return coeffs.sticky_mode
}

// Summary: Gets y z1 from one pole.
ow_one_pole_get_y_z1 :: proc(state: ^ow_one_pole_state) -> f32 {
	OW_ASSERT(state != nil)
	return state.y_z1
}

// Summary: Checks validity of one pole coeffs.
ow_one_pole_coeffs_is_valid :: proc(coeffs: ^ow_one_pole_coeffs) -> bool {
	if coeffs == nil {
		return false
	}

	if ow_is_nan(coeffs.cutoff_up) || coeffs.cutoff_up < 0.0 {
		return false
	}
	if ow_is_nan(coeffs.cutoff_down) || coeffs.cutoff_down < 0.0 {
		return false
	}
	if !ow_is_finite(coeffs.sticky_thresh) || coeffs.sticky_thresh < 0.0 || coeffs.sticky_thresh > 1.0e18 {
		return false
	}
	if coeffs.sticky_mode != .abs && coeffs.sticky_mode != .rel {
		return false
	}

	return true
}

// Summary: Checks validity of one pole state.
ow_one_pole_state_is_valid :: proc(coeffs: ^ow_one_pole_coeffs, state: ^ow_one_pole_state) -> bool {
	if state == nil {
		return false
	}

	if coeffs != nil && state.coeffs_reset_id != coeffs.reset_id {
		return false
	}

	return ow_is_finite(state.y_z1)
}
