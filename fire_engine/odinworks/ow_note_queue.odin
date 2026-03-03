package odinworks

// Summary: Data structure for note queue status.
ow_note_queue_status :: struct {
	pressed: i8,
	velocity: f32,
}

// Summary: Data structure for note queue event.
ow_note_queue_event :: struct {
	note: u8,
	went_off: i8,
}

// Summary: Data structure for note queue.
ow_note_queue :: struct {
	events: [128]ow_note_queue_event,
	status: [128]ow_note_queue_status,
	n_events: u8,
	n_pressed: u8,
}

// Summary: Executes note queue reset.
ow_note_queue_reset :: proc(queue: ^ow_note_queue) {
	OW_ASSERT(queue != nil)
	for i := 0; i < 128; i += 1 {
		queue.status[i].pressed = 0
		queue.status[i].velocity = 0.0
	}
	queue.n_events = 0
	queue.n_pressed = 0
}

// Summary: Executes note queue clear.
ow_note_queue_clear :: proc(queue: ^ow_note_queue) {
	OW_ASSERT(queue != nil)
	queue.n_events = 0
}

// Summary: Executes note queue add.
ow_note_queue_add :: proc(queue: ^ow_note_queue, note: u8, pressed: i8, velocity: f32, force_went_off: i8) {
	OW_ASSERT(queue != nil)
	OW_ASSERT(note < 128)
	OW_ASSERT(ow_is_finite(velocity) && velocity <= 1.0)

	if pressed == 0 && queue.status[note].pressed == 0 {
		return
	}

	i := 0
	for ; i < int(queue.n_events); i += 1 {
		if queue.events[i].note == note {
			break
		}
	}

	went_off: i8 = 0
	if i == int(queue.n_events) {
		queue.n_events += 1
	} else {
		if queue.events[i].went_off != 0 || queue.status[note].pressed == 0 {
			went_off = 1
		}
	}

	queue.events[i].note = note
	if went_off != 0 || force_went_off != 0 {
		queue.events[i].went_off = 1
	} else {
		queue.events[i].went_off = 0
	}

	if pressed != 0 && queue.status[note].pressed == 0 {
		queue.n_pressed += 1
	} else if pressed == 0 && queue.status[note].pressed != 0 {
		queue.n_pressed -= 1
	}

	queue.status[note].pressed = pressed
	queue.status[note].velocity = velocity
}

// Summary: Executes note queue all notes off.
ow_note_queue_all_notes_off :: proc(queue: ^ow_note_queue, velocity: f32) {
	OW_ASSERT(queue != nil)
	OW_ASSERT(ow_is_finite(velocity) && velocity <= 1.0)
	for i: u8 = 0; i < 128; i += 1 {
		if queue.status[i].pressed != 0 {
			ow_note_queue_add(queue, i, 0, velocity, 0)
		}
	}
}

// Summary: Checks validity of note queue.
ow_note_queue_is_valid :: proc(queue: ^ow_note_queue) -> i8 {
	if queue == nil {
		return 0
	}
	if queue.n_events > 128 || queue.n_pressed > 128 {
		return 0
	}

	for i: u8 = 0; i < queue.n_events; i += 1 {
		ev := queue.events[i]
		if ev.note >= 128 {
			return 0
		}
		for j: u8 = 0; j < i; j += 1 {
			if queue.events[j].note == ev.note {
				return 0
			}
		}
	}

	cnt: u8 = 0
	for i := 0; i < 128; i += 1 {
		st := queue.status[i]
		if st.pressed != 0 {
			cnt += 1
		}
		if !ow_is_finite(st.velocity) || st.velocity > 1.0 {
			return 0
		}
	}

	if cnt != queue.n_pressed {
		return 0
	}
	return 1
}
