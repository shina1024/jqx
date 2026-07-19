///|
priv struct CliRunResult {
  stdout_lines : Array[String]
  stderr_lines : Array[String]
  exit_code : Int?
}

///|
fn format_output(raw : Bool, compact : Bool, value : @lib.Value) -> String {
  let buf = StringBuilder()
  write_output(raw, compact, value, fn(chunk) { buf.write_string(chunk) })
  buf.to_string()
}

///|
fn run_cli(args : Array[String], stdin_text : String) -> CliRunResult {
  let stdout_lines = []
  let result = execute_cli(args, stdin_text, fn(raw, compact, value) {
    stdout_lines.push(format_output(raw, compact, value))
  })
  {
    stdout_lines,
    stderr_lines: result.stderr_lines,
    exit_code: result.exit_code,
  }
}
