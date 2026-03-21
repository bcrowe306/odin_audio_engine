#+feature using-stmt
package main


import "core:fmt"
import app_framework "app_framework"
import vg "vendor:nanovg"
import clay "app_framework/clay-odin"
import fe "fire_engine"
import "core:log"

createHeaderSection :: proc(page: ^app_framework.Page)  {
    using clay

    if UI()({
                layout = {
                    layoutDirection = LayoutDirection.LeftToRight,
                    childAlignment = {x= LayoutAlignmentX.Center, y = LayoutAlignmentY.Center},
                    sizing = {width = SizingGrow(), height = SizingFixed(32)},
                    padding = {
                        left = 180,
                        right = 180,
                        top = 5,
                        bottom = 5,
                    }
                },
                backgroundColor = app_framework.hexToRGBA(BACKGROUND_COLOR),
               
            }) {
                // Track Select Button
                if UI ()({
                    layout = {
                        layoutDirection = LayoutDirection.LeftToRight,
                        childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Center},
                        sizing = {width = SizingGrow(), height = SizingGrow()},
                        padding = PaddingAll(0),
                        
                    },
                    custom = {customData = page.elements["track_select_button"]},
                }) { }

                // Device Button
                if UI ()({
                    layout = {
                        layoutDirection = LayoutDirection.LeftToRight,
                        childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Center},
                        sizing = {width = SizingGrow(), height = SizingGrow()},
                        padding = PaddingAll(0),
                        
                    },
                    custom = {customData = page.elements["device_button"]},
                }) { }

                // Sequence Number
                if UI ()({
                    layout = {
                        layoutDirection = LayoutDirection.LeftToRight,
                        childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Center},
                        sizing = {width = SizingGrow(), height = SizingGrow()},
                        padding = PaddingAll(0),
                        
                    },
                    custom = {customData = page.elements["sequence_number"]},
                }) { }

                // Song Position
                if UI ()({
                    layout = {
                        layoutDirection = LayoutDirection.LeftToRight,
                        childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Center},
                        sizing = {width = SizingGrow(), height = SizingGrow()},
                        padding = PaddingAll(0),
                        
                    },
                    custom = {customData = page.elements["song_position"]},
                }) { }

                // Tempo Button
                if UI ()({
                    layout = {
                        layoutDirection = LayoutDirection.LeftToRight,
                        childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Center},
                        sizing = {width = SizingGrow(), height = SizingGrow()},
                        padding = PaddingAll(0),
                        
                    },
                    custom = {customData = page.elements["tempo_select_button"]},
                }) { }

                // Metronome Button
                if UI ()({
                    layout = {
                        layoutDirection = LayoutDirection.LeftToRight,
                        childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Center},
                        sizing = {width = SizingGrow(), height = SizingGrow()},
                        padding = PaddingAll(0),
                        
                    },
                    custom = {customData = page.elements["metronome_button"]},
                }) { }
                
            }

    

}