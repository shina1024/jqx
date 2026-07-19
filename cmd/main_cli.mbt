///|
priv struct CliExecutionResult {
  stderr_lines : Array[String]
  exit_code : Int?
}

///|
fn usage_summary_line() -> String {
  "Usage: jqx [options] [\"<filter>\"] [\"<json>\"]"
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
fn execute_cli(
  args : Array[String],
  stdin_text : String,
  emit : (Bool, Bool, @lib.Value) -> Unit,
) -> CliExecutionResult {
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else {
    return {
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
      stderr_lines: render_error_lines(compiled_result.unwrap_err()),
      exit_code: Some(3),
    }
  }
  try {
    let inputs = parse_cli_inputs(cfg, cli_stdin)
    let outputs = []
    for input in inputs {
      let result = @lib.execute_for_cli(compiled, input)
      for value in result.0 {
        outputs.push(value)
        emit(cfg.raw, cfg.compact, value)
      }
      match result.1 {
        Some(msg) =>
          return { stderr_lines: render_error_lines(msg), exit_code: Some(5) }
        None => ()
      }
    }
    let exit_code = if cfg.exit_status {
      Some(compute_exit_status(outputs))
    } else {
      None
    }
    { stderr_lines: [], exit_code }
  } catch {
    err =>
      { stderr_lines: render_error_lines(err.to_string()), exit_code: Some(5) }
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
