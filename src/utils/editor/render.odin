package editor

import "core:fmt"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"
import rl "vendor:raylib"
import gl "vendor:raylib/rlgl"

SQL_KEYWORD_COLOR :: rl.Color{86, 156, 214, 255}
SQL_STRING_COLOR :: rl.Color{206, 145, 120, 255}
SQL_COMMENT_COLOR :: rl.Color{106, 153, 85, 255}
SQL_NUMBER_COLOR :: rl.Color{181, 206, 168, 255}
SQL_DEFAULT_COLOR :: rl.Color{210, 210, 210, 255}

Context :: struct {
	x, y, w, h:    i32,
	editor:        Editor,
	font:          rl.Font,
	sfont:         rl.Font,
	background:    rl.Texture2D,
	focus:         bool,
	keyboard:      Keyboard,
	scroll_offset: rl.Vector2,
}

Token :: struct {
	text:  string,
	color: rl.Color,
}

is_sql_keyword :: proc(word: string) -> bool {
	KEYWORDS := []string {
		"SELECT",
		"FROM",
		"WHERE",
		"INSERT",
		"UPDATE",
		"DELETE",
		"CREATE",
		"DROP",
		"TABLE",
		"INTO",
		"VALUES",
		"AND",
		"OR",
		"NOT",
		"NULL",
		"JOIN",
		"LEFT",
		"RIGHT",
		"INNER",
		"GROUP",
		"BY",
		"ORDER",
		"HAVING",
		"LIMIT",
		"AS",
		"IN",
		"ON",
		"BETWEEN",
		"LIKE",
		"IS",
		"ANY",
		"ALL",
		"EXISTS",
		"DISTINCT",
		"DATABASE",
	}

	upper_word := strings.to_upper(word, context.temp_allocator)
	for kw in KEYWORDS {
		if upper_word == kw do return true
	}
	return false
}

tokenize_sql_line :: proc(line: string) -> [dynamic]Token {
	tokens := make([dynamic]Token, context.temp_allocator)
	if len(line) == 0 do return tokens

	i := 0
	for i < len(line) {
		r, width := utf8.decode_rune_in_string(line[i:])

		if unicode.is_white_space(r) {
			start := i
			for i < len(line) {
				next_r, next_w := utf8.decode_rune_in_string(line[i:])
				if !unicode.is_white_space(next_r) do break
				i += next_w
			}
			append(&tokens, Token{line[start:i], SQL_DEFAULT_COLOR})
			continue
		}

		if i + 1 < len(line) && line[i:i + 2] == "--" {
			append(&tokens, Token{line[i:], SQL_COMMENT_COLOR})
			break
		}

		if r == '\'' {
			start := i
			i += width
			for i < len(line) {
				curr_r, curr_w := utf8.decode_rune_in_string(line[i:])
				i += curr_w
				if curr_r == '\'' do break
			}
			append(&tokens, Token{line[start:i], SQL_STRING_COLOR})
			continue
		}

		if unicode.is_digit(r) {
			start := i
			for i < len(line) {
				curr_r, curr_w := utf8.decode_rune_in_string(line[i:])
				if !unicode.is_digit(curr_r) do break
				i += curr_w
			}
			append(&tokens, Token{line[start:i], SQL_NUMBER_COLOR})
			continue
		}

		if unicode.is_alpha(r) || r == '_' {
			start := i
			for i < len(line) {
				curr_r, curr_w := utf8.decode_rune_in_string(line[i:])
				if !unicode.is_alpha(curr_r) && !unicode.is_digit(curr_r) && curr_r != '_' do break
				i += curr_w
			}
			word := line[start:i]
			color := is_sql_keyword(word) ? SQL_KEYWORD_COLOR : SQL_DEFAULT_COLOR
			append(&tokens, Token{word, color})
			continue
		}

		append(&tokens, Token{line[i:i + width], SQL_DEFAULT_COLOR})
		i += width
	}
	return tokens
}

new_context :: proc(x, y, w, h: i32) -> Context {
	glyph_count :: 512

	return Context {
		x = x,
		y = y,
		w = w,
		h = h,
		background = rl.LoadTexture("assets/images/background.png"),
		font = rl.LoadFontEx(
			"assets/fonts/JetBrainsMonoNerdFont-Regular.ttf",
			32,
			nil,
			glyph_count,
		),
		sfont = rl.LoadFontEx(
			"assets/fonts/JetBrainsMonoNerdFont-Regular.ttf",
			18,
			nil,
			glyph_count,
		),
		editor = new_editor(""),
		keyboard = default_keyboard(),
		focus = false,
		scroll_offset = {0, 0},
	}
}

get_gutter_width :: proc(ctx: ^Context) -> f32 {
	total := max(line_count(&ctx.editor), 10)
	str := fmt.tprintf("%d ", total)
	font_size := f32(ctx.font.baseSize)
	text_size := rl.MeasureTextEx(
		ctx.font,
		strings.clone_to_cstring(str, context.temp_allocator),
		font_size,
		2,
	)
	return text_size.x + 15
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
	font_size := f32(ctx.sfont.baseSize)
	bar_height := font_size + 20
	bar_y := f32(ctx.y + ctx.h) - bar_height

	bg_color := rl.Color{30, 30, 30, 255}
	text_color := rl.Color{180, 180, 180, 255}
	accent_color: rl.Color

	switch ctx.keyboard.mode {
	case .NORMAL:
		accent_color = {255, 222, 33, 255}
	case .INSERT:
		accent_color = {0, 150, 255, 255}
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

get_cursor_x_offset :: proc(ctx: ^Context, line: string, target_col: int) -> f32 {
	font_size := f32(ctx.font.baseSize)
	spacing: f32 = 2

	tokens := tokenize_sql_line(line)
	current_x: f32 = 0
	current_col := 0

	for token in tokens {
		runes := utf8.string_to_runes(token.text, context.temp_allocator)
		token_len := len(runes)

		if current_col + token_len <= target_col {
			token_cstr := strings.clone_to_cstring(token.text, context.temp_allocator)
			current_x += rl.MeasureTextEx(ctx.font, token_cstr, font_size, spacing).x
			current_col += token_len
		} else {
			needed := target_col - current_col
			if needed > 0 {
				sub_str := utf8.runes_to_string(runes[:needed], context.temp_allocator)
				sub_cstr := strings.clone_to_cstring(sub_str, context.temp_allocator)
				current_x += rl.MeasureTextEx(ctx.font, sub_cstr, font_size, spacing).x
			}
			break
		}
	}
	return current_x
}

render_lines :: proc(ctx: ^Context, start, end: i32) {
	font_size := f32(ctx.font.baseSize)
	spacing: f32 = 2

	for i in start ..< end {
		line := get_line(&ctx.editor, int(i))
		y_pos := f32(i) * font_size

		tokens := tokenize_sql_line(line)
		current_x: f32 = 0

		for token in tokens {
			token_cstr := strings.clone_to_cstring(token.text, context.temp_allocator)
			rl.DrawTextEx(
				ctx.font,
				token_cstr,
				{current_x, y_pos},
				font_size,
				spacing,
				token.color,
			)

			width := rl.MeasureTextEx(ctx.font, token_cstr, font_size, spacing).x
			current_x += width
		}
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

	font_size := f32(ctx.font.baseSize)
	spacing: f32 = 2

	visual_col := col
	if ctx.keyboard.mode == .NORMAL {
		if len(line_runes) > 0 && visual_col >= len(line_runes) {
			visual_col = len(line_runes) - 1
		}
	}

	measure_x := get_cursor_x_offset(ctx, line_text, visual_col)
	cursor_pos := rl.Vector2{measure_x, f32(row) * font_size}

	if ctx.keyboard.mode == .NORMAL {
		char_under: rune = ' '
		if len(line_runes) > 0 && visual_col < len(line_runes) {
			char_under = line_runes[visual_col]
		}

		char_str := utf8.runes_to_string([]rune{char_under}, context.temp_allocator)
		char_cstr := strings.clone_to_cstring(char_str, context.temp_allocator)

		char_width := rl.MeasureTextEx(ctx.font, char_cstr, font_size, spacing).x
		if char_width < 5 do char_width = rl.MeasureTextEx(ctx.font, " ", font_size, spacing).x

		padding_x: f32 = 2.0
		padding_y: f32 = 0.0

		draw_pos := rl.Vector2{1 + cursor_pos.x - (padding_x / 2), cursor_pos.y - (padding_y / 2)}

		draw_size := rl.Vector2{char_width + padding_x, font_size + padding_y}

		rl.DrawRectangleV(draw_pos, draw_size, {255, 222, 33, 255})
		rl.DrawTextEx(ctx.font, char_cstr, cursor_pos, font_size, spacing, {28, 28, 28, 255})
	} else {
		rl.DrawRectangleV(cursor_pos, {2, font_size}, {255, 222, 33, 255})
	}
}

render :: proc(ctx: ^Context) {
	if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
		pos := rl.GetMousePosition()
		ctx.focus =
			pos.x >= f32(ctx.x) &&
			pos.y >= f32(ctx.y) &&
			pos.x <= f32(ctx.x + ctx.w) &&
			pos.y <= f32(ctx.y + ctx.h)
		if ctx.focus do ctx.keyboard.last_input_time = rl.GetTime()
	}

	if ctx.focus {
		read_input(ctx)
		update_scroll(ctx)
	}

	status_font_size := f32(ctx.font.baseSize) * 0.45
	status_bar_h := i32(status_font_size + 20)
	editor_view_h := ctx.h - status_bar_h

	rl.BeginScissorMode(ctx.x, ctx.y, ctx.w, editor_view_h)
	rl.ClearBackground({18, 18, 18, 255})
	rl.DrawTexture(
		ctx.background,
		ctx.x + (ctx.w - ctx.background.width) / 2,
		(ctx.y + (ctx.h - ctx.background.height) / 2) - status_bar_h + 20,
		{100, 100, 100, 255},
	)

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
	if ctx.focus do render_cursor(ctx)

	gl.PopMatrix()
	rl.EndScissorMode()

	render_status_bar(ctx)
}
