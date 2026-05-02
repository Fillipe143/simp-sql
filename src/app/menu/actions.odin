package menu

import "../../utils/ast_conv"
import "../../utils/editor"
import "../../utils/sql"
import "../tree"
import "../tabs"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"

new_file :: proc(ctx: ^Context) {
	editor_ctx := new(editor.Context)
	editor_ctx^ = editor.new_context(
		ctx.tab_ctx.ax,
		ctx.tab_ctx.ay,
		ctx.tab_ctx.aw,
		ctx.tab_ctx.ah,
	)
	editor_ctx.focus = true
	tabs.add_tab(ctx.tab_ctx, "query", .EDITOR, rawptr(editor_ctx))
}

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
	if err != nil || !state.success {
		tabs.show_alert(ctx.tab_ctx, "Não foi possível abrir o arquivo")
		return
	}

	path := strings.trim_space(string(stdout))
	if len(path) == 0 {
		tabs.show_alert(ctx.tab_ctx, "Não foi possível abrir o arquivo")
		return
	}

	data, read_ok := os.read_entire_file(path, context.temp_allocator)
	if !read_ok {
		tabs.show_alert(ctx.tab_ctx, "Não foi possível abrir o arquivo")
		return
	}

	content := string(data)
	base_name := filepath.base(path)
	editor_ctx := new(editor.Context)
	editor_ctx^ = editor.new_context(
		ctx.tab_ctx.ax,
		ctx.tab_ctx.ay,
		ctx.tab_ctx.aw,
		ctx.tab_ctx.ah,
	)
	editor_ctx.editor = editor.new_editor(content)
	editor_ctx.focus = true
	tabs.add_tab(ctx.tab_ctx, base_name, .EDITOR, rawptr(editor_ctx))
}

show_hieroglyphs :: proc(ctx: ^Context) {
    curr_tab := tabs.active_tab(ctx.tab_ctx)
    if curr_tab.type != .EDITOR {
	    tabs.show_alert(ctx.tab_ctx, "É necessário estar em um contexto de editor para utilizar esta função");
        return
    }
    editor_ctx := cast(^editor.Context)curr_tab.app_ctx
	content := editor.get_all_text(&editor_ctx.editor, context.temp_allocator)
	lexer := sql.new_lexer(transmute([]byte)content)
	parser := sql.new_parser(lexer)
	ast, err := sql.parse_all(&parser)
	if err.occured {
        tabs.show_alert(ctx.tab_ctx, err.message)
        return
    } 
    root_node := ast_conv.convert_ast_to_tree(ast[:])
	tree_ctx := new(tree.Context)
	tree_ctx^ = tree.new_context(
		ctx.tab_ctx.ax,
		ctx.tab_ctx.ay,
		ctx.tab_ctx.aw,
		ctx.tab_ctx.ah,
        root_node,
	)
	tabs.add_tab(ctx.tab_ctx, "ast", .TREE, rawptr(tree_ctx))
}
