///|
fn main {
  let args = @env.args()
  if args.length() < 2 {
    println(
      "Usage: moon run --target native cmd -- [options] \"<filter>\" [\"<json>\"]",
    )
    println(
      "Example (stdin): echo '{\"foo\": 1}' | moon run --target native cmd -- \".foo\"",
    )
    println(
      "Example (arg):   moon run --target native cmd -- \".foo\" '{\"foo\": 1}'",
    )
    println(
      "Options: -r (raw strings), -R (raw input), -c (compact; default), -n (null input), -s (slurp inputs), -e (set exit status)",
    )
    return
  }
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else {
    println("jqx: error: " + parsed.unwrap_err())
    println(
      "Usage: moon run --target native cmd -- [options] \"<filter>\" [\"<json>\"]",
    )
    return
  }
  let raw = cfg.raw
  let exit_status = cfg.exit_status
  let filter = cfg.filter
  let stdin_text = if cfg.no_input || cfg.input is Some(_) {
    ""
  } else {
    read_stdin_all()
  }
  try {
    let f = @lib.compile(filter)
    let inputs = parse_cli_inputs(cfg, stdin_text)
    let outputs = []
    for j in inputs {
      let result = @lib.execute_for_cli(f, j)
      let values = result.0
      for v in values {
        outputs.push(v)
      }
      match result.1 {
        Some(msg) => {
          println(format_error_message(msg))
          for v in outputs {
            println(format_output(raw, v))
          }
          jqx_exit(5)
        }
        None => ()
      }
    }
    for v in outputs {
      println(format_output(raw, v))
    }
    if exit_status {
      jqx_exit(compute_exit_status(outputs))
    }
  } catch {
    err => {
      let msg = format_error_message(err.to_string())
      println(msg)
      jqx_exit(5)
    }
  }
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
          let parsed_line = try? @strconv.parse_int(line_part)
          let parsed_col = try? @strconv.parse_int(col_part)
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
fn compute_exit_status(outputs : Array[@lib.Json]) -> Int {
  if outputs.length() == 0 {
    return 4
  }
  match outputs[outputs.length() - 1] {
    @lib.Json::JFalse | @lib.Json::JNull => 1
    _ => 0
  }
}

///|
fn parse_cli_inputs(
  cfg : CliArgs,
  stdin_text : String,
) -> Array[@lib.Json] raise @lib.ParseError {
  if cfg.no_input {
    [@lib.Json::null()]
  } else {
    let text = match cfg.input {
      Some(v) => v
      None => stdin_text
    }
    if cfg.raw_input {
      if cfg.slurp {
        [@lib.Json::string(text)]
      } else {
        parse_raw_lines(text)
      }
    } else {
      parse_json_inputs(text, cfg.slurp)
    }
  }
}

///|
fn parse_json_inputs(
  text : String,
  slurp : Bool,
) -> Array[@lib.Json] raise @lib.ParseError {
  if slurp {
    [@lib.Json::array(parse_slurp_values(text))]
  } else {
    parse_json_stream_values(text)
  }
}

///|
fn parse_slurp_values(text : String) -> Array[@lib.Json] raise @lib.ParseError {
  let trimmed = trim_ascii_ws(text)
  if trimmed.length() == 0 {
    return []
  }
  // Prefer parsing the full input as one JSON value first.
  try [@lib.parse(trimmed)] catch {
    // Fallback for newline-delimited JSON inputs.
    _ => parse_ndjson_lines(trimmed)
  } noraise {
    values => values
  }
}

///|
fn parse_json_stream_values(
  text : String,
) -> Array[@lib.Json] raise @lib.ParseError {
  let trimmed = trim_ascii_ws(text)
  if trimmed.length() == 0 {
    return []
  }
  // Prefer parsing the full input as one JSON value first.
  try [@lib.parse(trimmed)] catch {
    // Fallback for newline-delimited JSON inputs.
    _ => parse_ndjson_lines(trimmed)
  } noraise {
    values => values
  }
}

///|
fn parse_ndjson_lines(text : String) -> Array[@lib.Json] raise @lib.ParseError {
  let values = []
  let mut start = 0
  for i in 0..<text.length() {
    if text.unsafe_get(i) == '\n' {
      let line = text.view(start_offset=start, end_offset=i).to_string()
      let piece = trim_ascii_ws(line)
      if piece.length() > 0 {
        values.push(@lib.parse(piece))
      }
      start = i + 1
    }
  }
  if start <= text.length() {
    let line = text.view(start_offset=start).to_string()
    let piece = trim_ascii_ws(line)
    if piece.length() > 0 {
      values.push(@lib.parse(piece))
    }
  }
  values
}

///|
fn parse_raw_lines(text : String) -> Array[@lib.Json] {
  if text.length() == 0 {
    return []
  }
  let values = []
  let mut start = 0
  for i in 0..<text.length() {
    if text.unsafe_get(i) == '\n' {
      let line = text.view(start_offset=start, end_offset=i).to_string()
      values.push(@lib.Json::string(trim_single_trailing_cr(line)))
      start = i + 1
    }
  }
  if start < text.length() {
    let line = text.view(start_offset=start).to_string()
    values.push(@lib.Json::string(trim_single_trailing_cr(line)))
  }
  values
}

///|
fn trim_single_trailing_cr(s : String) -> String {
  if s.length() > 0 && s.unsafe_get(s.length() - 1) == '\r' {
    s.view(end_offset=s.length() - 1).to_string()
  } else {
    s
  }
}

///|
fn is_ascii_ws(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n'
}

///|
fn trim_ascii_ws(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  for {
    if start < end && is_ascii_ws(s.unsafe_get(start).to_int().unsafe_to_char()) {
      start += 1
    } else {
      break
    }
  }
  for {
    if end > start &&
      is_ascii_ws(s.unsafe_get(end - 1).to_int().unsafe_to_char()) {
      end -= 1
    } else {
      break
    }
  }
  s.view(start_offset=start, end_offset=end).to_string()
}
