package main 

import vg "vendor:nanovg"

draw_play_icon :: proc(
	ctx: ^vg.Context,
	x, y, width, height: f32,
	color: [4]f32,
) {
	if width <= 0 || height <= 0 {
		return
	}

	pad := width * 0.2
	if height < width {
		pad = height * 0.2
	}
	left := x + pad
	top := y + pad
	bottom := y + height - pad
	right := x + width - pad
	center_y := y + height * 0.5

	vg.BeginPath(ctx)
	vg.MoveTo(ctx, left, top)
	vg.LineTo(ctx, right, center_y)
	vg.LineTo(ctx, left, bottom)
	vg.ClosePath(ctx)
	vg.FillColor(ctx, color)
	vg.Fill(ctx)
}

draw_stop_icon :: proc(
	ctx: ^vg.Context,
	x, y, width, height: f32,
	color: [4]f32,
) {
	if width <= 0 || height <= 0 {
		return
	}

	pad := width * 0.2
	if height < width {
		pad = height * 0.2
	}

	vg.BeginPath(ctx)
	vg.Rect(ctx, x + pad, y + pad, width - pad * 2, height - pad * 2)
	vg.FillColor(ctx, color)
	vg.Fill(ctx)
}

draw_pause_icon :: proc(
	ctx: ^vg.Context,
	x, y, width, height: f32,
	color: [4]f32,
) {
	if width <= 0 || height <= 0 {
		return
	}

	pad := width * 0.2
	if height < width {
		pad = height * 0.2
	}

	inner_x := x + pad
	inner_y := y + pad
	inner_w := width - pad * 2
	inner_h := height - pad * 2
	if inner_w <= 0 || inner_h <= 0 {
		return
	}

	gap := inner_w * 0.25
	bar_w := (inner_w - gap) * 0.5
	if bar_w <= 0 {
		return
	}

	radius := bar_w * 0.2

	vg.BeginPath(ctx)
	vg.RoundedRect(ctx, inner_x, inner_y, bar_w, inner_h, radius)
	vg.RoundedRect(ctx, inner_x + bar_w + gap, inner_y, bar_w, inner_h, radius)
	vg.FillColor(ctx, color)
	vg.Fill(ctx)
}

draw_loop_icon :: proc(
	ctx: ^vg.Context,
	x, y, width, height: f32,
	color: [4]f32,
) {
	if width <= 0 || height <= 0 {
		return
	}

	pad := width * 0.2
	if height < width {
		pad = height * 0.2
	}

	inner_w := width - pad * 2
	inner_h := height - pad * 2
	if inner_w <= 0 || inner_h <= 0 {
		return
	}

	cx := x + width * 0.5
	cy := y + height * 0.5
	rx := inner_w * 0.5
	ry := inner_h * 0.5

	stroke_w := rx * 0.22
	if ry < rx {
		stroke_w = ry * 0.22
	}

	vg.BeginPath(ctx)
	vg.Ellipse(ctx, cx, cy, rx, ry)
	vg.StrokeWidth(ctx, stroke_w)
	vg.StrokeColor(ctx, color)
	vg.Stroke(ctx)

	arrow_tip_x := cx + rx + stroke_w * 0.35
	arrow_tip_y := cy - ry * 0.12
	arrow_back_x := cx + rx * 0.60
	arrow_top_y := cy - ry * 0.62
	arrow_bottom_y := cy - ry * 0.06

	vg.BeginPath(ctx)
	vg.MoveTo(ctx, arrow_tip_x, arrow_tip_y)
	vg.LineTo(ctx, arrow_back_x, arrow_top_y)
	vg.LineTo(ctx, arrow_back_x, arrow_bottom_y)
	vg.ClosePath(ctx)
	vg.FillColor(ctx, color)
	vg.Fill(ctx)
}

draw_hamburger_icon :: proc(
	ctx: ^vg.Context,
	x, y, width, height: f32,
	color: [4]f32,
) {
	if width <= 0 || height <= 0 {
		return
	}

	pad := width * 0.2
	if height < width {
		pad = height * 0.2
	}

	inner_x := x + pad
	inner_y := y + pad
	inner_w := width - pad * 2
	inner_h := height - pad * 2
	if inner_w <= 0 || inner_h <= 0 {
		return
	}

	line_h := inner_h * 0.18
	gap := (inner_h - line_h * 3) * 0.5
	if gap < 0 {
		gap = 0
		line_h = inner_h / 3
	}

	radius := line_h * 0.5

	vg.BeginPath(ctx)
	vg.RoundedRect(ctx, inner_x, inner_y, inner_w, line_h, radius)
	vg.RoundedRect(ctx, inner_x, inner_y + line_h + gap, inner_w, line_h, radius)
	vg.RoundedRect(ctx, inner_x, inner_y + (line_h + gap) * 2, inner_w, line_h, radius)
	vg.FillColor(ctx, color)
	vg.Fill(ctx)
}

draw_record_icon :: proc(
	ctx: ^vg.Context,
	x, y, width, height: f32,
	color: [4]f32 = {1.0, 0.0, 0.0, 1.0},
) {
	if width <= 0 || height <= 0 {
		return
	}

	pad := width * 0.2
	if height < width {
		pad = height * 0.2
	}

	inner_w := width - pad * 2
	inner_h := height - pad * 2
	if inner_w <= 0 || inner_h <= 0 {
		return
	}

	radius := inner_w * 0.5
	if inner_h < inner_w {
		radius = inner_h * 0.5
	}

	cx := x + width * 0.5
	cy := y + height * 0.5

	vg.BeginPath(ctx)
	vg.Circle(ctx, cx, cy, radius)
	vg.FillColor(ctx, color)
	vg.Fill(ctx)
}

draw_metronome_icon :: proc(
	ctx: ^vg.Context,
	x, y, width, height: f32,
	rect_color: [4]f32,
	circle_color: [4]f32,
) {
	if width <= 0 || height <= 0 {
		return
	}

	pad := width * 0.15
	if height < width {
		pad = height * 0.15
	}

	inner_x := x + pad
	inner_y := y + pad
	inner_w := width - pad * 2
	inner_h := height - pad * 2
	if inner_w <= 0 || inner_h <= 0 {
		return
	}

	vg.BeginPath(ctx)
	vg.Rect(ctx, inner_x, inner_y, inner_w, inner_h)
	vg.FillColor(ctx, rect_color)
	vg.Fill(ctx)

	gap := inner_w * 0.12
	circle_radius := (inner_w - gap) * 0.25
	max_radius := inner_h * 0.28
	if circle_radius > max_radius {
		circle_radius = max_radius
	}
	if circle_radius <= 0 {
		return
	}

	cx := inner_x + inner_w * 0.5
	cy := inner_y + inner_h * 0.5
	x_offset := circle_radius + gap * 0.5

	vg.BeginPath(ctx)
	vg.Circle(ctx, cx - x_offset, cy, circle_radius)
	vg.Circle(ctx, cx + x_offset, cy, circle_radius)
	vg.FillColor(ctx, circle_color)
	vg.Fill(ctx)
}

