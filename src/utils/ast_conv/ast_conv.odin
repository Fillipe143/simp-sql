package ast_conv

import "core:fmt"
import "core:strings"

import "../../app/tree"
import "../sql"

convert_ast_to_tree :: proc(stmts: []sql.Statement) -> tree.Node {
	root := tree.new_tree("AST_ROOT")

	for stmt in stmts {
		switch s in stmt {
		case sql.Query:
			child := query_to_node(s)
			append(&root.childrens, child)
		case:
			unknown := tree.new_tree("UNKNOWN_STATEMENT")
			append(&root.childrens, unknown)
		}
	}

	return root
}

@(private)
query_to_node :: proc(q: sql.Query) -> tree.Node {
	node := tree.new_tree("SELECT")

	if len(q.projections) > 0 {
		proj_node := tree.new_tree("PROJECTIONS")
		for p in q.projections {
			append(&proj_node.childrens, identifier_to_node(p))
		}
		append(&node.childrens, proj_node)
	}

	if len(q.from_tables) > 0 {
		from_node := tree.new_tree("FROM")
		for f in q.from_tables {
			append(&from_node.childrens, identifier_to_node(f))
		}
		append(&node.childrens, from_node)
	}

	if len(q.joins) > 0 {
		joins_node := tree.new_tree("JOINS")
		for j in q.joins {
			join_str := fmt.aprintf("%v JOIN", j.type)
			j_node := tree.new_tree(join_str)

			append(&j_node.childrens, identifier_to_node(j.table))

			if j.condition != nil {
				on_node := tree.new_tree("ON")
				append(&on_node.childrens, expression_to_node(j.condition^))
				append(&j_node.childrens, on_node)
			}

			append(&joins_node.childrens, j_node)
		}
		append(&node.childrens, joins_node)
	}

	if q.where_cond != nil {
		where_node := tree.new_tree("WHERE")

		cond_ptr := q.where_cond.?

		append(&where_node.childrens, expression_to_node(cond_ptr^))
		append(&node.childrens, where_node)
	}

	return node
}

@(private)
identifier_to_node :: proc(ident: sql.Identifier) -> tree.Node {
	str: string
	if ident.table != "" {
		str = fmt.aprintf("%s.%s", ident.table, ident.name)
	} else {
		str = strings.clone(ident.name)
	}

	if ident.alias != "" {
		temp := str
		str = fmt.aprintf("%s AS %s", temp, ident.alias)
		delete(temp) 
	}

	return tree.new_tree(str)
}

@(private)
expression_to_node :: proc(expr: sql.Expression) -> tree.Node {
	switch e in expr {
	case sql.Identifier:
		return identifier_to_node(e)

	case sql.Literal:
		val_str := fmt.aprintf("%v", e.value)
		return tree.new_tree(val_str)

	case sql.BinaryExpr:
		op_str := fmt.aprintf("%v", e.op)
		node := tree.new_tree(op_str)

		if e.left != nil {
			append(&node.childrens, expression_to_node(e.left^))
		}
		if e.right != nil {
			append(&node.childrens, expression_to_node(e.right^))
		}

		return node

	case:
		return tree.new_tree("UNKNOWN_EXPR")
	}
}
