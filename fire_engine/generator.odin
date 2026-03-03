package fire_engine

Generator :: struct {
    getSample: proc(this: ^Generator, buffer: ^[2]f32, cursor: f32),
}

SampleGenerator :: struct {
    using generator: Generator,
    engine: ^AudioEngine,
    start_frame: i64,
    end_frame: i64,
    file_path: string,
    resource: ^WaveResource,
}

createSampleGenerator :: proc(engine: ^AudioEngine, file_path: string) -> ^SampleGenerator {
    sg := new(SampleGenerator)
    sg.engine = engine
    sg.file_path = file_path
    sg.resource = engine->loadWave(file_path)
    sg.getSample = sampleGeneratorGetSample
    return sg
}

// Gets sample data for the given cursor position and fills the buffer. Cursor is in frames, so it can be fractional for interpolation.
sampleGeneratorGetSample :: proc(this: ^Generator, buffer: ^[2]f32, cursor: f32) {
    this := cast(^SampleGenerator)this
    if this.engine->getWaveStatus(this.file_path) != .Ready {
        buffer[0] = 0
        buffer[1] = 0
		return
	}
    audio, ok := this.engine->getWaveAudio(this.file_path)
    audio = cast(^WaveAudio)audio
    if !ok || audio == nil || audio.frames <= 0 || len(audio.samples) == 0 {
        buffer[0] = 0
        buffer[1] = 0
        return
    }
    interpolateInterleavedSamples(audio, cursor, buffer)
    
}

interpolateInterleavedSamples :: proc(audio: ^WaveAudio, cursor: f32, buffer: ^[2]f32) {

    // interpolate between the two nearest frames for each channel. If source is mono, duplicate the value across channels.
    // Samples are interleaved, so for stereo: [L0, R0, L1, R1, ...]
    frame_index := i64(cursor)
    next_frame_index := (frame_index + 1) % i64(audio.frames)
    t := cursor - f32(frame_index)
    sample_count := int(audio.channels)
    out := [2]f32{0, 0}
    for channel in 0..<sample_count {
        sample1 := audio.samples[int(frame_index) * sample_count + channel]
        sample2 := audio.samples[int(next_frame_index) * sample_count + channel]
        interpolated_sample := (1.0 - t) * sample1 + t * sample2
        out[channel] = interpolated_sample
    }
    // If mono, duplicate to second channel
    if sample_count == 1 {
        out[1] = out[0]
    }

    buffer[0] = out[0]
    buffer[1] = out[1]
}