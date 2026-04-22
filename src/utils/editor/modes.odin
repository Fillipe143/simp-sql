package editor

import rl "vendor:raylib"

Mode :: enum {
	NORMAL,
	INSERT,
	VISUAL,
}

Keyboard :: struct {
	mode:            Mode,
	last_input_time: f64,
	repeat_timer:    f64,
	repeat_delay:    f64,
	repeat_rate:     f64,
}

default_keyboard :: proc() -> Keyboard {
	return Keyboard{mode = .INSERT, repeat_delay = 0.3, repeat_rate = 0.03}
}

read_input :: proc(ctx: ^Context) {
	has_action := false

	switch ctx.keyboard.mode {
	case .NORMAL:
		has_action = normal_mode_logic(ctx)
	case .INSERT:
		has_action = insert_mode_logic(ctx)
	case .VISUAL:
		has_action = visual_mode_logic(ctx)
	}

	if has_action do ctx.keyboard.last_input_time = rl.GetTime()
}

key_is_actionable :: proc(key: rl.KeyboardKey, ctx: ^Context) -> bool {
	if rl.IsKeyPressed(key) {
		ctx.keyboard.repeat_timer = 0
		return true
	}

	if rl.IsKeyDown(key) {
		ctx.keyboard.repeat_timer += f64(rl.GetFrameTime())
		if ctx.keyboard.repeat_timer >= ctx.keyboard.repeat_delay {
			ctx.keyboard.repeat_timer = ctx.keyboard.repeat_delay - ctx.keyboard.repeat_rate
			return true
		}
	}
	return false
}

insert_mode_logic :: proc(ctx: ^Context) -> (action: bool) {
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	action = true

	switch {
	case key_is_actionable(.BACKSPACE, ctx):
		remove(&ctx.editor, true)
	case key_is_actionable(.DELETE, ctx):
		delete_char(&ctx.editor, true)
	case key_is_actionable(.ENTER, ctx):
		insert(&ctx.editor, '\n')
	case key_is_actionable(.TAB, ctx):
		for i := 0; i < 4; i += 1 do insert(&ctx.editor, ' ')
	case key_is_actionable(.LEFT, ctx):
		move_left(&ctx.editor)
	case key_is_actionable(.RIGHT, ctx):
		move_right(&ctx.editor)
	case key_is_actionable(.UP, ctx):
		move_up(&ctx.editor)
	case key_is_actionable(.DOWN, ctx):
		move_down(&ctx.editor)
	case key_is_actionable(.ESCAPE, ctx):
		ctx.keyboard.mode = .NORMAL
	case:
		action = false
	}

	for c := rl.GetCharPressed(); c != 0; c = rl.GetCharPressed() {
		insert(&ctx.editor, c)
		action = true
	}

	return action
}

normal_mode_logic :: proc(ctx: ^Context) -> (action: bool) {
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	pressed_char := rl.GetCharPressed()
	action = true

	switch {
	case key_is_actionable(.H, ctx):
		move_left(&ctx.editor)
	case key_is_actionable(.J, ctx):
		move_down(&ctx.editor)
	case key_is_actionable(.K, ctx):
		move_up(&ctx.editor)
	case key_is_actionable(.L, ctx):
		move_right(&ctx.editor)
	case pressed_char == '0':
		move_start(&ctx.editor)
	case pressed_char == '$':
		move_end(&ctx.editor)
	case key_is_actionable(.I, ctx):
        // TODO resolver problema quando left tiver vazio
		ctx.keyboard.mode = .INSERT
		if shift do move_start(&ctx.editor)
		else do move_left(&ctx.editor)
	case key_is_actionable(.A, ctx):
        // TODO resolver problema quando left tiver vazio
		ctx.keyboard.mode = .INSERT
		if shift do move_end(&ctx.editor)
	case key_is_actionable(.O, ctx):
		ctx.keyboard.mode = .INSERT
		if shift {
			move_start(&ctx.editor)
			insert(&ctx.editor, '\n')
			move_up(&ctx.editor)
		} else {
			move_end(&ctx.editor)
			insert(&ctx.editor, '\n')
			move_down(&ctx.editor)
		}
	case key_is_actionable(.DELETE, ctx):
		remove(&ctx.editor)
        move_right(&ctx.editor)
	case key_is_actionable(.X, ctx):
		remove(&ctx.editor)
        move_right(&ctx.editor)
    case key_is_actionable(.W, ctx):
        next_word(&ctx.editor)
    case key_is_actionable(.B, ctx):
        prev_word(&ctx.editor)
    case key_is_actionable(.E, ctx):
        next_word(&ctx.editor)
        move_left(&ctx.editor)
	case:
		action = false
	}
	return action
}

visual_mode_logic :: proc(ctx: ^Context) -> (action: bool) {
	return action
}
