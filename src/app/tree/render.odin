package tree

import "../../utils/color"
import "core:strings"
import rl "vendor:raylib"

Context :: struct {
	x, y, w, h: i32,
	font:       rl.Font,
	root:       Node,
	camera:     rl.Camera2D,
	dragged:    ^Node,
}

Node :: struct {
	value:     string,
	color:     rl.Color,
	x, y:      f32,
	vx, vy:    f32,
	childrens: [dynamic]Node,
}

new_tree :: proc(root_value: string) -> Node {
	return {
		value = root_value,
		color = color.random(),
		x = 0,
		y = 0,
		vx = 0,
		vy = 0,
		childrens = make([dynamic]Node),
	}
}

add_child :: proc(parent: ^Node, child_value: string) {
	node := new_tree(child_value)
	node.y = parent.y + 100
	node.x = parent.x + f32(len(parent.childrens) * 120)
	append(&parent.childrens, node)
}

new_context :: proc(x, y, w, h: i32, root: Node) -> Context {
	cam := rl.Camera2D {
		target   = {0, 0},
		offset   = {f32(w) / 2, f32(h) / 4},
		rotation = 0.0,
		zoom     = 1.0,
	}
	return Context {
		x = x,
		y = y,
		w = w,
		h = h,
		root = root,
		camera = cam,
		dragged = nil,
		font = rl.LoadFontEx("assets/fonts/JetBrainsMonoNerdFont-Regular.ttf", 48, nil, 8192),
	}
}

render :: proc(ctx: ^Context) {
	rl.BeginScissorMode(ctx.x, ctx.y, ctx.w, ctx.h)
	defer rl.EndScissorMode()

	handle_input(ctx)

	update_physics(ctx, &ctx.root, ctx.root.x, ctx.root.y, ctx.dragged)

	rl.BeginMode2D(ctx.camera)
	draw_connections(&ctx.root)
	draw_nodes(ctx, &ctx.root)
	rl.EndMode2D()
}

randomize_tree_colors :: proc(node: ^Node) {
    node.color = color.random()
    node.x, node.y = 0, 0
    for i in 0 ..< len(node.childrens) {
        randomize_tree_colors(&node.childrens[i])
    }
}

handle_input :: proc(ctx: ^Context) {
	mouse_pos := rl.GetMousePosition()

	if mouse_pos.x < f32(ctx.x) ||
	   mouse_pos.x > f32(ctx.x + ctx.w) ||
	   mouse_pos.y < f32(ctx.y) ||
	   mouse_pos.y > f32(ctx.y + ctx.h) {
		if rl.IsMouseButtonReleased(.LEFT) do ctx.dragged = nil
		return
	}

	mouse_world := rl.GetScreenToWorld2D(mouse_pos, ctx.camera)

	if rl.IsMouseButtonPressed(.LEFT) {
		ctx.dragged = find_node_under_mouse(ctx, &ctx.root, mouse_world.x, mouse_world.y)
	}

	if rl.IsMouseButtonReleased(.LEFT) {
		ctx.dragged = nil
	}

    if rl.IsKeyPressed(.R) {
        randomize_tree_colors(&ctx.root)
    }

	if rl.IsMouseButtonDown(.LEFT) {
		if ctx.dragged != nil {
			ctx.dragged.x = mouse_world.x
			ctx.dragged.y = mouse_world.y
		} else {
			delta := rl.GetMouseDelta()
			ctx.camera.target.x -= delta.x / ctx.camera.zoom
			ctx.camera.target.y -= delta.y / ctx.camera.zoom
		}
	}

	if rl.IsMouseButtonDown(.RIGHT) || rl.IsMouseButtonDown(.MIDDLE) {
		delta := rl.GetMouseDelta()
		ctx.camera.target.x -= delta.x / ctx.camera.zoom
		ctx.camera.target.y -= delta.y / ctx.camera.zoom
	}

	wheel := rl.GetMouseWheelMove()
	if wheel != 0 {
		mouse_world_before := rl.GetScreenToWorld2D(mouse_pos, ctx.camera)
		ctx.camera.zoom += wheel * 0.1
		ctx.camera.zoom = clamp(ctx.camera.zoom, f32(0.2), f32(5.0))
		mouse_world_after := rl.GetScreenToWorld2D(mouse_pos, ctx.camera)

		ctx.camera.target.x -= (mouse_world_after.x - mouse_world_before.x)
		ctx.camera.target.y -= (mouse_world_after.y - mouse_world_before.y)
	}
}

get_node_dimensions :: proc(ctx: ^Context, node: ^Node) -> (w: f32, h: f32) {
	cstr := strings.clone_to_cstring(node.value, context.temp_allocator)
	defer delete(cstr, context.temp_allocator)

	text_size := rl.MeasureTextEx(ctx.font, cstr, 24, 0)
	padding_x :: 24.0
	padding_y :: 16.0

	return text_size.x + padding_x * 2, text_size.y + padding_y * 2
}

get_subtree_width :: proc(ctx: ^Context, node: ^Node, gap_x: f32) -> f32 {
	node_w, _ := get_node_dimensions(ctx, node)
	num_children := len(node.childrens)

	if num_children == 0 do return node_w

	children_w: f32 = 0
	for i in 0 ..< num_children {
		children_w += get_subtree_width(ctx, &node.childrens[i], gap_x)
	}
	children_w += f32(num_children - 1) * gap_x

	return max(node_w, children_w)
}

update_physics :: proc(ctx: ^Context, node: ^Node, ideal_x, ideal_y: f32, dragged_node: ^Node) {
	SPRING_K :: 0.1
	DAMPING :: 0.8

	if node != dragged_node {
		fx := (ideal_x - node.x) * SPRING_K
		fy := (ideal_y - node.y) * SPRING_K

		node.vx = (node.vx + fx) * DAMPING
		node.vy = (node.vy + fy) * DAMPING

		node.x += node.vx
		node.y += node.vy
	} else {
		node.vx = 0
		node.vy = 0
	}

	gap_x :: 40.0
	spacing_y :: 100.0
	num_children := len(node.childrens)

	if num_children > 0 {
		subtree_widths := make([]f32, num_children, context.temp_allocator)
		relative_x := make([]f32, num_children, context.temp_allocator)
		defer delete(subtree_widths, context.temp_allocator)
		defer delete(relative_x, context.temp_allocator)

		for i in 0 ..< num_children {
			subtree_widths[i] = get_subtree_width(ctx, &node.childrens[i], gap_x)
		}

		current_offset: f32 = 0
		for i in 0 ..< num_children {
			relative_x[i] = current_offset + subtree_widths[i] / 1.5
			current_offset += subtree_widths[i] + gap_x
		}

		center_of_children: f32 = 0
		if num_children == 1 {
			center_of_children = relative_x[0]
		} else {
			center_of_children = (relative_x[0] + relative_x[num_children - 1]) / 2.0
		}

		for i in 0 ..< num_children {
			child := &node.childrens[i]

			cx := node.x + (relative_x[i] - center_of_children)
			cy := node.y + spacing_y

			update_physics(ctx, child, cx, cy, dragged_node)
		}
	}
}

find_node_under_mouse :: proc(ctx: ^Context, node: ^Node, mx, my: f32) -> ^Node {
	rect_w, rect_h := get_node_dimensions(ctx, node)

	left := node.x - rect_w / 2
	right := node.x + rect_w / 2
	top := node.y - rect_h / 2
	bottom := node.y + rect_h / 2

	if mx >= left && mx <= right && my >= top && my <= bottom {
		return node
	}

	for i in 0 ..< len(node.childrens) {
		found := find_node_under_mouse(ctx, &node.childrens[i], mx, my)
		if found != nil do return found
	}

	return nil
}

draw_connections :: proc(node: ^Node) {
	for i in 0 ..< len(node.childrens) {
		child := &node.childrens[i]
		rl.DrawLineEx(
			rl.Vector2{node.x, node.y},
			rl.Vector2{child.x, child.y},
			3.0,
			rl.DARKGRAY,
		)
		draw_connections(child)
	}
}

draw_nodes :: proc(ctx: ^Context, node: ^Node) {
	rect_w, rect_h := get_node_dimensions(ctx, node)

	rect := rl.Rectangle {
		x      = node.x - rect_w / 2,
		y      = node.y - rect_h / 2,
		width  = rect_w,
		height = rect_h,
	}

	roundness :: 0.3
	segments :: 16
	rl.DrawRectangleRounded(rect, roundness, segments, node.color)

	cstr := strings.clone_to_cstring(node.value, context.temp_allocator)
	defer delete(cstr, context.temp_allocator)
	text_size := rl.MeasureTextEx(ctx.font, cstr, 24, 0)

	text_pos := rl.Vector2{node.x - text_size.x / 2, node.y - text_size.y / 2}
	rl.DrawTextEx(ctx.font, cstr, text_pos, 24, 0, rl.WHITE)

	for i in 0 ..< len(node.childrens) {
		draw_nodes(ctx, &node.childrens[i])
	}
}
