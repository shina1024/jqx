///|
fn main {
  let args = read_cli_args()
  let stdin_text = if cli_reads_stdin(args) { read_stdin_all() } else { "" }
  let result = execute_cli(args, stdin_text, fn(raw, compact, value) {
    write_output(raw, compact, value, fn(chunk) { write_stdout_chunk(chunk) })
    write_stdout_chunk("\n")
  })
  for line in result.stderr_lines {
    write_stderr_line(line)
  }
  match result.exit_code {
    Some(code) => jqx_exit(code)
    None => ()
  }
}
