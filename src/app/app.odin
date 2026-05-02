package app

import "../utils/editor"
import "menu"
import "tabs"
import "tree"
import rl "vendor:raylib"

start :: proc() {
	WINDOW_W, WINDOW_H, MENU_H, TAB_H:: 1920, 1080, 40, 40
	// WINDOW_W, WINDOW_H, MENU_H, TAB_H :: 1000, 800, 40, 40
	WORKSPACE_Y :: MENU_H + TAB_H
	WORKSPACE_H :: WINDOW_H - WORKSPACE_Y

	rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
	rl.InitWindow(WINDOW_W, WINDOW_H, "Processador de consultas")
	rl.SetExitKey(.KEY_NULL)
	rl.SetTargetFPS(60)

	background := rl.LoadTexture("assets/images/background.png")
	tab_ctx := tabs.new_context(0, MENU_H, WINDOW_W, TAB_H, 0, WORKSPACE_Y, WINDOW_W, WORKSPACE_H)
	menu_ctx := menu.new_context(0, 0, WINDOW_W, MENU_H, &tab_ctx)
    last_tab_idx := -1

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground({18, 18, 18, 255})
		rl.DrawTexture(
			background,
			(WINDOW_W - background.width) / 2,
			WORKSPACE_Y + (WORKSPACE_H - background.height) / 2,
			{100, 100, 100, 255},
		)


		curr_tab := tabs.active_tab(&tab_ctx)
		switch curr_tab.type {
		case .NONE:
			break
		case .EDITOR:
            editor_ctx := cast(^editor.Context)curr_tab.app_ctx
            if last_tab_idx != tab_ctx.active_idx do editor_ctx.focus = true
			editor.render(editor_ctx)
			break
		case .TREE:
			tree.render(cast(^tree.Context)curr_tab.app_ctx)
			break
		}
        last_tab_idx = tab_ctx.active_idx

		menu.render(&menu_ctx)
		tabs.render(&tab_ctx)

		rl.EndDrawing()
	}

	rl.CloseWindow()
}
