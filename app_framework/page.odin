#+feature using-stmt
package app

import clay "clay-odin"
import vg "vendor:nanovg"


Page :: struct {
    using element: Element,
    render_cmd_array: clay.ClayArray(clay.RenderCommand),
    connections: [dynamic]^SignalConnection,

    // Function to add signal connections that will be automatically disconnected when the page is left
    addConnection: proc(page: ^Page, signal: ^Signal, observer: proc (value: any, user_data: rawptr)) -> ^SignalConnection,

    // Override this function to create a page layout using elements and clay layout commands
    createLayout: proc(page: ^Page) -> clay.ClayArray(clay.RenderCommand),
    
    drawPage: proc(page: ^Page, ctx: ^vg.Context, user_data: rawptr),

    clearPage: proc(page: ^Page, ctx: ^vg.Context),

    invalidatePage: proc(page: ^Page),

    // Lifecycle hooks
    beforeLoad: proc(page: ^Page),
    onBeforeLoad: proc(page: ^Page),
    afterLoad: proc(page: ^Page, data: any),
    onAfterLoad: proc(page: ^Page, data: any),
    beforeLeave: proc(page: ^Page), // Has default implementation that disconnects all signal connections added with addConnection
    onBeforeLeave: proc(page: ^Page),
    afterLeave: proc(page: ^Page),
    onAfterLeave: proc(page: ^Page),
}

createPage :: proc(name: string, layout: proc(page: ^Page) -> clay.ClayArray(clay.RenderCommand) = nil) -> ^Page {
    page := new(Page)
    configureElement(page)
    page.name = name
    page.createLayout = layout
    page.drawPage = drawPage
    
    // Lifecycle hooks
    page.clearPage = clearPage
    page.beforeLeave = beforeLeavePage
    page.addConnection = addConnection
    return page
}

configurePage :: proc(page: ^Page, name: string, layout: proc(page: ^Page) -> clay.ClayArray(clay.RenderCommand) = nil) {
    configureElement(page)
    page.name = name
    page.createLayout = layout
    page.drawPage = drawPage
    
    // Lifecycle hooks
    page.clearPage = clearPage
    page.beforeLeave = beforeLeavePage
    page.addConnection = addConnection

}


beforeLeavePage :: proc(page: ^Page) {
    for connection in page.connections {
        signalDisconnect(connection)
    }
    page.connections = nil
}

addConnection :: proc(page: ^Page, signal: ^Signal, observer: proc (value: any, user_data: rawptr)) -> ^SignalConnection {
    connection := signalConnect(signal, observer, cast(rawptr)page)
    append(&page.connections, connection)
    return connection
}

clearPage :: proc(page: ^Page, ctx: ^vg.Context) {

    for child_ptr in page.children {
        child := cast(^Element)child_ptr
        if child != nil && child.clear != nil {
            child.clear(child, ctx)
        }   
    }
}



drawPage :: proc(page: ^Page, vg: ^vg.Context, user_data: rawptr) {
    if page.createLayout == nil {
        return
    }

    page.render_cmd_array = page.createLayout(page)
    for i in 0..<page.render_cmd_array.length {
        cmd := clay.RenderCommandArray_Get(&page.render_cmd_array, i)

        #partial switch cmd.commandType {
            case clay.RenderCommandType.Rectangle:

            case clay.RenderCommandType.Custom:
                element_ptr := cmd.renderData.custom.customData
                element := cast(^Element)element_ptr
                element.setBounds(element, cmd.boundingBox)
                if element._draw != nil {
                    element._draw(element, vg, user_data)
                }
        }
    }
}


// Override this function to create a page layout using elements and clay layout commands
createLayout :: proc(page: ^Page) -> clay.ClayArray(clay.RenderCommand) {
    using clay
    BeginLayout()
    return EndLayout()
}
