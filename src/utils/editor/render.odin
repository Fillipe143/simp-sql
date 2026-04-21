package editor

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"
import gl "vendor:raylib/rlgl"

Context :: struct {
	x, y, w, h:    i32,
	editor:        Editor,
	font:          rl.Font,
	sfont:         rl.Font,
	focus:         bool,
	keyboard:      Keyboard,
	scroll_offset: rl.Vector2,
}

new_context :: proc(x, y, w, h: i32) -> Context {
	return Context {
		x = x,
		y = y,
		w = w,
		h = h,
		font = rl.LoadFontEx("assets/fonts/JetBrainsMonoNerdFont-Regular.ttf", 24, nil, 250),
		sfont = rl.LoadFontEx("assets/fonts/JetBrainsMonoNerdFont-Regular.ttf", 18, nil, 250),
		editor = new_editor(""),
		keyboard = default_keyboard(),
		focus = true,
		scroll_offset = {0, 0},
	}
}

get_gutter_width :: proc(ctx: ^Context) -> f32 {
	total := line_count(&ctx.editor)
	str := fmt.tprintf("%d ", total)
	font_size := f32(ctx.font.baseSize)
	return(
		rl.MeasureTextEx(ctx.font, strings.clone_to_cstring(str, context.temp_allocator), font_size, 2).x +
		15 \
	)
}

update_scroll :: proc(ctx: ^Context) {
	col, row := get_cursor(&ctx.editor)
	font_size := f32(ctx.font.baseSize)
	gutter_w := get_gutter_width(ctx)

	status_font_size := f32(ctx.font.baseSize) * 0.45
	status_bar_h := status_font_size + 20

	view_h := f32(ctx.h) - status_bar_h

	line_text := get_line(&ctx.editor, row)
	line_runes := utf8.string_to_runes(line_text, context.temp_allocator)
	safe_col := min(col, len(line_runes))
	text_before := utf8.runes_to_string(line_runes[:safe_col], context.temp_allocator)
	measure_x :=
		rl.MeasureTextEx(ctx.font, strings.clone_to_cstring(text_before, context.temp_allocator), font_size, 2).x

	cursor_x_px := measure_x + gutter_w
	cursor_y_px := f32(row) * font_size

	padding :: 40

	if cursor_y_px < ctx.scroll_offset.y {
		ctx.scroll_offset.y = cursor_y_px
	} else if cursor_y_px + font_size > ctx.scroll_offset.y + view_h - padding {
		ctx.scroll_offset.y = cursor_y_px + font_size - view_h + padding
	}

	if cursor_x_px < ctx.scroll_offset.x + gutter_w {
		ctx.scroll_offset.x = cursor_x_px - gutter_w
	} else if cursor_x_px > ctx.scroll_offset.x + f32(ctx.w) - padding {
		ctx.scroll_offset.x = cursor_x_px - f32(ctx.w) + padding
	}

	ctx.scroll_offset.x = max(0, ctx.scroll_offset.x)
	ctx.scroll_offset.y = max(0, ctx.scroll_offset.y)
}

render_gutter :: proc(ctx: ^Context, start, end: i32) {
	font_size := f32(ctx.font.baseSize)
	gutter_w := get_gutter_width(ctx)
	margin_right :: 10

	for i in start ..< end {
		num_str := fmt.tprintf("%d", i + 1)
		num_cstr := strings.clone_to_cstring(num_str, context.temp_allocator)
		num_width := rl.MeasureTextEx(ctx.font, num_cstr, font_size, 2).x

		x_pos := gutter_w - num_width - margin_right
		y_pos := f32(i) * font_size

		rl.DrawTextEx(ctx.font, num_cstr, {x_pos, y_pos}, font_size, 2, {80, 80, 80, 255})
	}
}

render_status_bar :: proc(ctx: ^Context) {
	font_size := f32(ctx.sfont.baseSize) * 1
	bar_height := font_size + 20
	bar_y := f32(ctx.y + ctx.h) - bar_height

	bg_color := rl.Color{30, 30, 30, 255}
	text_color := rl.Color{180, 180, 180, 255}
	accent_color := rl.Color{255, 222, 33, 255}
	switch ctx.keyboard.mode {
	case .NORMAL:
		accent_color = {255, 222, 33, 255}
	case .INSERT:
		accent_color = {0, 150, 255, 255}
	case .VISUAL:
		accent_color = {255, 100, 0, 255}
	}

	rl.DrawRectangleRec({f32(ctx.x), bar_y, f32(ctx.w), bar_height}, bg_color)
	rl.DrawLineEx({f32(ctx.x), bar_y}, {f32(ctx.x + ctx.w), bar_y}, 1, {50, 50, 50, 255})

	mode_str := fmt.tprintf("%v", ctx.keyboard.mode)
	mode_cstr := strings.clone_to_cstring(mode_str, context.temp_allocator)

	rl.DrawCircleV({f32(ctx.x) + 15, bar_y + (bar_height / 2)}, 4, accent_color)
	rl.DrawTextEx(ctx.sfont, mode_cstr, {f32(ctx.x) + 30, bar_y + 10}, font_size, 2, text_color)

	col, row := get_cursor(&ctx.editor)
	pos_text := fmt.tprintf("%d:%d", row + 1, col + 1)
	pos_cstr := strings.clone_to_cstring(pos_text, context.temp_allocator)
	pos_width := rl.MeasureTextEx(ctx.sfont, pos_cstr, font_size, 2).x

	rl.DrawTextEx(
		ctx.sfont,
		pos_cstr,
		{f32(ctx.x + ctx.w) - pos_width - 15, bar_y + 10},
		font_size,
		2,
		text_color,
	)
}

render_lines :: proc(ctx: ^Context, start, end: i32) {
	font_size := f32(ctx.font.baseSize)

	for i in start ..< end {
		line := get_line(&ctx.editor, int(i))
		y_pos := f32(i) * font_size

		rl.DrawTextEx(
			ctx.font,
			strings.clone_to_cstring(line, context.temp_allocator),
			{0, y_pos},
			font_size,
			2,
			{230, 230, 230, 255},
		)
	}
}

render_cursor :: proc(ctx: ^Context) {
	time := rl.GetTime()
	if (time - ctx.keyboard.last_input_time) > 0.5 {
		if i32(time * 2) % 2 != 0 do return
	}

	col, row := get_cursor(&ctx.editor)
	line_text := get_line(&ctx.editor, row)
	line_runes := utf8.string_to_runes(line_text, context.temp_allocator)
	safe_col := min(col, len(line_runes))

	font_size := f32(ctx.font.baseSize)
	spacing: f32 = 2

	text_before := utf8.runes_to_string(line_runes[:safe_col], context.temp_allocator)
	measure_x := rl.MeasureTextEx(ctx.font, strings.clone_to_cstring(text_before, context.temp_allocator), font_size, spacing).x

	cursor_pos := rl.Vector2{measure_x, f32(row) * font_size}

	if ctx.keyboard.mode == .NORMAL {
		char_under: rune = ' '
		if safe_col > 0 do char_under = line_runes[safe_col - 1]

		char_str := utf8.runes_to_string([]rune{char_under}, context.temp_allocator)
		char_cstr := strings.clone_to_cstring(char_str, context.temp_allocator)

		cursor_width := rl.MeasureTextEx(ctx.font, char_cstr, font_size, spacing).x
		if cursor_width < 5 do cursor_width = rl.MeasureTextEx(ctx.font, " ", font_size, spacing).x

		if safe_col > 0 do cursor_pos.x -= cursor_width

		rl.DrawRectangleV(cursor_pos, {cursor_width, font_size}, {255, 222, 33, 255})
		rl.DrawTextEx(ctx.font, char_cstr, cursor_pos, font_size, spacing, {20, 20, 20, 255})
	} else {
		rl.DrawRectangleV(cursor_pos, {2, font_size}, {255, 222, 33, 255})
	}
}

render :: proc(ctx: ^Context) {
	if ctx.focus {
		read_input(ctx)
		update_scroll(ctx)
	}

	status_font_size := f32(ctx.font.baseSize) * 0.45
	status_bar_h := i32(status_font_size + 20)

	editor_view_h := ctx.h - status_bar_h

	rl.BeginScissorMode(ctx.x, ctx.y, ctx.w, editor_view_h)
	rl.ClearBackground({18, 18, 18, 255})

	font_size := f32(ctx.font.baseSize)
	gutter_w := get_gutter_width(ctx)

	start_line := i32(ctx.scroll_offset.y / font_size)
	end_line := start_line + (editor_view_h / i32(font_size)) + 2
	total_lines := i32(line_count(&ctx.editor))
	end_line = min(end_line, total_lines)

	gl.PushMatrix()
	gl.Translatef(f32(ctx.x) + 10, f32(ctx.y) + 10 - ctx.scroll_offset.y, 0)
	render_gutter(ctx, start_line, end_line)
	gl.PopMatrix()

	rl.EndScissorMode()

	content_x := ctx.x + i32(gutter_w) + 10
	rl.BeginScissorMode(content_x, ctx.y, ctx.w - (content_x - ctx.x), editor_view_h)

	gl.PushMatrix()
	gl.Translatef(f32(content_x) - ctx.scroll_offset.x, f32(ctx.y) + 10 - ctx.scroll_offset.y, 0)

	render_lines(ctx, start_line, end_line)
	render_cursor(ctx)

	gl.PopMatrix()
	rl.EndScissorMode()

	render_status_bar(ctx)
}
