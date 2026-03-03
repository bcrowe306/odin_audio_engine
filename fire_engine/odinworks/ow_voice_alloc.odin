package odinworks

// Summary: Enumeration for voice alloc priority.
ow_voice_alloc_priority :: enum {
	ow_voice_alloc_priority_low,
	ow_voice_alloc_priority_high,
}

// Summary: Data structure for voice alloc opts.
ow_voice_alloc_opts :: struct {
	priority: ow_voice_alloc_priority,
	note_on: proc(voice: rawptr, note: u8, velocity: f32),
	note_off: proc(voice: rawptr, velocity: f32),
	get_note: proc(voice: rawptr) -> u8,
	is_free: proc(voice: rawptr) -> i8,
}

// Summary: Executes voice alloc.
ow_voice_alloc :: proc(opts: ^ow_voice_alloc_opts, queue: ^ow_note_queue, voices: ^rawptr, n_voices: int) {
	OW_ASSERT(opts != nil)
	OW_ASSERT(opts.priority == .ow_voice_alloc_priority_low || opts.priority == .ow_voice_alloc_priority_high)
	OW_ASSERT(queue != nil)
	OW_ASSERT(ow_note_queue_is_valid(queue) != 0)
	if n_voices > 0 {
		OW_ASSERT(voices != nil)
		OW_ASSERT(opts.note_on != nil)
		OW_ASSERT(opts.note_off != nil)
		OW_ASSERT(opts.get_note != nil)
		OW_ASSERT(opts.is_free != nil)
	}

	voices_arr := ([^]rawptr)(voices)

	for i: u8 = 0; i < queue.n_events; i += 1 {
		ev := &queue.events[i]
		st := &queue.status[ev.note]
		handled := false

		for j := 0; j < n_voices; j += 1 {
			if opts.is_free(voices_arr[j]) == 0 && opts.get_note(voices_arr[j]) == ev.note {
				if st.pressed == 0 || ev.went_off != 0 {
					opts.note_off(voices_arr[j], st.velocity)
				}
				if st.pressed != 0 {
					opts.note_on(voices_arr[j], ev.note, st.velocity)
				}
				handled = true
				break
			}
		}

		if handled || st.pressed == 0 {
			continue
		}

		for j := 0; j < n_voices; j += 1 {
			if opts.is_free(voices_arr[j]) != 0 {
				opts.note_on(voices_arr[j], ev.note, st.velocity)
				handled = true
				break
			}
		}
		if handled {
			continue
		}

		k := n_voices
		v := ev.note
		for j := 0; j < n_voices; j += 1 {
			n := opts.get_note(voices_arr[j])
			if queue.status[n].pressed == 0 {
				if k == n_voices || ((opts.priority == .ow_voice_alloc_priority_low && n > v) || (opts.priority == .ow_voice_alloc_priority_high && n < v)) {
					v = n
					k = j
				}
			}
		}

		if k == n_voices {
			for j := 0; j < n_voices; j += 1 {
				n := opts.get_note(voices_arr[j])
				if (opts.priority == .ow_voice_alloc_priority_low && n > v) || (opts.priority == .ow_voice_alloc_priority_high && n < v) {
					v = n
					k = j
				}
			}
		}

		if k != n_voices {
			opts.note_on(voices_arr[k], ev.note, st.velocity)
		}
	}
}
