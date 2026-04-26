package app

import "../utils/editor"
import "menu"
import rl "vendor:raylib"

start :: proc() {
    WINDOW_W, WINDOW_H, MENU_H :: 1000, 800, 40
    // WINDOW_W, WINDOW_H, MENU_H :: 1920, 1080, 40
	rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
	rl.InitWindow(WINDOW_W, WINDOW_H, "SQL Editor")
	rl.SetExitKey(.KEY_NULL)
	rl.SetTargetFPS(60)

	editor_ctx := editor.new_context(0, MENU_H, WINDOW_W, WINDOW_H - MENU_H)
	menu_ctx := menu.new_context(0, 0, WINDOW_W, MENU_H, &editor_ctx)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		if menu.render(&menu_ctx) do break
		editor.render(&editor_ctx)

		rl.EndDrawing()
	}

	rl.CloseWindow()
}
