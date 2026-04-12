#+private
package sql

// Returns true if b in [\n\r]
is_new_line :: proc(b: byte) -> bool {
	return b == '\n' || b == '\r'
}

// Returns true if b in [\s\t\n\r]
is_space :: proc(b: byte) -> bool {
	return b == ' ' || b == '\t' || b == '\n' || b == '\r'
}

// Returns true if b in [a-zA-Z_]
is_letter :: proc(b: byte) -> bool {
	return (b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z') || b == '_'
}

// Returns true if b in [0-9]
is_digit :: proc(b: byte) -> bool {
	return b >= '0' && b <= '9'
}

// Returns true if b in ['"`]
is_quote :: proc(b: byte) -> bool {
	return b == '\'' || b == '"' || b == '`'
}

// Returns true if b in [,.();=+-*/<>!]
is_symbol :: proc(b: byte) -> bool {
	switch b {
	case ',', '.', '(', ')', ';', '=', '+', '-', '*', '/', '<', '>', '!':
		return true
	case:
		return false
	}
}
