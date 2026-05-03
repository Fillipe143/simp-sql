package algebra

import "../../utils/color"
import "../../app/tree"
import "../sql"
import "core:fmt"
import "core:strings"

RelOperator :: enum {
	Projection,
	Selection,
	Join,
	CartesianProduct,
	Table,
}

RelNode :: struct {
	op:    RelOperator,
	label: string,
	left:  ^RelNode,
	right: ^RelNode,
}

@(private)
new_rel_node :: proc(
	op: RelOperator,
	label: string,
	left: ^RelNode = nil,
	right: ^RelNode = nil,
) -> ^RelNode {
	node := new(RelNode)
	node.op = op
	node.label = label
	node.left = left
	node.right = right
	return node
}

@(private)
format_projections :: proc(projections: [dynamic]sql.Identifier) -> string {
	if len(projections) == 0 do return "*"

	sb := strings.builder_make()
	for p, i in projections {
		if i > 0 do strings.write_string(&sb, ", ")
		if p.table != "" {
			strings.write_string(&sb, p.table)
			strings.write_string(&sb, ".")
		}
		strings.write_string(&sb, p.name)
	}
	return strings.to_string(sb)
}

@(private)
expr_to_string :: proc(expr: ^sql.Expression) -> string {
	if expr == nil do return ""

	switch e in expr^ {
	case sql.BinaryExpr:
		op_str := fmt.tprintf("%v", e.op)
		if op_str == "EQ" do op_str = "="
		else if op_str == "GT" do op_str = ">"
		else if op_str == "LT" do op_str = "<"
		else if op_str == "GTE" || op_str == "GE" do op_str = ">="
		else if op_str == "LTE" || op_str == "LE" do op_str = "<="
		else if op_str == "NEQ" || op_str == "NE" do op_str = "!="

		return fmt.tprintf("%s %s %s", expr_to_string(e.left), op_str, expr_to_string(e.right))

	case sql.Identifier:
		if e.table != "" do return fmt.tprintf("%s.%s", e.table, e.name)
		return e.name

	case sql.Literal:
		switch v in e.value {
		case string:
			return fmt.tprintf("'%s'", v)
		case f64:
			return fmt.tprintf("%v", v)
		case bool:
			return fmt.tprintf("%v", v)
		}
	}
	return ""
}

convert_to_relational_algebra :: proc(query: sql.Query) -> (^RelNode, string) {
	if len(query.from_tables) == 0 do return nil, "Query inválida: Nenhuma tabela especificada no FROM."

	for t in query.from_tables {
		if !is_valid_table(t.name) do return nil, fmt.tprintf("Erro Semântico: A tabela '%s' não existe.", t.name)
	}
	for j in query.joins {
		if !is_valid_table(j.table.name) do return nil, fmt.tprintf("Erro Semântico: A tabela '%s' não existe.", j.table.name)
	}
	for p in query.projections {
		err := validate_column_in_query(query, p.table, p.name)
		if err != "" do return nil, err
	}
	if query.where_cond != nil {
		err := validate_expr_columns(query.where_cond.?, query)
		if err != "" do return nil, err
	}
	for j in query.joins {
		if j.condition != nil {
			err := validate_expr_columns(j.condition, query)
			if err != "" do return nil, err
		}
	}

	t0_str := query.from_tables[0].name
	if query.from_tables[0].alias != "" do t0_str = fmt.tprintf("%s %s", query.from_tables[0].name, query.from_tables[0].alias)
	current_node := new_rel_node(.Table, fmt.tprintf("Tabela: %s", t0_str))

	for i in 1 ..< len(query.from_tables) {
		ti_str := query.from_tables[i].name
		if query.from_tables[i].alias != "" do ti_str = fmt.tprintf("%s %s", query.from_tables[i].name, query.from_tables[i].alias)
		t_node := new_rel_node(.Table, fmt.tprintf("Tabela: %s", ti_str))
		current_node = new_rel_node(.CartesianProduct, "X (Cartesiano)", current_node, t_node)
	}

	join_conditions := make([dynamic]string)
	for j in query.joins {
		j_str := j.table.name
		if j.table.alias != "" do j_str = fmt.tprintf("%s %s", j.table.name, j.table.alias)
		join_table := new_rel_node(.Table, fmt.tprintf("Tabela: %s", j_str))
		current_node = new_rel_node(.CartesianProduct, "X (Cartesiano)", current_node, join_table)

		if j.condition != nil {
			append(&join_conditions, expr_to_string(j.condition))
		}
	}

	where_str := ""
	if query.where_cond != nil {
		where_str = expr_to_string(query.where_cond.?)
	}

	all_conditions := ""
	if where_str != "" do all_conditions = where_str
	for cond in join_conditions {
		if all_conditions != "" do all_conditions = fmt.tprintf("%s AND %s", all_conditions, cond)
		else do all_conditions = cond
	}

	if all_conditions != "" {
		sel_label := fmt.tprintf("σ (%s)", all_conditions)
		current_node = new_rel_node(.Selection, sel_label, current_node)
	}

	if len(query.projections) > 0 {
		proj_label := fmt.tprintf("π %s", format_projections(query.projections))
		current_node = new_rel_node(.Projection, proj_label, current_node)
	}

	return current_node, ""
}

@(private)
valid_column :: proc(t_name: string, col: string) -> bool {
	switch t_name {
	case "Categoria":
		return col == "idCategoria" || col == "Descricao"
	case "Produto":
		return(
			col == "idProduto" ||
			col == "Nome" ||
			col == "Descricao" ||
			col == "Preco" ||
			col == "QuantEstoque" ||
			col == "Categoria_idCategoria" \
		)
	case "TipoCliente":
		return col == "idTipoCliente" || col == "Descricao"
	case "Cliente":
		return(
			col == "idCliente" ||
			col == "Nome" ||
			col == "Email" ||
			col == "Nascimento" ||
			col == "Senha" ||
			col == "TipoCliente_idTipoCliente" ||
			col == "DataRegistro" \
		)
	case "TipoEndereco":
		return col == "idTipoEndereco" || col == "Descricao"
	case "Endereco":
		return(
			col == "idEndereco" ||
			col == "EnderecoPadrao" ||
			col == "Logradouro" ||
			col == "Numero" ||
			col == "Complemento" ||
			col == "Bairro" ||
			col == "Cidade" ||
			col == "UF" ||
			col == "CEP" ||
			col == "TipoEndereco_idTipoEndereco" ||
			col == "Cliente_idCliente" \
		)
	case "Telefone":
		return col == "Numero" || col == "Cliente_idCliente"
	case "Status":
		return col == "idStatus" || col == "Descricao"
	case "Pedido":
		return(
			col == "idPedido" ||
			col == "Status_idStatus" ||
			col == "DataPedido" ||
			col == "ValorTotalPedido" ||
			col == "Cliente_idCliente" \
		)
	case "Pedido_has_Produto":
		return(
			col == "idPedidoProduto" ||
			col == "Pedido_idPedido" ||
			col == "Produto_idProduto" ||
			col == "Quantidade" ||
			col == "PrecoUnitario" \
		)
	}
	return false
}

@(private)
column_belongs_to_table :: proc(col_expr: string, table_label: string) -> bool {
	col := strings.trim_space(col_expr)
	t_label, _ := strings.replace(table_label, "Tabela: ", "", 1)
	t_label = strings.trim_space(t_label)

	parts := strings.split(t_label, " ")
	t_name := parts[0]
	t_alias := ""
	if len(parts) > 1 do t_alias = parts[1]

	col_parts := strings.split(col, ".")
	col_base := col
	c_alias := ""
	if len(col_parts) > 1 {
		c_alias = col_parts[0]
		col_base = strings.trim_space(col_parts[1])
	}

	if c_alias != "" && t_alias != "" {
		if c_alias != t_alias do return false
	}

	return valid_column(t_name, col_base)
}

@(private)
collect_tables :: proc(node: ^RelNode, list: ^[dynamic]^RelNode) {
	if node == nil do return
	if node.op == .Table {
		append(list, node)
		return
	}
	collect_tables(node.left, list)
	collect_tables(node.right, list)
}

@(private)
branch_provides_column :: proc(node: ^RelNode, col: string) -> bool {
	if node == nil do return false
	if node.op == .Table {
		return column_belongs_to_table(col, node.label)
	}
	return branch_provides_column(node.left, col) || branch_provides_column(node.right, col)
}

optimize_tree :: proc(root: ^RelNode) -> ^RelNode {
	if root == nil || root.op != .Projection do return root
	if root.left == nil || root.left.op != .Selection do return root

	proj_text, _ := strings.replace(root.label, "π ", "", 1)
	final_cols := strings.split(proj_text, ",")
	for i in 0 ..< len(final_cols) do final_cols[i] = strings.trim_space(final_cols[i])

	sel_node := root.left
	cond_text, _ := strings.replace(sel_node.label, "σ (", "", 1)
	cond_text, _ = strings.replace(cond_text, ")", "", 1)
	all_conditions := strings.split(cond_text, " AND ")

	filters := make([dynamic]string)
	joins := make([dynamic]string)
	defer {delete(filters); delete(joins)}

	for c in all_conditions {
		if strings.contains(c, "'") ||
		   strings.contains(c, ">") ||
		   strings.contains(c, "<") ||
		   strings.contains(c, "!=") {
			append(&filters, c)
		} else if strings.contains(c, " = ") {
			append(&joins, c)
		}
	}

	tables_nodes := make([dynamic]^RelNode)
	defer delete(tables_nodes)
	collect_tables(sel_node.left, &tables_nodes)

	branches := make([dynamic]^RelNode)
	defer delete(branches)

	for t in tables_nodes {
		my_filters := make([dynamic]string)
		for f in filters {
			clean_f, _ := strings.replace_all(f, "'", "")
			f_parts := strings.split(clean_f, " ")
			for p in f_parts {
				if column_belongs_to_table(p, t.label) {
					append(&my_filters, f)
					break
				}
			}
		}

		my_cols := make([dynamic]string)

		for fc in final_cols {
			if column_belongs_to_table(fc, t.label) {
				found := false
				for c in my_cols {if c == fc do found = true}
				if !found do append(&my_cols, fc)
			}
		}

		for j in joins {
			parts := strings.split(j, " = ")
			if len(parts) == 2 {
				p0 := strings.trim_space(parts[0])
				p1 := strings.trim_space(parts[1])
				if column_belongs_to_table(p0, t.label) {
					found := false
					for c in my_cols {if c == p0 do found = true}
					if !found do append(&my_cols, p0)
				}
				if column_belongs_to_table(p1, t.label) {
					found := false
					for c in my_cols {if c == p1 do found = true}
					if !found do append(&my_cols, p1)
				}
			}
		}

		curr := t
		if len(my_filters) > 0 {
			joined_filters := strings.join(my_filters[:], " AND ")
			curr = new_rel_node(.Selection, fmt.tprintf("σ %s", joined_filters), curr)
		}
		if len(my_cols) > 0 {
			joined_cols := strings.join(my_cols[:], ", ")
			curr = new_rel_node(.Projection, fmt.tprintf("π %s", joined_cols), curr)
		}

		if len(my_filters) > 0 {
			inject_at(&branches, 0, curr)
		} else {
			append(&branches, curr)
		}
	}

	if len(branches) == 0 do return root

	current_tree := branches[0]
	ordered_remove(&branches, 0)

	for len(branches) > 0 {
		best_idx := 0
		join_cond := ""
		join_cond_idx := -1

		for b_idx := 0; b_idx < len(branches); b_idx += 1 {
			cand_branch := branches[b_idx]

			for j, j_idx in joins {
				parts := strings.split(j, " = ")
				if len(parts) == 2 {
					c1, c2 := strings.trim_space(parts[0]), strings.trim_space(parts[1])

					l_has_1 := branch_provides_column(current_tree, c1)
					r_has_2 := branch_provides_column(cand_branch, c2)
					l_has_2 := branch_provides_column(current_tree, c2)
					r_has_1 := branch_provides_column(cand_branch, c1)

					if (l_has_1 && r_has_2) || (l_has_2 && r_has_1) {
						join_cond = j
						join_cond_idx = j_idx
						best_idx = b_idx
						break
					}
				}
			}
			if join_cond != "" do break
		}

		right_branch := branches[best_idx]
		ordered_remove(&branches, best_idx)

		join_node := new_rel_node(.Join, "|X|")
		if join_cond != "" {
			join_node.label = fmt.tprintf("|X| %s", join_cond)
			ordered_remove(&joins, join_cond_idx)
		}
		join_node.left = current_tree
		join_node.right = right_branch

		current_tree = join_node

		if len(branches) > 0 {
			needed_cols := make([dynamic]string)

			for fc in final_cols {
				if branch_provides_column(current_tree, fc) {
					found := false
					for c in needed_cols {if c == fc do found = true}
					if !found do append(&needed_cols, fc)
				}
			}

			for j in joins {
				parts := strings.split(j, " = ")
				if len(parts) == 2 {
					p0 := strings.trim_space(parts[0])
					p1 := strings.trim_space(parts[1])

					if branch_provides_column(current_tree, p0) {
						found := false
						for c in needed_cols {if c == p0 do found = true}
						if !found do append(&needed_cols, p0)
					}
					if branch_provides_column(current_tree, p1) {
						found := false
						for c in needed_cols {if c == p1 do found = true}
						if !found do append(&needed_cols, p1)
					}
				}
			}

			if len(needed_cols) > 0 {
				joined_cols := strings.join(needed_cols[:], ", ")
				current_tree = new_rel_node(
					.Projection,
					fmt.tprintf("π %s", joined_cols),
					current_tree,
				)
			}
		}
	}

	root.left = current_tree
	return root
}

build_ui_tree :: proc(rel_node: ^RelNode) -> tree.Node {
	ui_node := tree.Node{}

	if rel_node == nil do return ui_node

	ui_node.value = rel_node.label
	ui_node.color = color.random()
	ui_node.childrens = make([dynamic]tree.Node)

	if rel_node.left != nil {
		left_ui := build_ui_tree(rel_node.left)
		append(&ui_node.childrens, left_ui)
	}

	if rel_node.right != nil {
		right_ui := build_ui_tree(rel_node.right)
		append(&ui_node.childrens, right_ui)
	}

	return ui_node
}

print_tree :: proc(node: ^RelNode, depth: int = 0, prefix: string = "") {
	if node == nil do return

	for i in 0 ..< depth {
		fmt.print("  ")
	}

	fmt.printf("%s%s\n", prefix, node.label)

	print_tree(node.left, depth + 1, "L: ")
	print_tree(node.right, depth + 1, "R: ")
}

@(private)
is_valid_table :: proc(t_name: string) -> bool {
	switch t_name {
	case "Categoria",
	     "Produto",
	     "TipoCliente",
	     "Cliente",
	     "TipoEndereco",
	     "Endereco",
	     "Telefone",
	     "Status",
	     "Pedido",
	     "Pedido_has_Produto":
		return true
	}
	return false
}

@(private)
validate_column_in_query :: proc(query: sql.Query, col_alias: string, col_name: string) -> string {
	if col_name == "*" do return ""

	found_in_any := false
	valid_alias := false

	check_table :: proc(
		t_name, t_alias, c_alias, c_name: string,
		found_in_any, valid_alias: ^bool,
	) {
		if c_alias != "" {
			if c_alias == t_alias || c_alias == t_name {
				valid_alias^ = true
				if valid_column(t_name, c_name) do found_in_any^ = true
			}
		} else {
			if valid_column(t_name, c_name) do found_in_any^ = true
		}
	}

	for t in query.from_tables {
		check_table(t.name, t.alias, col_alias, col_name, &found_in_any, &valid_alias)
	}
	for j in query.joins {
		check_table(j.table.name, j.table.alias, col_alias, col_name, &found_in_any, &valid_alias)
	}

	if col_alias != "" && !valid_alias {
		return fmt.tprintf(
			"Erro Semântico: A tabela/apelido '%s' na coluna '%s.%s' não foi declarada.",
			col_alias,
			col_alias,
			col_name,
		)
	}

	if !found_in_any {
		if col_alias != "" {
			return fmt.tprintf(
				"Erro Semântico: A coluna '%s' não existe na tabela '%s'.",
				col_name,
				col_alias,
			)
		} else {
			return fmt.tprintf(
				"Erro Semântico: A coluna '%s' não existe em nenhuma tabela consultada.",
				col_name,
			)
		}
	}
	return ""
}

@(private)
validate_expr_columns :: proc(expr: ^sql.Expression, query: sql.Query) -> string {
	if expr == nil do return ""
	switch e in expr^ {
	case sql.BinaryExpr:
		err := validate_expr_columns(e.left, query)
		if err != "" do return err
		return validate_expr_columns(e.right, query)
	case sql.Identifier:
		return validate_column_in_query(query, e.table, e.name)
	case sql.Literal:
		return ""
	}
	return ""
}

generate_execution_plan :: proc(root: ^RelNode) -> [dynamic]string {
	steps := make([dynamic]string)
	step_counter := 1

	_post_order_traverse(root, &steps, &step_counter)

	return steps
}

@(private)
_post_order_traverse :: proc(node: ^RelNode, steps: ^[dynamic]string, counter: ^int) {
	if node == nil do return
	_post_order_traverse(node.left, steps, counter)
	_post_order_traverse(node.right, steps, counter)

	op_name := ""
	switch node.op {
	case .Table:
		op_name = "Ler"
	case .Selection:
		op_name = "Filtrar"
	case .Projection:
		op_name = "Projetar"
	case .Join:
		op_name = "Juntar"
	case .CartesianProduct:
		op_name = "Produto Cartesiano"
	}

	step_msg := fmt.tprintf("Passo %d: %s -> %s", counter^, op_name, node.label)
	append(steps, step_msg)

	counter^ += 1
}

tree_to_linear_string :: proc(node: ^RelNode) -> string {
	if node == nil do return ""

	#partial switch node.op {
	case .Table:
		clean_name, _ := strings.replace(node.label, "Tabela: ", "", 1)
		return strings.trim_space(clean_name)

	case .Selection, .Projection:
		left_str := tree_to_linear_string(node.left)
		return fmt.tprintf("%s(%s)", node.label, left_str)

	case .Join, .CartesianProduct:
		left_str := tree_to_linear_string(node.left)
		right_str := tree_to_linear_string(node.right)
		return fmt.tprintf("(%s %s %s)", left_str, node.label, right_str)
	}

	return ""
}
