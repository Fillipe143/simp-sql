package menu

import rl "vendor:raylib"
import "core:strings"
import "../../utils/editor"

Context :: struct {
    x, y, w, h: i32,
    font:       rl.Font,
    ctx_editor: ^editor.Context,
}

new_context :: proc(x, y, w, h: i32, ctx: ^editor.Context) -> Context {
    return Context {
        x = x,
        y = y,
        w = w,
        h = h,
        font = rl.LoadFontEx("assets/fonts/JetBrainsMonoNerdFont-Regular.ttf", i32(f32(h) * 0.6), nil, 256),
        ctx_editor = ctx,
    }
}

render_menu_list :: proc(ctx: ^Context, items: []string) -> (int, bool) {
    clicked_idx := -1
    any_hovered := false
    current_x := f32(ctx.x)
    padding: f32 = 10.0

    for item, i in items {
        label_cstr := strings.clone_to_cstring(item, context.temp_allocator)
        text_size := rl.MeasureTextEx(ctx.font, label_cstr, f32(ctx.font.baseSize), 0)
        
        btn_width := text_size.x + (padding * 2)
        btn_rect := rl.Rectangle{ current_x, f32(ctx.y), btn_width, f32(ctx.h) }
        
        is_hovering := rl.CheckCollisionPointRec(rl.GetMousePosition(), btn_rect)
        if is_hovering {
            any_hovered = true
            rl.DrawRectangleRec(btn_rect, {60, 60, 60, 255})
            if rl.IsMouseButtonReleased(.LEFT) {
                clicked_idx = i
            }
        }
        
        text_pos := rl.Vector2{
            btn_rect.x + padding,
            btn_rect.y + (f32(ctx.h) - text_size.y) / 2,
        }
        
        rl.DrawTextEx(ctx.font, label_cstr, text_pos, f32(ctx.font.baseSize), 0, rl.LIGHTGRAY)
        rl.DrawLine(i32(current_x + btn_width), ctx.y, i32(current_x + btn_width), ctx.y + ctx.h, rl.DARKGRAY)
        
        current_x += btn_width
    }
    
    return clicked_idx, any_hovered
}

render_close_circle :: proc(ctx: ^Context) -> (is_clicked: bool, is_hovering: bool) {
    COLOR_IDLE   := rl.Color{230, 40, 30, 255}
    COLOR_HOVER  := rl.Color{255, 60, 50, 255}
    COLOR_ACTIVE := rl.Color{160, 0, 0, 255}

    radius := f32(ctx.h) * 0.30
    center := rl.Vector2{
        f32(ctx.x + ctx.w) - (f32(ctx.h) / 2),
        f32(ctx.y) + (f32(ctx.h) / 2),
    }

    mouse_pos := rl.GetMousePosition()
    is_hovering = rl.CheckCollisionPointCircle(mouse_pos, center, radius)
    is_pressed := is_hovering && rl.IsMouseButtonDown(.LEFT)

    circle_color := COLOR_IDLE
    x_color := rl.WHITE
    
    if is_hovering {
        circle_color = is_pressed ? COLOR_ACTIVE : COLOR_HOVER
        x_color = {255, 255, 255, 255} 
    } else {
        x_color = {255, 255, 255, 200}
    }

    rl.DrawCircleV(center, radius, circle_color)
    
    size := radius * 0.4
    start1 := rl.Vector2{ center.x - size, center.y - size }
    end1   := rl.Vector2{ center.x + size, center.y + size }
    start2 := rl.Vector2{ center.x + size, center.y - size }
    end2   := rl.Vector2{ center.x - size, center.y + size }
    rl.DrawLineEx(start1, end1, 2.0, x_color)
    rl.DrawLineEx(start2, end2, 2.0, x_color)

    is_clicked = is_hovering && rl.IsMouseButtonReleased(.LEFT)
    return
}

render :: proc(ctx: ^Context) -> bool {
    rl.DrawRectangle(ctx.x, ctx.y, ctx.w, ctx.h, {35, 35, 35, 255})
    rl.DrawLine(ctx.x, ctx.y + ctx.h, ctx.x + ctx.w, ctx.y + ctx.h, rl.DARKGRAY)

    menu_items := []string{"Abrir arquivo", "Exibir hieroglifos"}
    clicked, menu_hovered := render_menu_list(ctx, menu_items)
    close_clicked, close_hovered := render_close_circle(ctx)

    if menu_hovered || close_hovered do rl.SetMouseCursor(.POINTING_HAND)
    else do rl.SetMouseCursor(.DEFAULT)

    if clicked != -1 {
        if clicked == 0 do open_file(ctx)
    }
    
    return close_clicked
}
