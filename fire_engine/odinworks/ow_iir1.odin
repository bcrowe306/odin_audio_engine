package odinworks

// Summary: Executes iir1 assert valid coeffs.
ow_iir1_assert_valid_coeffs :: proc(b0: f32, b1: f32, a1: f32) {
	OW_ASSERT(ow_is_finite(b0))
	OW_ASSERT(ow_is_finite(b1))
	OW_ASSERT(ow_is_finite(a1))
	OW_ASSERT(a1 >= -1.0 && a1 <= 1.0)
}

// Summary: Executes iir1 assert valid params.
ow_iir1_assert_valid_params :: proc(sample_rate: f32, cutoff: f32, prewarp_freq: f32) {
	OW_ASSERT(ow_is_finite(sample_rate))
	OW_ASSERT(sample_rate > 0.0)
	OW_ASSERT(ow_is_finite(cutoff))
	OW_ASSERT(cutoff >= 1.0e-6 && cutoff <= 1.0e12)
	OW_ASSERT(ow_is_finite(prewarp_freq))
	OW_ASSERT(prewarp_freq >= 1.0e-6 && prewarp_freq <= 1.0e12)
}

// Summary: Executes iir1 coeffs common.
ow_iir1_coeffs_common :: proc(sample_rate: f32, cutoff: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, a1: ^f32) -> (f32, f32, f32) {
	prewarp := prewarp_freq
	if prewarp_at_cutoff != 0 {
		prewarp = cutoff
	}
	prewarp = ow_minf(prewarp, 0.499*sample_rate)
	t := ow_tanf(3.141592653589793 * prewarp * ow_rcpf(sample_rate))
	k := t * cutoff
	d := ow_rcpf(k + prewarp)
	a1^ = d * (k - prewarp)
	return prewarp, k, d
}

// Summary: Executes iir1 reset.
ow_iir1_reset :: proc(x_0: f32, y_0: ^f32, s_0: ^f32, b0: f32, b1: f32, a1: f32) {
	OW_ASSERT(ow_is_finite(x_0))
	OW_ASSERT(y_0 != nil)
	OW_ASSERT(s_0 != nil)
	OW_ASSERT(y_0 != s_0)
	ow_iir1_assert_valid_coeffs(b0, b1, a1)

	if a1 == -1.0 {
		y_0^ = 0.0
		s_0^ = 0.0
	} else {
		d := ow_rcpf(1.0 + a1)
		k := d * x_0
		y_0^ = k * (b1 + b0)
		s_0^ = k * (b1 - a1*b0)
	}

	OW_ASSERT(ow_is_finite(y_0^))
	OW_ASSERT(ow_is_finite(s_0^))
}

// Summary: Executes iir1 reset multi.
ow_iir1_reset_multi :: proc(x_0: ^f32, y_0: ^f32, s_0: ^f32, b0: f32, b1: f32, a1: f32, n_channels: int) {
	OW_ASSERT(x_0 != nil)
	OW_ASSERT(s_0 == nil || x_0 != s_0)
	OW_ASSERT(y_0 == nil || s_0 == nil || y_0 != s_0)
	ow_iir1_assert_valid_coeffs(b0, b1, a1)

	x0 := ([^]f32)(x_0)
	y0: [^]f32
	s0: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	if s_0 != nil {
		s0 = ([^]f32)(s_0)
	}

	if y_0 != nil {
		if s_0 != nil {
			for i := 0; i < n_channels; i += 1 {
				ow_iir1_reset(x0[i], &y0[i], &s0[i], b0, b1, a1)
			}
		} else {
			for i := 0; i < n_channels; i += 1 {
				v_s: f32
				ow_iir1_reset(x0[i], &y0[i], &v_s, b0, b1, a1)
			}
		}
	} else {
		if s_0 != nil {
			for i := 0; i < n_channels; i += 1 {
				v_y: f32
				ow_iir1_reset(x0[i], &v_y, &s0[i], b0, b1, a1)
			}
		}
	}
}

// Summary: Processes one sample for iir1.
ow_iir1_process1 :: proc(x: f32, y: ^f32, s: ^f32, b0: f32, b1: f32, a1: f32) {
	OW_ASSERT(ow_is_finite(x))
	OW_ASSERT(y != nil)
	OW_ASSERT(s != nil)
	OW_ASSERT(y != s)
	OW_ASSERT(ow_is_finite(s^))
	ow_iir1_assert_valid_coeffs(b0, b1, a1)

	y^ = b0*x + s^
	s^ = b1*x - a1*y^

	OW_ASSERT(ow_is_finite(y^))
	OW_ASSERT(ow_is_finite(s^))
}

// Summary: Processes sample buffers for iir1.
ow_iir1_process :: proc(x: ^f32, y: ^f32, s: ^f32, b0: f32, b1: f32, a1: f32, n_samples: int) {
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	OW_ASSERT(s != nil)
	OW_ASSERT(x != s)
	OW_ASSERT(y != s)
	OW_ASSERT(ow_is_finite(s^))
	ow_iir1_assert_valid_coeffs(b0, b1, a1)

	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	for i := 0; i < n_samples; i += 1 {
		ow_iir1_process1(xm[i], &ym[i], s, b0, b1, a1)
	}
}

// Summary: Processes multiple channels for iir1.
ow_iir1_process_multi :: proc(x: ^^f32, y: ^^f32, s: ^f32, b0: f32, b1: f32, a1: f32, n_channels: int, n_samples: int) {
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	OW_ASSERT(s != nil)
	ow_iir1_assert_valid_coeffs(b0, b1, a1)

	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	sm := ([^]f32)(s)

	for ch := 0; ch < n_channels; ch += 1 {
		for i := 0; i < n_samples; i += 1 {
			ow_iir1_process1(xm[ch][i], &ym[ch][i], &sm[ch], b0, b1, a1)
		}
	}
}

// Summary: Executes iir1 coeffs ap1.
ow_iir1_coeffs_ap1 :: proc(sample_rate: f32, cutoff: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, b0: ^f32, b1: ^f32, a1: ^f32) {
	ow_iir1_assert_valid_params(sample_rate, cutoff, prewarp_freq)
	OW_ASSERT(b0 != nil)
	OW_ASSERT(b1 != nil)
	OW_ASSERT(a1 != nil)
	OW_ASSERT(b0 != b1)
	OW_ASSERT(b0 != a1)
	OW_ASSERT(b1 != a1)

	_, _, _ = ow_iir1_coeffs_common(sample_rate, cutoff, prewarp_at_cutoff, prewarp_freq, a1)
	b0^ = a1^
	b1^ = 1.0
	ow_iir1_assert_valid_coeffs(b0^, b1^, a1^)
}

// Summary: Executes iir1 coeffs hp1.
ow_iir1_coeffs_hp1 :: proc(sample_rate: f32, cutoff: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, b0: ^f32, b1: ^f32, a1: ^f32) {
	ow_iir1_assert_valid_params(sample_rate, cutoff, prewarp_freq)
	OW_ASSERT(b0 != nil)
	OW_ASSERT(b1 != nil)
	OW_ASSERT(a1 != nil)
	OW_ASSERT(b0 != b1)
	OW_ASSERT(b0 != a1)
	OW_ASSERT(b1 != a1)

	prewarp_freq2, _, d := ow_iir1_coeffs_common(sample_rate, cutoff, prewarp_at_cutoff, prewarp_freq, a1)
	b0^ = d * prewarp_freq2
	b1^ = -b0^
	ow_iir1_assert_valid_coeffs(b0^, b1^, a1^)
}

// Summary: Executes iir1 coeffs hs1.
ow_iir1_coeffs_hs1 :: proc(sample_rate: f32, cutoff: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, high_gain_dB: i8, high_gain: f32, b0: ^f32, b1: ^f32, a1: ^f32) {
	ow_iir1_assert_valid_params(sample_rate, cutoff, prewarp_freq)
	OW_ASSERT(b0 != nil)
	OW_ASSERT(b1 != nil)
	OW_ASSERT(a1 != nil)
	OW_ASSERT(b0 != b1)
	OW_ASSERT(b0 != a1)
	OW_ASSERT(b1 != a1)
	OW_ASSERT(ow_is_finite(high_gain))
	if high_gain_dB != 0 {
		OW_ASSERT(high_gain >= -600.0 && high_gain <= 600.0)
	} else {
		OW_ASSERT(high_gain >= 1.0e-30 && high_gain <= 1.0e30)
	}

	hg := high_gain
	if high_gain_dB != 0 {
		hg = ow_dB2linf(high_gain)
	}
	OW_ASSERT(cutoff*ow_sqrtf(hg) >= 1.0e-6 && cutoff*ow_sqrtf(hg) <= 1.0e12)

	cutoff2 := cutoff * ow_sqrtf(hg)
	prewarp_freq2, k, d := ow_iir1_coeffs_common(sample_rate, cutoff2, prewarp_at_cutoff, prewarp_freq, a1)
	k2 := hg * prewarp_freq2
	b0^ = d * (k + k2)
	b1^ = d * (k - k2)
	ow_iir1_assert_valid_coeffs(b0^, b1^, a1^)
}

// Summary: Executes iir1 coeffs lp1.
ow_iir1_coeffs_lp1 :: proc(sample_rate: f32, cutoff: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, b0: ^f32, b1: ^f32, a1: ^f32) {
	ow_iir1_assert_valid_params(sample_rate, cutoff, prewarp_freq)
	OW_ASSERT(b0 != nil)
	OW_ASSERT(b1 != nil)
	OW_ASSERT(a1 != nil)
	OW_ASSERT(b0 != b1)
	OW_ASSERT(b0 != a1)
	OW_ASSERT(b1 != a1)

	_, k, d := ow_iir1_coeffs_common(sample_rate, cutoff, prewarp_at_cutoff, prewarp_freq, a1)
	b0^ = d * k
	b1^ = b0^
	ow_iir1_assert_valid_coeffs(b0^, b1^, a1^)
}

// Summary: Executes iir1 coeffs ls1.
ow_iir1_coeffs_ls1 :: proc(sample_rate: f32, cutoff: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, dc_gain_dB: i8, dc_gain: f32, b0: ^f32, b1: ^f32, a1: ^f32) {
	ow_iir1_assert_valid_params(sample_rate, cutoff, prewarp_freq)
	OW_ASSERT(b0 != nil)
	OW_ASSERT(b1 != nil)
	OW_ASSERT(a1 != nil)
	OW_ASSERT(b0 != b1)
	OW_ASSERT(b0 != a1)
	OW_ASSERT(b1 != a1)
	OW_ASSERT(ow_is_finite(dc_gain))
	if dc_gain_dB != 0 {
		OW_ASSERT(dc_gain >= -600.0 && dc_gain <= 600.0)
	} else {
		OW_ASSERT(dc_gain >= 1.0e-30 && dc_gain <= 1.0e30)
	}

	dg := dc_gain
	if dc_gain_dB != 0 {
		dg = ow_dB2linf(dc_gain)
	}
	r := ow_rcpf(ow_sqrtf(dg))
	OW_ASSERT(cutoff*r >= 1.0e-6 && cutoff*r <= 1.0e12)

	cutoff2 := cutoff * r
	prewarp_freq2, k, d := ow_iir1_coeffs_common(sample_rate, cutoff2, prewarp_at_cutoff, prewarp_freq, a1)
	k2 := dg * k
	b0^ = d * (k2 + prewarp_freq2)
	b1^ = d * (k2 - prewarp_freq2)
	ow_iir1_assert_valid_coeffs(b0^, b1^, a1^)
}

// Summary: Executes iir1 coeffs mm1.
ow_iir1_coeffs_mm1 :: proc(sample_rate: f32, cutoff: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, coeff_x: f32, coeff_lp: f32, b0: ^f32, b1: ^f32, a1: ^f32) {
	ow_iir1_assert_valid_params(sample_rate, cutoff, prewarp_freq)
	OW_ASSERT(b0 != nil)
	OW_ASSERT(b1 != nil)
	OW_ASSERT(a1 != nil)
	OW_ASSERT(b0 != b1)
	OW_ASSERT(b0 != a1)
	OW_ASSERT(b1 != a1)
	OW_ASSERT(ow_is_finite(coeff_x))
	OW_ASSERT(ow_is_finite(coeff_lp))

	prewarp_freq2, k, d := ow_iir1_coeffs_common(sample_rate, cutoff, prewarp_at_cutoff, prewarp_freq, a1)
	k2 := prewarp_freq2 * coeff_x
	k3 := k * (coeff_lp + coeff_x)
	b0^ = d * (k3 + k2)
	b1^ = d * (k3 - k2)
	ow_iir1_assert_valid_coeffs(b0^, b1^, a1^)
}

// Summary: Checks validity of iir1 coeffs.
ow_iir1_coeffs_is_valid :: proc(b0: f32, b1: f32, a1: f32) -> i8 {
	if !ow_is_finite(b0) || !ow_is_finite(b1) || !ow_is_finite(a1) {
		return 0
	}
	if a1 < -1.0 || a1 > 1.0 {
		return 0
	}
	return 1
}
