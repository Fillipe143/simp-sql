package sql

Statement :: union {
	Query,
}

Query :: struct {
	projections: [dynamic]Identifier,
	from_tables: [dynamic]Identifier,
	joins:       [dynamic]JoinClause,
	where_cond:  Maybe(^Expression),
}

JoinClause :: struct {
	type:      TokenKind,
	table:     Identifier,
	condition: ^Expression,
}

Expression :: union {
	BinaryExpr,
	Identifier,
	Literal,
}

BinaryExpr :: struct {
	left:  ^Expression,
	op:    TokenKind,
	right: ^Expression,
}

Identifier :: struct {
	table: string,
	name:  string,
    alias: string,
}

LiteralValue :: union {
	string,
	f64,
	bool,
}

Literal :: struct {
	value: LiteralValue,
}
