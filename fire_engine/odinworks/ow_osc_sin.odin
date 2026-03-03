package odinworks

// Summary: Processes one sample for osc sin.
ow_osc_sin_process1 :: proc(x: f32) -> f32 {
	OW_ASSERT(ow_is_finite(x))
	OW_ASSERT(x >= 0.0 && x < 1.0)
	return ow_sin2pif(x)
}

// Summary: Processes sample buffers for osc sin.
ow_osc_sin_process :: proc(x: [^]f32, y: [^]f32, n_samples: int) {
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	for i := 0; i < n_samples; i += 1 {
		y[i] = ow_osc_sin_process1(x[i])
	}
}

// Summary: Processes multiple channels for osc sin.
ow_osc_sin_process_multi :: proc(x: [^][^]f32, y: [^][^]f32, n_channels: int, n_samples: int) {
	OW_ASSERT(x != nil)
	OW_ASSERT(y != nil)
	for ch := 0; ch < n_channels; ch += 1 {
		ow_osc_sin_process(x[ch], y[ch], n_samples)
	}
}
