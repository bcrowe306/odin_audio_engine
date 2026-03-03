package odinworks

// Summary: Fills buffers with a constant value.
ow_buf_fill :: proc(k: f32, dest: ^f32, n_elems: int) {
	OW_ASSERT(!ow_is_nan(k))
	OW_ASSERT(dest != nil)
	d := ([^]f32)(dest)
	for i := 0; i < n_elems; i += 1 {
		d[i] = k
	}
}

// Summary: Copies buffers.
ow_buf_copy :: proc(src: ^f32, dest: ^f32, n_elems: int) {
	OW_ASSERT(src != nil)
	OW_ASSERT(dest != nil)
	s := ([^]f32)(src)
	d := ([^]f32)(dest)
	for i := 0; i < n_elems; i += 1 {
		d[i] = s[i]
	}
}

// Summary: Negates buffer values.
ow_buf_neg :: proc(src: ^f32, dest: ^f32, n_elems: int) {
	OW_ASSERT(src != nil)
	OW_ASSERT(dest != nil)
	s := ([^]f32)(src)
	d := ([^]f32)(dest)
	for i := 0; i < n_elems; i += 1 {
		d[i] = -s[i]
	}
}

// Summary: Adds a scalar to buffers.
ow_buf_add :: proc(src: ^f32, k: f32, dest: ^f32, n_elems: int) {
	OW_ASSERT(src != nil)
	OW_ASSERT(!ow_is_nan(k))
	OW_ASSERT(dest != nil)
	s := ([^]f32)(src)
	d := ([^]f32)(dest)
	for i := 0; i < n_elems; i += 1 {
		d[i] = k + s[i]
	}
}

// Summary: Scales buffers by a scalar.
ow_buf_scale :: proc(src: ^f32, k: f32, dest: ^f32, n_elems: int) {
	OW_ASSERT(src != nil)
	OW_ASSERT(!ow_is_nan(k))
	OW_ASSERT(dest != nil)
	s := ([^]f32)(src)
	d := ([^]f32)(dest)
	for i := 0; i < n_elems; i += 1 {
		d[i] = k * s[i]
	}
}

// Summary: Adds buffers element-wise.
ow_buf_mix :: proc(src1: ^f32, src2: ^f32, dest: ^f32, n_elems: int) {
	OW_ASSERT(src1 != nil)
	OW_ASSERT(src2 != nil)
	OW_ASSERT(dest != nil)
	s1 := ([^]f32)(src1)
	s2 := ([^]f32)(src2)
	d := ([^]f32)(dest)
	for i := 0; i < n_elems; i += 1 {
		d[i] = s1[i] + s2[i]
	}
}

// Summary: Multiplies buffers element-wise.
ow_buf_mul :: proc(src1: ^f32, src2: ^f32, dest: ^f32, n_elems: int) {
	OW_ASSERT(src1 != nil)
	OW_ASSERT(src2 != nil)
	OW_ASSERT(dest != nil)
	s1 := ([^]f32)(src1)
	s2 := ([^]f32)(src2)
	d := ([^]f32)(dest)
	for i := 0; i < n_elems; i += 1 {
		d[i] = s1[i] * s2[i]
	}
}

// Summary: Executes buf fill multi.
ow_buf_fill_multi :: proc(k: f32, dest: ^^f32, n_channels: int, n_elems: int) {
	OW_ASSERT(dest != nil)
	dm := ([^][^]f32)(dest)
	for ch := 0; ch < n_channels; ch += 1 {
		ow_buf_fill(k, (^f32)(dm[ch]), n_elems)
	}
}

// Summary: Executes buf copy multi.
ow_buf_copy_multi :: proc(src: ^^f32, dest: ^^f32, n_channels: int, n_elems: int) {
	OW_ASSERT(src != nil)
	OW_ASSERT(dest != nil)
	sm := ([^][^]f32)(src)
	dm := ([^][^]f32)(dest)
	for ch := 0; ch < n_channels; ch += 1 {
		ow_buf_copy((^f32)(sm[ch]), (^f32)(dm[ch]), n_elems)
	}
}

// Summary: Executes buf neg multi.
ow_buf_neg_multi :: proc(src: ^^f32, dest: ^^f32, n_channels: int, n_elems: int) {
	OW_ASSERT(src != nil)
	OW_ASSERT(dest != nil)
	sm := ([^][^]f32)(src)
	dm := ([^][^]f32)(dest)
	for ch := 0; ch < n_channels; ch += 1 {
		ow_buf_neg((^f32)(sm[ch]), (^f32)(dm[ch]), n_elems)
	}
}

// Summary: Executes buf add multi.
ow_buf_add_multi :: proc(src: ^^f32, k: f32, dest: ^^f32, n_channels: int, n_elems: int) {
	OW_ASSERT(src != nil)
	OW_ASSERT(dest != nil)
	sm := ([^][^]f32)(src)
	dm := ([^][^]f32)(dest)
	for ch := 0; ch < n_channels; ch += 1 {
		ow_buf_add((^f32)(sm[ch]), k, (^f32)(dm[ch]), n_elems)
	}
}

// Summary: Executes buf scale multi.
ow_buf_scale_multi :: proc(src: ^^f32, k: f32, dest: ^^f32, n_channels: int, n_elems: int) {
	OW_ASSERT(src != nil)
	OW_ASSERT(dest != nil)
	sm := ([^][^]f32)(src)
	dm := ([^][^]f32)(dest)
	for ch := 0; ch < n_channels; ch += 1 {
		ow_buf_scale((^f32)(sm[ch]), k, (^f32)(dm[ch]), n_elems)
	}
}

// Summary: Executes buf mix multi.
ow_buf_mix_multi :: proc(src1: ^^f32, src2: ^^f32, dest: ^^f32, n_channels: int, n_elems: int) {
	OW_ASSERT(src1 != nil)
	OW_ASSERT(src2 != nil)
	OW_ASSERT(dest != nil)
	s1m := ([^][^]f32)(src1)
	s2m := ([^][^]f32)(src2)
	dm := ([^][^]f32)(dest)
	for ch := 0; ch < n_channels; ch += 1 {
		ow_buf_mix((^f32)(s1m[ch]), (^f32)(s2m[ch]), (^f32)(dm[ch]), n_elems)
	}
}

// Summary: Executes buf mul multi.
ow_buf_mul_multi :: proc(src1: ^^f32, src2: ^^f32, dest: ^^f32, n_channels: int, n_elems: int) {
	OW_ASSERT(src1 != nil)
	OW_ASSERT(src2 != nil)
	OW_ASSERT(dest != nil)
	s1m := ([^][^]f32)(src1)
	s2m := ([^][^]f32)(src2)
	dm := ([^][^]f32)(dest)
	for ch := 0; ch < n_channels; ch += 1 {
		ow_buf_mul((^f32)(s1m[ch]), (^f32)(s2m[ch]), (^f32)(dm[ch]), n_elems)
	}
}
