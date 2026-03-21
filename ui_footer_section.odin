#+feature using-stmt
package main


import "core:fmt"
import app_framework "app_framework"
import vg "vendor:nanovg"
import clay "app_framework/clay-odin"
import fe "fire_engine"
import "core:log"

createFooterSection :: proc(page: ^app_framework.Page)  {
    using clay

    if UI()({
                layout = {
                    layoutDirection = LayoutDirection.LeftToRight,
                    childAlignment = {x= LayoutAlignmentX.Center, y = LayoutAlignmentY.Center},
                    sizing = {width = SizingGrow(), height = SizingFixed(32)},
                    padding = {
                        left = 360,
                        right = 360,
                    }
                },
                backgroundColor = app_framework.hexToRGBA(BACKGROUND_COLOR),
               
            }) {
                // Footer content could go here

                // Play Button
                if UI ()({
                    layout = {
                        layoutDirection = LayoutDirection.LeftToRight,
                        childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Center},
                        sizing = {width = SizingGrow(), height = SizingGrow()},
                        padding = PaddingAll(0),
                        
                    },
                    custom = {customData = page.elements["play_button"]},
                }) { }

                // Stop Button
                if UI ()({
                    layout = {
                        layoutDirection = LayoutDirection.LeftToRight,
                        childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Center},
                        sizing = {width = SizingGrow(), height = SizingGrow()},
                        padding = PaddingAll(0),
                        
                    },
                    custom = {customData = page.elements["stop_button"]},
                }) { }

                // Pause Button
                if UI ()({
                    layout = {
                        layoutDirection = LayoutDirection.LeftToRight,
                        childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Center},
                        sizing = {width = SizingGrow(), height = SizingGrow()},
                        padding = PaddingAll(0),
                        
                    },
                    custom = {customData = page.elements["pause_button"]},
                }) { }

                // Record Button
                if UI ()({
                    layout = {
                        layoutDirection = LayoutDirection.LeftToRight,
                        childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Center},
                        sizing = {width = SizingGrow(), height = SizingGrow()},
                        padding = PaddingAll(0),
                        
                    },
                    custom = {customData = page.elements["record_button"]},
                }) { }

                // Loop Button
                if UI ()({
                    layout = {
                        layoutDirection = LayoutDirection.LeftToRight,
                        childAlignment = {x= LayoutAlignmentX.Left, y = LayoutAlignmentY.Center},
                        sizing = {width = SizingGrow(), height = SizingGrow()},
                        padding = PaddingAll(0),
                        
                    },
                    custom = {customData = page.elements["loop_button"]},
                }) { }
                
            }

    

}