package odinworks

// Summary: Coefficient data for src.
ow_src_coeffs :: struct {
	k: f32,
	b0: f32,
	ma1: f32,
	ma2: f32,
	ma3: f32,
	ma4: f32,
}

// Summary: Runtime state for src.
ow_src_state :: struct {
	i: f32,
	z1: f32,
	z2: f32,
	z3: f32,
	z4: f32,
	xz1: f32,
	xz2: f32,
	xz3: f32,
}

// Summary: Initializes src.
ow_src_init :: proc(coeffs: ^ow_src_coeffs, ratio: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ratio > 0.0)
	if ratio >= 1.0 {
		coeffs.k = 1.0 / ratio
	} else {
		coeffs.k = -1.0 / ratio
	}
	fc := ow_minf((ratio >= 1.0) ? (1.0 / ratio) : ratio, 0.9)
	T := ow_tanf(1.570796326794896 * fc)
	T2 := T * T
	k := ow_rcpf(T*(T*(T*(T+2.613125929752753)+3.414213562373095)+2.613125929752753) + 1.0)
	coeffs.b0 = k * T2 * T2
	coeffs.ma1 = k * (T*(T2*(-5.226251859505504-4.0*T)+5.226251859505504) + 4.0)
	coeffs.ma2 = k * ((6.82842712474619-6.0*T2)*T2 - 6.0)
	coeffs.ma3 = k * (T*(T2*(5.226251859505504-4.0*T)-5.226251859505504) + 4.0)
	coeffs.ma4 = k * (T*(T*((2.613125929752753-T)*T-3.414213562373095)+2.613125929752753) - 1.0)
}

// Summary: Resets state for src.
ow_src_reset_state :: proc(coeffs: ^ow_src_coeffs, state: ^ow_src_state, x_0: f32) -> f32 {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_0))
	if coeffs.k < 0.0 {
		state.z1 = x_0 / (1.0 - coeffs.ma1 - coeffs.ma2 - coeffs.ma3 - coeffs.ma4)
		state.z2 = state.z1
		state.z3 = state.z2
		state.z4 = state.z3
	} else {
		k := 4.0 * coeffs.b0
		state.z4 = (coeffs.b0 + coeffs.ma4) * x_0
		state.z3 = (k + coeffs.ma3) * x_0 + state.z4
		state.z2 = (6.0*coeffs.b0 + coeffs.ma2) * x_0 + state.z3
		state.z1 = (k + coeffs.ma1) * x_0 + state.z2
	}
	state.i = 0.0
	state.xz1 = x_0
	state.xz2 = x_0
	state.xz3 = x_0
	return x_0
}

// Summary: Resets multi-channel state for src.
ow_src_reset_state_multi :: proc(coeffs: ^ow_src_coeffs, state: ^^ow_src_state, x_0: ^f32, y_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_0 != nil)
	states := ([^]^ow_src_state)(state)
	x0 := ([^]f32)(x_0)
	y0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	for ch := 0; ch < n_channels; ch += 1 {
		v := ow_src_reset_state(coeffs, states[ch], x0[ch])
		if y_0 != nil {
			y0[ch] = v
		}
	}
}

// Summary: Processes sample buffers for src.
ow_src_process :: proc(coeffs: ^ow_src_coeffs, state: ^ow_src_state, x: ^f32, y: ^f32, n_in_samples: ^int, n_out_samples: ^int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	OW_ASSERT(n_in_samples != nil)
	OW_ASSERT(n_out_samples != nil)
	OW_ASSERT(n_in_samples != n_out_samples)

	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	in_max := n_in_samples^
	out_max := n_out_samples^
	i := 0
	j := 0

	if coeffs.k < 0.0 {
		for i < in_max && j < out_max {
			z0 := xm[i] + coeffs.ma1*state.z1 + coeffs.ma2*state.z2 + coeffs.ma3*state.z3 + coeffs.ma4*state.z4
			o := coeffs.b0 * (z0 + state.z4 + 4.0*(state.z1+state.z3) + 6.0*state.z2)
			if state.i >= 0.0 {
				k1 := state.xz1 - state.xz2
				k2 := 0.333333333333333 * (state.xz3 - o)
				k3 := o - k1
				k4 := k3 - state.xz1
				a := k2 - k4 - 0.5*k4
				b := k3 - k1 - 0.5*(state.xz1+state.xz3)
				c := 0.5 * (k1 + k2)
				ym[j] = o + state.i*(a+state.i*(b+state.i*c))
				state.i += coeffs.k
				j += 1
			}
			state.z4 = state.z3
			state.z3 = state.z2
			state.z2 = state.z1
			state.z1 = z0
			state.xz3 = state.xz2
			state.xz2 = state.xz1
			state.xz1 = o
			state.i += 1.0
			i += 1
		}
	} else {
		for i < in_max && j < out_max {
			for state.i < 1.0 && j < out_max {
				k1 := state.xz2 - state.xz1
				k2 := 0.333333333333333 * (xm[i] - state.xz3)
				k3 := state.xz3 - k1
				k4 := state.xz2 - k3
				a := k2 + k4 + 0.5*k4
				b := k3 - k1 - 0.5*(xm[i]+state.xz2)
				c := 0.5 * (k1 + k2)
				o := state.xz3 + state.i*(a+state.i*(b+state.i*c))
				v0 := coeffs.b0 * o
				v1 := 4.0 * v0
				v2 := 6.0 * v0
				ym[j] = v0 + state.z1
				state.z1 = v1 + coeffs.ma1*ym[j] + state.z2
				state.z2 = v2 + coeffs.ma2*ym[j] + state.z3
				state.z3 = v1 + coeffs.ma3*ym[j] + state.z4
				state.z4 = v0 + coeffs.ma4*ym[j]
				state.i += coeffs.k
				j += 1
			}
			if state.i >= 1.0 {
				state.xz3 = state.xz2
				state.xz2 = state.xz1
				state.xz1 = xm[i]
				state.i -= 1.0
				i += 1
			}
		}
	}

	n_in_samples^ = i
	n_out_samples^ = j
}

// Summary: Processes multiple channels for src.
ow_src_process_multi :: proc(coeffs: ^ow_src_coeffs, state: ^^ow_src_state, x: ^^f32, y: ^^f32, n_channels: int, n_in_samples: ^int, n_out_samples: ^int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	OW_ASSERT(n_in_samples != nil)
	OW_ASSERT(n_out_samples != nil)
	OW_ASSERT(n_in_samples != n_out_samples)
	states := ([^]^ow_src_state)(state)
	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	nins := ([^]int)(n_in_samples)
	nouts := ([^]int)(n_out_samples)
	for ch := 0; ch < n_channels; ch += 1 {
		ow_src_process(coeffs, states[ch], xm[ch], ym[ch], &nins[ch], &nouts[ch])
	}
}

// Summary: Checks validity of src coeffs.
ow_src_coeffs_is_valid :: proc(coeffs: ^ow_src_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.k) || coeffs.k == 0.0 {
		return 0
	}
	if !ow_is_finite(coeffs.b0) || !ow_is_finite(coeffs.ma1) || !ow_is_finite(coeffs.ma2) || !ow_is_finite(coeffs.ma3) || !ow_is_finite(coeffs.ma4) {
		return 0
	}
	return 1
}

// Summary: Checks validity of src state.
ow_src_state_is_valid :: proc(coeffs: ^ow_src_coeffs, state: ^ow_src_state) -> i8 {
	if state == nil {
		return 0
	}
	_ = coeffs
	if !ow_is_finite(state.i) || !ow_is_finite(state.z1) || !ow_is_finite(state.z2) || !ow_is_finite(state.z3) || !ow_is_finite(state.z4) || !ow_is_finite(state.xz1) || !ow_is_finite(state.xz2) || !ow_is_finite(state.xz3) {
		return 0
	}
	return 1
}
