package menu

import "core:fmt"
import "../../utils/editor"
import "../../utils/sql"
import "core:os"
import "core:os/os2"
import "core:strings"

open_file :: proc(ctx: ^Context) {
	desc := os2.Process_Desc {
		command = []string {
			"zenity",
			"--file-selection",
			"--title=Selecione o arquivo SQL",
			"--file-filter=Arquivos SQL | *.sql",
		},
	}

	state, stdout, stderr, err := os2.process_exec(desc, context.temp_allocator)
	if err != nil || !state.success do return

	path := strings.trim_space(string(stdout))
	if len(path) == 0 do return

	data, read_ok := os.read_entire_file(path, context.temp_allocator)
	if !read_ok do return

	content := string(data)
	ctx.ctx_editor.editor = editor.new_editor(content)
	ctx.ctx_editor.focus = true
}

show_hieroglyphs :: proc(ctx: ^Context) {
	content := editor.get_all_text(&ctx.ctx_editor.editor, context.temp_allocator)
	lexer := sql.new_lexer(transmute([]byte)content)
    parser := sql.new_parser(lexer)
    ast, err := sql.parse_all(&parser)
    if err.occured do fmt.println(err.message)
    else do fmt.println(ast)
}
