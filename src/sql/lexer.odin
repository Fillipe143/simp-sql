package sql

import "core:strings"

Lexer :: struct {
	data:   []byte,
	cursor: Position,
	eof:    bool,
}

new_lexer :: proc(data: []byte) -> Lexer {
	return {data = data, cursor = Position{0, 1, 1}, eof = len(data) == 0}
}

next_token :: proc(l: ^Lexer) -> Token {
	consume_trivia(l)
	if l.eof {return new_token("", l.cursor, .EOF)}

	b := peek(l)
	if is_letter(b) {return consume_identifier(l)}
	if is_digit(b) {return consume_number(l)}
	if is_symbol(b) {return consume_symbol(l)}
	if is_quote(b) {return consume_quoted(l)}

	start := l.cursor; consume(l)
	return new_token(string([]u8{b}), start, .ILEGAL)
}

@(private)
peek :: proc(l: ^Lexer) -> byte {
    // Returns the byte on the current cursor position
	if l.eof {return 0}
	return l.data[l.cursor.idx]
}

@(private)
peek_next :: proc(l: ^Lexer) -> byte {
    // Returns the byte of the next cursor position
	if (l.cursor.idx + 1) >= len(l.data) {return 0}
	return l.data[l.cursor.idx + 1]
}

@(private)
split_data :: proc(l: ^Lexer, start: Position) -> string {
    // Returns a string with the bytes between the start and the current cursor
	return string(l.data[start.idx:l.cursor.idx])
}

@(private)
consume :: proc(l: ^Lexer) {
    // Consumes a character moving the cursor
	if l.eof {return}

	b := peek(l)
	l.cursor.idx += 1
	l.cursor.col += 1

	if is_new_line(b) {
		// Windows uses \r\n as new line
		if b == '\r' && peek(l) == '\n' {l.cursor.idx += 1}
		l.cursor.col = 1
		l.cursor.row += 1
	}

	if l.cursor.idx >= len(l.data) {l.eof = true}
}

@(private)
consume_trivia :: proc(l: ^Lexer) {
    // Consumes white spaces and comments
	for !l.eof {
		b := peek(l)
		nb := peek_next(l)

		// Consume white spaces
		if is_space(b) {
			consume(l)
			continue
		}

		// Consumes single line comments
		if b == '-' && nb == '-' {
			for !l.eof && !is_new_line(peek(l)) {
				consume(l)
			}
			continue
		}

		// Consumes multi line comments
		if b == '/' && nb == '*' {
			for !l.eof {
				if peek(l) == '*' && peek_next(l) == '/' {
					consume(l); consume(l)
					break
				}
				consume(l)
			}
			continue
		}

		break
	}
}

@(private)
consume_identifier :: proc(l: ^Lexer) -> Token {
    // Consumes a keyword or identifier
	start := l.cursor
	for is_letter(peek(l)) || is_digit(peek(l)) {consume(l)}
	value := split_data(l, start)
	return new_token(value, start, identify_kind(value))
}

@(private)
consume_number :: proc(l: ^Lexer) -> Token {
    // Consumes a number including floats
	start := l.cursor
	for is_digit(peek(l)) || peek(l) == '.' {consume(l)}
	return new_token(split_data(l, start), start, .NUMBER)
}

@(private)
consume_symbol :: proc(l: ^Lexer) -> Token {
    // Consumes symbols
	start := l.cursor
	for is_symbol(peek(l)) {consume(l)}
	value := split_data(l, start)
	return new_token(value, start, identify_kind(value))
}

@(private)
consume_quoted :: proc(l: ^Lexer) -> Token {
    // Consumes strings and quoted identifiers "string", 'string', `identifier`
	start := l.cursor
	quote_char := peek(l); consume(l)
	sb := strings.builder_make()

	for !l.eof {
		b := peek(l)

		// Double quotes escape
		if b == quote_char {
			if peek_next(l) == quote_char {
				strings.write_byte(&sb, quote_char)
				consume(l); consume(l)
				continue
			}
			consume(l)
			break
		}

		// Normal '\' escape (only in case of strings)
		if quote_char != '`' && b == '\\' {
			consume(l)
			next := peek(l)
			switch next {
			case 'n':
				strings.write_byte(&sb, '\n')
			case 't':
				strings.write_byte(&sb, '\t')
			case 'r':
				strings.write_byte(&sb, '\r')
			case '\\':
				strings.write_byte(&sb, '\\')
			case quote_char:
				strings.write_byte(&sb, quote_char)
			case:
				strings.write_byte(&sb, next)
			}
            consume(l)
            continue
		}

        strings.write_byte(&sb, b)
        consume(l)
	}

    value := strings.to_string(sb)
    kind := quote_char == '`' ? TokenKind.IDENTIFIER : TokenKind.STRING
	return new_token(value, start, kind)
}
