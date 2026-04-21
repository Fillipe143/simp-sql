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
	return Keyboard{mode = .NORMAL, repeat_delay = 0.3, repeat_rate = 0.03}
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

reset_blink :: proc(ctx: ^Context) {
	ctx.keyboard.last_input_time = rl.GetTime()
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

	if has_action do reset_blink(ctx)
}

insert_mode_logic :: proc(ctx: ^Context) -> bool {
	action := false

	for c := rl.GetCharPressed(); c != 0; c = rl.GetCharPressed() {
		insert(&ctx.editor, c)
		action = true
	}

	if key_is_actionable(.BACKSPACE, ctx) {remove(&ctx.editor); action = true}
	if key_is_actionable(.ENTER, ctx) {insert(&ctx.editor, '\n'); action = true}
	if key_is_actionable(.LEFT, ctx) {move_left(&ctx.editor); action = true}
	if key_is_actionable(.RIGHT, ctx) {move_right(&ctx.editor); action = true}
	if key_is_actionable(.UP, ctx) {move_up(&ctx.editor); action = true}
	if key_is_actionable(.DOWN, ctx) {move_down(&ctx.editor); action = true}
	if key_is_actionable(.TAB, ctx) {for i:= 0; i < 3; i+=1 do insert(&ctx.editor, ' '); action = true}

	if rl.IsKeyPressed(.ESCAPE) {
		ctx.keyboard.mode = .NORMAL
		action = true
	}

	return action
}

normal_mode_logic :: proc(ctx: ^Context) -> bool {
	action := false

	if key_is_actionable(.H, ctx) ||
	   key_is_actionable(.LEFT, ctx) {move_left(&ctx.editor); action = true}
	if key_is_actionable(.L, ctx) ||
	   key_is_actionable(.RIGHT, ctx) {move_right(&ctx.editor); action = true}
	if key_is_actionable(.J, ctx) ||
	   key_is_actionable(.DOWN, ctx) {move_down(&ctx.editor); action = true}
	if key_is_actionable(.K, ctx) ||
	   key_is_actionable(.UP, ctx) {move_up(&ctx.editor); action = true}

	if rl.IsKeyPressed(.I) {
		ctx.keyboard.mode = .INSERT
		action = true; move_left(&ctx.editor)
	}

    if rl.IsKeyPressed(.O) {
		action = true
		ctx.keyboard.mode = .INSERT
        insert(&ctx.editor, '\n')
        move_up(&ctx.editor)
    }

    if rl.IsKeyPressed(.X) {
		action = true
        remove(&ctx.editor)
    }
	if rl.IsKeyPressed(.A) {
		ctx.keyboard.mode = .INSERT
		action = true
	}
	if rl.IsKeyPressed(.V) {ctx.keyboard.mode = .VISUAL; action = true}

	return action
}

visual_mode_logic :: proc(ctx: ^Context) -> bool {
	if rl.IsKeyPressed(.ESCAPE) {
		ctx.keyboard.mode = .NORMAL
		return true
	}
	return false
}
