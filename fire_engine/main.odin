package main

import "core:fmt"
import "core:time"

BeatTriggerData :: struct {
	playhead: ^PlayheadNode,
	sample_node: ^AudioSampleNode,
}

main :: proc() {
	ae := createEngine(auto_start = true)
	defer ae->uninit()

	graph := createAudioGraph()
	defer graph->uninit()

	ae->attachAudioGraph(graph)

	sample_node := createAudioSampleNode(ae, "perc.wav", true, false)
	defer sample_node->releaseResource()
	sample_node->setRateFromMidiNote(60)
	sample_node->attachToGraph(graph)
	filter_node := createFilterNode(
		filter_type = .Highpass,
		cutoff_frequency_hz = 1200,
		resonance_q = 0.8,
		morph_parameter = 0.5,
		slope = .Db12,
	)
	filter_node->attachToGraph(graph)

	gain_node := createGainNode(initial_gain = 1)
	gain_node->attachToGraph(graph)
	lfo_node := createLFONode(
		wavetable_name = "sine",
		rate_mode = .Hz,
		rate_hz = 0.1,
		rate_beat_time = .N1_4,
		depth = 1,
		bias = 0.0,
		enabled = true,
		attack_time_seconds = 0,
		offset_normalized = 0.0,
		tempo_bpm = 120,
	)
	lfo_node->attachToGraph(graph)
	_ = graph->connectModulationInput(gain_node.node_id, 0, lfo_node.node_id, 0)

	pan_node := createPanNode(initial_pan = 0.0)
	pan_node->attachToGraph(graph)
	graph->queueConnect(sample_node.node_id, 0, filter_node.node_id, 0)
	graph->queueConnect(filter_node.node_id, 0, gain_node.node_id, 0)
	graph->queueConnect(gain_node.node_id, 0, pan_node.node_id, 0)
	graph->connectToEndpoint(pan_node.node_id)

	playhead := ae->getPlayhead()
    playhead->setTempo(140)
	if playhead != nil {
		beat_trigger := new(BeatTriggerData)
		beat_trigger.playhead = playhead
		beat_trigger.sample_node = sample_node

		signalConnect(playhead.onTick, proc(value: any, user_data: rawptr = nil) {
			trigger := cast(^BeatTriggerData)user_data
            tick_event := value.(TickEvent)
			if trigger == nil || trigger.playhead == nil || trigger.sample_node == nil {
				return
			}

			if trigger.playhead->isBeat() {
					trigger.sample_node->play(u32(tick_event.frame_offset))
			}
		}, cast(rawptr)beat_trigger)

		playhead->setState(.Playing)
	}

	fmt.println("fire_engine graph demo running (AudioSampleNode async playback from perc.wav).")
	fmt.println("Sample playback chain: AudioSampleNode -> FilterNode -> GainNode -> PanNode -> endpoint.")
	fmt.println("GainNode modulation: LFONode connected to modulation input 0.")
	fmt.println("FilterNode sweep test: lowpass cutoff sweeping between 200 Hz and 8 kHz.")
	fmt.println("Press Ctrl+C to quit.")

	for {

		time.sleep(100 * time.Millisecond)
	}
}
