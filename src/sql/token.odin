package sql

import "core:strings"

TokenKind :: enum {
	IDENTIFIER,
	NUMBER,
	STRING,
    BOOLEAN,
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

	// Symbols
	COMMA,      // ,
	DOT,        // .
	LPAREN,     // (
	RPAREN,     // )
	SEMICOLON,  // ;
	EQ,         // =
	NEQ,        // <> or !=
	LT,         // <
	GT,         // >
	LTE,        // <=
	GTE,        // >=
	PLUS,       // +
	MINUS,      // -
	ASTERISK,   // *
	SLASH,      // /
}

Token :: struct {
	kind:  TokenKind,
	start: Position,
	value: string,
}

new_token :: proc(value: string, start: Position, kind: TokenKind) -> Token {
	return Token{kind, start, value}
}

identify_kind :: proc(value: string) -> TokenKind {
    upper := strings.to_upper(value, context.temp_allocator)
    switch upper {
    case "TRUE":        return .BOOLEAN
    case "FALSE":       return .BOOLEAN
    case "SELECT":      return .SELECT
    case "INSERT":      return .INSERT
    case "UPDATE":      return .UPDATE
    case "DELETE":      return .DELETE
    case "FROM":        return .FROM
    case "WHERE":       return .WHERE
    case "AND":         return .AND
    case "OR":          return .OR
    case "NOT":         return .NOT
    case "IN":          return .IN
    case "IS":          return .IS
    case "NULL":        return .NULL
    case "CREATE":      return .CREATE
    case "TABLE":       return .TABLE
    case "DROP":        return .DROP
    case "INTO":        return .INTO
    case "VALUES":      return .VALUES
    case "JOIN":        return .JOIN
    case "LEFT":        return .LEFT
    case "RIGHT":       return .RIGHT
    case "INNER":       return .INNER
    case "ON":          return .ON
    case "GROUP":       return .GROUP
    case "BY":          return .BY
    case "ORDER":       return .ORDER
    case "HAVING":      return .HAVING
    case "LIMIT":       return .LIMIT
    case "AS":          return .AS
    case "DISTINCT":    return .DISTINCT
    case "UNION":       return .UNION
    case "ALL":         return .ALL
    case ",":           return .COMMA
    case ".":           return .DOT
    case "(":           return .LPAREN
    case ")":           return .RPAREN
    case ";":           return .SEMICOLON
    case "=":           return .EQ
    case "!=", "<>":    return .NEQ
    case "<":           return .LT
    case ">":           return .GT
    case "<=":          return .LTE
    case ">=":          return .GTE
    case "+":           return .PLUS
    case "-":           return .MINUS
    case "*":           return .ASTERISK
    case "/":           return .SLASH
    }
    return is_letter(value[0]) ? .IDENTIFIER : .ILEGAL
}
