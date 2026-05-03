package table

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

Column :: struct {
	name:  string,
	is_pk: bool,
	is_fk: bool,
}

Table :: struct {
	name:    string,
	columns: [dynamic]Column,
	x, y:    f32,
	vx, vy:  f32,
	color:   rl.Color,
	width:   f32,
	height:  f32,
}

Context :: struct {
	x, y, w, h: i32,
	font:       rl.Font,
	camera:     rl.Camera2D,
	tables:     [dynamic]Table,
	dragged:    ^Table,
}

new_context :: proc(x, y, w, h: i32) -> Context {
	cam := rl.Camera2D {
		target   = {0, 0},
		offset   = {f32(w) / 2, f32(h) / 2},
		rotation = 0.0,
		zoom     = 1.0,
	}

	return Context {
		x = x,
		y = y,
		w = w,
		h = h,
		camera = cam,
		tables = make([dynamic]Table),
		font = rl.LoadFontEx("assets/fonts/JetBrainsMonoNerdFont-Regular.ttf", 64, nil, 256),
	}
}

add_table :: proc(ctx: ^Context, name: string, cols: []string, color: rl.Color) {
	t := Table {
		name    = name,
		color   = color,
		x       = 0, 
		y       = 0, 
		columns = make([dynamic]Column),
	}

	for c in cols {
		lower_c := strings.to_lower(c, context.temp_allocator)
		is_pk := strings.contains(lower_c, "id") && !strings.contains(lower_c, "_id")
		is_fk := strings.contains(lower_c, "_id")
		append(&t.columns, Column{name = c, is_pk = is_pk, is_fk = is_fk})
	}
	append(&ctx.tables, t)
}

organize_tables :: proc(ctx: ^Context) {
    if len(ctx.tables) == 0 do return

    for i in 0 ..< len(ctx.tables) {
        w, h := get_table_dimensions(ctx, &ctx.tables[i])
        ctx.tables[i].width = w
        ctx.tables[i].height = h
    }

    adj := make([dynamic][dynamic]int, len(ctx.tables), context.temp_allocator)
    for i in 0 ..< len(ctx.tables) {
        adj[i] = make([dynamic]int, context.temp_allocator)
    }

    for i in 0 ..< len(ctx.tables) {
        for col in ctx.tables[i].columns {
            if col.is_fk {
                parent_name := strings.split(col.name, "_", context.temp_allocator)[0]
                for j in 0 ..< len(ctx.tables) {
                    if strings.equal_fold(ctx.tables[j].name, parent_name) {
                        found_j := false
                        for item in adj[i] { if item == j { found_j = true; break } }
                        if !found_j do append(&adj[i], j)

                        found_i := false
                        for item in adj[j] { if item == i { found_i = true; break } }
                        if !found_i do append(&adj[j], i)
                    }
                }
            }
        }
    }

    is_satellite := make([]bool, len(ctx.tables), context.temp_allocator)
    spine_nodes := make([dynamic]int, context.temp_allocator)

    for i in 0 ..< len(ctx.tables) {
        if len(adj[i]) <= 1 {
            is_satellite[i] = true  
        } else {
            append(&spine_nodes, i) 
        }
    }

    placed := make([]bool, len(ctx.tables), context.temp_allocator)
    
    START_X :: f32(-800.0)
    SPINE_Y :: f32(0.0)
    PAD_X   :: f32(250.0) 
    PAD_Y   :: f32(150.0) 

    current_x := START_X

    for s in spine_nodes {
        if placed[s] do continue

        curr := s
        for node in spine_nodes {
            if placed[node] do continue
            spine_degree := 0
            for n in adj[node] {
                if !is_satellite[n] do spine_degree += 1
            }
            if spine_degree <= 1 {
                curr = node
                break
            }
        }

        for {
            placed[curr] = true
            t := &ctx.tables[curr]
            t.x = current_x + (t.width / 2.0)
            t.y = SPINE_Y

            current_x += t.width + PAD_X

            next_node := -1
            for n in adj[curr] {
                if !is_satellite[n] && !placed[n] {
                    next_node = n
                    break
                }
            }
            if next_node == -1 do break
            curr = next_node
        }
        current_x += PAD_X 
    }

    sat_count := make([]int, len(ctx.tables), context.temp_allocator)

    for i in 0 ..< len(ctx.tables) {
        if placed[i] do continue

        parent := -1
        for n in adj[i] {
            parent = n
            break
        }

        t := &ctx.tables[i]

        if parent != -1 && placed[parent] {
            pt := &ctx.tables[parent]
            count := sat_count[parent]

            t.x = pt.x 
            
            if count % 2 == 0 {
                t.y = pt.y - (pt.height / 2.0) - PAD_Y - (t.height / 2.0)
            } else {
                t.y = pt.y + (pt.height / 2.0) + PAD_Y + (t.height / 2.0)
            }
            
            sat_count[parent] += 1
            placed[i] = true
        } else {
            t.x = current_x + (t.width / 2.0)
            t.y = SPINE_Y
            current_x += t.width + PAD_X
            placed[i] = true
        }
    }
}

setup_database_diagram :: proc(ctx: ^Context) {
	color_prod := rl.MAROON
	color_cli := rl.DARKBLUE
	color_ped := rl.DARKGREEN
	color_aux := rl.DARKPURPLE

	add_table(ctx, "Categoria", {"idCategoria", "Descricao"}, color_prod)
	add_table(
		ctx,
		"Produto",
		{"idProduto", "Nome", "Descricao", "Preco", "QuantEstoque", "Categoria_idCategoria"},
		color_prod,
	)
	add_table(ctx, "TipoCliente", {"idTipoCliente", "Descricao"}, color_cli)
	add_table(
		ctx,
		"Cliente",
		{
			"idCliente",
			"Nome",
			"Email",
			"Nascimento",
			"Senha",
			"TipoCliente_idTipoCliente",
			"DataRegistro",
		},
		color_cli,
	)
	add_table(ctx, "TipoEndereco", {"idTipoEndereco", "Descricao"}, color_aux)
	add_table(
		ctx,
		"Endereco",
		{
			"idEndereco",
			"EnderecoPadrao",
			"Logradouro",
			"Numero",
			"Complemento",
			"Bairro",
			"Cidade",
			"UF",
			"CEP",
			"TipoEndereco_idTipoEndereco",
			"Cliente_idCliente",
		},
		color_cli,
	)
	add_table(ctx, "Telefone", {"Numero", "Cliente_idCliente"}, color_cli)
	add_table(ctx, "Status", {"idStatus", "Descricao"}, color_ped)
	add_table(
		ctx,
		"Pedido",
		{"idPedido", "Status_idStatus", "DataPedido", "ValorTotalPedido", "Cliente_idCliente"},
		color_ped,
	)
	add_table(
		ctx,
		"Pedido_has_Produto",
		{"idPedidoProduto", "Pedido_idPedido", "Produto_idProduto", "Quantidade", "PrecoUnitario"},
		color_ped,
	)
	organize_tables(ctx)
}

@(private)
get_table_dimensions :: proc(ctx: ^Context, table: ^Table) -> (f32, f32) {
	padding :: 24.0
	line_height :: 32.0

	header_w :=
		rl.MeasureTextEx(ctx.font, strings.clone_to_cstring(table.name, context.temp_allocator), 33, 1).x

	max_w := header_w
	for col in table.columns {
		col_text := fmt.tprintf("  [%s] %s  ", col.is_pk ? "PK" : "FK", col.name)
		w :=
			rl.MeasureTextEx(ctx.font, strings.clone_to_cstring(col_text, context.temp_allocator), 33, 1).x
		if w > max_w do max_w = w
	}

	height := f32(len(table.columns)) * line_height + 60.0
	return max_w + padding, height
}

handle_input :: proc(ctx: ^Context) {
	mouse_pos := rl.GetMousePosition()
	mouse_world := rl.GetScreenToWorld2D(mouse_pos, ctx.camera)

	if rl.IsMouseButtonPressed(.LEFT) {
		for i := len(ctx.tables) - 1; i >= 0; i -= 1 {
			t := &ctx.tables[i]
			rect := rl.Rectangle{t.x - t.width / 2, t.y - t.height / 2, t.width, t.height}
			if rl.CheckCollisionPointRec(mouse_world, rect) {
				ctx.dragged = t
				break
			}
		}
	}

	if rl.IsMouseButtonReleased(.LEFT) do ctx.dragged = nil

	if rl.IsMouseButtonDown(.LEFT) {
		if ctx.dragged != nil {
			ctx.dragged.x = mouse_world.x
			ctx.dragged.y = mouse_world.y
		} else {
			delta := rl.GetMouseDelta()
			ctx.camera.target -= delta / ctx.camera.zoom
		}
	}

	wheel := rl.GetMouseWheelMove()
	if wheel != 0 {
		mouse_before := rl.GetScreenToWorld2D(mouse_pos, ctx.camera)
		ctx.camera.zoom = clamp(ctx.camera.zoom + wheel * 0.1, 0.1, 5.0)
		mouse_after := rl.GetScreenToWorld2D(mouse_pos, ctx.camera)
		ctx.camera.target -= (mouse_after - mouse_before)
	}
}

draw_connections :: proc(ctx: ^Context) {
	for &t_src in ctx.tables {
		for col in t_src.columns {
			if col.is_fk {
				parts := strings.split(col.name, "_", context.temp_allocator)
				if len(parts) < 2 do continue
				target_name := parts[0]

				for &t_dst in ctx.tables {
					if strings.equal_fold(t_dst.name, target_name) {
						start := rl.Vector2{t_src.x, t_src.y}
						end := rl.Vector2{t_dst.x, t_dst.y}

						rl.DrawLineEx(start, end, 2.5, rl.Fade(rl.SKYBLUE, 0.4))
					}
				}
			}
		}
	}
}

render :: proc(ctx: ^Context) {
	handle_input(ctx)

	rl.BeginScissorMode(ctx.x, ctx.y, ctx.w, ctx.h)
	defer rl.EndScissorMode()

	rl.BeginMode2D(ctx.camera)
	draw_connections(ctx)

	for &t in ctx.tables {
		w, h := get_table_dimensions(ctx, &t)
		t.width, t.height = w, h

		rect := rl.Rectangle{t.x - w / 2, t.y - h / 2, w, h}
		rl.DrawRectangleRounded(rect, 0.05, 12, {35, 35, 40, 255})

		header_rect := rl.Rectangle{rect.x, rect.y, rect.width, 40}
		title_cstr := strings.clone_to_cstring(t.name, context.temp_allocator)
		rl.DrawTextEx(ctx.font, title_cstr, {rect.x + 12, rect.y + 10}, 32, 1, rl.WHITE)

		for col, i in t.columns {
			col_y := rect.y + 55 + f32(i * 28)
			color := rl.LIGHTGRAY
			icon := "-"

			if col.is_pk {
				color = rl.GOLD
                icon = "PK"
			} else if col.is_fk {
				color = rl.SKYBLUE
                icon = "FK"
			}

			col_text := fmt.tprintf("[%s] %s", icon, col.name)
			rl.DrawTextEx(
				ctx.font,
				strings.clone_to_cstring(col_text, context.temp_allocator),
				{rect.x + 12, col_y},
				32,
				1,
				color,
			)
		}
	}

	rl.EndMode2D()
}
