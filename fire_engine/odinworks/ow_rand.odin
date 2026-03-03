package odinworks

// Summary: Executes randu32.
ow_randu32 :: proc(state: ^u64) -> u32 {
	OW_ASSERT(state != nil)
	state^ = state^ * 0x9b60933458e17d7d + 0xd737232eeccdf7ed
	shift := u32(29 - (state^ >> 61))
	return u32(state^ >> shift)
}

// Summary: Executes randf.
ow_randf :: proc(state: ^u64) -> f32 {
	OW_ASSERT(state != nil)
	raw := ow_randu32(state)
	y := (2.0 / 4294967295.0) * f32(raw) - 1.0
	OW_ASSERT(ow_is_finite(y))
	return y
}
