package editor

import rl "vendor:raylib"

Mode :: enum {
	NORMAL,
	INSERT,
}

Action :: enum {
	NONE,
	DELETE,
    G,
}

Keyboard :: struct {
	mode:            Mode,
	last_input_time: f64,
	pending_action:  Action,
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
    ctrl := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
    pressed_char := rl.GetCharPressed()
    prev_pending := ctx.keyboard.pending_action
    action = true

    switch {
    case key_is_actionable(.ESCAPE, ctx):
        ctx.keyboard.pending_action = .NONE
    case key_is_actionable(.H, ctx):
        move_left(&ctx.editor)
    case key_is_actionable(.J, ctx):
        move_down(&ctx.editor)
    case key_is_actionable(.K, ctx):
        move_up(&ctx.editor)
    case key_is_actionable(.L, ctx):
        move_right(&ctx.editor)
    case pressed_char == '0':
        x, y := get_cursor(&ctx.editor)
        move_start(&ctx.editor)
        pending_delete(ctx, x, y)
    case pressed_char == '$':
        x, y := get_cursor(&ctx.editor)
        move_end(&ctx.editor)
        pending_delete(ctx, x, y)
    case key_is_actionable(.U, ctx):
        undo(&ctx.editor)
    case key_is_actionable(.R, ctx) && ctrl:
        redo(&ctx.editor)
    case key_is_actionable(.I, ctx):
        commit_undo(&ctx.editor)
        ctx.keyboard.mode = .INSERT
        if shift do move_start(&ctx.editor)
        else do move_left(&ctx.editor)
    case key_is_actionable(.A, ctx):
        commit_undo(&ctx.editor)
        ctx.keyboard.mode = .INSERT
        if shift do move_end(&ctx.editor)
    case key_is_actionable(.O, ctx):
        commit_undo(&ctx.editor)
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
        commit_undo(&ctx.editor)
        remove(&ctx.editor)
        move_right(&ctx.editor)
    case key_is_actionable(.X, ctx):
        commit_undo(&ctx.editor)
        remove(&ctx.editor)
        move_right(&ctx.editor)
    case key_is_actionable(.W, ctx):
        x, y := get_cursor(&ctx.editor)
        next_word(&ctx.editor)
        pending_delete(ctx, x, y)
    case key_is_actionable(.B, ctx):
        x, y := get_cursor(&ctx.editor)
        prev_word(&ctx.editor)
        pending_delete(ctx, x, y)
    case key_is_actionable(.E, ctx):
        x, y := get_cursor(&ctx.editor)
        next_word(&ctx.editor)
        move_left(&ctx.editor)
        pending_delete(ctx, x, y)
    case key_is_actionable(.D, ctx):
        if ctx.keyboard.pending_action != .DELETE {
            ctx.keyboard.pending_action = .DELETE
            return true
        }
        commit_undo(&ctx.editor)
        delete_current_line(&ctx.editor)
        ctx.keyboard.pending_action = .NONE
    case key_is_actionable(.G, ctx):
        if ctx.keyboard.pending_action == .G {
            move_to_first_line(&ctx.editor)
            ctx.keyboard.pending_action = .NONE
        } else if shift {
            move_to_last_line(&ctx.editor)
            ctx.keyboard.pending_action = .NONE
        } else {
            ctx.keyboard.pending_action = .G
        }
    case:
        action = false
    }

    if action && prev_pending == ctx.keyboard.pending_action {
        ctx.keyboard.pending_action = .NONE
    }

    return action
}

pending_delete :: proc(ctx: ^Context, x, y: int) {
    if ctx.keyboard.pending_action == .DELETE {
        commit_undo(&ctx.editor)
        delete_between_cursors(&ctx.editor, x, y)
        ctx.keyboard.pending_action = .NONE
    }
}
