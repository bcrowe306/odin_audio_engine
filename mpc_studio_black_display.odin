package main

import fe "fire_engine"
import cairo "cairo"

MPCSB_Display :: struct {
    width: i32,
    height: i32,
    control_surface: ^fe.ControlSurface,
    cairo_surface: ^cairo.surface_t,
    size: [2]i32,
    cairo_context: ^cairo.context_t,
    cairo_format: cairo.format_t,
}







sendLine :: proc(mpc: ^MPCSB_Display, x_pos, y_pos: i32, lineData: []u8) {
    // Construct and send a SysEx message for the line data
    pixel_count := fe.toMsbLsbArr(u16(len(lineData) * 3)) // Each byte represents 3 pixels
    x := fe.toMsbLsbArr(u16(x_pos))
    y := fe.toMsbLsbArr(u16(y_pos))
    payload := make([]u8, len(pixel_count) + len(x) + len(y) + len(lineData))
    copy(payload, pixel_count[:])
    copy(payload[len(pixel_count):], x[:])
    copy(payload[len(pixel_count) + len(x):], y[:])
    copy(payload[len(pixel_count) + len(x) + len(y):], lineData[:])

    mpc->control_surface->sendSysex(payload)
}

renderElement :: proc(element_ptr: rawptr, surface: ^cairo.surface_t, render_user_data: rawptr) {
    element := cast(^graphics.Element)element_ptr
    if !element.changed {
        // fmt.printf("Element: %s has not changed, skipping render\n", element.type)
        return
    }
    mpc := cast(^MPC_Studio_Black)render_user_data
    xPos := i32(element.bounds.x) - 1
    yPos := i32(element.bounds.y) - 1
    width := i32(element.bounds.width)
    height := i32(element.bounds.height)
    xPos = clamp(xPos, 0, MPC_SCREEN_WIDTH - 1)
    yPos = clamp(yPos, 0, MPC_SCREEN_HEIGHT - 1)

    // fmt.printf("Bounds: x=%d, y=%d, width=%d, height=%d\n", xPos, yPos, width, height)


    format := cairo.image_surface_get_format(surface)
    bytes_per_pixel := cairo.format_stride_for_width(format, 1)
    stride := cairo.image_surface_get_stride(surface)
    data := cairo.image_surface_get_data(surface)
    y_end := yPos + height
    x_end := xPos + width

    for y :i32 = 0; y + yPos <= y_end; y += 1 {
        line_byte_counter := 0
        final_x_val: i32 = 0
        for x :i32 = 0; x + xPos <= x_end + 1; x += 1 {
            
            offset := (y + yPos ) * stride + ((x + xPos) * bytes_per_pixel)
           
            if mpc->isPixelOn(data[offset + 3], data[offset + 2], data[offset + 1], data[offset + 0], 128) {
                mpc.line_bytes[x / MPC_BIT_STRIDE] |= MPC_SCREEN_BYTE_MAP[x % MPC_BIT_STRIDE]
            } else {
                mpc.line_bytes[x / MPC_BIT_STRIDE] |= 0x00
            }
            if x % MPC_BIT_STRIDE == 0 && x != 0 {
                line_byte_counter += 1
            }
            final_x_val = x
            
        }
        // Handle case where line width is not perfectly divisible by MPC_BIT_STRIDE
        if final_x_val % MPC_BIT_STRIDE > 0 {
            line_byte_counter += 1
        }

        // Send the line data to the MPC via sysex
        mpc->sendLine(xPos, y + yPos, mpc.line_bytes[:line_byte_counter])

        // Debug: Print line byte data before sending
        // debugLineData(mpc.line_bytes[:line_byte_counter], line_byte_counter)

        // Clear line bytes for next line
        mem.set(&mpc.line_bytes, 0, int(MPC_LINE_STRIDE)) // Clear line bytes for next line
        
    }
    element.changed = false
}