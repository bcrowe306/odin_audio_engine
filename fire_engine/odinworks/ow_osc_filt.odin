package odinworks

// Summary: Runtime state for osc filt.
ow_osc_filt_state :: struct {
	z1: f32,
}

// Summary: Resets state for osc filt.
ow_osc_filt_reset_state :: proc(state: ^ow_osc_filt_state, x_0: f32) -> f32 {
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	state.z1 = 0.0
	return x_0
}

// Summary: Resets multi-channel state for osc filt.
ow_osc_filt_reset_state_multi :: proc(state: ^^ow_osc_filt_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_osc_filt_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_osc_filt_reset_state(states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Processes one sample for osc filt.
ow_osc_filt_process1 :: proc(state: ^ow_osc_filt_state, x: f32) -> f32 {
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x))
	y := 1.371308261611209*x + state.z1
	state.z1 = 0.08785458027104826*x - 4.591628418822578e-1*y
	return y
}

// Summary: Processes sample buffers for osc filt.
ow_osc_filt_process :: proc(state: ^ow_osc_filt_state, x: ^f32, y: ^f32, n_samples: int) {
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	for i := 0; i < n_samples; i += 1 {
		ym[i] = ow_osc_filt_process1(state, xm[i])
	}
}

// Summary: Processes multiple channels for osc filt.
ow_osc_filt_process_multi :: proc(state: ^^ow_osc_filt_state, x: ^^f32, y: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_osc_filt_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	for ch := 0; ch < n_channels; ch += 1 {
		ow_osc_filt_process(states[ch], xm[ch], ym[ch], n_samples)
	}
}

// Summary: Checks validity of osc filt state.
ow_osc_filt_state_is_valid :: proc(state: ^ow_osc_filt_state) -> i8 {
	if state == nil {
		return 0
	}
	if !ow_is_finite(state.z1) {
		return 0
	}
	return 1
}
