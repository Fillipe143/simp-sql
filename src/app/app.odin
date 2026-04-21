package app

import "../utils/editor"
import rl "vendor:raylib"

start :: proc() {
	rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
	rl.InitWindow(800, 600, "SQL Editor")
    rl.SetExitKey(.KEY_NULL)
	rl.SetTargetFPS(60)

	editor_ctx := editor.new_context(10, 10, 780, 580)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		editor.render(&editor_ctx)
		rl.EndDrawing()
	}

	rl.CloseWindow()
}
