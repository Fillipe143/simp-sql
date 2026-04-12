#+feature dynamic-literals
package sql

import "core:strings"

TokenKind :: enum {
	IDENTIFIER,
	NUMBER,
	STRING,
	ILEGAL,
	EOF,

	// Keywords
	SELECT,
	INSERT,
	UPDATE,
	DELETE,
	FROM,
	WHERE,
	AND,
	OR,
	NOT,
	IN,
	IS,
	NULL,
	CREATE,
	TABLE,
	DROP,
	INTO,
	VALUES,
	JOIN,
	LEFT,
	RIGHT,
	INNER,
	ON,
	GROUP,
	BY,
	ORDER,
	HAVING,
	LIMIT,
	AS,
	DISTINCT,
	UNION,
	ALL,

	// Símbolos
	COMMA, // ,
	DOT, // .
	LPAREN, // (
	RPAREN, // )
	SEMICOLON, // ;
	EQ, // =
	NEQ, // <> ou !=
	LT, // <
	GT, // >
	LTE, // <=
	GTE, // >=
	PLUS, // +
	MINUS, // -
	ASTERISK, // *
	SLASH, // /
}

Token :: struct {
	kind:    TokenKind,
	literal: string,
	pos:     Pos,
}

@(private)
new_token :: proc(l: ^Lexer, literal: string, kind: TokenKind, pos: Pos) -> Token {
	return Token{kind, literal, pos}
}

KEYWORDS := map[string]TokenKind {
	"SELECT"   = .SELECT,
	"INSERT"   = .INSERT,
	"UPDATE"   = .UPDATE,
	"DELETE"   = .DELETE,
	"FROM"     = .FROM,
	"WHERE"    = .WHERE,
	"AND"      = .AND,
	"OR"       = .OR,
	"NOT"      = .NOT,
	"IN"       = .IN,
	"IS"       = .IS,
	"NULL"     = .NULL,
	"CREATE"   = .CREATE,
	"TABLE"    = .TABLE,
	"DROP"     = .DROP,
	"INTO"     = .INTO,
	"VALUES"   = .VALUES,
	"JOIN"     = .JOIN,
	"LEFT"     = .LEFT,
	"RIGHT"    = .RIGHT,
	"INNER"    = .INNER,
	"ON"       = .ON,
	"GROUP"    = .GROUP,
	"BY"       = .BY,
	"ORDER"    = .ORDER,
	"HAVING"   = .HAVING,
	"LIMIT"    = .LIMIT,
	"AS"       = .AS,
	"DISTINCT" = .DISTINCT,
	"UNION"    = .UNION,
	"ALL"      = .ALL,
}

@(private)
identifier_kind :: proc(literal: string) -> TokenKind {
	upper := strings.to_upper(literal)
	defer delete(upper)

	if kind, ok := KEYWORDS[upper]; ok {
		return kind
	}
	return .IDENTIFIER
}
