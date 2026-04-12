package sql

@(private)
is_space :: proc(b: byte) -> bool {
	return b == ' ' || b == '\t' || b == '\r' || b == '\n'
}

@(private)
is_letter :: proc(b: byte) -> bool {
	return (b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z') || b == '_'
}

@(private)
is_digit :: proc(b: byte) -> bool {
	return b >= '0' && b <= '9'
}

@(private)
is_quote :: proc(b: byte) -> bool {
	return b == '\'' || b == '"' || b == '`'
}
