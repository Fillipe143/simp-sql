package tabs

import "core:strings"
import rl "vendor:raylib"

TabType :: enum {
	NONE,
	EDITOR,
	TREE,
	TABLE,
}

Tab :: struct {
	title:   string,
	type:    TabType,
	app_ctx: rawptr,
	message: string,
}

Context :: struct {
	x, y, w, h:     i32,
	ax, ay, aw, ah: i32,
	font, afont:    rl.Font,
	tab_list:       [dynamic]Tab,
	active_idx:     int,
	dragging_idx:   int,
	alert_message:  string,
	counter:        int,
}

new_context :: proc(x, y, w, h, ax, ay, aw, ah: i32) -> Context {
	return Context {
		x = x,
		y = y,
		w = w,
		h = h,
		ax = ax,
		ay = ay,
		aw = aw,
		ah = ah,
		font = rl.LoadFontEx("assets/fonts/JetBrainsMonoNerdFont-Regular.ttf", 18, nil, 250),
		afont = rl.LoadFontEx("assets/fonts/JetBrainsMonoNerdFont-Regular.ttf", 22, nil, 4096),
		active_idx = -1,
		dragging_idx = -1,
		alert_message = "",
		counter = 1,
	}
}

add_tab :: proc(
	ctx: ^Context,
	title: string,
	type: TabType,
	app_ctx: rawptr,
	message: string = "",
) {
	ctx.active_idx = len(ctx.tab_list)
	append(&ctx.tab_list, Tab{title, type, app_ctx, message})
}

active_tab :: proc(ctx: ^Context) -> Tab {
	if ctx.active_idx < 0 || ctx.active_idx >= len(ctx.tab_list) do return Tab{"", .NONE, nil, ""}
	return ctx.tab_list[ctx.active_idx]
}

show_alert :: proc(ctx: ^Context, msg: string) {
	ctx.alert_message = msg
}

render :: proc(ctx: ^Context) {
	mouse_pos := rl.GetMousePosition()
	real_clicked := rl.IsMouseButtonPressed(.LEFT)

	clicked := real_clicked
	mouse_down := rl.IsMouseButtonDown(.LEFT)
	released := rl.IsMouseButtonReleased(.LEFT)

	dialog_open := len(ctx.alert_message) > 0
	if dialog_open {
		clicked = false
		mouse_down = false
		released = false
	}

	if len(ctx.tab_list) > 0 {
		rl.DrawRectangle(ctx.x, ctx.y, ctx.w, ctx.h, rl.Color{30, 30, 30, 255})
	}

	if len(ctx.tab_list) > 0 {
		if released {
			ctx.dragging_idx = -1
		}

		padding_x :: 16.0
		close_size :: 12.0
		gap :: 1.0

		current_x := f32(ctx.x)
		closed_idx := -1
		swap_target := -1

		for i in 0 ..< len(ctx.tab_list) {
			tab := &ctx.tab_list[i]

			cstr := strings.clone_to_cstring(tab.title, context.temp_allocator)
			text_size := rl.MeasureTextEx(ctx.font, cstr, 18, 0)

			tab_w := padding_x + text_size.x + 12.0 + close_size + padding_x
			tab_rect := rl.Rectangle{current_x, f32(ctx.y), tab_w, f32(ctx.h)}

			btn_rect := rl.Rectangle {
				current_x + tab_w - padding_x - close_size,
				f32(ctx.y) + (f32(ctx.h) - close_size) / 2.0,
				close_size,
				close_size,
			}

			hover_tab := rl.CheckCollisionPointRec(mouse_pos, tab_rect)
			hover_btn := rl.CheckCollisionPointRec(mouse_pos, btn_rect)

			if clicked && hover_btn {
				closed_idx = i
			} else if clicked && hover_tab {
				ctx.active_idx = i
				ctx.dragging_idx = i
			} else if mouse_down && hover_tab && ctx.dragging_idx >= 0 && ctx.dragging_idx != i {
				swap_target = i
			}

			bg_color := rl.Color{50, 50, 50, 255}
			if ctx.active_idx == i {
				bg_color = rl.Color{80, 80, 80, 255}
			} else if hover_tab && !dialog_open {
				bg_color = rl.Color{65, 65, 65, 255}
			}

			rl.DrawRectangleRec(tab_rect, bg_color)

			if ctx.active_idx == i {
				rl.DrawRectangle(
					i32(tab_rect.x),
					i32(tab_rect.y),
					i32(tab_rect.width),
					3,
					rl.RAYWHITE,
				)
				message := active_tab(ctx).message
				if message != "" {
					margin_x: f32 = 20.0
					margin_y: f32 = 20.0

					max_text_w := f32(ctx.aw) - (margin_x * 2.0)

					words := strings.fields(message, context.temp_allocator)
					current_line := ""
					lines := make([dynamic]string, context.temp_allocator)

					for word in words {
						test_line: string
						if len(current_line) == 0 {
							test_line = word
						} else {
							test_line = strings.concatenate(
								{current_line, " ", word},
								context.temp_allocator,
							)
						}

						test_cstr := strings.clone_to_cstring(test_line, context.temp_allocator)
						size := rl.MeasureTextEx(ctx.afont, test_cstr, 22, 0)

						if size.x > max_text_w && len(current_line) > 0 {
							append(&lines, current_line)
							current_line = word
						} else {
							current_line = test_line
						}
					}
					if len(current_line) > 0 {
						append(&lines, current_line)
					}

					line_spacing: f32 = 26.0
					total_text_h := (f32(len(lines)) * line_spacing) - (line_spacing - 22.0)
					start_y := f32(ctx.ay + ctx.ah) - total_text_h - margin_y

					max_line_w: f32 = 0.0
					for line in lines {
						line_cstr := strings.clone_to_cstring(line, context.temp_allocator)
						size := rl.MeasureTextEx(ctx.afont, line_cstr, 22, 0)
						if size.x > max_line_w do max_line_w = size.x
					}

					bg_padding_x: f32 = 16.0
					bg_padding_y: f32 = 12.0

					bg_w := max_line_w + (bg_padding_x * 2.0)
					bg_h := total_text_h + (bg_padding_y * 2.0)

					bg_x := f32(ctx.ax) + (f32(ctx.aw) - bg_w) / 2.0
					bg_y := start_y - bg_padding_y

					rl.DrawRectangleRounded(
						rl.Rectangle{bg_x, bg_y, bg_w, bg_h},
						0.3,
						10,
						rl.Color{0, 0, 0, 200},
					)

					for line, idx in lines {
						line_cstr := strings.clone_to_cstring(line, context.temp_allocator)
						line_size := rl.MeasureTextEx(ctx.afont, line_cstr, 22, 0)
						line_x := f32(ctx.ax) + (f32(ctx.aw) - line_size.x) / 2.0

						rl.DrawTextEx(
							ctx.afont,
							line_cstr,
							{line_x, start_y + f32(idx) * line_spacing},
							22,
							0,
							rl.WHITE,
						)
					}
				}
			}

			text_y := f32(ctx.y) + (f32(ctx.h) - text_size.y) / 2.0
			text_color := ctx.active_idx == i ? rl.WHITE : rl.LIGHTGRAY
			rl.DrawTextEx(ctx.font, cstr, {current_x + padding_x, text_y}, 18, 0, text_color)

			x_color := (hover_btn && !dialog_open) ? rl.WHITE : rl.GRAY
			if hover_btn && !dialog_open {
				center_x := btn_rect.x + btn_rect.width / 2.0
				center_y := btn_rect.y + btn_rect.height / 2.0
				radius := btn_rect.width / 2.0 + 2.0
				rl.DrawCircleV(rl.Vector2{center_x, center_y}, radius, rl.RED)
			}

			margin :: 2.0
			rl.DrawLineEx(
				{btn_rect.x + margin, btn_rect.y + margin},
				{btn_rect.x + btn_rect.width - margin, btn_rect.y + btn_rect.height - margin},
				2.0,
				x_color,
			)
			rl.DrawLineEx(
				{btn_rect.x + btn_rect.width - margin, btn_rect.y + margin},
				{btn_rect.x + margin, btn_rect.y + btn_rect.height - margin},
				2.0,
				x_color,
			)

			current_x += tab_w + gap
		}

		if swap_target >= 0 {
			dragged_tab := ctx.tab_list[ctx.dragging_idx]

			if swap_target > ctx.dragging_idx {
				for j in ctx.dragging_idx ..< swap_target {
					ctx.tab_list[j] = ctx.tab_list[j + 1]
				}
			} else {
				for j := ctx.dragging_idx; j > swap_target; j -= 1 {
					ctx.tab_list[j] = ctx.tab_list[j - 1]
				}
			}

			ctx.tab_list[swap_target] = dragged_tab
			ctx.active_idx = swap_target
			ctx.dragging_idx = swap_target
		}

		if closed_idx >= 0 {
			ordered_remove(&ctx.tab_list, closed_idx)

			if ctx.active_idx == closed_idx {
				ctx.active_idx = max(0, closed_idx - 1)
			} else if ctx.active_idx > closed_idx {
				ctx.active_idx -= 1
			}

			ctx.dragging_idx = -1

			if len(ctx.tab_list) == 0 {
				ctx.active_idx = -1
			}
		}
	}

	if dialog_open {
		rl.DrawRectangle(ctx.ax, ctx.ay, ctx.aw, ctx.ah, rl.Color{0, 0, 0, 150})

		dialog_w: f32 = 420.0
		dialog_h: f32 = 220.0
		dialog_x := f32(ctx.ax) + (f32(ctx.aw) - dialog_w) / 2.0
		dialog_y := f32(ctx.ay) + (f32(ctx.ah) - dialog_h) / 2.0

		dialog_rect := rl.Rectangle{dialog_x, dialog_y, dialog_w, dialog_h}

		rl.DrawRectangleRounded(dialog_rect, 0.1, 10, rl.Color{40, 40, 40, 255})

		title_cstr := strings.clone_to_cstring("Aviso", context.temp_allocator)
		rl.DrawTextEx(ctx.afont, title_cstr, {dialog_x + 20.0, dialog_y + 15.0}, 22, 0, rl.WHITE)
		rl.DrawLineEx(
			{dialog_x + 20.0, dialog_y + 45.0},
			{dialog_x + dialog_w - 20.0, dialog_y + 45.0},
			1.0,
			rl.Color{80, 80, 80, 255},
		)

		max_text_w := dialog_w - 40.0
		words := strings.fields(ctx.alert_message, context.temp_allocator)

		current_line := ""
		lines := make([dynamic]string, context.temp_allocator)

		for word in words {
			test_line: string
			if len(current_line) == 0 {
				test_line = word
			} else {
				test_line = strings.concatenate({current_line, " ", word}, context.temp_allocator)
			}

			test_cstr := strings.clone_to_cstring(test_line, context.temp_allocator)
			size := rl.MeasureTextEx(ctx.afont, test_cstr, 22, 0)

			if size.x > max_text_w && len(current_line) > 0 {
				append(&lines, current_line)
				current_line = word
			} else {
				current_line = test_line
			}
		}
		if len(current_line) > 0 {
			append(&lines, current_line)
		}

		text_start_y := dialog_y + 60.0
		line_spacing: f32 = 22.0
		for line, idx in lines {
			line_cstr := strings.clone_to_cstring(line, context.temp_allocator)
			rl.DrawTextEx(
				ctx.afont,
				line_cstr,
				{dialog_x + 20.0, text_start_y + f32(idx) * line_spacing},
				22,
				0,
				rl.LIGHTGRAY,
			)
		}

		btn_w: f32 = 100.0
		btn_h: f32 = 36.0
		btn_x := dialog_x + dialog_w - btn_w - 20.0
		btn_y := dialog_y + dialog_h - btn_h - 15.0
		btn_rect := rl.Rectangle{btn_x, btn_y, btn_w, btn_h}

		hover_close_btn := rl.CheckCollisionPointRec(mouse_pos, btn_rect)
		btn_color := hover_close_btn ? rl.Color{70, 70, 70, 255} : rl.Color{50, 50, 50, 255}
		if hover_close_btn do rl.SetMouseCursor(.POINTING_HAND)
		else do rl.SetMouseCursor(.DEFAULT)

		rl.DrawRectangleRounded(btn_rect, 0.2, 10, btn_color)

		btn_txt_cstr := strings.clone_to_cstring("Fechar", context.temp_allocator)
		btn_txt_size := rl.MeasureTextEx(ctx.font, btn_txt_cstr, 18, 0)
		btn_txt_x := btn_x + (btn_w - btn_txt_size.x) / 2.0
		btn_txt_y := btn_y + (btn_h - btn_txt_size.y) / 2.0
		rl.DrawTextEx(ctx.font, btn_txt_cstr, {btn_txt_x, btn_txt_y}, 18, 0, rl.WHITE)

		if real_clicked && hover_close_btn {
			ctx.alert_message = ""
		}
	}
}
