package sql

import "core:fmt"
import "core:strconv"

Parse_Error :: struct {
	occured:  bool,
	message:  string,
	row, col: uint,
}

@(private)
error_fmt :: proc(p: ^Parser, expected: string) -> Parse_Error {
	msg := fmt.tprintf(
		"[%d:%d] Erro: esperado %s, mas obteve '%s'",
		p.current.start.row,
		p.current.start.col,
		expected,
		p.current.value,
	)
	return Parse_Error{true, msg, p.current.start.row, p.current.start.col}
}

Parser :: struct {
	lexer:   Lexer,
	current: Token,
	peek:    Token,
}

new_parser :: proc(l: Lexer) -> Parser {
	p := Parser {
		lexer = l,
	}
	p.current = next_token(&p.lexer)
	p.peek = next_token(&p.lexer)
	return p
}

parse_all :: proc(p: ^Parser) -> ([dynamic]Statement, Parse_Error) {
	stmts := make([dynamic]Statement)
	for p.current.kind != .EOF {
		if expect(p, .SEMICOLON) do continue

		stmt, err := parse_statement(p)
		if err.message != "" do return stmts, err

		append(&stmts, stmt)

		if p.current.kind != .SEMICOLON && p.current.kind != .EOF {
			return stmts, error_fmt(p, "';'")
		}
		expect(p, .SEMICOLON)
	}
	return stmts, {}
}

@(private)
parse_statement :: proc(p: ^Parser) -> (Statement, Parse_Error) {
	#partial switch p.current.kind {
	case .SELECT:
		return parse_query(p)
	case:
		return nil, error_fmt(p, "SELECT")
	}
}

@(private)
parse_query :: proc(p: ^Parser) -> (Query, Parse_Error) {
	query: Query
	err: Parse_Error

	advance(p) // consome SELECT

	query.projections, err = parse_list(p)
	if err.message != "" do return {}, err

	if !expect(p, .FROM) do return {}, error_fmt(p, "FROM")

	query.from_tables, err = parse_list(p)
	if err.message != "" do return {}, err

	for is_join_start(p.current.kind) {
		join, j_err := parse_join(p)
		if j_err.message != "" do return {}, j_err
		append(&query.joins, join)
	}

	if expect(p, .WHERE) {
		query.where_cond, err = parse_expression(p)
		if err.message != "" do return {}, err
	}

	return query, {}
}

@(private)
parse_alias :: proc(p: ^Parser) -> string {
    expect(p, .AS) 
    
    if p.current.kind == .IDENTIFIER {
        alias := p.current.value
        advance(p)
        return alias
    }
    return ""
}

@(private)
parse_identifier :: proc(p: ^Parser) -> (Identifier, Parse_Error) {
    ident: Identifier
    token_atual := p.current

    if !expect(p, .IDENTIFIER) && !expect(p, .ASTERISK) {
        return {}, error_fmt(p, "IDENTIFIER ou '*'")
    }

    if expect(p, .DOT) {
        if token_atual.kind == .ASTERISK {
            return {}, Parse_Error{true, "'*' não pode ser usado como nome de tabela", token_atual.start.row, token_atual.start.col}
        }
        
        ident.table = token_atual.value
        column_token := p.current

        if !expect(p, .IDENTIFIER) && !expect(p, .ASTERISK) {
            return {}, error_fmt(p, "IDENTIFIER ou '*' após o ponto")
        }
        ident.name = column_token.value
    } else {
        ident.table = ""
        ident.name = token_atual.value
    }

    if p.current.kind == .AS {
        advance(p) // consome "AS"
        if p.current.kind == .IDENTIFIER {
            ident.alias = p.current.value
            advance(p)
        } else {
            return {}, error_fmt(p, "IDENTIFIER para o apelido")
        }
    } else if p.current.kind == .IDENTIFIER {
        ident.alias = p.current.value
        advance(p)
    }

    return ident, {}
}

@(private)
parse_join :: proc(p: ^Parser) -> (JoinClause, Parse_Error) {
	join: JoinClause
	join.type = p.current.kind

	if !expect(p, .LEFT) && !expect(p, .INNER) && !expect(p, .RIGHT) {
		join.type = .INNER
	}

	if !expect(p, .JOIN) do return {}, error_fmt(p, "JOIN")

	table, t_err := parse_identifier(p)
	if t_err.message != "" do return {}, t_err
	join.table = table

	if !expect(p, .ON) do return {}, error_fmt(p, "ON")

	cond, c_err := parse_expression(p)
	if c_err.message != "" do return {}, c_err
	join.condition = cond

	return join, {}
}

@(private)
parse_atomic :: proc(p: ^Parser) -> (^Expression, Parse_Error) {
	#partial switch p.current.kind {
	case .IDENTIFIER, .ASTERISK:
		node := new(Expression)
		ident, err := parse_identifier(p)
		if err.message != "" {free(node); return nil, err}
		node^ = ident
		return node, {}
	case .STRING:
		node := new(Expression); node^ = Literal{p.current.value}
		advance(p); return node, {}
	case .NUMBER:
		node := new(Expression)
		val, ok := strconv.parse_f64(p.current.value)
		if !ok do return nil, Parse_Error{true, fmt.tprintf("valor numérico inválido: %s", p.current.value), p.current.start.row, p.current.start.col}
		node^ = Literal{val}
		advance(p); return node, {}
	case .LPAREN:
		advance(p)
		expr, err := parse_expression(p)
		if err.message != "" do return nil, err
		if !expect(p, .RPAREN) do return nil, error_fmt(p, "')'")
		return expr, {}
	case:
		return nil, error_fmt(p, "EXPRESSION")
	}
}

@(private)
parse_list :: proc(p: ^Parser) -> ([dynamic]Identifier, Parse_Error) {
	list := make([dynamic]Identifier)
	first, err := parse_identifier(p)
	if err.message != "" do return list, err
	append(&list, first)
	for expect(p, .COMMA) {
		next, n_err := parse_identifier(p)
		if n_err.message != "" do return list, n_err
		append(&list, next)
	}
	return list, {}
}

@(private)
parse_expression :: proc(p: ^Parser) -> (^Expression, Parse_Error) {
	return parse_binary(p)
}

@(private)
parse_binary :: proc(p: ^Parser) -> (^Expression, Parse_Error) {
	left, l_err := parse_atomic(p)
	if l_err.message != "" do return nil, l_err
	if !is_operator(p.current.kind) do return left, {}
	op := p.current.kind
	advance(p)
	right, r_err := parse_binary(p)
	if r_err.message != "" do return nil, r_err
	node := new(Expression)
	node^ = BinaryExpr{left, op, right}
	return node, {}
}

@(private)
advance :: proc(p: ^Parser) {
	p.current = p.peek
	p.peek = next_token(&p.lexer)
}

@(private)
expect :: proc(p: ^Parser, kind: TokenKind) -> bool {
	if p.current.kind == kind {
		advance(p)
		return true
	}
	return false
}

@(private)
is_join_start :: proc(k: TokenKind) -> bool {
	#partial switch k {
	case .JOIN, .LEFT, .INNER, .RIGHT:
		return true
	}
	return false
}
