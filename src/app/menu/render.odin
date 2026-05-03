package menu

import rl "vendor:raylib"
import "core:strings"
import "../tabs"

Context :: struct {
    x, y, w, h: i32,
    font:       rl.Font,
    tab_ctx: ^tabs.Context,
}

new_context :: proc(x, y, w, h: i32, ctx: ^tabs.Context) -> Context {
    return Context {
        x = x,
        y = y,
        w = w,
        h = h,
        font = rl.LoadFontEx("assets/fonts/JetBrainsMonoNerdFont-Regular.ttf", i32(f32(h) * 0.6), nil, 256),
        tab_ctx = ctx,
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


render :: proc(ctx: ^Context) {
    rl.DrawRectangle(ctx.x, ctx.y, ctx.w, ctx.h, {35, 35, 35, 255})
    rl.DrawLine(ctx.x, ctx.y + ctx.h, ctx.x + ctx.w, ctx.y + ctx.h, rl.DARKGRAY)

    menu_items := []string{"Abrir arquivo", "Novo arquivo", "Algebra", "Otimizar", "Execução", "Tabelas"}
    clicked, menu_hovered := render_menu_list(ctx, menu_items)

    if menu_hovered do rl.SetMouseCursor(.POINTING_HAND)
    else do rl.SetMouseCursor(.DEFAULT)

    if clicked != -1 {
        if clicked == 0 do open_file(ctx)
        else if clicked == 1 do new_file(ctx)
        else if clicked == 2 do show_algebra(ctx)
        else if clicked == 3 do optimized_algebra(ctx)
        else if clicked == 4 do show_plan(ctx)
        else if clicked == 5 do show_tables(ctx)
    }
}
