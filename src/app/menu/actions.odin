package menu

import "../../utils/algebra"
import "../../utils/color"
import "../../utils/editor"
import "../../utils/sql"
import "../table"
import "../tabs"
import "../tree"
import "core:fmt"
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
	base_name := fmt.tprintf("query%d", ctx.tab_ctx.counter)
	tabs.add_tab(ctx.tab_ctx, base_name, .EDITOR, rawptr(editor_ctx))
	ctx.tab_ctx.counter += 1
}

open_file :: proc(ctx: ^Context) {
	desc := os2.Process_Desc {
		command = []string {
			"zenity",
			"--file-selection",
			"--title=Selecione o arquivo SQL",
			"--file-filter=Arquivos SQL | *.sql",
			"--filename=./",
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

get_algebra :: proc(ctx: ^Context) -> ^algebra.RelNode {
	curr_tab := tabs.active_tab(ctx.tab_ctx)
	if curr_tab.type != .EDITOR {
		tabs.show_alert(
			ctx.tab_ctx,
			"É necessário estar em um contexto de editor para utilizar esta função",
		)
		return nil
	}
	editor_ctx := cast(^editor.Context)curr_tab.app_ctx
	content := editor.get_all_text(&editor_ctx.editor, context.temp_allocator)
	lexer := sql.new_lexer(transmute([]byte)content)
	parser := sql.new_parser(lexer)
	ast, err := sql.parse_all(&parser)
	if err.occured {
		tabs.show_alert(ctx.tab_ctx, err.message)
		return nil
	}

	if len(ast) == 0 {
		tabs.show_alert(ctx.tab_ctx, "Nenhum comando SQL encontrado.")
		return nil
	}

	query, is_query := ast[0].(sql.Query)
	if !is_query {
		tabs.show_alert(
			ctx.tab_ctx,
			"Por enquanto, apenas comandos SELECT podem ser convertidos para Álgebra Relacional.",
		)
		return nil
	}

	ar_tree, tree_err := algebra.convert_to_relational_algebra(query)
	if tree_err != "" {
		tabs.show_alert(ctx.tab_ctx, tree_err)
		return nil
	}
	return ar_tree
}

show_algebra :: proc(ctx: ^Context) {
	ar_tree := get_algebra(ctx)
	if ar_tree == nil do return

	root_node := algebra.build_ui_tree(ar_tree)
	tree_ctx := new(tree.Context)
	tree_ctx^ = tree.new_context(
		ctx.tab_ctx.ax,
		ctx.tab_ctx.ay,
		ctx.tab_ctx.aw,
		ctx.tab_ctx.ah,
		root_node,
	)
    message := algebra.tree_to_linear_string(ar_tree)
	base_name := fmt.tprintf("algebra(%s)", tabs.active_tab(ctx.tab_ctx).title)
	tabs.add_tab(ctx.tab_ctx, base_name, .TREE, rawptr(tree_ctx), message)
}

optimized_algebra :: proc(ctx: ^Context) {
	ar_tree := get_algebra(ctx)
	if ar_tree == nil do return
	ar_tree = algebra.optimize_tree(ar_tree)

	root_node := algebra.build_ui_tree(ar_tree)
	tree_ctx := new(tree.Context)
	tree_ctx^ = tree.new_context(
		ctx.tab_ctx.ax,
		ctx.tab_ctx.ay,
		ctx.tab_ctx.aw,
		ctx.tab_ctx.ah,
		root_node,
	)
    message := algebra.tree_to_linear_string(ar_tree)
	base_name := fmt.tprintf("algebra_otimizada(%s)", tabs.active_tab(ctx.tab_ctx).title)
	tabs.add_tab(ctx.tab_ctx, base_name, .TREE, rawptr(tree_ctx), message)
}

show_plan :: proc(ctx: ^Context) {
    ar_tree := get_algebra(ctx)
    if ar_tree == nil do return

    ar_tree = algebra.optimize_tree(ar_tree)
    plan := algebra.generate_execution_plan(ar_tree)
    root_node := tree.Node{}

    if len(plan) > 0 {
        last_idx := len(plan) - 1
        root_node.value = plan[last_idx]
        root_node.childrens = make([dynamic]tree.Node)
        root_node.color = color.random()
        
        for i := last_idx - 1; i >= 0; i -= 1 {
            parent := tree.Node{
                value = plan[i],
                childrens = make([dynamic]tree.Node),
                color = color.random(),
            }
            append(&parent.childrens, root_node)
            root_node = parent
        }
    }

    tree_ctx := new(tree.Context)
    tree_ctx^ = tree.new_context(
        ctx.tab_ctx.ax,
        ctx.tab_ctx.ay,
        ctx.tab_ctx.aw,
        ctx.tab_ctx.ah,
        root_node,
    )
    
    base_name := fmt.tprintf("Plano de Execução (%s)", tabs.active_tab(ctx.tab_ctx).title)
    tabs.add_tab(ctx.tab_ctx, base_name, .TREE, rawptr(tree_ctx))
}

show_tables :: proc(ctx: ^Context) {
	table_ptr := new(table.Context)
	table_ptr^ = table.new_context(ctx.tab_ctx.ax, ctx.tab_ctx.ay, ctx.tab_ctx.aw, ctx.tab_ctx.ah)
	table.setup_database_diagram(table_ptr)
	tabs.add_tab(ctx.tab_ctx, "SQL Schema", .TABLE, rawptr(table_ptr))
}
