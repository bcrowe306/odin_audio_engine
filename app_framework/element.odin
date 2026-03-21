package app

import "core:encoding/uuid"
import "core:crypto"
import sdl "vendor:sdl3"
import vg "vendor:nanovg"
import clay "clay-odin"
import "core:fmt"

ElementBounds :: [4]f64 // left, top, width, height


Element :: struct {
    id: uuid.Identifier,
    name: string,
    visible: bool,
    enabled: bool,
    changed: bool,
    selected: bool,
    focused: bool,
    hovered: bool,
    bounds: clay.BoundingBox,
    input_state: ^InputState,
    drag_threshold: f64, // Scale factor for drag input, can be used to adjust sensitivity of drag interactions
    parent: ^Page,
    
    elements: map[string]^Element, // Optional map of child elements for easy access by name
    user_data: rawptr, // Optional field for storing custom data associated with the element

    setBounds: proc(Element: ^Element, bounds: clay.BoundingBox),
    setVisible: proc(Element: ^Element, visible: bool),
    setEnabled: proc(Element: ^Element, enabled: bool),
    setSelected: proc(Element: ^Element, selected: bool),
    setFocused: proc(Element: ^Element, focused: bool),

    clear: proc(element: ^Element, ctx: ^vg.Context),

    // User overrides. Use this to update the element
    _update: proc(element: ^Element, app: ^App, delta_time: f64, events: []sdl.Event, user_data: rawptr),
    onUpdate: proc(element: ^Element, app: ^App, delta_time: f64, events: []sdl.Event, user_data: rawptr),
    
    // Drawing proc. Use this to draw the element using the provided render command.
    _draw: proc(element: ^Element, ctx: ^vg.Context, user_data: rawptr),
    onDraw: proc(element: ^Element, ctx: ^vg.Context, user_data: rawptr),

    // Render proc. Use this to render the surface to various targets like a hardware display.
    _render: proc(element: ^Element, user_data: rawptr),
    onRender: proc(element: ^Element, user_data: rawptr),

    // Signals
    onPressed: ^Signal,
    onReleased: ^Signal,
    onClick: ^Signal,
    onDrag: ^Signal,
    onHover: ^Signal,
    onUnhover: ^Signal,
}

createElement :: proc(name: string, user_data: rawptr = nil) -> ^Element {
    el := new(Element)
    configureElement(el)
    el.name = name
    el.user_data = user_data
    return el
}

configureElement :: proc(el: ^Element) {
    context.random_generator = crypto.random_generator()
    el.id = uuid.generate_v4()
    el.changed = true
    el.visible = true
    el.enabled = true
    el.drag_threshold = 20.0
    el.input_state = createInputState()
    el._update = elementUpdate

    el._draw = elementDraw
    el.setBounds = elementSetBounds
    el.setVisible = elementSetVisible
    el.setEnabled = elementSetEnabled
    el.setSelected = elementSetSelected
    el.setFocused = elementSetFocused
    
    // Signals
    el.onPressed = createSignal()
    el.onReleased = createSignal()
    el.onClick = createSignal()
    el.onDrag = createSignal()
    el.onHover = createSignal()
}


elementUpdate :: proc(element: ^Element, app: ^App, delta_time: f64, events: []sdl.Event, user_data: rawptr) {
    element.input_state->update(events, element)
    processDefaultElementEvents(element, events)
    if element.onUpdate != nil && element.enabled {
        element.onUpdate(element, app, delta_time, events, user_data)
    }
}

processDefaultElementEvents :: proc(element: ^Element, events: []sdl.Event) {
    element_processReleaseAndClick(element, events)
    element_processPressed(element, events)
    element_processDrag(element)
    element_processHovered(element, events)
}

element_processReleaseAndClick :: proc(element: ^Element, events: []sdl.Event) {
    for event in events {
        if event.type == sdl.EventType.MOUSE_BUTTON_UP {
            for is_button_down, index in element.input_state.mouse_buttons{
                if index == int(event.button.button) - 1 && is_button_down {
                    signalEmit(element.onClick, index)
                }
            }
            if isInBoundsScaled(element.input_state.mouse_position.x, element.input_state.mouse_position.y, element.bounds, element.input_state.window_scale) {
                signalEmit(element.onReleased, int(event.button.button) - 1)
            }
        }
    }
}

element_processHovered :: proc(element: ^Element, events : []sdl.Event) {
    for event in events {
        if event.type == sdl.EventType.MOUSE_MOTION {
            if isInBoundsScaled(element.input_state.mouse_position.x, element.input_state.mouse_position.y, element.bounds, element.input_state.window_scale) {
                if !element.hovered {
                    element.hovered = true
                    signalEmit(element.onHover, true)
                }
            } else {
                if element.hovered {
                    element.hovered = false
                    signalEmit(element.onHover, false)
                }
            }
        }
    }
}

element_processPressed :: proc(element: ^Element, events: []sdl.Event) {
    if element.input_state.isClicked(events, element, 0, 1) {
        for button_clicked, index in element.input_state.mouse_buttons {
            if button_clicked {
                signalEmit(element.onPressed, index)
            }
        }
    }
}

element_processDrag :: proc(element: ^Element) {
     if element.input_state->isMouseButtonDown(0) {
        mouse_drag := element.input_state->getDrag(0)
            if abs(f64(mouse_drag.y)) > element.drag_threshold {
                element.input_state.mouse_delta.y = 0
                multiplier := 1.0
                if mouse_drag.y < 0 {
                    multiplier = -1.0
                }
                signalEmit(element.onDrag, multiplier)
            }
    }
}


elementDraw :: proc(element: ^Element, ctx: ^vg.Context, user_data: rawptr) {
    if element.onDraw != nil && element.visible {
        element.onDraw(element, ctx, user_data)
    }
}

elementSetBounds :: proc(element: ^Element, bounds: clay.BoundingBox) {
    element.bounds = bounds
    element.changed = true
}


elementSetVisible :: proc(element: ^Element, visible: bool) {
    if element.visible != visible {
        element.visible = visible
        element.changed = true
    }
}

elementSetEnabled :: proc(element: ^Element, enabled: bool) {
    if element.enabled != enabled {
        element.enabled = enabled
        element.changed = true
    }
}

elementSetSelected :: proc(element: ^Element, selected: bool) {
    if selected != element.selected {
        element.selected = selected
        element.changed = true
    }
}

elementSetFocused :: proc(element: ^Element, focused: bool) {
    if focused != element.focused {
        element.focused = focused
        element.changed = true
    }
}