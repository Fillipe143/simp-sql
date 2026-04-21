package editor

import "core:unicode/utf8"
import z "../zipper"

Editor :: struct {
    data: z.Zipper(z.Zipper(rune)),
    target_column: int,
}

new_editor :: proc(data: string) -> Editor {
    e: Editor
    e.data = z.Zipper(z.Zipper(rune)) {
        left  = make([dynamic]z.Zipper(rune)),
        right = make([dynamic]z.Zipper(rune)),
    }

    if len(data) == 0 {
        first_line := z.new_zipper(make([dynamic]rune, 0))
        append(&e.data.right, first_line)
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
        } else if len(e.data.left) > 0 {
            z.move_left(&e.data)
            if upper := z.current(&e.data); upper != nil {
                for len(upper.right) > 0 do z.move_right(upper)
                e.target_column = len(upper.left)
            }
        }
    }
}

move_right :: proc(e: ^Editor) {
    if line := z.current(&e.data); line != nil {
        if len(line.right) > 0 {
            z.move_right(line)
            e.target_column = len(line.left)
        } else if len(e.data.right) > 1 {
            z.move_right(&e.data)
            if lower := z.current(&e.data); lower != nil {
                for len(lower.left) > 0 do z.move_left(lower)
                e.target_column = 0
            }
        }
    }
}

move_up :: proc(e: ^Editor) {
    if len(e.data.left) > 0 {
        z.move_left(&e.data)
        set_column_to_target(e)
    } else if line := z.current(&e.data); line != nil {
        for len(line.left) > 0 do z.move_left(line)
        e.target_column = 0
    }
}

move_down :: proc(e: ^Editor) {
    if len(e.data.right) > 1 {
        z.move_right(&e.data)
        set_column_to_target(e)
    } else if line := z.current(&e.data); line != nil {
        for len(line.right) > 0 do z.move_right(line)
        e.target_column = len(line.left)
    }
}

insert :: proc(e: ^Editor, char: rune) {
    if line_ptr := z.current(&e.data); line_ptr != nil {
        if char == '\n' {
            next_line := z.Zipper(rune){
                left = make([dynamic]rune),
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

remove :: proc(e: ^Editor) {
    line := z.current(&e.data)
    if line == nil do return

    if len(line.left) > 0 {
        z.remove_left(line)
        e.target_column = len(line.left)
    } else if len(e.data.left) > 0 {
        current_line := pop(&e.data.right)
        z.move_left(&e.data)
        upper_line := z.current(&e.data)
        e.target_column = len(upper_line.left)
        
        for c in current_line.left do z.insert_left(upper_line, c)
        #reverse for c in current_line.right do z.insert_right(upper_line, c)
        
        z.destroy(&current_line)
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

line_count:: proc(e: ^Editor) -> int {
    return z.length(&e.data)
}

get_cursor :: proc (e: ^Editor) -> (int, int) {
    row := len(e.data.left)
    col := 0

    if line_ptr := z.current(&e.data); line_ptr != nil {
        col = len(line_ptr.left)
    }

    return col, row
}
