package odinworks

// Summary: Executes iir2 assert valid coeff ptrs.
ow_iir2_assert_valid_coeff_ptrs :: proc(b0: ^f32, b1: ^f32, b2: ^f32, a1: ^f32, a2: ^f32) {
	OW_ASSERT(b0 != nil)
	OW_ASSERT(b1 != nil)
	OW_ASSERT(b2 != nil)
	OW_ASSERT(a1 != nil)
	OW_ASSERT(a2 != nil)
	OW_ASSERT(b0 != b1)
	OW_ASSERT(b0 != b2)
	OW_ASSERT(b1 != b2)
	OW_ASSERT(b0 != a1)
	OW_ASSERT(b1 != a1)
	OW_ASSERT(b2 != a1)
	OW_ASSERT(b0 != a2)
	OW_ASSERT(b1 != a2)
	OW_ASSERT(b2 != a2)
	OW_ASSERT(a1 != a2)
}

// Summary: Executes iir2 assert valid params.
ow_iir2_assert_valid_params :: proc(sample_rate: f32, cutoff: f32, Q: f32, prewarp_freq: f32) {
	OW_ASSERT(ow_is_finite(sample_rate))
	OW_ASSERT(sample_rate > 0.0)
	OW_ASSERT(ow_is_finite(cutoff))
	OW_ASSERT(cutoff >= 1.0e-6 && cutoff <= 1.0e12)
	OW_ASSERT(ow_is_finite(Q))
	OW_ASSERT(Q >= 1.0e-6 && Q <= 1.0e6)
	OW_ASSERT(ow_is_finite(prewarp_freq))
	OW_ASSERT(prewarp_freq >= 1.0e-6 && prewarp_freq <= 1.0e12)
}

// Summary: Executes iir2 coeffs common.
ow_iir2_coeffs_common :: proc(sample_rate: f32, cutoff: f32, Q: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, a1: ^f32, a2: ^f32) -> (f32, f32, f32, f32, f32, f32, f32, f32) {
	prewarp := prewarp_freq
	if prewarp_at_cutoff != 0 {
		prewarp = cutoff
	}
	prewarp = ow_minf(prewarp, 0.499*sample_rate)
	t := ow_tanf(3.141592653589793 * prewarp * ow_rcpf(sample_rate))
	k1 := prewarp * prewarp
	k2 := t * cutoff
	k3 := k2 * k2
	k4 := k2 * prewarp
	k5 := Q * (k1 + k3)
	d := ow_rcpf(k5 + k4)
	a1^ = d * (Q + Q) * (k3 - k1)
	a2^ = d * (k5 - k4)
	return prewarp, k1, k2, k3, k4, k5, d, t
}

// Summary: Executes iir2 reset.
ow_iir2_reset :: proc(x_0: f32, y_0: ^f32, s1_0: ^f32, s2_0: ^f32, b0: f32, b1: f32, b2: f32, a1: f32, a2: f32) {
	OW_ASSERT(ow_is_finite(x_0))
	OW_ASSERT(y_0 != nil)
	OW_ASSERT(s1_0 != nil)
	OW_ASSERT(s2_0 != nil)
	OW_ASSERT(y_0 != s1_0)
	OW_ASSERT(y_0 != s2_0)
	OW_ASSERT(s1_0 != s2_0)
	OW_ASSERT(ow_iir2_coeffs_is_valid(b0, b1, b2, a1, a2) != 0)

	if a1+a2 == -1.0 {
		y_0^ = 0.0
		s1_0^ = 0.0
		s2_0^ = 0.0
	} else {
		d := ow_rcpf(1.0 + a1 + a2)
		k := d * x_0
		y_0^ = k * (b0 + b1 + b2)
		s1_0^ = k * (b1 + b2 - b0*(a1+a2))
		s2_0^ = k * (b2 + b2*a1 - a2*(b0+b1))
	}
}

// Summary: Executes iir2 reset multi.
ow_iir2_reset_multi :: proc(x_0: ^f32, y_0: ^f32, s1_0: ^f32, s2_0: ^f32, b0: f32, b1: f32, b2: f32, a1: f32, a2: f32, n_channels: int) {
	OW_ASSERT(x_0 != nil)
	OW_ASSERT(s1_0 == nil || x_0 != s1_0)
	OW_ASSERT(y_0 == nil || s1_0 == nil || y_0 != s1_0)
	OW_ASSERT(s2_0 == nil || x_0 != s2_0)
	OW_ASSERT(y_0 == nil || s2_0 == nil || y_0 != s2_0)
	OW_ASSERT(s1_0 == nil || s2_0 == nil || s1_0 != s2_0)
	OW_ASSERT(ow_iir2_coeffs_is_valid(b0, b1, b2, a1, a2) != 0)

	x0 := ([^]f32)(x_0)
	y0: [^]f32
	s10: [^]f32
	s20: [^]f32
	if y_0 != nil {
		y0 = ([^]f32)(y_0)
	}
	if s1_0 != nil {
		s10 = ([^]f32)(s1_0)
	}
	if s2_0 != nil {
		s20 = ([^]f32)(s2_0)
	}

	if y_0 != nil {
		if s1_0 != nil {
			if s2_0 != nil {
				for i := 0; i < n_channels; i += 1 {
					ow_iir2_reset(x0[i], &y0[i], &s10[i], &s20[i], b0, b1, b2, a1, a2)
				}
			} else {
				for i := 0; i < n_channels; i += 1 {
					v_s2: f32
					ow_iir2_reset(x0[i], &y0[i], &s10[i], &v_s2, b0, b1, b2, a1, a2)
				}
			}
		} else {
			if s2_0 != nil {
				for i := 0; i < n_channels; i += 1 {
					v_s1: f32
					ow_iir2_reset(x0[i], &y0[i], &v_s1, &s20[i], b0, b1, b2, a1, a2)
				}
			} else {
				for i := 0; i < n_channels; i += 1 {
					v_s1, v_s2: f32
					ow_iir2_reset(x0[i], &y0[i], &v_s1, &v_s2, b0, b1, b2, a1, a2)
				}
			}
		}
	} else {
		if s1_0 != nil {
			if s2_0 != nil {
				for i := 0; i < n_channels; i += 1 {
					v_y: f32
					ow_iir2_reset(x0[i], &v_y, &s10[i], &s20[i], b0, b1, b2, a1, a2)
				}
			} else {
				for i := 0; i < n_channels; i += 1 {
					v_y, v_s2: f32
					ow_iir2_reset(x0[i], &v_y, &s10[i], &v_s2, b0, b1, b2, a1, a2)
				}
			}
		} else {
			if s2_0 != nil {
				for i := 0; i < n_channels; i += 1 {
					v_y, v_s1: f32
					ow_iir2_reset(x0[i], &v_y, &v_s1, &s20[i], b0, b1, b2, a1, a2)
				}
			}
		}
	}
}

// Summary: Processes one sample for iir2.
ow_iir2_process1 :: proc(x: f32, y: ^f32, s1: ^f32, s2: ^f32, b0: f32, b1: f32, b2: f32, a1: f32, a2: f32) {
	OW_ASSERT(ow_is_finite(x))
	OW_ASSERT(y != nil)
	OW_ASSERT(s1 != nil)
	OW_ASSERT(s2 != nil)
	OW_ASSERT(y != s1)
	OW_ASSERT(y != s2)
	OW_ASSERT(s1 != s2)
	OW_ASSERT(ow_iir2_coeffs_is_valid(b0, b1, b2, a1, a2) != 0)

	y^ = b0*x + s1^
	s1^ = b1*x - a1*y^ + s2^
	s2^ = b2*x - a2*y^
}

// Summary: Processes sample buffers for iir2.
ow_iir2_process :: proc(x: ^f32, y: ^f32, s1: ^f32, s2: ^f32, b0: f32, b1: f32, b2: f32, a1: f32, a2: f32, n_samples: int) {
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	OW_ASSERT(s1 != nil)
	OW_ASSERT(s2 != nil)
	OW_ASSERT(x != s1)
	OW_ASSERT(y != s1)
	OW_ASSERT(x != s2)
	OW_ASSERT(y != s2)
	OW_ASSERT(s1 != s2)
	OW_ASSERT(ow_iir2_coeffs_is_valid(b0, b1, b2, a1, a2) != 0)

	xm := ([^]f32)(x)
	ym := ([^]f32)(y)
	for i := 0; i < n_samples; i += 1 {
		ow_iir2_process1(xm[i], &ym[i], s1, s2, b0, b1, b2, a1, a2)
	}
}

// Summary: Processes multiple channels for iir2.
ow_iir2_process_multi :: proc(x: ^^f32, y: ^^f32, s1: ^f32, s2: ^f32, b0: f32, b1: f32, b2: f32, a1: f32, a2: f32, n_channels: int, n_samples: int) {
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	OW_ASSERT(s1 != nil)
	OW_ASSERT(s2 != nil)
	OW_ASSERT(s1 != s2)
	OW_ASSERT(ow_iir2_coeffs_is_valid(b0, b1, b2, a1, a2) != 0)

	xm := ([^][^]f32)(x)
	ym := ([^][^]f32)(y)
	s1m := ([^]f32)(s1)
	s2m := ([^]f32)(s2)

	for ch := 0; ch < n_channels; ch += 1 {
		for i := 0; i < n_samples; i += 1 {
			ow_iir2_process1(xm[ch][i], &ym[ch][i], &s1m[ch], &s2m[ch], b0, b1, b2, a1, a2)
		}
	}
}

// Summary: Executes iir2 coeffs ap2.
ow_iir2_coeffs_ap2 :: proc(sample_rate: f32, cutoff: f32, Q: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, b0: ^f32, b1: ^f32, b2: ^f32, a1: ^f32, a2: ^f32) {
	ow_iir2_assert_valid_params(sample_rate, cutoff, Q, prewarp_freq)
	ow_iir2_assert_valid_coeff_ptrs(b0, b1, b2, a1, a2)
	_, _, _, _, _, _, _, _ = ow_iir2_coeffs_common(sample_rate, cutoff, Q, prewarp_at_cutoff, prewarp_freq, a1, a2)
	b0^ = a2^
	b1^ = a1^
	b2^ = 1.0
}

// Summary: Executes iir2 coeffs bp2.
ow_iir2_coeffs_bp2 :: proc(sample_rate: f32, cutoff: f32, Q: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, b0: ^f32, b1: ^f32, b2: ^f32, a1: ^f32, a2: ^f32) {
	ow_iir2_assert_valid_params(sample_rate, cutoff, Q, prewarp_freq)
	ow_iir2_assert_valid_coeff_ptrs(b0, b1, b2, a1, a2)
	_, _, _, _, k4, _, _, _ := ow_iir2_coeffs_common(sample_rate, cutoff, Q, prewarp_at_cutoff, prewarp_freq, a1, a2)
	b0^ = Q * k4
	b1^ = 0.0
	b2^ = -b0^
}

// Summary: Executes iir2 coeffs hp2.
ow_iir2_coeffs_hp2 :: proc(sample_rate: f32, cutoff: f32, Q: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, b0: ^f32, b1: ^f32, b2: ^f32, a1: ^f32, a2: ^f32) {
	ow_iir2_assert_valid_params(sample_rate, cutoff, Q, prewarp_freq)
	ow_iir2_assert_valid_coeff_ptrs(b0, b1, b2, a1, a2)
	_, k1, _, _, _, _, _, _ := ow_iir2_coeffs_common(sample_rate, cutoff, Q, prewarp_at_cutoff, prewarp_freq, a1, a2)
	b0^ = Q * k1
	b1^ = -(b0^ + b0^)
	b2^ = b0^
}

// Summary: Executes iir2 coeffs hs2.
ow_iir2_coeffs_hs2 :: proc(sample_rate: f32, cutoff: f32, Q: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, high_gain_dB: i8, high_gain: f32, b0: ^f32, b1: ^f32, b2: ^f32, a1: ^f32, a2: ^f32) {
	ow_iir2_assert_valid_params(sample_rate, cutoff, Q, prewarp_freq)
	ow_iir2_assert_valid_coeff_ptrs(b0, b1, b2, a1, a2)
	hg := high_gain
	if high_gain_dB != 0 {
		hg = ow_dB2linf(high_gain)
	}
	sg := ow_sqrtf(hg)
	ssg := ow_sqrtf(sg)
	cutoff2 := cutoff * ssg
	_, k1, _, k3, k4, _, d, _ := ow_iir2_coeffs_common(sample_rate, cutoff2, Q, prewarp_at_cutoff, prewarp_freq, a1, a2)
	k6 := k1 * hg
	k7 := k3 - k3*sg
	k8 := Q * (k7 + k6)
	k9 := k4 * sg
	b0^ = d * (k8 + k9)
	b1^ = d * (Q + Q) * (k7 - k6)
	b2^ = d * (k8 - k9)
}

// Summary: Executes iir2 coeffs lp2.
ow_iir2_coeffs_lp2 :: proc(sample_rate: f32, cutoff: f32, Q: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, b0: ^f32, b1: ^f32, b2: ^f32, a1: ^f32, a2: ^f32) {
	ow_iir2_assert_valid_params(sample_rate, cutoff, Q, prewarp_freq)
	ow_iir2_assert_valid_coeff_ptrs(b0, b1, b2, a1, a2)
	_, _, _, k3, _, _, _, _ := ow_iir2_coeffs_common(sample_rate, cutoff, Q, prewarp_at_cutoff, prewarp_freq, a1, a2)
	b0^ = Q * k3
	b1^ = b0^ + b0^
	b2^ = b0^
}

// Summary: Executes iir2 coeffs ls2.
ow_iir2_coeffs_ls2 :: proc(sample_rate: f32, cutoff: f32, Q: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, dc_gain_dB: i8, dc_gain: f32, b0: ^f32, b1: ^f32, b2: ^f32, a1: ^f32, a2: ^f32) {
	ow_iir2_assert_valid_params(sample_rate, cutoff, Q, prewarp_freq)
	ow_iir2_assert_valid_coeff_ptrs(b0, b1, b2, a1, a2)
	dg := dc_gain
	if dc_gain_dB != 0 {
		dg = ow_dB2linf(dc_gain)
	}
	sg := ow_sqrtf(dg)
	issg := ow_rcpf(ow_sqrtf(sg))
	cutoff2 := cutoff * issg
	_, k1, _, k3, k4, _, d, _ := ow_iir2_coeffs_common(sample_rate, cutoff2, Q, prewarp_at_cutoff, prewarp_freq, a1, a2)
	k6 := k3 * (dg - sg)
	k7 := Q * (k6 + k1)
	k8 := k4 * sg
	b0^ = d * (k7 + k8)
	b1^ = d * (Q + Q) * (k6 - k1)
	b2^ = d * (k7 - k8)
}

// Summary: Executes iir2 coeffs mm2.
ow_iir2_coeffs_mm2 :: proc(sample_rate: f32, cutoff: f32, Q: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, coeff_x: f32, coeff_lp: f32, coeff_bp: f32, coeff_hp: f32, b0: ^f32, b1: ^f32, b2: ^f32, a1: ^f32, a2: ^f32) {
	ow_iir2_assert_valid_params(sample_rate, cutoff, Q, prewarp_freq)
	ow_iir2_assert_valid_coeff_ptrs(b0, b1, b2, a1, a2)
	_, k1, _, k3, k4, _, d, _ := ow_iir2_coeffs_common(sample_rate, cutoff, Q, prewarp_at_cutoff, prewarp_freq, a1, a2)
	k6 := k3 * (coeff_lp + coeff_x)
	k7 := k1 * (coeff_hp + coeff_x)
	k8 := k4 * (Q*coeff_bp + coeff_x)
	k9 := Q * (k6 + k7)
	b0^ = d * (k9 + k8)
	b1^ = d * (Q + Q) * (k6 - k7)
	b2^ = d * (k9 - k8)
}

// Summary: Executes iir2 coeffs notch.
ow_iir2_coeffs_notch :: proc(sample_rate: f32, cutoff: f32, Q: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, b0: ^f32, b1: ^f32, b2: ^f32, a1: ^f32, a2: ^f32) {
	ow_iir2_assert_valid_params(sample_rate, cutoff, Q, prewarp_freq)
	ow_iir2_assert_valid_coeff_ptrs(b0, b1, b2, a1, a2)
	_, _, _, _, _, k5, d, _ := ow_iir2_coeffs_common(sample_rate, cutoff, Q, prewarp_at_cutoff, prewarp_freq, a1, a2)
	b0^ = d * k5
	b1^ = a1^
	b2^ = b0^
}

// Summary: Executes iir2 coeffs peak.
ow_iir2_coeffs_peak :: proc(sample_rate: f32, cutoff: f32, use_bandwidth: i8, Q_bandwidth: f32, prewarp_at_cutoff: i8, prewarp_freq: f32, peak_gain_dB: i8, peak_gain: f32, b0: ^f32, b1: ^f32, b2: ^f32, a1: ^f32, a2: ^f32) {
	OW_ASSERT(ow_is_finite(Q_bandwidth))
	if use_bandwidth != 0 {
		OW_ASSERT(Q_bandwidth >= 1.0e-6 && Q_bandwidth <= 90.0)
	}
	pg := peak_gain
	if peak_gain_dB != 0 {
		pg = ow_dB2linf(peak_gain)
	}

	Q := Q_bandwidth
	if use_bandwidth != 0 {
		k6 := ow_pow2f(Q_bandwidth)
		Q = ow_sqrtf(k6*pg) * ow_rcpf(k6-1.0)
	}

	ow_iir2_assert_valid_params(sample_rate, cutoff, Q, prewarp_freq)
	ow_iir2_assert_valid_coeff_ptrs(b0, b1, b2, a1, a2)
	_, k1, _, k3, k4, _, d, _ := ow_iir2_coeffs_common(sample_rate, cutoff, Q, prewarp_at_cutoff, prewarp_freq, a1, a2)
	k6 := Q * (k1 + k3)
	k7 := k4 * pg
	b0^ = d * (k6 + k7)
	b1^ = a1^
	b2^ = d * (k6 - k7)
}

// Summary: Checks validity of iir2 coeffs.
ow_iir2_coeffs_is_valid :: proc(b0: f32, b1: f32, b2: f32, a1: f32, a2: f32) -> i8 {
	if !ow_is_finite(b0) || !ow_is_finite(b1) || !ow_is_finite(b2) || !ow_is_finite(a1) || !ow_is_finite(a2) {
		return 0
	}
	if ow_absf(a1) > 2.0 {
		return 0
	}
	if a2 < ow_absf(a1)-1.0 || a2 > 1.0 {
		return 0
	}
	return 1
}
