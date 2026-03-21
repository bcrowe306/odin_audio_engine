package app


hexToRGBA :: proc(hexNumber: u32) -> [4]f32 {
    r : f32 = f32((hexNumber >> 24) & 0xFF) / 255.0
    g : f32 = f32((hexNumber >> 16) & 0xFF) / 255.0
    b : f32 = f32((hexNumber >> 8) & 0xFF) / 255.0
    a : f32 = f32(hexNumber & 0xFF) / 255.0
    return {r, g, b, a}
}
