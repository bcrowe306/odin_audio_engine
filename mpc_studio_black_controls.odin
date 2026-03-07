package main

import fire_engine "fire_engine"

MPCStudioBlackControls :: struct {
    playButton: ^OneColorButton,
    stopButton: ^fire_engine.ButtonControl,
    recordButton: ^OneColorButton,
    overdubButton: ^OneColorButton,
    stepRightButton: ^fire_engine.ButtonControl,
    stepLeftButton: ^fire_engine.ButtonControl,
    gotoButton: ^fire_engine.ButtonControl,
    barLeftButton: ^fire_engine.ButtonControl,
    barRightButton: ^fire_engine.ButtonControl,
    tapTempoButton: OneColorButton,
    leftButton: ^fire_engine.ButtonControl,
    rightButton: ^fire_engine.ButtonControl,
    upButton: ^fire_engine.ButtonControl,
    downButton: ^fire_engine.ButtonControl,
    undoButton: ^OneColorButton,
    shiftButton: ^fire_engine.ButtonControl,
    minusButton: ^fire_engine.ButtonControl,
    plusButton: ^fire_engine.ButtonControl,
    windowButton: ^OneColorButton,
    mainButton: ^OneColorButton,
    browserButton: ^OneColorButton,
    numericButton: ^fire_engine.ButtonControl,
    projectButton: ^OneColorButton,
    seqButton: ^OneColorButton,
    progButton: ^OneColorButton,
    sampleButton: ^OneColorButton,
    noFilterButton: ^OneColorButton,
    progEditButton: ^TwoColorButton,
    progMixButton: ^TwoColorButton,
    seqEditButton: ^TwoColorButton,
    sampleEditButton: ^TwoColorButton,
    songButton: ^TwoColorButton,
    fullLevelButton: ^OneColorButton,
    sixteenLevelButton: ^OneColorButton,
    stepSeqButton: ^OneColorButton,
    nextSeqButton: ^OneColorButton,
    trackMuteButton: ^TwoColorButton,
    padBankAButton: ^TwoColorButton,
    padBankBButton: ^TwoColorButton,
    padBankCButton: ^TwoColorButton,
    padBankDButton: ^TwoColorButton,
    padAssignButton: ^OneColorButton,
    f1Button: ^OneColorButton,
    f2Button: ^OneColorButton,
    f3Button: ^OneColorButton,
    f4Button: ^OneColorButton,
    f5Button: ^OneColorButton,
    f6Button: ^OneColorButton,
    qlink1: ^fire_engine.TouchEncoderControl,
    qlink2: ^fire_engine.TouchEncoderControl,
    qlink3: ^fire_engine.TouchEncoderControl,
    qlink4: ^fire_engine.TouchEncoderControl,
    qlinkScroll: ^fire_engine.EncoderControl,
    jogWheel: ^fire_engine.EncoderControl,
    qlinkTriggerButton: ^OneColorButton,
    eraseButton: ^fire_engine.ButtonControl,
    noteRepeatButton: ^fire_engine.ButtonControl,
}

createMPCStudioBlackControls :: proc(cs: ^fire_engine.ControlSurface) {
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("playStartButton", 0, u8(MPCSB_CONTROL.PLAY_START_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("playButton", u8(MPCSB_CONTROL.PLAY_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("stopButton", 0, u8(MPCSB_CONTROL.STOP_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("recordButton", u8(MPCSB_CONTROL.REC_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("overdubButton", u8(MPCSB_CONTROL.OVERDUB_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("stepRightButton", 0, u8(MPCSB_CONTROL.STEP_RIGHT_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("stepLeftButton", 0, u8(MPCSB_CONTROL.STEP_LEFT_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("gotoButton", 0, u8(MPCSB_CONTROL.GOTO_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("barLeftButton", 0, u8(MPCSB_CONTROL.BAR_LEFT_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("barRightButton", 0, u8(MPCSB_CONTROL.BAR_RIGHT_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("tapTempoButton", u8(MPCSB_CONTROL.TAP_TEMPO_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("leftButton", 0, u8(MPCSB_CONTROL.LEFT_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("rightButton", 0, u8(MPCSB_CONTROL.RIGHT_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("upButton", 0, u8(MPCSB_CONTROL.UP_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("downButton", 0, u8(MPCSB_CONTROL.DOWN_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("undoButton", u8(MPCSB_CONTROL.UNDO_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("shiftButton", 0, u8(MPCSB_CONTROL.SHIFT_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("minusButton", 0, u8(MPCSB_CONTROL.MINUS_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("plusButton", 0, u8(MPCSB_CONTROL.PLUS_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("windowButton", u8(MPCSB_CONTROL.WINDOW_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("mainButton", u8(MPCSB_CONTROL.MAIN_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("browserButton", u8(MPCSB_CONTROL.BROWSER_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("numericButton", 0, u8(MPCSB_CONTROL.NUMERIC_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("projectButton", u8(MPCSB_CONTROL.PROJECT_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("seqButton", u8(MPCSB_CONTROL.SEQ_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("progButton", u8(MPCSB_CONTROL.PROG_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("sampleButton", u8(MPCSB_CONTROL.SAMPLE_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("noFilterButton", u8(MPCSB_CONTROL.NO_FILTER_BUTTON)))
    cs->addControl(cast(^TwoColorButton)createTwoColorButton("progEditButton", u8(MPCSB_CONTROL.PROG_EDIT_BUTTON)))
    cs->addControl(cast(^TwoColorButton)createTwoColorButton("progMixButton", u8(MPCSB_CONTROL.PROG_MIX_BUTTON)))
    cs->addControl(cast(^TwoColorButton)createTwoColorButton("seqEditButton", u8(MPCSB_CONTROL.SEQ_EDIT_BUTTON)))
    cs->addControl(cast(^TwoColorButton)createTwoColorButton("sampleEditButton", u8(MPCSB_CONTROL.SAMPLE_EDIT_BUTTON)))
    cs->addControl(cast(^TwoColorButton)createTwoColorButton("songButton", u8(MPCSB_CONTROL.SONG_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("fullLevelButton", u8(MPCSB_CONTROL.FULL_LEVEL_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("sixteenLevelButton", u8(MPCSB_CONTROL.SIXTEEN_LEVEL_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("stepSeqButton", u8(MPCSB_CONTROL.STEP_SEQ_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("nextSeqButton", u8(MPCSB_CONTROL.NEXT_SEQ_BUTTON)))
    cs->addControl(cast(^TwoColorButton)createTwoColorButton("trackMuteButton", u8(MPCSB_CONTROL.TRACK_MUTE_BUTTON)))
    cs->addControl(cast(^TwoColorButton)createTwoColorButton("padBankAButton", u8(MPCSB_CONTROL.PAD_BANK_A_BUTTON)))
    cs->addControl(cast(^TwoColorButton)createTwoColorButton("padBankBButton", u8(MPCSB_CONTROL.PAD_BANK_B_BUTTON)))
    cs->addControl(cast(^TwoColorButton)createTwoColorButton("padBankCButton", u8(MPCSB_CONTROL.PAD_BANK_C_BUTTON)))
    cs->addControl(cast(^TwoColorButton)createTwoColorButton("padBankDButton", u8(MPCSB_CONTROL.PAD_BANK_D_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("padAssignButton", u8(MPCSB_CONTROL.PAD_ASSIGN_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("f1Button", u8(MPCSB_CONTROL.F1_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("f2Button", u8(MPCSB_CONTROL.F2_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("f3Button", u8(MPCSB_CONTROL.F3_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("f4Button", u8(MPCSB_CONTROL.F4_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("f5Button", u8(MPCSB_CONTROL.F5_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("f6Button", u8(MPCSB_CONTROL.F6_BUTTON)))
    cs->addControl(cast(^OneColorButton)createOneColorButton("eraseButton", u8(MPCSB_CONTROL.ERASE_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("qlinkTriggerButton", 0, u8(MPCSB_CONTROL.QLINK_TRIGGER_BUTTON)))
    cs->addControl(cast(^fire_engine.ButtonControl)fire_engine.createButtonControl("noteRepeatButton", 0, u8(MPCSB_CONTROL.NOTE_REPEAT_BUTTON)))
    cs->addControl(fire_engine.createTouchEncoderControl("qlink1", 0, u8(MPCSB_CONTROL.QLINK_1), u8(MPCSB_CONTROL.QLINK_1_TOUCH) ) )
    cs->addControl(fire_engine.createTouchEncoderControl("qlink2", 0, u8(MPCSB_CONTROL.QLINK_2), u8(MPCSB_CONTROL.QLINK_2_TOUCH) ) )
    cs->addControl(fire_engine.createTouchEncoderControl("qlink3", 0, u8(MPCSB_CONTROL.QLINK_3), u8(MPCSB_CONTROL.QLINK_3_TOUCH) ) )
    cs->addControl(fire_engine.createTouchEncoderControl("qlink4", 0, u8(MPCSB_CONTROL.QLINK_4), u8(MPCSB_CONTROL.QLINK_4_TOUCH) ) )
    cs->addControl(fire_engine.createEncoderControl("qlinkScroll", 0, u8(MPCSB_CONTROL.QLINK_SCROLL)))
    cs->addControl(cast(^fire_engine.EncoderControl)fire_engine.createEncoderControl("jogWheel", 0, u8(MPCSB_CONTROL.JOG_WHEEL)))

    padModesComponent := fire_engine.createComponent("padModesComponent")
    padModesComponent->addControl(cs->getControl("padBankAButton"))
    padModesComponent->addControl(cs->getControl("padBankBButton"))
    padModesComponent->addControl(cs->getControl("padBankCButton"))
    padModesComponent->addControl(cs->getControl("padBankDButton"))
    padModesComponent.onActivate = proc(component_ptr: rawptr) {
        component := cast(^fire_engine.Component)component_ptr
        fe := component.fe
        padBankAButton := cast(^TwoColorButton)component.controls["padBankAButton"]
        padBankBButton := cast(^TwoColorButton)component.controls["padBankBButton"]
        padBankCButton := cast(^TwoColorButton)component.controls["padBankCButton"]
        padBankDButton := cast(^TwoColorButton)component.controls["padBankDButton"]

        padBankAButton->sendColor(.Primary)
        padBankBButton->sendColor(.Primary)
        padBankCButton->sendColor(.Primary)
        padBankDButton->sendColor(.Primary)
    }

    transportComponent := fire_engine.createComponent("transportComponent")
    transportComponent->addControl(cs->getControl("playButton"))
    transportComponent->addControl(cs->getControl("recordButton"))
    transportComponent->addControl(cs->getControl("overdubButton"))
    transportComponent->addControl(cs->getControl("stopButton"))
    transportComponent->addControl(cs->getControl("playStartButton"))
    transportComponent.onActivate = proc(component_ptr: rawptr) {
        component := cast(^fire_engine.Component)component_ptr
        fe := component.fe
        playButton := cast(^OneColorButton)component.controls["playButton"]
        stopButton := cast(^fire_engine.ButtonControl)component.controls["stopButton"]
        component->addConnection(playButton.onPress, proc(value: any, user_data: rawptr) {
            comp := cast(^fire_engine.Component)user_data
            fe := comp.fe
            fe.transport->togglePlay()
        })

        component->addConnection(stopButton.onPress, proc(value: any, user_data: rawptr){
            comp := cast(^fire_engine.Component)user_data
            fe := comp.fe
            fe.transport->stop()
        })

        component->addConnection(fe.audio_engine.playhead.onStateChange, proc(value: any, user_data: rawptr) {
            comp := cast(^fire_engine.Component)user_data
            fe := comp.fe
            value := value.(fire_engine.PlayheadState)
            playButton := cast(^OneColorButton)comp.controls["playButton"]
            if value == .Playing{
                playButton->sendColor(.On)
            } else {
                playButton->sendColor(.Off)
            }
        })
    }

    trans_mode := fire_engine.createMode("trans_mode")
    trans_mode->addComponent(transportComponent)
    pads_mode := fire_engine.createMode("pads_mode")
    pads_mode->addComponent(padModesComponent)
    modescomp := fire_engine.createModesComponent("testMode", "pads_mode")
    modescomp->addModes(trans_mode, pads_mode)
    modescomp->addControl(cs->getControl("projectButton"))
    modescomp->addControl(cs->getControl("seqButton"))

    modescomp.onActivate = proc(component_ptr: rawptr) {
        component := cast(^fire_engine.ModesComponent)component_ptr
        fe := component.fe
        projectButton := cast(^OneColorButton)component.controls["projectButton"]
        seqButton := cast(^OneColorButton)component.controls["seqButton"]

        component->addConnection(projectButton.onPress, proc(value: any, user_data: rawptr) {
            mc := cast(^fire_engine.ModesComponent)user_data
            mc->switchMode("pads_mode")
        })
        component->addConnection(seqButton.onPress, proc(value: any, user_data: rawptr) {
            mc := cast(^fire_engine.ModesComponent)user_data
            mc->switchMode("trans_mode")
        })
        
        component->addConnection(component.onModeChange, proc(value: any, user_data: rawptr) {
            mc := cast(^fire_engine.ModesComponent)user_data
            projectButton := cast(^OneColorButton)mc.controls["projectButton"]
            seqButton := cast(^OneColorButton)mc.controls["seqButton"]
            mode_name := value.(string)
            if mode_name == "pads_mode" {
                projectButton->sendColor(.On)
                seqButton->sendColor(.Off)
            } else if mode_name == "trans_mode" {
                projectButton->sendColor(.Off)
                seqButton->sendColor(.On)
            }
        })
        if component.current_mode == "pads_mode" {
            projectButton->sendColor(.On)
            seqButton->sendColor(.Off)
        } else if component.current_mode == "trans_mode" {
            projectButton->sendColor(.Off)
            seqButton->sendColor(.On)
        }

    }

    cs->addComponent(modescomp)
}

