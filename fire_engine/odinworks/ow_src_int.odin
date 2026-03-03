package odinworks

// Summary: Coefficient data for src int.
ow_src_int_coeffs :: struct {
	ratio: int,
	b0: f32,
	ma1: f32,
	ma2: f32,
	ma3: f32,
	ma4: f32,
}

// Summary: Runtime state for src int.
ow_src_int_state :: struct {
	i: int,
	z1: f32,
	z2: f32,
	z3: f32,
	z4: f32,
}

// Summary: Initializes src int.
ow_src_int_init :: proc(coeffs: ^ow_src_int_coeffs, ratio: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ratio < -1 || ratio > 1)
	coeffs.ratio = ratio
	fc := f32(ratio)
	if fc < 0.0 {
		fc = -fc
	}
	T := ow_tanf(1.570796326794896 / fc)
	T2 := T * T
	k := ow_rcpf(T*(T*(T*(T+2.613125929752753)+3.414213562373095)+2.613125929752753) + 1.0)
	coeffs.b0 = k * T2 * T2
	coeffs.ma1 = k * (T*(T2*(-5.226251859505504-4.0*T)+5.226251859505504) + 4.0)
	coeffs.ma2 = k * ((6.82842712474619-6.0*T2)*T2 - 6.0)
	coeffs.ma3 = k * (T*(T2*(5.226251859505504-4.0*T)-5.226251859505504) + 4.0)
	coeffs.ma4 = k * (T*(T*((2.613125929752753-T)*T-3.414213562373095)+2.613125929752753) - 1.0)
}

// Summary: Resets state for src int.
ow_src_int_reset_state :: proc(coeffs: ^ow_src_int_coeffs, state: ^ow_src_int_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	if coeffs.ratio < 0 {
		state.z1 = x_0 / (1.0 - coeffs.ma1 - coeffs.ma2 - coeffs.ma3 - coeffs.ma4)
		state.z2 = state.z1
		state.z3 = state.z2
		state.z4 = state.z3
		state.i = 0
	} else {
		k := 4.0 * coeffs.b0
		state.z4 = (coeffs.b0 + coeffs.ma4) * x_0
		state.z3 = (k + coeffs.ma3) * x_0 + state.z4
		state.z2 = (6.0*coeffs.b0 + coeffs.ma2) * x_0 + state.z3
		state.z1 = (k + coeffs.ma1) * x_0 + state.z2
		state.i = 0
	}
	return x_0
}

// Summary: Resets multi-channel state for src int.
ow_src_int_reset_state_multi :: proc(coeffs: ^ow_src_int_coeffs, state: ^^ow_src_int_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_src_int_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for i := 0; i < n_channels; i += 1 {
		v := ow_src_int_reset_state(coeffs, states[i], x0[i])
		if y_0 != nil {
			y0[i] = v
		}
	}
}

// Summary: Processes sample buffers for src int.
ow_src_int_process :: proc(coeffs: ^ow_src_int_coeffs, state: ^ow_src_int_state, x: ^f32, y: ^f32, n_in_samples: int) -> int {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	n := 0
	if coeffs.ratio < 0 {
		for i := 0; i < n_in_samples; i += 1 {
			z0 := xm[i] + coeffs.ma1*state.z1 + coeffs.ma2*state.z2 + coeffs.ma3*state.z3 + coeffs.ma4*state.z4
			if state.i == 0 {
				state.i = -coeffs.ratio
				ym[n] = coeffs.b0 * (z0 + state.z4 + 4.0*(state.z1+state.z3) + 6.0*state.z2)
				n += 1
			}
			state.i -= 1
			state.z4 = state.z3
			state.z3 = state.z2
			state.z2 = state.z1
			state.z1 = z0
		}
	} else {
		for i := 0; i < n_in_samples; i += 1 {
			input_sample := f32(coeffs.ratio) * xm[i]
			v0 := coeffs.b0 * input_sample
			v1 := 4.0 * v0
			v2 := 6.0 * v0
			o := v0 + state.z1
			state.z1 = v1 + coeffs.ma1*o + state.z2
			state.z2 = v2 + coeffs.ma2*o + state.z3
			state.z3 = v1 + coeffs.ma3*o + state.z4
			state.z4 = v0 + coeffs.ma4*o
			ym[n] = o
			n += 1
			for j := 1; j < coeffs.ratio; j += 1 {
				o = state.z1
				state.z1 = coeffs.ma1*o + state.z2
				state.z2 = coeffs.ma2*o + state.z3
				state.z3 = coeffs.ma3*o + state.z4
				state.z4 = coeffs.ma4*o
				ym[n] = o
				n += 1
			}
		}
	}
	return n
}

// Summary: Processes multiple channels for src int.
ow_src_int_process_multi :: proc(coeffs: ^ow_src_int_coeffs, state: ^^ow_src_int_state, x: ^^f32, y: ^^f32, n_channels: int, n_in_samples: int, n_out_samples: ^int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	states := ([^]^ow_src_int_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	nouts: [^]int
	if n_out_samples != nil {
		nouts = ([^]int)(n_out_samples)
	}
	for ch := 0; ch < n_channels; ch += 1 {
		n := ow_src_int_process(coeffs, states[ch], xm[ch], ym[ch], n_in_samples)
		if n_out_samples != nil {
			nouts[ch] = n
		}
	}
}

// Summary: Checks validity of src int coeffs.
ow_src_int_coeffs_is_valid :: proc(coeffs: ^ow_src_int_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !(coeffs.ratio < -1 || coeffs.ratio > 1) {
		return 0
	}
	if !ow_is_finite(coeffs.b0) || !ow_is_finite(coeffs.ma1) || !ow_is_finite(coeffs.ma2) || !ow_is_finite(coeffs.ma3) || !ow_is_finite(coeffs.ma4) {
		return 0
	}
	return 1
}

// Summary: Checks validity of src int state.
ow_src_int_state_is_valid :: proc(coeffs: ^ow_src_int_coeffs, state: ^ow_src_int_state) -> i8 {
	if state == nil {
		return 0
	}
	if coeffs != nil && coeffs.ratio < 0 {
		if state.i < 0 || state.i >= -coeffs.ratio {
			return 0
		}
	}
	if !ow_is_finite(state.z1) || !ow_is_finite(state.z2) || !ow_is_finite(state.z3) || !ow_is_finite(state.z4) {
		return 0
	}
	return 1
}
