package main

import "core:fmt"
import "core:os"
import "sql"

main :: proc() {
	data, ok := os.read_entire_file("./examples/query_1.sql")
	assert(ok, "Não foi possível ler o arquivo")

	l := sql.new_lexer(data)
    p := sql.new_parser(l)
    fmt.printf("%#v\n", sql.parse_all(&p))
}
