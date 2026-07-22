package main

import cairo "cairo"
import fmt "core:fmt"
import math "core:math"

MPCSB_Element :: struct {
    changed: bool,
    draw: proc(element_ptr: ^MPCSB_Element, cairo_context: ^cairo.context_t),
    bounds: cairo.rectangle_t,
    visible: bool,
    fg_color: cairo.Color,
    bg_color: cairo.Color,
    setBounds: proc(element: ^MPCSB_Element, bounds: cairo.rectangle_t),
    setVisible: proc(element: ^MPCSB_Element, visible: bool),
    clear: proc(element: ^MPCSB_Element, cairo_context: ^cairo.context_t),
    data: rawptr,
    
}

MPCSB_Element_create :: proc( bounds: cairo.rectangle_t, visible: bool = true) -> ^MPCSB_Element {
    element := new(MPCSB_Element)
    element.draw = MPCSB_Element_draw_default
    element.bounds = bounds
    element.visible = visible
    element.fg_color = cairo.WHITE
    element.bg_color = cairo.BLACK
    element.setBounds = MPCSB_Element_setBounds
    element.setVisible = MPCSB_Element_setVisible
    element.clear = MPCSB_Element_clear
    element.data = nil
    element.changed = true
    return element
}


MPCSB_Element_draw_default :: proc(element: ^MPCSB_Element, cairo_context: ^cairo.context_t) {
}

MPCSB_Element_setBounds :: proc(element: ^MPCSB_Element, bounds: cairo.rectangle_t) {
    element.bounds = bounds
    element.changed = true
}

MPCSB_Element_setVisible :: proc(element: ^MPCSB_Element, visible: bool) {
    element.visible = visible
    element.changed = true
}

MPCSB_Element_clear :: proc(element: ^MPCSB_Element, cairo_context: ^cairo.context_t) {
    cairo.set_source_rgba(cairo_context, 0.0, 0.0, 0.0, 1.0) // Set color to black
    cairo.rectangle(cairo_context, element.bounds.x, element.bounds.y, element.bounds.width, element.bounds.height) // Define the rectangle area
    cairo.fill(cairo_context) // Fill the rectangle with the current color
}


FunctionButtonDef :: struct {
    label: string,
    selected: bool,
    font_size: f64,
    radius: f64,
}

FunctionButtonElement_create :: proc(x, y, width, height: f64, label: string, selected: bool = false) -> ^MPCSB_Element {
    bounds := cairo.rectangle_t { x= x, y= y, width= width, height= height }
    element := MPCSB_Element_create(bounds, true)
    button_def := new(FunctionButtonDef)
    button_def.label = label
    button_def.selected = selected
    button_def.font_size = 9.0
    button_def.radius = 5.0
    element.data = button_def
    element.draw = proc (element: ^MPCSB_Element, cairo_context: ^cairo.context_t) {
        button_def := cast(^FunctionButtonDef)element.data
        text_color := element.fg_color
        fill_color := element.bg_color

        if button_def.selected {
            text_color = element.bg_color
        }
        cairo.draw_top_rounded_rectangle(cairo_context, element.bounds.x, element.bounds.y, element.bounds.width, element.bounds.height, button_def.radius, button_def.selected, element.fg_color)
        // draw_text(cairo_context, button_def.label, element.padding_x, 5, element.font_size, text_color)
        cairo.draw_text_centered(cairo_context, button_def.label, element.bounds, button_def.font_size, text_color)
    }
    return element
}

FunctionButtonElement_setSelected :: proc(element: ^MPCSB_Element, selected: bool) {
    button_def := cast(^FunctionButtonDef)element.data
    button_def.selected = selected
    element.changed = true
}

FunctionButtonElement_setLabel :: proc(element: ^MPCSB_Element, label: string) {
    button_def := cast(^FunctionButtonDef)element.data
    button_def.label = label
    element.changed = true
}

ButtonElementDef :: struct {
    label: string,
    font_size: f64,
    radius: f64,
    selected: bool,
}

ButtonElement_create :: proc(x, y, width, height: f64, label: string, selected: bool = false) -> ^MPCSB_Element {
    bounds := cairo.rectangle_t { x= x, y= y, width= width, height= height }
    element := MPCSB_Element_create(bounds, true)
    button_def := new(ButtonElementDef)
    button_def.label = label
    button_def.font_size = 9.0
    button_def.radius = 5.0
    button_def.selected = selected
    element.data = button_def
    element.draw = proc (element: ^MPCSB_Element, cairo_context: ^cairo.context_t) {
        button_def := cast(^ButtonElementDef)element.data
        text_color := element.fg_color
        fill_color := element.bg_color
        if button_def.selected {
            text_color = element.bg_color
        }
        cairo.draw_rectangle_bounds(cairo_context, element.bounds, button_def.selected, element.fg_color)
        // draw_text(cairo_context, button_def.label, element.padding_x, 5, button_def.font_size, text_color)
        cairo.draw_text_centered(cairo_context, button_def.label, element.bounds, button_def.font_size, text_color)
        if button_def.selected {
            line_x_padding : f64 = element.bounds.width * .15
            cairo.draw_horizontal_line(cairo_context, element.bounds.y + element.bounds.height - 2, element.bounds.x + line_x_padding, element.bounds.x + element.bounds.width - line_x_padding, 1.0, text_color)
        }
    }
    return element
}


KnobElementDef :: struct {
    label: string,
    value: f64,
    min: f64,
    max: f64,
    default: f64,
    angle_range: f64,
    angle_start: f64,
    thickness: f64,
    value_string: string,
    font_size: f64,
    selected: bool,
    valueDisplayFunction: proc(value: f64) -> cstring,
}

KnobElement_create :: proc(x, y, width, height: f64, label: string, min: f64, max: f64, default: f64) -> ^MPCSB_Element {
    bounds := cairo.rectangle_t { x= x, y= y, width= width, height= height }
    element := MPCSB_Element_create(bounds, true)
    knob_def := new(KnobElementDef)
    knob_def.label = label
    knob_def.value = default
    knob_def.min = min
    knob_def.max = max
    knob_def.default = default
    knob_def.angle_range = 270.0
    knob_def.angle_start = 120.0
    knob_def.thickness = 6.0
    knob_def.value_string = ""
    knob_def.font_size = 9.5
    element.data = knob_def
    element.draw = proc (element: ^MPCSB_Element, cairo_context: ^cairo.context_t) {
        knob_def := cast(^KnobElementDef)element.data
        text_height := knob_def.font_size + 1
        label_padding_left := 10.0
        x := element.bounds.x
        y := element.bounds.y
        width := element.bounds.width
        height := element.bounds.height
        // Draw Label
        cairo.select_font_face(cairo_context, "Sans", cairo.font_slant_t.NORMAL, cairo.font_weight_t.NORMAL)
        cairo.set_font_size(cairo_context, knob_def.font_size)
        cairo.set_source_rgba(cairo_context, element.fg_color.r, element.fg_color.g, element.fg_color.b, element.fg_color.a)
        extents: cairo.text_extents_t
        cairo.text_extents(cairo_context, fmt.ctprint(knob_def.label), &extents)
        cairo.move_to(cairo_context, x +label_padding_left, y + text_height)
        cairo.show_text(cairo_context, fmt.ctprint(knob_def.label))
    
        center_x := x + width / 2;
        center_y := y + (height - text_height) / 2 + text_height; // Adjust center_y to account for label height
        radius := (height - knob_def.thickness - text_height ) / 2 - 4; // Adjust radius to fit within the widget
    
        // sangle := math.to_radians(90 + ((360.0 - widget.angle_range) / 2.0));
        sangle := math.to_radians(f64(90))
        eangle := math.to_radians(90 + knob_def.angle_range * knob_def.value + 2);
        cairo.move_to(cairo_context, center_x, center_y + radius)

        cairo.set_line_width(cairo_context, knob_def.thickness);
        cairo.set_source_rgba(cairo_context, 1.0, 1.0, 1.0, 1.0); // Set knob color
        cairo.arc(cairo_context, center_x, center_y, radius, sangle, eangle);
        cairo.stroke(cairo_context);

        cairo.move_to(cairo_context, center_x + 2, center_y + text_height + radius / 2 - 3);
        cairo.select_font_face(cairo_context, "Sans", cairo.font_slant_t.NORMAL, cairo.font_weight_t.NORMAL)
        cairo.set_font_size(cairo_context, knob_def.font_size)
        cairo.set_source_rgba(cairo_context, element.fg_color.r, element.fg_color.g, element.fg_color.b, element.fg_color.a)

        valueDisplay : cstring
        if knob_def.valueDisplayFunction != nil {
            valueDisplay = knob_def.valueDisplayFunction(knob_def.value)
        } else {
            if knob_def.value_string != "" {
                valueDisplay = fmt.ctprint(fmt.ctprintf("%s", knob_def.value_string))
            } else {
                valueDisplay = fmt.ctprint(fmt.ctprintf("%.2f", knob_def.value))
            }
        }
        extents2: cairo.text_extents_t
        cairo.text_extents(cairo_context, valueDisplay, &extents2)
        cairo.show_text(cairo_context, valueDisplay)

        if knob_def.selected {
            cairo.draw_rectangle(cairo_context, x + 1, y + 1, width - 2, height - 2, false, element.fg_color)
        }
    }
    return element
}

KnobElement_setValue :: proc(element: ^MPCSB_Element, value: f64) {
    knob_def := cast(^KnobElementDef)element.data
    knob_def.value = value
    element.changed = true
}

KnobElement_setValueDisplayFunction :: proc(element: ^MPCSB_Element, valueDisplayFunction: proc(value: f64) -> cstring) {
    knob_def := cast(^KnobElementDef)element.data
    knob_def.valueDisplayFunction = valueDisplayFunction
    element.changed = true
}

KnobElement_setSelected :: proc(element: ^MPCSB_Element, selected: bool) {
    knob_def := cast(^KnobElementDef)element.data
    knob_def.selected = selected
    element.changed = true
}

KnobElement_setLabel :: proc(element: ^MPCSB_Element, label: string) {
    knob_def := cast(^KnobElementDef)element.data
    knob_def.label = label
    element.changed = true
}

KnobElement_setValueString :: proc(element: ^MPCSB_Element, value_string: string) {
    knob_def := cast(^KnobElementDef)element.data
    knob_def.value_string = value_string
    element.changed = true
}

KnobElement_setFontSize :: proc(element: ^MPCSB_Element, font_size: f64) {
    knob_def := cast(^KnobElementDef)element.data
    knob_def.font_size = font_size
    element.changed = true
}

KnobElement_setAngleRange :: proc(element: ^MPCSB_Element, angle_range: f64) {
    knob_def := cast(^KnobElementDef)element.data
    knob_def.angle_range = angle_range
    element.changed = true
}

KnobElement_setAngleStart :: proc(element: ^MPCSB_Element, angle_start: f64) {
    knob_def := cast(^KnobElementDef)element.data
    knob_def.angle_start = angle_start
    element.changed = true
}

KnobElement_setThickness :: proc(element: ^MPCSB_Element, thickness: f64) {
    knob_def := cast(^KnobElementDef)element.data
    knob_def.thickness = thickness
    element.changed = true
}

KnobElement_setMinMax :: proc(element: ^MPCSB_Element, min: f64, max: f64) {
    knob_def := cast(^KnobElementDef)element.data
    knob_def.min = min
    knob_def.max = max
    element.changed = true
}


MeterElementDef :: struct {
    l_value: f64,
    r_value: f64,
    value: f64,
    min_decibel: f64,
    max_decibel: f64,
    min_fader: f64,
    max_fader: f64,
    font_size: f64,
    selected: bool,
    getLabelText: proc(element: ^MeterElementDef) -> cstring
}

MeterElement_create :: proc(x, y, width, height: f64, min_decibel: f64, max_decibel: f64) -> ^MPCSB_Element {
    bounds := cairo.rectangle_t { x= x, y= y, width= width, height= height }
    element := MPCSB_Element_create(bounds, true)
    meter_def := new(MeterElementDef)
    meter_def.getLabelText = getLabelText
    meter_def.l_value = -6.0
    meter_def.r_value = -12.0
    meter_def.value = 0.0
    meter_def.min_decibel = min_decibel
    meter_def.max_decibel = max_decibel
    meter_def.min_fader = -60.0
    meter_def.max_fader = 6.0
    meter_def.font_size = 9.0
    element.data = meter_def
    element.draw = proc (element: ^MPCSB_Element, cairo_context: ^cairo.context_t) {
        meter_def := cast(^MeterElementDef)element.data
        cr := cairo_context
        decibel_range :f64= f64(meter_def.max_decibel - meter_def.min_decibel)
        fader_range :f64 = f64(meter_def.max_fader - meter_def.min_fader)
        gap :f64 = 4
        x_padding: f64 = 4
        y_padding: f64 = 4
        sections :f64 = 3

        // Label
        exts : cairo.text_extents_t
        fader_volume_label := meter_def.getLabelText(meter_def)
        cairo.text_extents(cr, fader_volume_label, &exts)

        // Calculate meter dimensions
        meter_width :f64 = (element.bounds.width - (gap * (sections - 1) + x_padding)) / sections 
        max_meter_height :f64 = element.bounds.height - (y_padding * 2) - exts.height
        left_meter_height := (f64(meter_def.l_value) - f64(meter_def.min_decibel)) / decibel_range * max_meter_height
        right_meter_height := (f64(meter_def.r_value) - f64(meter_def.min_decibel)) / decibel_range * max_meter_height
        
        left_meter_y := element.bounds.y + max_meter_height - left_meter_height
        right_meter_y := element.bounds.y + max_meter_height - right_meter_height
        
        left_meter_x := element.bounds.x + x_padding
        right_meter_x := element.bounds.x + x_padding + meter_width + gap
        
        fader_height := (f64(meter_def.value) - f64(meter_def.min_fader)) / fader_range * max_meter_height - (exts.height / 2)
        fader_x := element.bounds.x + x_padding + (meter_width + gap) * 2
        fader_y := element.bounds.y + max_meter_height - fader_height
        fader_line_width := 1.0
        fader_x_end := fader_x + meter_width - fader_line_width - x_padding
        

        label_y := element.bounds.y + max_meter_height + y_padding
        label_x := element.bounds.x
        label_height : = element.bounds.height - max_meter_height - (y_padding * 2)
        label_width := element.bounds.width

        label_bounds := cairo.rectangle_t{label_x, label_y, label_width, label_height}

        // Draw left meter
        cairo.draw_rectangle(cr, left_meter_x, left_meter_y, meter_width, left_meter_height, true, element.fg_color)
        // Draw right meter
        cairo.draw_rectangle(cr, right_meter_x, right_meter_y, meter_width, right_meter_height, true, element.fg_color)
        // Draw fader    cairo.draw_rectangle(cr, fader_x, fader_y, meter_width, 2, element.fg_color)
        cairo.draw_horizontal_line(cr, fader_y, fader_x, fader_x_end, fader_line_width, element.fg_color)
        cairo.draw_vertical_line(cr, fader_x_end, fader_y, fader_y + fader_height, fader_line_width, element.fg_color)
        


        // Draw label centered
        cairo.draw_text_centered(cr, fmt.tprintf("%s", meter_def.getLabelText(meter_def)), label_bounds, meter_def.font_size, element.fg_color)

        if meter_def.selected {
            cairo.draw_rectangle(cr, element.bounds.x + 1, element.bounds.y + 1, element.bounds.width - 2, element.bounds.height - 2, false, element.fg_color)
        }
    }
    return element
}

getLabelText :: proc(element: ^MeterElementDef) -> cstring {
    return fmt.ctprintf("%.2f dB", element.value)
}

MeterElement_setLValue :: proc(element: ^MPCSB_Element, l_value: f64) {
    meter_def := cast(^MeterElementDef)element.data
    meter_def.l_value = l_value
    element.changed = true
}

MeterElement_setRValue :: proc(element: ^MPCSB_Element, r_value: f64) {
    meter_def := cast(^MeterElementDef)element.data
    meter_def.r_value = r_value
    element.changed = true
}

MeterElement_setMeters :: proc(element: ^MPCSB_Element, l_value: f64, r_value: f64) {
    meter_def := cast(^MeterElementDef)element.data
    meter_def.l_value = l_value
    meter_def.r_value = r_value
    element.changed = true
}

MeterElement_setValue :: proc(element: ^MPCSB_Element, value: f64) {
    meter_def := cast(^MeterElementDef)element.data
    meter_def.value = value
    element.changed = true
}

MeterElement_setSelected :: proc(element: ^MPCSB_Element, selected: bool) {
    meter_def := cast(^MeterElementDef)element.data
    meter_def.selected = selected
    element.changed = true
}

