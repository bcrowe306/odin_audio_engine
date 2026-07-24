package main

import fe "fire_engine"
import cairo "cairo"
import "core:fmt"
import "core:mem"

MPCSB_Display :: struct {
    width: i32,
    height: i32,
    control_surface: ^fe.ControlSurface,
    cairo_surface: ^cairo.surface_t,
    backgound_color: cairo.Color,
    size: [2]i32,
    cairo_context: ^cairo.context_t,
    cairo_format: cairo.format_t,
    router: ^MPCSB_Router,
    sendLine: proc(mpc: ^MPCSB_Display, x_pos, y_pos: i32, lineData: []u8),
    renderElement: proc(display: ^MPCSB_Display, element_ptr: ^MPCSB_Element),
    line_bytes: [MPC_LINE_STRIDE]u8,
    isPixelOn: proc(r, g, b, a: u8, threshold: u8) -> bool,
    draw: proc(display: ^MPCSB_Display),
    addPage: proc(display: ^MPCSB_Display, name: string, page: ^MPCSB_Page),
}

MPCSB_Display_create :: proc(control_surface: ^fe.ControlSurface) -> ^MPCSB_Display {
    display := new(MPCSB_Display)
    display.width = MPC_SCREEN_WIDTH
    display.height = MPC_SCREEN_HEIGHT
    display.size = [2]i32{display.width, display.height}
    display.control_surface = control_surface
    display.cairo_format = cairo.format_t.ARGB32
    display.backgound_color = cairo.BLACK
    display.cairo_surface = cairo.image_surface_create(display.cairo_format, display.width, display.height)
    display.cairo_context = cairo.create(display.cairo_surface)
    cairo.SetupAntialiasing(display.cairo_context)
    display.sendLine = sendLine
    display.renderElement = renderElement
    display.isPixelOn = isPixelOn
    display.router = MPCSB_Router_create(nil) // Initialize the router with no default page
    display.addPage = MPCSB_Display_addPage
    display.draw = MPCSB_Display_draw
    return display
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

    msg := generateMPCSysexCommand(MPC_STUDIO_BLACK_COMMANDS.UPDATE_DISPLAY, payload)
    mpc->control_surface->sendSysex(msg)
}

renderElement :: proc(display: ^MPCSB_Display, element: ^MPCSB_Element) {
    xPos := i32(element.bounds.x)
    yPos := i32(element.bounds.y)
    width := i32(element.bounds.width)
    height := i32(element.bounds.height)

    // fmt.printf("Bounds: x=%d, y=%d, width=%d, height=%d\n", xPos, yPos, width, height)


    format := cairo.image_surface_get_format(display.cairo_surface)
    bytes_per_pixel := cairo.format_stride_for_width(format, 1)
    stride := cairo.image_surface_get_stride(display.cairo_surface)
    data := cairo.image_surface_get_data(display.cairo_surface)
    y_end := yPos + height
    x_end := xPos + width

    for y :i32 = 0; y + yPos < y_end; y += 1 {
        line_byte_counter := 0
        final_x_val: i32 = 0
        for x :i32 = 0; x + xPos < x_end; x += 1 {
            
            offset := (y + yPos ) * stride + ((x + xPos) * bytes_per_pixel)
           
            if isPixelOn(data[offset + 3], data[offset + 2], data[offset + 1], data[offset + 0], 1) {
                display.line_bytes[x / MPC_BIT_STRIDE] |= MPC_SCREEN_BYTE_MAP[x % MPC_BIT_STRIDE]
            } else {
                display.line_bytes[x / MPC_BIT_STRIDE] |= 0x00
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
        display->sendLine(xPos, y + yPos, display.line_bytes[:line_byte_counter])

        // Debug: Print line byte data before sending
        // debugLineData(display.line_bytes[:line_byte_counter], line_byte_counter)

        // Clear line bytes for next line
        mem.set(&display.line_bytes, 0, int(MPC_LINE_STRIDE)) // Clear line bytes for next line
        
    }
    element.changed = false
}

isPixelOn :: proc(a,r,g,b, threshold: u8) -> bool {
    return r > threshold || g > threshold || b > threshold
}

MPCSB_Display_draw :: proc(display: ^MPCSB_Display) {
    // Clear the display surface with the background color
    cairo.set_source_rgba(display.cairo_context, display.backgound_color.r, display.backgound_color.g, display.backgound_color.b, display.backgound_color.a)
    cairo.paint(display.cairo_context)

    display.router->draw(display.cairo_context)
    if display.router.current_page != nil {
        for element in display.router.current_page.elements {
            if element.changed {
                display->renderElement(element)
            }
        }
    }
}

MPCSB_Display_addPage :: proc(display: ^MPCSB_Display, name: string, page: ^MPCSB_Page) {
    page.control_surface = display.control_surface
    display.router->addPage(name, page)
}


debugLineData :: proc(lineData: []u8, length: int) {
    line_byte_string := ""
    for i in 0..<length {
        line_byte_string = fmt.tprintf(line_byte_string, "%02X ", lineData[i])
    }
    fmt.printfln("Line Data: %s", line_byte_string)
}
