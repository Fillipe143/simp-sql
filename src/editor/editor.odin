package editor

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

open :: proc() {
	WIDTH, HEIGHT :: 800, 500
	rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
	rl.InitWindow(WIDTH, HEIGHT, "SQL Editor")
	rl.SetTargetFPS(60)

	lines := make([dynamic]string); append(&lines, "")
	ctx := create_editor_context(10, 10, WIDTH - 20, HEIGHT - 20, &lines)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		render_editor(&ctx)
		rl.EndDrawing()
	}

	rl.CloseWindow()
}

Cursor :: struct {
	x, y:    i32,
	timer:   f32,
	visible: bool,
}

EditorStyle :: struct {
	margin:           i32,
	line_number_size: i32,
	font_size:        i32,
	font:             rl.Font,
	highlight_color:  rl.Color,
	foreground_color: rl.Color,
	background_color: rl.Color,
}

EditorContext :: struct {
	x, y, w, h: i32,
	lines:      [dynamic]string,
	cursor:     Cursor,
	style:      EditorStyle,
}


create_editor_style :: proc(font_size: i32) -> EditorStyle {
	return {
		margin = 10,
		line_number_size = i32(f32(font_size) * 2.5),
		font_size = font_size,
		font = rl.LoadFontEx("assets/fonts/JetBrainsMonoNerdFont-Regular.ttf", font_size, nil, 0),
		highlight_color = {255, 222, 33, 255},
		foreground_color = {230, 230, 230, 255},
		background_color = {18, 18, 18, 255},
	}
}

create_editor_context :: proc(x, y, w, h: i32, lines: ^[dynamic]string) -> EditorContext {
	return {x, y, w, h, lines^, {0, 0, 0, true}, create_editor_style(32)}
}

draw_text :: proc(ctx: ^EditorContext, text: cstring, x, y: i32, color: rl.Color) {
	rl.DrawTextEx(
		ctx.style.font,
		text,
		{
			f32(ctx.x + x + ctx.style.margin + ctx.style.line_number_size),
			f32(ctx.y + y + ctx.style.margin),
		},
		f32(ctx.style.font_size),
		0,
		color,
	)
}

handle_input :: proc(ctx: ^EditorContext) {
	if c := rl.GetCharPressed(); c != 0 do insert_char(ctx, c)
	check_key :: proc(key: rl.KeyboardKey) -> bool {
		return rl.IsKeyPressed(key) || rl.IsKeyPressedRepeat(key)
	}

	if check_key(.LEFT) {
		if ctx.cursor.x > 0 {
			ctx.cursor.x -= 1
		} else if ctx.cursor.y > 0 {
			ctx.cursor.y -= 1
			ctx.cursor.x = i32(len(ctx.lines[ctx.cursor.y]))
		}
		reset_cursor_blink(ctx)
	}

	if check_key(.RIGHT) {
		if int(ctx.cursor.x) < len(ctx.lines[ctx.cursor.y]) {
			ctx.cursor.x += 1
		} else if int(ctx.cursor.y) < len(ctx.lines) - 1 {
			ctx.cursor.y += 1
			ctx.cursor.x = 0
		}
		reset_cursor_blink(ctx)
	}

	if check_key(.UP) {
		if ctx.cursor.y > 0 {
			ctx.cursor.y -= 1
			ctx.cursor.x = min(ctx.cursor.x, i32(len(ctx.lines[ctx.cursor.y])))
		} else {
			ctx.cursor.x = 0
		}
		reset_cursor_blink(ctx)
	}

	if check_key(.DOWN) {
		if int(ctx.cursor.y) < len(ctx.lines) - 1 {
			ctx.cursor.y += 1
			ctx.cursor.x = min(ctx.cursor.x, i32(len(ctx.lines[ctx.cursor.y])))
		} else {
			ctx.cursor.x = i32(len(ctx.lines[ctx.cursor.y]))
		}
		reset_cursor_blink(ctx)
	}

	if check_key(.BACKSPACE) do backspace(ctx)
	if check_key(.DELETE) do delete_char(ctx)
	if check_key(.ENTER) do insert_newline(ctx)

	if check_key(.TAB) {
		for _ in 0 ..< 4 do insert_char(ctx, ' ')
	}
}

reset_cursor_blink :: proc(ctx: ^EditorContext) {
	ctx.cursor.visible = true
	ctx.cursor.timer = 0
}

insert_char :: proc(ctx: ^EditorContext, c: rune) {
	l := ctx.lines[ctx.cursor.y]
	ctx.lines[ctx.cursor.y] = fmt.aprintf("%s%r%s", l[:ctx.cursor.x], c, l[ctx.cursor.x:])
	ctx.cursor.x += 1
}

insert_newline :: proc(ctx: ^EditorContext) {
	line := ctx.lines[ctx.cursor.y]

	left := line[:ctx.cursor.x]
	right := line[ctx.cursor.x:]

	ctx.lines[ctx.cursor.y] = strings.clone(left)

	inject_at(&ctx.lines, int(ctx.cursor.y + 1), strings.clone(right))

	ctx.cursor.y += 1
	ctx.cursor.x = 0
}

backspace :: proc(ctx: ^EditorContext) {
	if ctx.cursor.x > 0 {
		l := ctx.lines[ctx.cursor.y]
		ctx.lines[ctx.cursor.y] = fmt.aprintf("%s%s", l[:ctx.cursor.x - 1], l[ctx.cursor.x:])
		ctx.cursor.x -= 1
	} else if ctx.cursor.y > 0 {
		prev_y := ctx.cursor.y - 1
		prev_len := i32(len(ctx.lines[prev_y]))

		ctx.lines[prev_y] = fmt.aprintf("%s%s", ctx.lines[prev_y], ctx.lines[ctx.cursor.y])

		ordered_remove(&ctx.lines, int(ctx.cursor.y))

		ctx.cursor.y = prev_y
		ctx.cursor.x = prev_len
	}
}

delete_char :: proc(ctx: ^EditorContext) {
	l := ctx.lines[ctx.cursor.y]

	if int(ctx.cursor.x) < len(l) {
		ctx.lines[ctx.cursor.y] = fmt.aprintf("%s%s", l[:ctx.cursor.x], l[ctx.cursor.x + 1:])
	} else if int(ctx.cursor.y) < len(ctx.lines) - 1 {
		next_line := ctx.lines[ctx.cursor.y + 1]
		ctx.lines[ctx.cursor.y] = fmt.aprintf("%s%s", l, next_line)

		ordered_remove(&ctx.lines, int(ctx.cursor.y + 1))
	}
}

render_cursor :: proc(ctx: ^EditorContext) {
	ctx.cursor.timer += rl.GetFrameTime()
	if ctx.cursor.timer >= .6 {
		ctx.cursor.visible ~= true
		ctx.cursor.timer = 0
	}

	rl.DrawRectangle(
		ctx.x + ctx.style.margin + ctx.style.line_number_size,
		ctx.style.font_size * ctx.cursor.y + ctx.y + ctx.style.margin,
		ctx.w,
		ctx.style.font_size,
		{32, 32, 32, 255},
	)
	if !ctx.cursor.visible do return

	cursor_line := strings.clone_to_cstring(
		ctx.lines[ctx.cursor.y][:ctx.cursor.x],
		context.temp_allocator,
	)
	cursor_x := rl.MeasureTextEx(ctx.style.font, cursor_line, f32(ctx.style.font_size), 0).x
	rl.DrawRectangle(
		i32(cursor_x) + ctx.x + ctx.style.margin + ctx.style.line_number_size + 1,
		ctx.style.font_size * ctx.cursor.y + ctx.y + ctx.style.margin + 3,
		2,
		ctx.style.font_size - 6,
		ctx.style.highlight_color,
	)
}

render_editor :: proc(ctx: ^EditorContext) {
	rl.BeginScissorMode(ctx.x, ctx.y, ctx.w, ctx.h)
	rl.ClearBackground(ctx.style.background_color)

	handle_input(ctx)
	render_cursor(ctx)

	for line, i in ctx.lines {
		draw_text(
			ctx,
			fmt.ctprintf("% 3d.", i + 1),
			-ctx.style.line_number_size,
			i32(i) * ctx.style.font_size,
			ctx.style.highlight_color,
		)
		draw_text(
			ctx,
			strings.clone_to_cstring(line, context.temp_allocator),
			0,
			i32(i) * ctx.style.font_size,
			ctx.style.foreground_color,
		)
	}
	rl.EndScissorMode()
}
