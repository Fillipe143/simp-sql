package sql

import "core:strings"

Pos :: struct {
	idx, row, col: uint,
}

Lexer :: struct {
	data: []byte,
	pos:  Pos,
	eof:  bool,
}

new_lexer :: proc(data: []byte) -> Lexer {
	return Lexer{data = data, pos = Pos{0, 1, 1}, eof = len(data) == 0}
}

@(private)
peek :: proc(l: ^Lexer) -> byte {
	if l.eof {return 0}
	return l.data[l.pos.idx]
}

@(private)
peek_next :: proc(l: ^Lexer) -> byte {
	if (l.pos.idx + 1) >= len(l.data) {return 0}
	return l.data[l.pos.idx + 1]
}

@(private)
consume_and_peek :: proc(l: ^Lexer) -> byte {
	if l.eof {return 0}

	b := peek(l)
	l.pos.idx += 1
	l.pos.col += 1

	if b == '\n' || b == '\r' {
		if b == '\r' && peek(l) == '\n' {
			l.pos.idx += 1
		}
		l.pos.col = 1
		l.pos.row += 1
	}

	if l.pos.idx >= len(l.data) {l.eof = true}
	return peek(l)
}

@(private)
consume_trivia :: proc(l: ^Lexer) {
	for !l.eof {
		b := peek(l)
		if is_space(b) {
			consume_and_peek(l)
		} else if b == '-' && peek_next(l) == '-' {
			// Comentário de linha: --
			for !l.eof && peek(l) != '\n' && peek(l) != '\r' {
				consume_and_peek(l)
			}
		} else if b == '/' && peek_next(l) == '*' {
			// Comentário de bloco: /* ... */
			consume_and_peek(l); consume_and_peek(l)
			for !l.eof {
				if peek(l) == '*' && peek_next(l) == '/' {
					consume_and_peek(l); consume_and_peek(l)
					break
				}
				consume_and_peek(l)
			}
		} else {
			break
		}
	}
}

@(private)
consume_identifier :: proc(l: ^Lexer) -> Token {
	start_pos := l.pos
	for !l.eof && (is_letter(peek(l)) || is_digit(peek(l))) {
		consume_and_peek(l)
	}
	literal := string(l.data[start_pos.idx:l.pos.idx])
	return new_token(l, literal, identifier_kind(literal), start_pos)
}

@(private)
consume_number :: proc(l: ^Lexer) -> Token {
	start_pos := l.pos
	for !l.eof && (is_digit(peek(l)) || peek(l) == '.') {
		consume_and_peek(l)
	}
	return new_token(l, string(l.data[start_pos.idx:l.pos.idx]), .NUMBER, start_pos)
}

@(private)
consume_quoted :: proc(l: ^Lexer) -> Token {
	start_pos := l.pos
	quote_type := peek(l)
	consume_and_peek(l)

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	for !l.eof {
		b := peek(l)

		if b == quote_type {
			if peek_next(l) == quote_type {
				strings.write_byte(&builder, quote_type)
				consume_and_peek(l); consume_and_peek(l)
				continue
			}
			consume_and_peek(l)
			break
		}

		if b == '\\' && quote_type != '`' {
			consume_and_peek(l)
			next := peek(l)
			switch next {
			case 'n':
				strings.write_byte(&builder, '\n')
			case 'r':
				strings.write_byte(&builder, '\r')
			case 't':
				strings.write_byte(&builder, '\t')
			case '\\':
				strings.write_byte(&builder, '\\')
			case quote_type:
				strings.write_byte(&builder, quote_type)
			case:
				strings.write_byte(&builder, '\\')
				strings.write_byte(&builder, next)
			}
			consume_and_peek(l)
			continue
		}

		strings.write_byte(&builder, b)
		consume_and_peek(l)
	}

	literal := strings.clone(strings.to_string(builder))
	kind := (quote_type == '`') ? TokenKind.IDENTIFIER : TokenKind.STRING
	return new_token(l, literal, kind, start_pos)
}

@(private)
consume_symbol :: proc(l: ^Lexer) -> Token {
	start_pos := l.pos
	b := peek(l)
	next := peek_next(l)

	kind := TokenKind.ILEGAL

	switch b {
	case ',':
		kind = .COMMA
	case '.':
		kind = .DOT
	case '(':
		kind = .LPAREN
	case ')':
		kind = .RPAREN
	case ';':
		kind = .SEMICOLON
	case '=':
		kind = .EQ
	case '+':
		kind = .PLUS
	case '-':
		kind = .MINUS
	case '*':
		kind = .ASTERISK
	case '/':
		kind = .SLASH

	case '<':
		kind = .LT
		if next == '>' {
			consume_and_peek(l)
			consume_and_peek(l)
			return new_token(l, "<>", .NEQ, start_pos)
		} else if next == '=' {
			consume_and_peek(l)
			consume_and_peek(l)
			return new_token(l, "<=", .LTE, start_pos)
		}

	case '>':
		kind = .GT
		if next == '=' {
			consume_and_peek(l)
			consume_and_peek(l)
			return new_token(l, ">=", .GTE, start_pos)
		}

	case '!':
		if next == '=' {
			consume_and_peek(l)
			consume_and_peek(l)
			return new_token(l, "!=", .NEQ, start_pos)
		}
	}

	if kind != .ILEGAL {
		consume_and_peek(l)
		return new_token(l, string(l.data[start_pos.idx:l.pos.idx]), kind, start_pos)
	}

	consume_and_peek(l)
	return new_token(l, string(l.data[start_pos.idx:l.pos.idx]), .ILEGAL, start_pos)
}
next_token :: proc(l: ^Lexer) -> Token {
	consume_trivia(l)

	current_pos := l.pos
	if l.eof {return new_token(l, "", .EOF, current_pos)}

	b := peek(l)
	if is_letter(b) {
		return consume_identifier(l)
	} else if is_digit(b) {
		return consume_number(l)
	} else if is_quote(b) {
		return consume_quoted(l)
	} else {
		return consume_symbol(l)
	}
}
