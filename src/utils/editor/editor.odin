package editor

import "core:strings"
import z "../zipper"
import "core:unicode"
import "core:unicode/utf8"

Editor_Snapshot :: struct {
	text:     string,
	cursor_x: int,
	cursor_y: int,
}

Editor :: struct {
	data:          z.Zipper(z.Zipper(rune)),
	target_column: int,
	undo_stack:    [dynamic]Editor_Snapshot,
	redo_stack:    [dynamic]Editor_Snapshot,
}

new_editor :: proc(data: string) -> Editor {
	e: Editor
    e.undo_stack = make([dynamic]Editor_Snapshot)
    e.redo_stack = make([dynamic]Editor_Snapshot)
	e.data = z.Zipper(z.Zipper(rune)) {
		left  = make([dynamic]z.Zipper(rune)),
		right = make([dynamic]z.Zipper(rune)),
	}

	if len(data) == 0 {
		first_line := z.new_zipper(make([dynamic]rune, 0))
		append(&e.data.right, first_line)
        commit_undo(&e)
		return e
	}

	lines := make([dynamic]z.Zipper(rune))
	current_line_runes := make([dynamic]rune)

	for char in data {
		if char == '\r' {
			continue
		} else if char == '\n' {
			append(&lines, z.new_zipper(current_line_runes))
			current_line_runes = make([dynamic]rune)
		} else {
			append(&current_line_runes, char)
		}
	}

	append(&lines, z.new_zipper(current_line_runes))

	for i := len(lines) - 1; i >= 0; i -= 1 {
		append(&e.data.right, lines[i])
	}

	delete(lines)
    commit_undo(&e)
	return e
}

set_column_to_target :: proc(e: ^Editor) {
	if line := z.current(&e.data); line != nil {
		for len(line.left) > 0 do z.move_left(line)
		for _ in 0 ..< e.target_column {
			if len(line.right) > 0 do z.move_right(line)
			else do break
		}
	}
}

move_left :: proc(e: ^Editor) {
	if line := z.current(&e.data); line != nil {
		if len(line.left) > 0 {
			z.move_left(line)
			e.target_column = len(line.left)
		}
	}
}

move_right :: proc(e: ^Editor) {
	if line := z.current(&e.data); line != nil {
		if len(line.right) > 0 {
			z.move_right(line)
			e.target_column = len(line.left)
		}
	}
}

move_up :: proc(e: ^Editor) {
	if len(e.data.left) > 0 {
		z.move_left(&e.data)
		set_column_to_target(e)
	}
}

move_down :: proc(e: ^Editor) {
	if len(e.data.right) > 1 {
		z.move_right(&e.data)
		set_column_to_target(e)
	}
}

move_start :: proc(e: ^Editor) {
	if line := z.current(&e.data); line != nil {
		for len(line.left) > 0 {
			z.move_left(line)
		}
		e.target_column = 0
	}
}

move_end :: proc(e: ^Editor) {
	if line := z.current(&e.data); line != nil {
		for len(line.right) > 0 {
			z.move_right(line)
		}
		e.target_column = len(line.left)
	}
}

next_word :: proc(e: ^Editor) {
	line := z.current(&e.data)
	if line == nil do return

	for len(line.right) > 0 && unicode.is_alpha(line.right[len(line.right) - 1]) {
		z.move_right(line)
	}

	for len(line.right) > 0 && !unicode.is_alpha(line.right[len(line.right) - 1]) {
		z.move_right(line)
	}

	e.target_column = len(line.left)
}

prev_word :: proc(e: ^Editor) {
	line := z.current(&e.data)
	if line == nil do return

	for len(line.left) > 0 && !unicode.is_alpha(line.left[len(line.left) - 1]) {
		z.move_left(line)
	}

	for len(line.left) > 0 && unicode.is_alpha(line.left[len(line.left) - 1]) {
		z.move_left(line)
	}

	e.target_column = len(line.left)
}

insert :: proc(e: ^Editor, char: rune) {
	if line_ptr := z.current(&e.data); line_ptr != nil {
		if char == '\n' {
			next_line := z.Zipper(rune) {
				left  = make([dynamic]rune),
				right = line_ptr.right,
			}
			line_ptr.right = make([dynamic]rune)
			current_line_val := pop(&e.data.right)
			z.insert_left(&e.data, current_line_val)
			z.insert_right(&e.data, next_line)
			e.target_column = 0
		} else {
			z.insert_left(line_ptr, char)
			e.target_column = len(line_ptr.left)
		}
	}
}

remove :: proc(e: ^Editor, allow_line_merge: bool = false) {
	line := z.current(&e.data)
	if line == nil do return

	if len(line.left) > 0 {
		z.remove_left(line)
		e.target_column = len(line.left)
	} else if allow_line_merge && len(e.data.left) > 0 {
		current_line := pop(&e.data.right)
		z.move_left(&e.data)

		upper_line := z.current(&e.data)
		e.target_column = len(upper_line.left)

		for c in current_line.left do z.insert_left(upper_line, c)
		for c in current_line.right do z.insert_right(upper_line, c)

		z.destroy(&current_line)
	}
}

delete_char :: proc(e: ^Editor, allow_line_merge: bool = false) {
	line_ptr := z.current(&e.data)
	if line_ptr == nil do return

	if len(line_ptr.right) > 0 {
		z.remove_right(line_ptr)
		e.target_column = len(line_ptr.left)
	} else if allow_line_merge && len(e.data.right) > 1 {
		current_line_val := pop(&e.data.right)
		next_line_ptr := z.current(&e.data)

		for c in next_line_ptr.left {
			z.insert_right(&current_line_val, c)
		}
		#reverse for c in next_line_ptr.right {
			z.insert_right(&current_line_val, c)
		}

		next_line_val := pop(&e.data.right)
		z.destroy(&next_line_val)
		append(&e.data.right, current_line_val)
		e.target_column = len(current_line_val.left)
	}
}

get_line :: proc(e: ^Editor, i: int) -> string {
	total_lines := z.length(&e.data)
	if i < 0 || i >= total_lines do return ""

	line_ptr: ^z.Zipper(rune)
	if i < len(e.data.left) {
		line_ptr = &e.data.left[i]
	} else {
		dist := i - len(e.data.left)
		idx := (len(e.data.right) - 1) - dist
		line_ptr = &e.data.right[idx]
	}

	line_data := z.join(line_ptr, context.temp_allocator)
	line_string := utf8.runes_to_string(line_data[:], context.temp_allocator)
	return line_string
}

line_count :: proc(e: ^Editor) -> int {
	return z.length(&e.data)
}

get_cursor :: proc(e: ^Editor) -> (int, int) {
	row := len(e.data.left)
	col := 0

	if line_ptr := z.current(&e.data); line_ptr != nil {
		col = len(line_ptr.left)
	}

	return col, row
}

delete_current_line :: proc(e: ^Editor) {
	if len(e.data.right) == 0 do return

	current_line := pop(&e.data.right)
	z.destroy(&current_line)

	if len(e.data.right) == 0 {
		if len(e.data.left) > 0 {
			z.move_left(&e.data)
		} else {
			empty_line := z.new_zipper(make([dynamic]rune, 0))
			append(&e.data.right, empty_line)
		}
	}

	set_column_to_target(e)
}

delete_between_cursors :: proc(e: ^Editor, other_x, other_y: int) {
	curr_x, curr_y := get_cursor(e)

	start_x, start_y, end_x, end_y: int
	if curr_y < other_y || (curr_y == other_y && curr_x < other_x) {
		start_x, start_y = curr_x, curr_y
		end_x, end_y = other_x, other_y
	} else {
		start_x, start_y = other_x, other_y
		end_x, end_y = curr_x, curr_y
	}

	for len(e.data.left) > start_y do z.move_left(&e.data)
	for len(e.data.left) < start_y do z.move_right(&e.data)

	line_start := z.current(&e.data)
	if line_start == nil do return

	if start_y == end_y {
		for len(line_start.left) > start_x do z.move_left(line_start)
		for len(line_start.left) < start_x do z.move_right(line_start)

		dist := end_x - start_x
		for _ in 0 ..< dist {
			if len(line_start.right) > 0 do z.remove_right(line_start)
		}
	} else {
		for len(line_start.left) > start_x do z.move_left(line_start)
		for len(line_start.left) < start_x do z.move_right(line_start)
		clear(&line_start.right) 

		for len(e.data.left) < end_y do z.move_right(&e.data)
		line_end_val := pop(&e.data.right) 

		for len(e.data.left) > start_y {
			mid_line := pop(&e.data.left)
			z.destroy(&mid_line)
		}

		for len(line_end_val.left) > end_x do z.move_left(&line_end_val)
		for len(line_end_val.left) < end_x do z.move_right(&line_end_val)

		line_start.right = line_end_val.right
		delete(line_end_val.left)
	}

	e.target_column = start_x
	set_column_to_target(e)
}

save_to_snapshot :: proc(e: ^Editor) -> Editor_Snapshot {
    x, y := get_cursor(e)
    all_lines: [dynamic]string
    defer delete(all_lines)
    
    for i in 0 ..< line_count(e) {
        append(&all_lines, get_line(e, i))
    }
    
    return Editor_Snapshot{
        text     = strings.join(all_lines[:], "\n", context.allocator),
        cursor_x = x,
        cursor_y = y,
    }
}

commit_undo :: proc(e: ^Editor) {
    append(&e.undo_stack, save_to_snapshot(e))
    for len(e.redo_stack) > 0 {
        s := pop(&e.redo_stack)
        delete(s.text)
    }
}

undo :: proc(e: ^Editor) {
    if len(e.undo_stack) == 0 do return
    append(&e.redo_stack, save_to_snapshot(e))
    snap := pop(&e.undo_stack)
    restore_from_snapshot(e, snap)
    delete(snap.text)
}

redo :: proc(e: ^Editor) {
    if len(e.redo_stack) == 0 do return
    append(&e.undo_stack, save_to_snapshot(e))
    snap := pop(&e.redo_stack)
    restore_from_snapshot(e, snap)
    delete(snap.text)
}

restore_from_snapshot :: proc(e: ^Editor, snap: Editor_Snapshot) {
    for len(e.data.left) > 0  { l := pop(&e.data.left);  z.destroy(&l) }
    for len(e.data.right) > 0 { l := pop(&e.data.right); z.destroy(&l) }
    
    temp_editor := new_editor(snap.text)
    e.data = temp_editor.data
    
    for _ in 0 ..< snap.cursor_y do move_down(e)
    e.target_column = snap.cursor_x
    set_column_to_target(e)
}

move_to_first_line :: proc(e: ^Editor) {
    for len(e.data.left) > 0 {
        z.move_left(&e.data)
    }
    set_column_to_target(e)
}

move_to_last_line :: proc(e: ^Editor) {
    for len(e.data.right) > 1 {
        z.move_right(&e.data)
    }
    set_column_to_target(e)
}
