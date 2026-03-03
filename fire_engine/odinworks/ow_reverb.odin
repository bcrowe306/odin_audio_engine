package odinworks

import "core:math"

// Summary: Coefficient data for reverb.
ow_reverb_coeffs :: struct {
	predelay_coeffs: ow_delay_coeffs,
	bandwidth_coeffs: ow_lp1_coeffs,
	delay_id1_coeffs: ow_delay_coeffs,
	delay_id2_coeffs: ow_delay_coeffs,
	delay_id3_coeffs: ow_delay_coeffs,
	delay_id4_coeffs: ow_delay_coeffs,
	delay_dd1_coeffs: ow_delay_coeffs,
	delay_dd2_coeffs: ow_delay_coeffs,
	delay_dd3_coeffs: ow_delay_coeffs,
	delay_dd4_coeffs: ow_delay_coeffs,
	delay_d1_coeffs: ow_delay_coeffs,
	delay_d2_coeffs: ow_delay_coeffs,
	delay_d3_coeffs: ow_delay_coeffs,
	delay_d4_coeffs: ow_delay_coeffs,
	decay_coeffs: ow_gain_coeffs,
	phase_gen_coeffs: ow_phase_gen_coeffs,
	phase_gen_state: ow_phase_gen_state,
	damping_coeffs: ow_lp1_coeffs,
	dry_wet_coeffs: ow_dry_wet_coeffs,
	smooth_coeffs: ow_one_pole_coeffs,
	smooth_predelay_state: ow_one_pole_state,

	fs: f32,
	T: f32,
	id1: int,
	id2: int,
	id3: int,
	id4: int,
	dd2: int,
	dd4: int,
	d1: int,
	d2: int,
	d3: int,
	d4: int,
	dl1: int,
	dl2: int,
	dl3: int,
	dl4: int,
	dl5: int,
	dl6: int,
	dl7: int,
	dr1: int,
	dr2: int,
	dr3: int,
	dr4: int,
	dr5: int,
	dr6: int,
	dr7: int,

	s: f32,
	diff2: f32,

	predelay: f32,
}

// Summary: Runtime state for reverb.
ow_reverb_state :: struct {
	predelay_state: ow_delay_state,
	bandwidth_state: ow_lp1_state,
	delay_id1_state: ow_delay_state,
	delay_id2_state: ow_delay_state,
	delay_id3_state: ow_delay_state,
	delay_id4_state: ow_delay_state,
	delay_dd1_state: ow_delay_state,
	delay_dd2_state: ow_delay_state,
	delay_dd3_state: ow_delay_state,
	delay_dd4_state: ow_delay_state,
	delay_d1_state: ow_delay_state,
	delay_d2_state: ow_delay_state,
	delay_d3_state: ow_delay_state,
	delay_d4_state: ow_delay_state,
	damping_1_state: ow_lp1_state,
	damping_2_state: ow_lp1_state,
}

// Summary: Initializes reverb.
ow_reverb_init :: proc(coeffs: ^ow_reverb_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_delay_init(&coeffs.predelay_coeffs, 0.1)
	ow_lp1_init(&coeffs.bandwidth_coeffs)
	ow_delay_init(&coeffs.delay_id1_coeffs, 142.0/29761.0)
	ow_delay_init(&coeffs.delay_id2_coeffs, 107.0/29761.0)
	ow_delay_init(&coeffs.delay_id3_coeffs, 379.0/29761.0)
	ow_delay_init(&coeffs.delay_id4_coeffs, 277.0/29761.0)
	ow_delay_init(&coeffs.delay_dd1_coeffs, (672.0+8.0)/29761.0)
	ow_delay_init(&coeffs.delay_dd2_coeffs, 1800.0/29761.0)
	ow_delay_init(&coeffs.delay_dd3_coeffs, (908.0+8.0)/29761.0)
	ow_delay_init(&coeffs.delay_dd4_coeffs, 2656.0/29761.0)
	ow_delay_init(&coeffs.delay_d1_coeffs, 4453.0/29761.0)
	ow_delay_init(&coeffs.delay_d2_coeffs, 3720.0/29761.0)
	ow_delay_init(&coeffs.delay_d3_coeffs, 4217.0/29761.0)
	ow_delay_init(&coeffs.delay_d4_coeffs, 3163.0/29761.0)
	ow_gain_init(&coeffs.decay_coeffs)
	ow_phase_gen_init(&coeffs.phase_gen_coeffs)
	ow_lp1_init(&coeffs.damping_coeffs)
	ow_dry_wet_init(&coeffs.dry_wet_coeffs)
	ow_one_pole_init(&coeffs.smooth_coeffs)

	ow_lp1_set_cutoff(&coeffs.bandwidth_coeffs, 20e3)
	ow_lp1_set_cutoff(&coeffs.damping_coeffs, 20e3)
	ow_gain_set_gain_lin(&coeffs.decay_coeffs, 0.5)
	ow_dry_wet_set_wet(&coeffs.dry_wet_coeffs, 0.5)
	ow_one_pole_set_tau(&coeffs.smooth_coeffs, 0.05)
	ow_one_pole_set_sticky_thresh(&coeffs.smooth_coeffs, 1e-6)

	coeffs.predelay = 0.0
}

// Summary: Sets sample rate for reverb.
ow_reverb_set_sample_rate :: proc(coeffs: ^ow_reverb_coeffs, sample_rate: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(sample_rate) && sample_rate > 0.0)
	ow_delay_set_sample_rate(&coeffs.predelay_coeffs, sample_rate)
	ow_lp1_set_sample_rate(&coeffs.bandwidth_coeffs, sample_rate)
	ow_delay_set_sample_rate(&coeffs.delay_id1_coeffs, sample_rate)
	ow_delay_set_sample_rate(&coeffs.delay_id2_coeffs, sample_rate)
	ow_delay_set_sample_rate(&coeffs.delay_id3_coeffs, sample_rate)
	ow_delay_set_sample_rate(&coeffs.delay_id4_coeffs, sample_rate)
	ow_delay_set_sample_rate(&coeffs.delay_dd1_coeffs, sample_rate)
	ow_delay_set_sample_rate(&coeffs.delay_dd2_coeffs, sample_rate)
	ow_delay_set_sample_rate(&coeffs.delay_dd3_coeffs, sample_rate)
	ow_delay_set_sample_rate(&coeffs.delay_dd4_coeffs, sample_rate)
	ow_delay_set_sample_rate(&coeffs.delay_d1_coeffs, sample_rate)
	ow_delay_set_sample_rate(&coeffs.delay_d2_coeffs, sample_rate)
	ow_delay_set_sample_rate(&coeffs.delay_d3_coeffs, sample_rate)
	ow_delay_set_sample_rate(&coeffs.delay_d4_coeffs, sample_rate)
	ow_gain_set_sample_rate(&coeffs.decay_coeffs, sample_rate)
	ow_phase_gen_set_sample_rate(&coeffs.phase_gen_coeffs, sample_rate)
	ow_lp1_set_sample_rate(&coeffs.damping_coeffs, sample_rate)
	ow_dry_wet_set_sample_rate(&coeffs.dry_wet_coeffs, sample_rate)
	ow_one_pole_set_sample_rate(&coeffs.smooth_coeffs, sample_rate)
	ow_one_pole_reset_coeffs(&coeffs.smooth_coeffs)
	coeffs.fs = sample_rate
	coeffs.T = 1.0 / sample_rate
	coeffs.id1 = int(math.round(coeffs.fs * (142.0 / 29761.0)))
	coeffs.id2 = int(math.round(coeffs.fs * (107.0 / 29761.0)))
	coeffs.id3 = int(math.round(coeffs.fs * (379.0 / 29761.0)))
	coeffs.id4 = int(math.round(coeffs.fs * (277.0 / 29761.0)))
	coeffs.dd2 = int(math.round(coeffs.fs * (1800.0 / 29761.0)))
	coeffs.dd4 = int(math.round(coeffs.fs * (2656.0 / 29761.0)))
	coeffs.d1 = int(math.round(coeffs.fs * (4453.0 / 29761.0)))
	coeffs.d2 = int(math.round(coeffs.fs * (3720.0 / 29761.0)))
	coeffs.d3 = int(math.round(coeffs.fs * (4217.0 / 29761.0)))
	coeffs.d4 = int(math.round(coeffs.fs * (3163.0 / 29761.0)))
	coeffs.dl1 = int(math.round(coeffs.fs * (266.0 / 29761.0)))
	coeffs.dl2 = int(math.round(coeffs.fs * (2974.0 / 29761.0)))
	coeffs.dl3 = int(math.round(coeffs.fs * (1913.0 / 29761.0)))
	coeffs.dl4 = int(math.round(coeffs.fs * (1996.0 / 29761.0)))
	coeffs.dl5 = int(math.round(coeffs.fs * (1990.0 / 29761.0)))
	coeffs.dl6 = int(math.round(coeffs.fs * (187.0 / 29761.0)))
	coeffs.dl7 = int(math.round(coeffs.fs * (1066.0 / 29761.0)))
	coeffs.dr1 = int(math.round(coeffs.fs * (353.0 / 29761.0)))
	coeffs.dr2 = int(math.round(coeffs.fs * (3627.0 / 29761.0)))
	coeffs.dr3 = int(math.round(coeffs.fs * (1228.0 / 29761.0)))
	coeffs.dr4 = int(math.round(coeffs.fs * (2673.0 / 29761.0)))
	coeffs.dr5 = int(math.round(coeffs.fs * (2111.0 / 29761.0)))
	coeffs.dr6 = int(math.round(coeffs.fs * (335.0 / 29761.0)))
	coeffs.dr7 = int(math.round(coeffs.fs * (121.0 / 29761.0)))
}

// Summary: Executes reverb mem req.
ow_reverb_mem_req :: proc(coeffs: ^ow_reverb_coeffs) -> int {
	OW_ASSERT(coeffs != nil)
	return ow_delay_mem_req(&coeffs.predelay_coeffs) +
		ow_delay_mem_req(&coeffs.delay_id1_coeffs) +
		ow_delay_mem_req(&coeffs.delay_id2_coeffs) +
		ow_delay_mem_req(&coeffs.delay_id3_coeffs) +
		ow_delay_mem_req(&coeffs.delay_id4_coeffs) +
		ow_delay_mem_req(&coeffs.delay_dd1_coeffs) +
		ow_delay_mem_req(&coeffs.delay_dd2_coeffs) +
		ow_delay_mem_req(&coeffs.delay_dd3_coeffs) +
		ow_delay_mem_req(&coeffs.delay_dd4_coeffs) +
		ow_delay_mem_req(&coeffs.delay_d1_coeffs) +
		ow_delay_mem_req(&coeffs.delay_d2_coeffs) +
		ow_delay_mem_req(&coeffs.delay_d3_coeffs) +
		ow_delay_mem_req(&coeffs.delay_d4_coeffs)
}

// Summary: Executes reverb mem set.
ow_reverb_mem_set :: proc(coeffs: ^ow_reverb_coeffs, state: ^ow_reverb_state, mem: rawptr) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(mem != nil)
	addr := uintptr(mem)
	ow_delay_mem_set(&coeffs.predelay_coeffs, &state.predelay_state, rawptr(addr))
	addr += uintptr(ow_delay_mem_req(&coeffs.predelay_coeffs))
	ow_delay_mem_set(&coeffs.delay_id1_coeffs, &state.delay_id1_state, rawptr(addr))
	addr += uintptr(ow_delay_mem_req(&coeffs.delay_id1_coeffs))
	ow_delay_mem_set(&coeffs.delay_id2_coeffs, &state.delay_id2_state, rawptr(addr))
	addr += uintptr(ow_delay_mem_req(&coeffs.delay_id2_coeffs))
	ow_delay_mem_set(&coeffs.delay_id3_coeffs, &state.delay_id3_state, rawptr(addr))
	addr += uintptr(ow_delay_mem_req(&coeffs.delay_id3_coeffs))
	ow_delay_mem_set(&coeffs.delay_id4_coeffs, &state.delay_id4_state, rawptr(addr))
	addr += uintptr(ow_delay_mem_req(&coeffs.delay_id4_coeffs))
	ow_delay_mem_set(&coeffs.delay_dd1_coeffs, &state.delay_dd1_state, rawptr(addr))
	addr += uintptr(ow_delay_mem_req(&coeffs.delay_dd1_coeffs))
	ow_delay_mem_set(&coeffs.delay_dd2_coeffs, &state.delay_dd2_state, rawptr(addr))
	addr += uintptr(ow_delay_mem_req(&coeffs.delay_dd2_coeffs))
	ow_delay_mem_set(&coeffs.delay_dd3_coeffs, &state.delay_dd3_state, rawptr(addr))
	addr += uintptr(ow_delay_mem_req(&coeffs.delay_dd3_coeffs))
	ow_delay_mem_set(&coeffs.delay_dd4_coeffs, &state.delay_dd4_state, rawptr(addr))
	addr += uintptr(ow_delay_mem_req(&coeffs.delay_dd4_coeffs))
	ow_delay_mem_set(&coeffs.delay_d1_coeffs, &state.delay_d1_state, rawptr(addr))
	addr += uintptr(ow_delay_mem_req(&coeffs.delay_d1_coeffs))
	ow_delay_mem_set(&coeffs.delay_d2_coeffs, &state.delay_d2_state, rawptr(addr))
	addr += uintptr(ow_delay_mem_req(&coeffs.delay_d2_coeffs))
	ow_delay_mem_set(&coeffs.delay_d3_coeffs, &state.delay_d3_state, rawptr(addr))
	addr += uintptr(ow_delay_mem_req(&coeffs.delay_d3_coeffs))
	ow_delay_mem_set(&coeffs.delay_d4_coeffs, &state.delay_d4_state, rawptr(addr))
}

// Summary: Resets coefficients for reverb.
ow_reverb_reset_coeffs :: proc(coeffs: ^ow_reverb_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_delay_reset_coeffs(&coeffs.predelay_coeffs)
	ow_lp1_reset_coeffs(&coeffs.bandwidth_coeffs)
	ow_delay_reset_coeffs(&coeffs.delay_id1_coeffs)
	ow_delay_reset_coeffs(&coeffs.delay_id2_coeffs)
	ow_delay_reset_coeffs(&coeffs.delay_id3_coeffs)
	ow_delay_reset_coeffs(&coeffs.delay_id4_coeffs)
	ow_delay_reset_coeffs(&coeffs.delay_dd1_coeffs)
	ow_delay_reset_coeffs(&coeffs.delay_dd2_coeffs)
	ow_delay_reset_coeffs(&coeffs.delay_dd3_coeffs)
	ow_delay_reset_coeffs(&coeffs.delay_dd4_coeffs)
	ow_delay_reset_coeffs(&coeffs.delay_d1_coeffs)
	ow_delay_reset_coeffs(&coeffs.delay_d2_coeffs)
	ow_delay_reset_coeffs(&coeffs.delay_d3_coeffs)
	ow_delay_reset_coeffs(&coeffs.delay_d4_coeffs)
	ow_gain_reset_coeffs(&coeffs.decay_coeffs)
	ow_phase_gen_reset_coeffs(&coeffs.phase_gen_coeffs)
	p, pi: f32
	ow_phase_gen_reset_state(&coeffs.phase_gen_coeffs, &coeffs.phase_gen_state, 0.0, &p, &pi)
	coeffs.s = (8.0/29761.0) * ow_osc_sin_process1(p)
	ow_lp1_reset_coeffs(&coeffs.damping_coeffs)
	coeffs.diff2 = ow_clipf(ow_gain_get_gain_lin(&coeffs.decay_coeffs)+0.15, 0.25, 0.5)
	ow_dry_wet_reset_coeffs(&coeffs.dry_wet_coeffs)
	coeffs.predelay = coeffs.T * math.round(coeffs.fs*coeffs.predelay)
	_ = ow_one_pole_reset_state(&coeffs.smooth_coeffs, &coeffs.smooth_predelay_state, coeffs.predelay)
}

// Summary: Resets state for reverb.
ow_reverb_reset_state :: proc(coeffs: ^ow_reverb_coeffs, state: ^ow_reverb_state, x_l_0: f32, x_r_0: f32, y_l_0: ^f32, y_r_0: ^f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_l_0))
	OW_ASSERT(ow_is_finite(x_r_0))
	OW_ASSERT(y_l_0 != nil)
	OW_ASSERT(y_r_0 != nil)
	OW_ASSERT(y_l_0 != y_r_0)

	i := 0.5 * (x_l_0 + x_r_0)
	pd := ow_delay_reset_state(&coeffs.predelay_coeffs, &state.predelay_state, i)
	bw := ow_lp1_reset_state(&coeffs.bandwidth_coeffs, &state.bandwidth_state, pd)

	v1 := (1.0 / (1.0 + 0.75)) * bw
	v2 := (1.0 / (1.0 + 0.625)) * bw

	_ = ow_delay_reset_state(&coeffs.delay_id1_coeffs, &state.delay_id1_state, v1)
	_ = ow_delay_reset_state(&coeffs.delay_id2_coeffs, &state.delay_id2_state, v1)
	_ = ow_delay_reset_state(&coeffs.delay_id3_coeffs, &state.delay_id3_state, v2)
	_ = ow_delay_reset_state(&coeffs.delay_id4_coeffs, &state.delay_id4_state, v2)

	decay := ow_gain_get_gain_cur(&coeffs.decay_coeffs)
	v3 := bw / (1.0 - decay*decay)
	v4 := decay * bw
	v5 := (1.0 / (1.0 - 0.7)) * v3
	v6 := (1.0 / (1.0 + coeffs.diff2)) * v4

	_ = ow_lp1_reset_state(&coeffs.damping_coeffs, &state.damping_1_state, v3)
	_ = ow_lp1_reset_state(&coeffs.damping_coeffs, &state.damping_2_state, v3)

	_ = ow_delay_reset_state(&coeffs.delay_d1_coeffs, &state.delay_d1_state, v3)
	_ = ow_delay_reset_state(&coeffs.delay_d2_coeffs, &state.delay_d2_state, v4)
	_ = ow_delay_reset_state(&coeffs.delay_d3_coeffs, &state.delay_d3_state, v3)
	_ = ow_delay_reset_state(&coeffs.delay_d4_coeffs, &state.delay_d4_state, v4)

	_ = ow_delay_reset_state(&coeffs.delay_dd1_coeffs, &state.delay_dd1_state, v5)
	_ = ow_delay_reset_state(&coeffs.delay_dd2_coeffs, &state.delay_dd2_state, v6)
	_ = ow_delay_reset_state(&coeffs.delay_dd3_coeffs, &state.delay_dd3_state, v5)
	_ = ow_delay_reset_state(&coeffs.delay_dd4_coeffs, &state.delay_dd4_state, v6)

	y := 0.6 * (v3 - v6 - v6)
	y_l_0^ = ow_dry_wet_process1(&coeffs.dry_wet_coeffs, x_l_0, y)
	y_r_0^ = ow_dry_wet_process1(&coeffs.dry_wet_coeffs, x_r_0, y)
}

// Summary: Resets multi-channel state for reverb.
ow_reverb_reset_state_multi :: proc(coeffs: ^ow_reverb_coeffs, state: ^^ow_reverb_state, x_l_0: ^f32, x_r_0: ^f32, y_l_0: ^f32, y_r_0: ^f32, n_channels: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_l_0 != nil)
	OW_ASSERT(x_r_0 != nil)
	states := ([^]^ow_reverb_state)(state)
	xl0 := ([^]f32)(x_l_0)
	xr0 := ([^]f32)(x_r_0)
	yl0: [^]f32
	yr0: [^]f32
	if y_l_0 != nil {
		yl0 = ([^]f32)(y_l_0)
	}
	if y_r_0 != nil {
		yr0 = ([^]f32)(y_r_0)
	}
	if y_l_0 != nil {
		if y_r_0 != nil {
			for ch := 0; ch < n_channels; ch += 1 {
				ow_reverb_reset_state(coeffs, states[ch], xl0[ch], xr0[ch], &yl0[ch], &yr0[ch])
			}
		} else {
			tmp: f32
			for ch := 0; ch < n_channels; ch += 1 {
				ow_reverb_reset_state(coeffs, states[ch], xl0[ch], xr0[ch], &yl0[ch], &tmp)
			}
		}
	} else {
		if y_r_0 != nil {
			tmp: f32
			for ch := 0; ch < n_channels; ch += 1 {
				ow_reverb_reset_state(coeffs, states[ch], xl0[ch], xr0[ch], &tmp, &yr0[ch])
			}
		} else {
			tmp_l, tmp_r: f32
			for ch := 0; ch < n_channels; ch += 1 {
				ow_reverb_reset_state(coeffs, states[ch], xl0[ch], xr0[ch], &tmp_l, &tmp_r)
			}
		}
	}
}

// Summary: Updates control-rate coefficients for reverb.
ow_reverb_update_coeffs_ctrl :: proc(coeffs: ^ow_reverb_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_lp1_update_coeffs_ctrl(&coeffs.bandwidth_coeffs)
	ow_gain_update_coeffs_ctrl(&coeffs.decay_coeffs)
	ow_phase_gen_update_coeffs_ctrl(&coeffs.phase_gen_coeffs)
	ow_dry_wet_update_coeffs_ctrl(&coeffs.dry_wet_coeffs)
	ow_lp1_update_coeffs_ctrl(&coeffs.damping_coeffs)
}

// Summary: Updates audio-rate coefficients for reverb.
ow_reverb_update_coeffs_audio :: proc(coeffs: ^ow_reverb_coeffs) {
	OW_ASSERT(coeffs != nil)
	ow_delay_update_coeffs_audio(&coeffs.predelay_coeffs)
	ow_lp1_update_coeffs_audio(&coeffs.bandwidth_coeffs)
	pd := ow_one_pole_process1_sticky_abs(&coeffs.smooth_coeffs, &coeffs.smooth_predelay_state, coeffs.predelay)
	ow_delay_set_delay(&coeffs.predelay_coeffs, pd)
	ow_delay_update_coeffs_ctrl(&coeffs.predelay_coeffs)
	ow_delay_update_coeffs_audio(&coeffs.predelay_coeffs)
	ow_gain_update_coeffs_audio(&coeffs.decay_coeffs)
	ow_phase_gen_update_coeffs_audio(&coeffs.phase_gen_coeffs)
	p, pi: f32
	ow_phase_gen_process1(&coeffs.phase_gen_coeffs, &coeffs.phase_gen_state, &p, &pi)
	coeffs.s = (8.0/29761.0) * ow_osc_sin_process1(p)
	ow_lp1_update_coeffs_audio(&coeffs.damping_coeffs)
	coeffs.diff2 = ow_clipf(ow_gain_get_gain_cur(&coeffs.decay_coeffs)+0.15, 0.25, 0.5)
	ow_dry_wet_update_coeffs_audio(&coeffs.dry_wet_coeffs)
}

// Summary: Processes one sample for reverb.
ow_reverb_process1 :: proc(coeffs: ^ow_reverb_coeffs, state: ^ow_reverb_state, x_l: f32, x_r: f32, y_l: ^f32, y_r: ^f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(ow_is_finite(x_l))
	OW_ASSERT(ow_is_finite(x_r))
	OW_ASSERT(y_l != nil)
	OW_ASSERT(y_r != nil)
	OW_ASSERT(y_l != y_r)

	i := 0.5 * (x_l + x_r)
	pd := ow_delay_process1(&coeffs.predelay_coeffs, &state.predelay_state, i)
	bw := ow_lp1_process1(&coeffs.bandwidth_coeffs, &state.bandwidth_state, pd)

	n14 := ow_delay_read(&coeffs.delay_id1_coeffs, &state.delay_id1_state, coeffs.id1, 0.0)
	n13 := bw - 0.75*n14
	id1 := n14 + 0.75*n13
	ow_delay_write(&coeffs.delay_id1_coeffs, &state.delay_id1_state, n13)
	n20 := ow_delay_read(&coeffs.delay_id2_coeffs, &state.delay_id2_state, coeffs.id2, 0.0)
	n19 := id1 - 0.75*n20
	id2 := n20 + 0.75*n19
	ow_delay_write(&coeffs.delay_id2_coeffs, &state.delay_id2_state, n19)
	n16 := ow_delay_read(&coeffs.delay_id3_coeffs, &state.delay_id3_state, coeffs.id3, 0.0)
	n15 := id2 - 0.625*n16
	id3 := n16 + 0.625*n15
	ow_delay_write(&coeffs.delay_id3_coeffs, &state.delay_id3_state, n15)
	n22 := ow_delay_read(&coeffs.delay_id4_coeffs, &state.delay_id4_state, coeffs.id4, 0.0)
	n21 := id3 - 0.625*n22
	id4 := n22 + 0.625*n21
	ow_delay_write(&coeffs.delay_id4_coeffs, &state.delay_id4_state, n21)

	n39 := ow_delay_read(&coeffs.delay_d2_coeffs, &state.delay_d2_state, coeffs.d2, 0.0)
	n63 := ow_delay_read(&coeffs.delay_d4_coeffs, &state.delay_d4_state, coeffs.d4, 0.0)
	s1 := id4 + ow_gain_process1(&coeffs.decay_coeffs, n63)
	s2 := id4 + ow_gain_process1(&coeffs.decay_coeffs, n39)

	dd1v := coeffs.fs * ((672.0 / 29761.0) + coeffs.s)
	dd1if := ow_floorf(dd1v)
	dd1f := dd1v - dd1if
	dd1i := int(dd1if)
	dd3v := coeffs.fs * ((908.0 / 29761.0) + coeffs.s)
	dd3if := ow_floorf(dd3v)
	dd3f := dd3v - dd3if
	dd3i := int(dd3if)

	n24 := ow_delay_read(&coeffs.delay_dd1_coeffs, &state.delay_dd1_state, dd1i, dd1f)
	n23 := s1 + 0.7*n24
	dd1 := n24 - 0.7*n23
	ow_delay_write(&coeffs.delay_dd1_coeffs, &state.delay_dd1_state, n23)
	n48 := ow_delay_read(&coeffs.delay_dd3_coeffs, &state.delay_dd3_state, dd3i, dd3f)
	n46 := s2 + 0.7*n48
	dd3 := n48 - 0.7*n46
	ow_delay_write(&coeffs.delay_dd3_coeffs, &state.delay_dd3_state, n46)
	n30 := ow_delay_read(&coeffs.delay_d1_coeffs, &state.delay_d1_state, coeffs.d1, 0.0)
	ow_delay_write(&coeffs.delay_d1_coeffs, &state.delay_d1_state, dd1)
	n54 := ow_delay_read(&coeffs.delay_d3_coeffs, &state.delay_d3_state, coeffs.d3, 0.0)
	ow_delay_write(&coeffs.delay_d3_coeffs, &state.delay_d3_state, dd3)
	damp1 := ow_lp1_process1(&coeffs.damping_coeffs, &state.damping_1_state, n30)
	damp2 := ow_lp1_process1(&coeffs.damping_coeffs, &state.damping_2_state, n54)
	decay1 := ow_gain_process1(&coeffs.decay_coeffs, damp1)
	decay2 := ow_gain_process1(&coeffs.decay_coeffs, damp2)
	n33 := ow_delay_read(&coeffs.delay_dd2_coeffs, &state.delay_dd2_state, coeffs.dd2, 0.0)
	n31 := decay1 - coeffs.diff2*n33
	dd2 := n33 + coeffs.diff2*n31
	ow_delay_write(&coeffs.delay_dd2_coeffs, &state.delay_dd2_state, n31)
	n59 := ow_delay_read(&coeffs.delay_dd4_coeffs, &state.delay_dd4_state, coeffs.dd4, 0.0)
	n55 := decay2 - coeffs.diff2*n59
	dd4 := n59 + coeffs.diff2*n55
	ow_delay_write(&coeffs.delay_dd2_coeffs, &state.delay_dd2_state, n55)
	ow_delay_write(&coeffs.delay_d2_coeffs, &state.delay_d2_state, dd2)
	ow_delay_write(&coeffs.delay_d4_coeffs, &state.delay_d4_state, dd4)

	y_l^ = 0.6 * (
		ow_delay_read(&coeffs.delay_d3_coeffs, &state.delay_d3_state, coeffs.dl1, 0.0) +
			ow_delay_read(&coeffs.delay_d3_coeffs, &state.delay_d3_state, coeffs.dl2, 0.0) -
			ow_delay_read(&coeffs.delay_dd4_coeffs, &state.delay_dd4_state, coeffs.dl3, 0.0) +
			ow_delay_read(&coeffs.delay_d4_coeffs, &state.delay_d4_state, coeffs.dl4, 0.0) -
			ow_delay_read(&coeffs.delay_d1_coeffs, &state.delay_d1_state, coeffs.dl5, 0.0) -
			ow_delay_read(&coeffs.delay_dd2_coeffs, &state.delay_dd2_state, coeffs.dl6, 0.0) -
			ow_delay_read(&coeffs.delay_d2_coeffs, &state.delay_d2_state, coeffs.dl7, 0.0)
	)
	y_r^ = 0.6 * (
		ow_delay_read(&coeffs.delay_d1_coeffs, &state.delay_d1_state, coeffs.dr1, 0.0) +
			ow_delay_read(&coeffs.delay_d1_coeffs, &state.delay_d1_state, coeffs.dr2, 0.0) -
			ow_delay_read(&coeffs.delay_dd2_coeffs, &state.delay_dd2_state, coeffs.dr3, 0.0) +
			ow_delay_read(&coeffs.delay_d2_coeffs, &state.delay_d2_state, coeffs.dr4, 0.0) -
			ow_delay_read(&coeffs.delay_d3_coeffs, &state.delay_d3_state, coeffs.dr5, 0.0) -
			ow_delay_read(&coeffs.delay_dd4_coeffs, &state.delay_dd4_state, coeffs.dr6, 0.0) -
			ow_delay_read(&coeffs.delay_d4_coeffs, &state.delay_d4_state, coeffs.dr7, 0.0)
	)
	y_l^ = ow_dry_wet_process1(&coeffs.dry_wet_coeffs, x_l, y_l^)
	y_r^ = ow_dry_wet_process1(&coeffs.dry_wet_coeffs, x_r, y_r^)
}

// Summary: Processes sample buffers for reverb.
ow_reverb_process :: proc(coeffs: ^ow_reverb_coeffs, state: ^ow_reverb_state, x_l: ^f32, x_r: ^f32, y_l: ^f32, y_r: ^f32, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_l != nil)
	OW_ASSERT(x_r != nil)
	OW_ASSERT(y_l != nil)
	OW_ASSERT(y_r != nil)
	xlm := ([^]f32)(x_l)
	xrm := ([^]f32)(x_r)
	ylm := ([^]f32)(y_l)
	yrm := ([^]f32)(y_r)
	ow_reverb_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_reverb_update_coeffs_audio(coeffs)
		ow_reverb_process1(coeffs, state, xlm[i], xrm[i], &ylm[i], &yrm[i])
	}
}

// Summary: Processes multiple channels for reverb.
ow_reverb_process_multi :: proc(coeffs: ^ow_reverb_coeffs, state: ^^ow_reverb_state, x_l: ^^f32, x_r: ^^f32, y_l: ^^f32, y_r: ^^f32, n_channels: int, n_samples: int) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(state != nil)
	OW_ASSERT(x_l != nil)
	OW_ASSERT(x_r != nil)
	OW_ASSERT(y_l != nil)
	OW_ASSERT(y_r != nil)
	states := ([^]^ow_reverb_state)(state)
	xlm := ([^][^]f32)(x_l)
	xrm := ([^][^]f32)(x_r)
	ylm := ([^][^]f32)(y_l)
	yrm := ([^][^]f32)(y_r)
	ow_reverb_update_coeffs_ctrl(coeffs)
	for i := 0; i < n_samples; i += 1 {
		ow_reverb_update_coeffs_audio(coeffs)
		for ch := 0; ch < n_channels; ch += 1 {
			ow_reverb_process1(coeffs, states[ch], xlm[ch][i], xrm[ch][i], &ylm[ch][i], &yrm[ch][i])
		}
	}
}

// Summary: Sets predelay for reverb.
ow_reverb_set_predelay :: proc(coeffs: ^ow_reverb_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0 && value <= 0.1)
	coeffs.predelay = coeffs.T * math.round(coeffs.fs*value)
}

// Summary: Sets bandwidth for reverb.
ow_reverb_set_bandwidth :: proc(coeffs: ^ow_reverb_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 20.0 && value <= 20e3)
	ow_lp1_set_cutoff(&coeffs.bandwidth_coeffs, value)
}

// Summary: Sets damping for reverb.
ow_reverb_set_damping :: proc(coeffs: ^ow_reverb_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 20.0 && value <= 20e3)
	ow_lp1_set_cutoff(&coeffs.damping_coeffs, value)
}

// Summary: Sets decay for reverb.
ow_reverb_set_decay :: proc(coeffs: ^ow_reverb_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0 && value < 1.0)
	ow_gain_set_gain_lin(&coeffs.decay_coeffs, value)
}

// Summary: Sets wet for reverb.
ow_reverb_set_wet :: proc(coeffs: ^ow_reverb_coeffs, value: f32) {
	OW_ASSERT(coeffs != nil)
	OW_ASSERT(ow_is_finite(value) && value >= 0.0 && value <= 1.0)
	ow_dry_wet_set_wet(&coeffs.dry_wet_coeffs, value)
}

// Summary: Checks validity of reverb coeffs.
ow_reverb_coeffs_is_valid :: proc(coeffs: ^ow_reverb_coeffs) -> i8 {
	if coeffs == nil {
		return 0
	}
	if !ow_is_finite(coeffs.predelay) || coeffs.predelay < 0.0 || coeffs.predelay > 0.1 {
		return 0
	}
	if !ow_one_pole_coeffs_is_valid(&coeffs.smooth_coeffs) {
		return 0
	}
	if !ow_phase_gen_coeffs_is_valid(&coeffs.phase_gen_coeffs) {
		return 0
	}
	if ow_delay_coeffs_is_valid(&coeffs.predelay_coeffs) == 0 ||
		ow_lp1_coeffs_is_valid(&coeffs.bandwidth_coeffs) == 0 ||
		ow_delay_coeffs_is_valid(&coeffs.delay_id1_coeffs) == 0 ||
		ow_delay_coeffs_is_valid(&coeffs.delay_id2_coeffs) == 0 ||
		ow_delay_coeffs_is_valid(&coeffs.delay_id3_coeffs) == 0 ||
		ow_delay_coeffs_is_valid(&coeffs.delay_id4_coeffs) == 0 ||
		ow_delay_coeffs_is_valid(&coeffs.delay_dd1_coeffs) == 0 ||
		ow_delay_coeffs_is_valid(&coeffs.delay_dd2_coeffs) == 0 ||
		ow_delay_coeffs_is_valid(&coeffs.delay_dd3_coeffs) == 0 ||
		ow_delay_coeffs_is_valid(&coeffs.delay_dd4_coeffs) == 0 ||
		ow_delay_coeffs_is_valid(&coeffs.delay_d1_coeffs) == 0 ||
		ow_delay_coeffs_is_valid(&coeffs.delay_d2_coeffs) == 0 ||
		ow_delay_coeffs_is_valid(&coeffs.delay_d3_coeffs) == 0 ||
		ow_delay_coeffs_is_valid(&coeffs.delay_d4_coeffs) == 0 ||
		ow_lp1_coeffs_is_valid(&coeffs.damping_coeffs) == 0 ||
		ow_dry_wet_coeffs_is_valid(&coeffs.dry_wet_coeffs) == 0 {
		return 0
	}
	return 1
}

// Summary: Checks validity of reverb state.
ow_reverb_state_is_valid :: proc(coeffs: ^ow_reverb_coeffs, state: ^ow_reverb_state) -> i8 {
	if state == nil {
		return 0
	}
	if coeffs != nil {
		if ow_delay_state_is_valid(&coeffs.predelay_coeffs, &state.predelay_state) == 0 ||
			ow_delay_state_is_valid(&coeffs.delay_id1_coeffs, &state.delay_id1_state) == 0 ||
			ow_delay_state_is_valid(&coeffs.delay_id2_coeffs, &state.delay_id2_state) == 0 ||
			ow_delay_state_is_valid(&coeffs.delay_id3_coeffs, &state.delay_id3_state) == 0 ||
			ow_delay_state_is_valid(&coeffs.delay_id4_coeffs, &state.delay_id4_state) == 0 ||
			ow_delay_state_is_valid(&coeffs.delay_dd1_coeffs, &state.delay_dd1_state) == 0 ||
			ow_delay_state_is_valid(&coeffs.delay_dd2_coeffs, &state.delay_dd2_state) == 0 ||
			ow_delay_state_is_valid(&coeffs.delay_dd3_coeffs, &state.delay_dd3_state) == 0 ||
			ow_delay_state_is_valid(&coeffs.delay_dd4_coeffs, &state.delay_dd4_state) == 0 ||
			ow_delay_state_is_valid(&coeffs.delay_d1_coeffs, &state.delay_d1_state) == 0 ||
			ow_delay_state_is_valid(&coeffs.delay_d2_coeffs, &state.delay_d2_state) == 0 ||
			ow_delay_state_is_valid(&coeffs.delay_d3_coeffs, &state.delay_d3_state) == 0 ||
			ow_delay_state_is_valid(&coeffs.delay_d4_coeffs, &state.delay_d4_state) == 0 {
			return 0
		}
	} else {
		if ow_delay_state_is_valid(nil, &state.predelay_state) == 0 ||
			ow_delay_state_is_valid(nil, &state.delay_id1_state) == 0 ||
			ow_delay_state_is_valid(nil, &state.delay_id2_state) == 0 ||
			ow_delay_state_is_valid(nil, &state.delay_id3_state) == 0 ||
			ow_delay_state_is_valid(nil, &state.delay_id4_state) == 0 ||
			ow_delay_state_is_valid(nil, &state.delay_dd1_state) == 0 ||
			ow_delay_state_is_valid(nil, &state.delay_dd2_state) == 0 ||
			ow_delay_state_is_valid(nil, &state.delay_dd3_state) == 0 ||
			ow_delay_state_is_valid(nil, &state.delay_dd4_state) == 0 ||
			ow_delay_state_is_valid(nil, &state.delay_d1_state) == 0 ||
			ow_delay_state_is_valid(nil, &state.delay_d2_state) == 0 ||
			ow_delay_state_is_valid(nil, &state.delay_d3_state) == 0 ||
			ow_delay_state_is_valid(nil, &state.delay_d4_state) == 0 {
			return 0
		}
	}
	return 1
}
