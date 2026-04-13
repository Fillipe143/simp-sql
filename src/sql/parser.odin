package sql

import "core:crypto/_fiat/field_curve25519"
import "core:strconv"
import "core:strings"

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

parse_all :: proc(p: ^Parser) -> [dynamic]Statement {
    stmts := make([dynamic]Statement)
    for p.current.kind != .EOF {
        if expect(p, .SEMICOLON) do continue
        append(&stmts, parse_statement(p))
        expect(p, .SEMICOLON)
    }
    return stmts
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
parse_statement :: proc(p: ^Parser) -> Statement {
	#partial switch p.current.kind {
    case .SELECT:
        return parse_query(p)
    case:
        assert(false, "TODO retornar erro, statement inválido")
        return nil
    }
}

@(private)
parse_identifier :: proc(p: ^Parser) -> Identifier {
	first := p.current
	if !expect(p, .IDENTIFIER) && !expect(p, .ASTERISK) {
		assert(false, "TODO retornar erro, esperava identifier ou *")
	}

	if expect(p, .DOT) {
		if first.kind == .ASTERISK {
			assert(false, "TODO retornar erro, não pode usar um asterisco como nome de tabela")
		}

		second := p.current
		if !expect(p, .IDENTIFIER) && !expect(p, .ASTERISK) {
			assert(false, "TODO retornar erro, nome da tabela informado, mas nome da coluna não")
		}
		return Identifier{table = first.value, name = second.value}
	}

	return Identifier{table = "", name = first.value}
}

@(private)
parse_list :: proc(p: ^Parser) -> [dynamic]Identifier {
	list := make([dynamic]Identifier)
	append(&list, parse_identifier(p))

	for expect(p, .COMMA) {
		append(&list, parse_identifier(p))
	}
	return list
}

@(private)
parse_join :: proc(p: ^Parser) -> JoinClause {
	join := JoinClause{}
	join.type = p.current.kind
	if !expect(p, .LEFT) && !expect(p, .INNER) && !expect(p, .RIGHT) {
		join.type = .INNER
	}

	if !expect(p, .JOIN) {
		assert(false, "TODO retornar erro, JOIN não informado")
	}

	join.table = parse_identifier(p)
	if !expect(p, .ON) {
		assert(false, "TODO retornar erro, ON não informado no JOIN")
	}

	join.condition = parse_expression(p)

	return join
}

@(private)
parse_expression :: proc(p: ^Parser) -> ^Expression {
	return parse_binary(p)
}

@(private)
parse_binary :: proc(p: ^Parser) -> ^Expression {
	left := parse_atomic(p)
	if !is_operator(p.current.kind) {return left}

	op := p.current.kind
	advance(p)

	right := parse_binary(p)
	node := new(Expression)
	node^ = BinaryExpr{left, op, right}

	return node
}

@(private)
parse_atomic :: proc(p: ^Parser) -> ^Expression {
	node := new(Expression)
	#partial switch p.current.kind {
	case .IDENTIFIER, .ASTERISK:
		node^ = parse_identifier(p)
	case .STRING:
		node^ = Literal{p.current.value}
		advance(p)
	case .NUMBER:
		val, _ := strconv.parse_f64(p.current.value)
		node^ = Literal{val}
		advance(p)
	case .BOOLEAN:
		node^ = Literal{strings.to_lower(p.current.value) == "true"}
		advance(p)
	case .LPAREN:
		advance(p)
		free(node)
		expr := parse_expression(p)
		if !expect(p, .RPAREN) {
			assert(false, "TODO retornar erro, falta o ) no final")
		}
		return expr
	}
	return node
}

@(private)
parse_query :: proc(p: ^Parser) -> Query {
	query: Query

	if !expect(p, .SELECT) {
		assert(false, "TODO retornar erro, a query deve iniciar com SELECT")
	}

	query.projections = parse_list(p)
	if !expect(p, .FROM) {
		assert(false, "TODO retornar erro, FROM não informado apos os nomes das colunas")
	}

	query.from_tables = parse_list(p)

	for p.current.kind == .JOIN ||
	    p.current.kind == .LEFT ||
	    p.current.kind == .INNER ||
	    p.current.kind == .RIGHT {
		append(&query.joins, parse_join(p))
	}

	if expect(p, .WHERE) {
		query.where_cond = parse_expression(p)
	}

	return query
}
