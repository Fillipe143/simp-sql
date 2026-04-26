package menu

import "core:os"
import "core:os/os2"
import "core:strings"
import "../../utils/editor"

open_file :: proc(ctx: ^Context) {
    desc := os2.Process_Desc {
        command = []string {
            "zenity",
            "--file-selection",
            "--title=Selecione o arquivo SQL",
            "--file-filter=Arquivos SQL | *.sql",
        },
    }

    state, stdout, stderr, err := os2.process_exec(desc, context.temp_allocator)
    if err != nil || !state.success do return

    path := strings.trim_space(string(stdout))
    if len(path) == 0 do return 

    data, read_ok := os.read_entire_file(path, context.allocator)
    if !read_ok do return

    content := string(data)
    ctx.ctx_editor.editor = editor.new_editor(content)
    ctx.ctx_editor.focus = true
}
