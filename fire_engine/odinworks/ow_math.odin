package odinworks

import "core:math"

// Summary: Returns the reciprocal of x.
ow_rcpf :: proc(x: f32) -> f32 {
	OW_ASSERT(x != 0.0)
	return 1.0 / x
}

// Summary: Returns the absolute value.
ow_absf :: proc(x: f32) -> f32 {
	return math.abs(x)
}

// Summary: Returns the smaller of two values.
ow_minf :: proc(a: f32, b: f32) -> f32 {
	if a < b {
		return a
	}
	return b
}

// Summary: Returns the larger of two values.
ow_maxf :: proc(a: f32, b: f32) -> f32 {
	if a > b {
		return a
	}
	return b
}

// Summary: Returns the floor of x.
ow_floorf :: proc(x: f32) -> f32 {
	return math.floor(x)
}

// Summary: Returns the square root of x.
ow_sqrtf :: proc(x: f32) -> f32 {
	OW_ASSERT(x >= 0.0)
	return math.sqrt(x)
}

// Summary: Returns the tangent of x.
ow_tanf :: proc(x: f32) -> f32 {
	return math.tan(x)
}

// Summary: Returns 2 raised to x.
ow_pow2f :: proc(x: f32) -> f32 {
	return math.pow(2.0, x)
}

// Summary: Clamps x to the inclusive range [m, M].
ow_clipf :: proc(x: f32, m: f32, M: f32) -> f32 {
	if x < m {
		return m
	}
	if x > M {
		return M
	}
	return x
}

// Summary: Converts a dB value to linear gain.
ow_dB2linf :: proc(value: f32) -> f32 {
	return math.pow(10.0, value / 20.0)
}

// Summary: Returns sin(2πx).
ow_sin2pif :: proc(x: f32) -> f32 {
	return math.sin(math.TAU * x)
}

// Summary: Returns magnitude with the sign of sign_source.
ow_copysignf :: proc(magnitude: f32, sign_source: f32) -> f32 {
	return math.copy_sign(magnitude, sign_source)
}
