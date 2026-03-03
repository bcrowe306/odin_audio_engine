package odinworks

import "core:math"

// Summary: Coefficient data for delay.
ow_delay_coeffs :: struct {
	fs: f32,
	len: int,
	di: int,
	df: f32,
	max_delay: f32,
	delay: f32,
	delay_changed: bool,
}

// Summary: Runtime state for delay.
ow_delay_state :: struct {
	buf: [^]f32,
	idx: int,
}

// Summary: Initializes delay.
ow_delay_init :: proc(coeffs: ^ow_delay_coeffs, max_delay: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(max_delay) && max_delay >= 0.0)
	coeffs.max_delay = max_delay
	coeffs.delay = 0.0
	coeffs.delay_changed = true
}

// Summary: Sets sample rate for delay.
ow_delay_set_sample_rate :: proc(coeffs: ^ow_delay_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	coeffs.fs = sample_rate
	coeffs.len = int(math.ceil(coeffs.fs*coeffs.max_delay)) + 1
}

// Summary: Executes delay mem req.
ow_delay_mem_req :: proc(coeffs: ^ow_delay_coeffs) -> int {
	OW_ASSERT(coeffs != nil)
	return coeffs.len * size_of(f32)
}

// Summary: Executes delay mem set.
ow_delay_mem_set :: proc(coeffs: ^ow_delay_coeffs, state: ^ow_delay_state, mem: rawptr) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(mem != nil)
	_ = coeffs
	state.buf = ([^]f32)(mem)
}

// Summary: Updates control-rate coefficients for delay do.
ow_delay_do_update_coeffs_ctrl :: proc(coeffs: ^ow_delay_coeffs) {
	if coeffs.delay_changed {
		d := coeffs.fs * coeffs.delay
		di_f := ow_floorf(d)
		coeffs.di = int(di_f)
		coeffs.df = d - di_f
		coeffs.delay_changed = false
	}
}

// Summary: Resets coefficients for delay.
ow_delay_reset_coeffs :: proc(coeffs: ^ow_delay_coeffs) {
	OW_ASSERT(coeffs != nil)
	coeffs.delay_changed = true
	ow_delay_do_update_coeffs_ctrl(coeffs)
}

// Summary: Resets state for delay.
ow_delay_reset_state :: proc(coeffs: ^ow_delay_coeffs, state: ^ow_delay_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	ow_buf_fill(x_0, (^f32)(state.buf), coeffs.len)
	state.idx = 0
	return x_0
}

// Summary: Resets multi-channel state for delay.
ow_delay_reset_state_multi :: proc(coeffs: ^ow_delay_coeffs, state: ^^ow_delay_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_delay_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_delay_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Executes delay read.
ow_delay_read :: proc(coeffs: ^ow_delay_coeffs, state: ^ow_delay_state, di: int, df: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(df) && df >= 0.0 && df < 1.0)
	OW_ASSERT(f32(di)+df <= f32(coeffs.len))
	n := state.idx - di
	if state.idx < di {
		n += coeffs.len
	}
	p := coeffs.len - 1
	if n != 0 {
		p = n - 1
	}
	return state.buf[n] + df*(state.buf[p]-state.buf[n])
}

// Summary: Executes delay write.
ow_delay_write :: proc(coeffs: ^ow_delay_coeffs, state: ^ow_delay_state, x: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	state.idx += 1
	if state.idx == coeffs.len {
		state.idx = 0
	}
	state.buf[state.idx] = x
}

// Summary: Updates control-rate coefficients for delay.
ow_delay_update_coeffs_ctrl :: proc(coeffs: ^ow_delay_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_delay_do_update_coeffs_ctrl(coeffs)
}

// Summary: Updates audio-rate coefficients for delay.
ow_delay_update_coeffs_audio :: proc(coeffs: ^ow_delay_coeffs) {
	OW_ASSERT(coeffs != nil)
}

// Summary: Processes one sample for delay.
ow_delay_process1 :: proc(coeffs: ^ow_delay_coeffs, state: ^ow_delay_state, x: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	ow_delay_write(coeffs, state, x)
	return ow_delay_read(coeffs, state, coeffs.di, coeffs.df)
}

// Summary: Processes sample buffers for delay.
ow_delay_process :: proc(coeffs: ^ow_delay_coeffs, state: ^ow_delay_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	ow_delay_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ym[i] = ow_delay_process1(coeffs, state, xm[i])
	}
}

// Summary: Processes multiple channels for delay.
ow_delay_process_multi :: proc(coeffs: ^ow_delay_coeffs, state: ^^ow_delay_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_delay_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	ow_delay_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		for ch := 0; ch < n_channels; ch += 1 {
			ym[ch][i] = ow_delay_process1(coeffs, states[ch], xm[ch][i])
		}
	}
}

// Summary: Sets delay for delay.
ow_delay_set_delay :: proc(coeffs: ^ow_delay_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value))
	if value != coeffs.delay {
		coeffs.delay = value
		coeffs.delay_changed = true
	}
}

// Summary: Gets length from delay.
ow_delay_get_length :: proc(coeffs: ^ow_delay_coeffs) -> int {
	OW_ASSERT(coeffs != nil)
	return coeffs.len
}

// Summary: Checks validity of delay coeffs.
ow_delay_coeffs_is_valid :: proc(coeffs: ^ow_delay_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.max_delay) || coeffs.max_delay < 0.0 {
		return 0
	}
	if !ow_is_finite(coeffs.delay) || coeffs.delay < 0.0 || coeffs.delay > coeffs.max_delay {
		return 0
	}
	if coeffs.len < 0 {
		return 0
	}
	if !ow_is_finite(coeffs.df) || coeffs.df < 0.0 || coeffs.df >= 1.0 {
		return 0
	}
	if f32(coeffs.di)+coeffs.df > f32(coeffs.len) {
		return 0
	}
	return 1
}

// Summary: Checks validity of delay state.
ow_delay_state_is_valid :: proc(coeffs: ^ow_delay_coeffs, state: ^ow_delay_state) -> i8 {
	if state == nil {
		return 0
	}
	if state.buf == nil {
		return 0
	}
	if coeffs != nil && (state.idx < 0 || state.idx >= coeffs.len) {
		return 0
	}
	return 1
}
