package fire_engine
import "core:fmt"
import "core:time"

BeatTriggerData :: struct {
	playhead: ^PlayheadNode,
	sample_node: ^AudioSampleNode,
}

main :: proc() {
	fe := createFireEngine()
	fe.midi_engine.debug = true
	fe.audio_engine->setMultithreadedGraph(false)
	fe->init()
	fe->start()
	defer fe->uninit()


	sample_node := createAudioSampleNode(fe.audio_engine, "prec.wav", true, false)
	defer sample_node->releaseResource()
	sample_node->setRateFromMidiNote(60)
	sample_node->attachToGraph(fe.audio_engine.audio_graph)
	fe.audio_engine.audio_graph->connectToEndpoint(sample_node.node_id)

	playhead := fe.audio_engine->getPlayhead()
    playhead->setTempo(140)
	if playhead != nil {
		// beat_trigger := new(BeatTriggerData)
		// beat_trigger.playhead = playhead
		// beat_trigger.sample_node = sample_node

		// signalConnect(playhead.onTick, proc(value: any, user_data: rawptr = nil) {
		// 	trigger := cast(^BeatTriggerData)user_data
        //     tick_event := value.(TickEvent)
		// 	if trigger == nil || trigger.playhead == nil || trigger.sample_node == nil {
		// 		return
		// 	}

		// 	if trigger.playhead->isBeat() {
		// 			trigger.sample_node->play(u32(tick_event.frame_offset))
		// 	}
		// }, cast(rawptr)beat_trigger)

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
