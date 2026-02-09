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
      "Options: -r (raw strings), -c (compact; default), -n (null input), -e (set exit status)",
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
  let input = if cfg.no_input {
    None
  } else {
    match cfg.input {
      Some(text) => Some(text)
      None => Some(read_stdin_all())
    }
  }
  try {
    let f = @lib.parse_filter(filter)
    let j = match input {
      Some(text) => @lib.parse(text)
      None => @lib.Json::null()
    }
    let outputs = @lib.eval(f, j)
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
      jqx_exit(1)
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
