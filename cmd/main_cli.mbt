///|
priv struct CliRunResult {
  lines : Array[String]
  exit_code : Int?
}

///|
fn usage_summary_line() -> String {
  "Usage: jqx [options] \"<filter>\" [\"<json>\"]"
}

///|
fn usage_lines() -> Array[String] {
  [
    usage_summary_line(),
    "Example (stdin): echo '{\"foo\": 1}' | jqx \".foo\"",
    "Example (arg):   jqx \".foo\" '{\"foo\": 1}'",
    "Options: -r, -R, -c, -n, -s, -e, -L <dir>",
  ]
}

///|
fn append_output_lines(
  lines : Array[String],
  raw : Bool,
  outputs : Array[@lib.Value],
) -> Unit {
  for value in outputs {
    lines.push(format_output(raw, value))
  }
}

///|
fn append_json_output_values(
  outputs : Array[@lib.Value],
  values : Array[@lib.Value],
) -> Unit {
  for value in values {
    outputs.push(value)
  }
}

///|
fn render_error_lines(msg : String) -> Array[String] {
  let lines = []
  let parts = split_error_lines(msg)
  let mut printed = false
  for part in parts {
    if part.length() == 0 {
      continue
    }
    lines.push(format_error_message(part))
    printed = true
  }
  if !printed {
    lines.push(format_error_message(msg))
  }
  lines
}

///|
fn cli_reads_stdin(args : Array[String]) -> Bool {
  if args.length() < 2 {
    return false
  }
  match parse_cli_args(args) {
    Ok(cfg) => !cfg.no_input && cfg.input is None
    Err(_) => false
  }
}

///|
fn configure_module_search_paths(cfg : CliArgs) -> Unit {
  @lib.clear_module_search_paths()
  if cfg.module_search_paths.length() == 0 {
    @lib.set_module_search_paths(["."])
  } else {
    @lib.set_module_search_paths(cfg.module_search_paths)
  }
}

///|
fn run_cli(args : Array[String], stdin_text : String) -> CliRunResult {
  if args.length() < 2 {
    return { lines: usage_lines(), exit_code: None }
  }
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else {
    return {
      lines: ["jqx: error: " + parsed.unwrap_err(), usage_summary_line()],
      exit_code: None,
    }
  }
  let cli_stdin = if cfg.no_input || cfg.input is Some(_) {
    ""
  } else {
    stdin_text
  }
  configure_module_search_paths(cfg)
  try {
    let compiled = @lib.compile(cfg.filter)
    let inputs = parse_cli_inputs(cfg, cli_stdin)
    let outputs = []
    for input in inputs {
      let result = @lib.execute_for_cli(compiled, input)
      append_json_output_values(outputs, result.0)
      match result.1 {
        Some(msg) => {
          let lines = render_error_lines(msg)
          append_output_lines(lines, cfg.raw, outputs)
          return { lines, exit_code: Some(5) }
        }
        None => ()
      }
    }
    let lines = []
    append_output_lines(lines, cfg.raw, outputs)
    let exit_code = if cfg.exit_status {
      Some(compute_exit_status(outputs))
    } else {
      None
    }
    { lines, exit_code }
  } catch {
    err => { lines: render_error_lines(err.to_string()), exit_code: Some(5) }
  }
}

///|
fn main {
  let args = read_cli_args()
  let stdin_text = if cli_reads_stdin(args) { read_stdin_all() } else { "" }
  let result = run_cli(args, stdin_text)
  for line in result.lines {
    println(line)
  }
  match result.exit_code {
    Some(code) => jqx_exit(code)
    None => ()
  }
}

///|
fn split_error_lines(msg : String) -> Array[String] {
  let out = []
  let mut start = 0
  for i in 0..<msg.length() {
    let ch = msg.unsafe_get(i).to_int().unsafe_to_char()
    if ch == '\n' {
      out.push(msg.view(start_offset=start, end_offset=i).to_string())
      start = i + 1
    }
  }
  out.push(msg.view(start_offset=start).to_string())
  out
}

///|
fn format_error_message(msg : String) -> String {
  let marker = " at line "
  let marker2 = ", column "
  match msg.find(marker) {
    Some(i) => {
      let start_line = i + marker.length()
      let rest = msg.view(start_offset=start_line)
      match rest.find(marker2) {
        Some(j) => {
          let line_part = msg
            .view(start_offset=start_line, end_offset=start_line + j)
            .to_string()
          let start_col = start_line + j + marker2.length()
          let col_part = msg.view(start_offset=start_col).to_string()
          let parsed_line = try? @string.parse_int(line_part)
          let parsed_col = try? @string.parse_int(col_part)
          match (parsed_line, parsed_col) {
            (Ok(line), Ok(col)) => {
              let base = msg.view(start_offset=0, end_offset=i).to_string()
              return "jqx: error (at <stdin>:" +
                line.to_string() +
                ":" +
                col.to_string() +
                "): " +
                base
            }
            _ => ()
          }
        }
        None => ()
      }
    }
    None => ()
  }
  "jqx: error: " + msg
}

///|
fn compute_exit_status(outputs : Array[@lib.Value]) -> Int {
  if outputs.length() == 0 {
    return 4
  }
  match outputs[outputs.length() - 1] {
    @lib.Value::JFalse | @lib.Value::JNull => 1
    _ => 0
  }
}
