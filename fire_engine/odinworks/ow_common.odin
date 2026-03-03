package odinworks

import "core:math"

// Summary: Asserts that a condition is true.
OW_ASSERT :: proc(cond: bool) {
	assert(cond)
}

// Summary: Asserts a deep/internal condition.
OW_ASSERT_DEEP :: proc(cond: bool) {
	assert(cond)
}

// Summary: Returns whether inf is true.
ow_is_inf :: proc(x: f32) -> bool {
	return math.is_inf(x)
}

// Summary: Returns whether nan is true.
ow_is_nan :: proc(x: f32) -> bool {
	return math.is_nan(x)
}

// Summary: Returns whether finite is true.
ow_is_finite :: proc(x: f32) -> bool {
	return !math.is_nan(x) && !math.is_inf(x)
}

// Summary: Returns whether data has inf.
ow_has_inf :: proc(x: [^]f32, n_elems: int) -> bool {
	OW_ASSERT(x != nil)
	for i := 0; i < n_elems; i += 1 {
		if ow_is_inf(x[i]) {
			return true
		}
	}
	return false
}

// Summary: Returns whether data has nan.
ow_has_nan :: proc(x: [^]f32, n_elems: int) -> bool {
	OW_ASSERT(x != nil)
	for i := 0; i < n_elems; i += 1 {
		if ow_is_nan(x[i]) {
			return true
		}
	}
	return false
}

// Summary: Returns whether data has only finite.
ow_has_only_finite :: proc(x: [^]f32, n_elems: int) -> bool {
	OW_ASSERT(x != nil)
	for i := 0; i < n_elems; i += 1 {
		if !ow_is_finite(x[i]) {
			return false
		}
	}
	return true
}

// Summary: Computes a sdbm hash.
ow_hash_sdbm :: proc(string: cstring) -> u32 {
	OW_ASSERT(string != nil)

	hash: u32 = 0
	bytes := ([^]u8)(string)
	for i := 0; bytes[i] != 0; i += 1 {
		hash = u32(bytes[i]) + (hash << 6) + (hash << 16) - hash
	}
	return hash
}
