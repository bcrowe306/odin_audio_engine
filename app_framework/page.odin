#+feature using-stmt
package app

import "core:fmt"
import clay "clay-odin"
import vg "vendor:nanovg"
import sdl "vendor:sdl3"

PageConnectionData :: struct {
    page: ^Page,
    user_data: rawptr,
}

Page :: struct {
    name: string,
    render_cmd_array: clay.ClayArray(clay.RenderCommand),
    changed: bool,
    connections: [dynamic]^SignalConnection,
    children : [dynamic]^Element, // Child elements for nesting
    elements: map[string]^Element, // Optional map of child elements for easy access by name
     // Add child element to this element. Child elements will be updated, laid out, drawn, and rendered when the parent element is.
    addChild: proc(parent: ^Page, child: ^Element),
    routers: map[string]^Router, // Optional map of child routers for easy access by name
    addRouter: proc(page: ^Page, name: string), // Add child router to this page. Child routers will be updated and drawn when the parent page is.
    removeRouter: proc(page: ^Page, name: string), // Remove child router from this page. Child routers will no longer be updated or drawn when the parent page is.
    getRouter: proc(page: ^Page, name: string) -> ^Router, // Get child router by name

    // Remove child element from this element. Child elements will no longer be updated, laid out, drawn, or rendered when the parent element is.
    removeChild: proc(parent: ^Page, child: ^Element),

    // Function to add signal connections that will be automatically disconnected when the page is left
    addConnection: proc(page: ^Page, signal: ^Signal, observer: proc (value: any, user_data: rawptr), user_data: rawptr = nil) -> ^SignalConnection,


    _update: proc(page: ^Page, app: ^App, delta_time: f64, events: []sdl.Event, user_data: rawptr),
    update: proc(page: ^Page, app: ^App, delta_time: f64, events: []sdl.Event, user_data: rawptr), // User Extention for update function. Use this to update the page and its children using the provided app state, delta time, and events.
    draw: proc(page: ^Page, ctx: ^vg.Context, user_data: rawptr), // User Override for draw function. Use this to draw the page and its elements using clay and the provided vg context.

    invalidatePage: proc(page: ^Page),

    // Lifecycle hooks
    beforeLoad: proc(page: ^Page, app_user_data: rawptr),
    onBeforeLoad: proc(page: ^Page, app_user_data: rawptr),
    afterLoad: proc(page: ^Page, data: any, app_user_data: rawptr), // Override this to add signal connections for page specific events, such as button clicks. The data parameter is the data passed from the router when switching to this page. This allows you to have dynamic pages that can react to the context in which they were opened. For example, if we push a plugin page from a sample slot, we can pass a reference to that sample slot so that the plugin page can directly manipulate the sample slot's parameters.
    onAfterLoad: proc(page: ^Page, data: any, app_user_data: rawptr),
    beforeLeave: proc(page: ^Page, app_user_data: rawptr), // Has default implementation that disconnects all signal connections added with addConnection
    onBeforeLeave: proc(page: ^Page , app_user_data: rawptr),
    afterLeave: proc(page: ^Page, app_user_data: rawptr),
    onAfterLeave: proc(page: ^Page, app_user_data: rawptr),
}

createPage :: proc(name: string, layout: proc(page: ^Page) = nil) -> ^Page {
    page := new(Page)
    page.name = name
    page.addChild = addChild
    page.removeChild = removeChild
    page._update = pageUpdate
    
    // Lifecycle hooks
    page.beforeLeave = beforeLeavePage
    page.addConnection = addConnection
    page.addRouter = addRouterToPage
    page.removeRouter = removeRouterFromPage
    page.getRouter = getRouterFromPage
    return page
}

configurePage :: proc(page: ^Page, name: string, layout: proc(page: ^Page) = nil) {
    page.name = name
    page.draw = pageDraw
    
    // Lifecycle hooks
    page.beforeLeave = beforeLeavePage
    page.addConnection = addConnection
    page.addRouter = addRouterToPage
    page.removeRouter = removeRouterFromPage
    page.getRouter = getRouterFromPage
}

pageUpdate :: proc(page: ^Page, app: ^App, delta_time: f64, events: []sdl.Event, user_data: rawptr) {
    
    // Call user update function for this page
    if page.update != nil {
        page.update(page, app, delta_time, events, user_data)
    }

    // Update child routers
    for router_name, router in page.routers {
        if router._update != nil {
            router->_update(app, delta_time, events, user_data)
        } else {
            fmt.printf("Router %s does not have an update function\n", router_name)
        }
    }

    // Update child elements
    for child_ptr in page.children { 
        child := cast(^Element)child_ptr 
        child->_update( app, delta_time, events, user_data) 
    } 
}


beforeLeavePage :: proc(page: ^Page, app_user_data: rawptr) {

    // Handle before leave for child routers
    for router_name, router in page.routers {
        router->beforeLeave(app_user_data)
    }

    // Handle before leave for child elements
    for connection in page.connections {
        signalDisconnect(connection)
    }
    clear(&page.connections)
}

addConnection :: proc(page: ^Page, signal: ^Signal, observer: proc (value: any, user_data: rawptr), user_data: rawptr = nil) -> ^SignalConnection {
    page_connection_data := new(PageConnectionData)
    page_connection_data.page = page
    page_connection_data.user_data = user_data
    connection := signalConnect(signal, observer, cast(rawptr)page_connection_data)
    append(&page.connections, connection)
    return connection
}


pageDraw :: proc(page: ^Page, vg_ctx: ^vg.Context, user_data: rawptr) {
}


// Override this function to create a page layout using elements and clay layout commands
createLayout :: proc(page: ^Page)  {
}



addChild :: proc(parent: ^Page, child: ^Element) {
    append(&parent.children, child)
    if child.name != "" {
        parent.elements[child.name] = child
    }
    parent.changed = true
    child.parent = parent
}   

removeChild :: proc(parent: ^Page, child: ^Element) {
    for index in 0..<len(parent.children) {
        if parent.children[index] == child {
            ordered_remove(&parent.children, index)
            break
        }
    }
    parent.changed = true
    child.parent = nil
    if child.name != "" {
        delete_key(&parent.elements, child.name)
    }
}

addRouterToPage :: proc(page: ^Page, name: string) {
    router := createRouter(name)
    page.routers[router.name] = router
}

removeRouterFromPage :: proc(page: ^Page, name: string) {
    if router, ok := page.routers[name]; ok {
        delete_key(&page.routers, name)
    }
}

getRouterFromPage :: proc(page: ^Page, name: string) -> ^Router {
    if router, ok := page.routers[name]; ok {
        return router
    }
    return nil
}