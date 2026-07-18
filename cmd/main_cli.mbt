///|
priv struct CliRunResult {
  stdout_lines : Array[String]
  stderr_lines : Array[String]
  exit_code : Int?
}

///|
fn usage_summary_line() -> String {
  "Usage: jqx [options] [\"<filter>\"] [\"<json>\"]"
}

///|
fn append_output_lines(
  lines : Array[String],
  raw : Bool,
  compact : Bool,
  outputs : Array[@lib.Value],
) -> Unit {
  for value in outputs {
    lines.push(format_output(raw, compact, value))
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
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else {
    return {
      stdout_lines: [],
      stderr_lines: ["jqx: error: " + parsed.unwrap_err(), usage_summary_line()],
      exit_code: Some(2),
    }
  }
  let cli_stdin = if cfg.no_input || cfg.input is Some(_) {
    ""
  } else {
    stdin_text
  }
  configure_module_search_paths(cfg)
  let compiled_result = try @lib.compile(cfg.filter) catch {
    err => Err(err.to_string())
  } noraise {
    compiled => Ok(compiled)
  }
  guard compiled_result is Ok(compiled) else {
    return {
      stdout_lines: [],
      stderr_lines: render_error_lines(compiled_result.unwrap_err()),
      exit_code: Some(3),
    }
  }
  try {
    let inputs = parse_cli_inputs(cfg, cli_stdin)
    let outputs = []
    for input in inputs {
      let result = @lib.execute_for_cli(compiled, input)
      append_json_output_values(outputs, result.0)
      match result.1 {
        Some(msg) => {
          let stdout_lines = []
          append_output_lines(stdout_lines, cfg.raw, cfg.compact, outputs)
          return {
            stdout_lines,
            stderr_lines: render_error_lines(msg),
            exit_code: Some(5),
          }
        }
        None => ()
      }
    }
    let stdout_lines = []
    append_output_lines(stdout_lines, cfg.raw, cfg.compact, outputs)
    let exit_code = if cfg.exit_status {
      Some(compute_exit_status(outputs))
    } else {
      None
    }
    { stdout_lines, stderr_lines: [], exit_code }
  } catch {
    err =>
      {
        stdout_lines: [],
        stderr_lines: render_error_lines(err.to_string()),
        exit_code: Some(5),
      }
  }
}

///|
fn main {
  let args = read_cli_args()
  let stdin_text = if cli_reads_stdin(args) { read_stdin_all() } else { "" }
  let result = run_cli(args, stdin_text)
  for line in result.stdout_lines {
    println(line)
  }
  for line in result.stderr_lines {
    write_stderr_line(line)
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
      out.push(msg.view(start_offset=start, end_offset=i).to_owned())
      start = i + 1
    }
  }
  out.push(msg.view(start_offset=start).to_owned())
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
            .to_owned()
          let start_col = start_line + j + marker2.length()
          let col_part = msg.view(start_offset=start_col).to_owned()
          let parsed_line = try @string.parse_int(line_part) catch {
            _ => None
          } noraise {
            line => Some(line)
          }
          let parsed_col = try @string.parse_int(col_part) catch {
            _ => None
          } noraise {
            col => Some(col)
          }
          match (parsed_line, parsed_col) {
            (Some(line), Some(col)) => {
              let base = msg.view(start_offset=0, end_offset=i).to_owned()
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
    JFalse | JNull => 1
    _ => 0
  }
}
