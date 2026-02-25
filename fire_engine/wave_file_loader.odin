package main

import "core:math"
import "core:os"
import "core:strings"

WaveLoadError :: enum {
	None,
	InvalidExtension,
	IoFailure,
	InvalidHeader,
	MissingFmtChunk,
	MissingDataChunk,
	UnsupportedFormat,
	UnsupportedBitDepth,
	CorruptData,
}

WaveAudio :: struct {
	samples: []f32,
	channels: u16,
	sample_rate: u32,
	frames: int,
}

WavFmtChunk :: struct {
	audio_format: u16,
	channels: u16,
	sample_rate: u32,
	byte_rate: u32,
	block_align: u16,
	bits_per_sample: u16,
}

freeWaveAudio :: proc(audio: ^WaveAudio, allocator := context.allocator) {
	if len(audio.samples) > 0 {
		delete(audio.samples, allocator)
	}
	audio^ = WaveAudio{}
}

loadWaveFile :: proc(path: string, target_sample_rate: u32 = 0, allocator := context.allocator) -> (WaveAudio, WaveLoadError) {
	lower_path := strings.to_lower(path)
	if !strings.has_suffix(lower_path, ".wav") {
		return WaveAudio{}, .InvalidExtension
	}

	file_bytes, ok := os.read_entire_file(path, allocator)
	if !ok {
		return WaveAudio{}, .IoFailure
	}
	defer delete(file_bytes, allocator)

	return decodeWaveBytes(file_bytes, target_sample_rate, allocator)
}

decodeWaveBytes :: proc(bytes: []u8, target_sample_rate: u32 = 0, allocator := context.allocator) -> (WaveAudio, WaveLoadError) {
	if len(bytes) < 44 {
		return WaveAudio{}, .InvalidHeader
	}

	if string(bytes[0:4]) != "RIFF" || string(bytes[8:12]) != "WAVE" {
		return WaveAudio{}, .InvalidHeader
	}

	fmt_chunk := WavFmtChunk{}
	has_fmt := false
	data_chunk: []u8
	has_data := false

	cursor := 12
	for cursor+8 <= len(bytes) {
		chunk_id := string(bytes[cursor : cursor+4])
		chunk_size := int(readU32LE(bytes, cursor+4))
		data_start := cursor + 8
		data_end := data_start + chunk_size
		if data_end > len(bytes) {
			return WaveAudio{}, .CorruptData
		}

		if chunk_id == "fmt " {
			if chunk_size < 16 {
				return WaveAudio{}, .CorruptData
			}
			fmt_chunk.audio_format = readU16LE(bytes, data_start+0)
			fmt_chunk.channels = readU16LE(bytes, data_start+2)
			fmt_chunk.sample_rate = readU32LE(bytes, data_start+4)
			fmt_chunk.byte_rate = readU32LE(bytes, data_start+8)
			fmt_chunk.block_align = readU16LE(bytes, data_start+12)
			fmt_chunk.bits_per_sample = readU16LE(bytes, data_start+14)
			has_fmt = true
		} else if chunk_id == "data" {
			data_chunk = bytes[data_start:data_end]
			has_data = true
		}

		cursor = data_end
		if (chunk_size & 1) == 1 {
			cursor += 1
		}
	}

	if !has_fmt {
		return WaveAudio{}, .MissingFmtChunk
	}
	if !has_data {
		return WaveAudio{}, .MissingDataChunk
	}

	if fmt_chunk.audio_format != 1 {
		return WaveAudio{}, .UnsupportedFormat
	}
	if fmt_chunk.channels == 0 || fmt_chunk.sample_rate == 0 {
		return WaveAudio{}, .CorruptData
	}

	if fmt_chunk.bits_per_sample != 8 && fmt_chunk.bits_per_sample != 16 && fmt_chunk.bits_per_sample != 24 {
		return WaveAudio{}, .UnsupportedBitDepth
	}

	bytes_per_sample := int(fmt_chunk.bits_per_sample / 8)
	frame_stride := int(fmt_chunk.channels) * bytes_per_sample
	if frame_stride <= 0 || len(data_chunk)%frame_stride != 0 {
		return WaveAudio{}, .CorruptData
	}

	frame_count := len(data_chunk) / frame_stride
	decoded := make([]f32, frame_count*int(fmt_chunk.channels), allocator)

	src := 0
	dst := 0
	for _ in 0..<frame_count {
		for _ in 0..<int(fmt_chunk.channels) {
			decoded[dst] = decodeSampleToF32(data_chunk, src, fmt_chunk.bits_per_sample)
			src += bytes_per_sample
			dst += 1
		}
	}

	final_samples := decoded
	final_rate := fmt_chunk.sample_rate
	final_frames := frame_count

	if target_sample_rate > 0 && target_sample_rate != fmt_chunk.sample_rate {
		resampled := resampleInterleavedLinear(decoded, int(fmt_chunk.channels), fmt_chunk.sample_rate, target_sample_rate, allocator)
		delete(decoded, allocator)
		final_samples = resampled
		final_rate = target_sample_rate
		final_frames = len(final_samples) / int(fmt_chunk.channels)
	}

	return WaveAudio{
		samples = final_samples,
		channels = fmt_chunk.channels,
		sample_rate = final_rate,
		frames = final_frames,
	}, .None
}

decodeSampleToF32 :: proc(data: []u8, offset: int, bits_per_sample: u16) -> f32 {
	switch bits_per_sample {
	case 8:
		// WAV 8-bit PCM is unsigned.
		return (f32(data[offset]) - 128.0) / 128.0
	case 16:
		raw := readU16LE(data, offset)
		signed := cast(i16)raw
		return f32(signed) / 32768.0
	case 24:
		b0 := i32(data[offset+0])
		b1 := i32(data[offset+1])
		b2 := i32(data[offset+2])
		signed := (b0 | (b1 << 8) | (b2 << 16))
		if (signed & 0x00800000) != 0 {
			signed |= -16777216
		}
		return f32(signed) / 8388608.0
	}

	return 0
}

resampleInterleavedLinear :: proc(samples: []f32, channels: int, source_rate: u32, target_rate: u32, allocator := context.allocator) -> []f32 {
	source_frames := len(samples) / channels
	if source_frames == 0 {
		return make([]f32, 0, allocator)
	}

	target_frames_f := f64(source_frames) * f64(target_rate) / f64(source_rate)
	target_frames := int(math.max(1.0, math.floor(target_frames_f+0.5)))

	out := make([]f32, target_frames*channels, allocator)

	ratio := f64(source_rate) / f64(target_rate)
	for frame_index in 0..<target_frames {
		src_pos := f64(frame_index) * ratio
		left_frame := int(src_pos)
		if left_frame >= source_frames {
			left_frame = source_frames - 1
		}
		right_frame := left_frame + 1
		if right_frame >= source_frames {
			right_frame = source_frames - 1
		}

		frac := f32(src_pos - f64(left_frame))
		base_out := frame_index * channels
		base_left := left_frame * channels
		base_right := right_frame * channels

		for ch in 0..<channels {
			left := samples[base_left+ch]
			right := samples[base_right+ch]
			out[base_out+ch] = left + (right-left)*frac
		}
	}

	return out
}

readU16LE :: proc(data: []u8, offset: int) -> u16 {
	return u16(data[offset]) | (u16(data[offset+1]) << 8)
}

readU32LE :: proc(data: []u8, offset: int) -> u32 {
	return u32(data[offset]) |
		(u32(data[offset+1]) << 8) |
		(u32(data[offset+2]) << 16) |
		(u32(data[offset+3]) << 24)
}
