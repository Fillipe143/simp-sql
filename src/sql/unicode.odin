#+private
package sql

is_new_line :: proc(b: byte) -> bool {
    // Returns true if b in [\n\r]
	return b == '\n' || b == '\r'
}

is_space :: proc(b: byte) -> bool {
    // Returns true if b in [\s\t\n\r]
	return b == ' ' || b == '\t' || b == '\n' || b == '\r'
}

is_letter :: proc(b: byte) -> bool {
    // Returns true if b in [a-zA-Z_]
	return (b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z') || b == '_'
}

is_digit :: proc(b: byte) -> bool {
    // Returns true if b in [0-9]
	return b >= '0' && b <= '9'
}

is_quote :: proc(b: byte) -> bool {
    // Returns true if b in ['"`]
	return b == '\'' || b == '"' || b == '`'
}

is_symbol :: proc(b: byte) -> bool {
    // Returns true if b in [,.();=+-*/<>!]
	switch b {
	case ',', '.', '(', ')', ';', '=', '+', '-', '*', '/', '<', '>', '!':
		return true
	case:
		return false
	}
}
