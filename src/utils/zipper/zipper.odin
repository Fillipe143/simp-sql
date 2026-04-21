package zipper

Zipper :: struct($T: typeid) {
    left, right: [dynamic]T,
}

new_zipper :: proc(data: [dynamic]$T, cursor: int = 0) -> Zipper(T) {
    c := clamp(cursor, 0, len(data))
    z := Zipper(T){
        make([dynamic]T, 0, c), 
        make([dynamic]T, 0, len(data) - c),
    }

    for i in 0 ..< c do append(&z.left, data[i])
    for i := len(data) - 1; i >= c; i -= 1 do append(&z.right, data[i])

    return z
}

move_left :: proc(z: ^Zipper($T)) {
    if len(z.left) > 0 do append(&z.right, pop(&z.left))
}

move_right :: proc(z: ^Zipper($T)) {
    if len(z.right) > 0 do append(&z.left, pop(&z.right))
}

insert_left :: proc(z: ^Zipper($T), value: T) {
    append(&z.left, value)
}

insert_right :: proc(z: ^Zipper($T), value: T) {
    append(&z.right, value)
}

remove_left :: proc(z: ^Zipper($T)) {
    if len(z.left) > 0 do pop(&z.left)
}

remove_right :: proc(z: ^Zipper($T)) {
    if len(z.right) > 0 do pop(&z.right)
}

length :: proc(z: ^Zipper($T)) -> int {
    return len(z.left) + len(z.right)
}

current :: proc(z: ^Zipper($T)) -> ^T {
    if len(z.right) > 0 do return &z.right[len(z.right) - 1] 
    return nil
}

join :: proc(z: ^Zipper($T), allocator := context.allocator) -> [dynamic]T {
    result := make([dynamic]T, 0, len(z.left) + len(z.right), allocator)
    for item in z.left do append(&result, item)
    #reverse for item in z.right do append(&result, item)
    return result
}

destroy :: proc(z: ^Zipper($T)) {
    delete(z.left)
    delete(z.right)
}
