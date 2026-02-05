///|
fn main {
  let args = @env.args()
  if args.length() < 2 {
    println(
      "Usage: moon run --target native cmd/jqx -- [options] \"<filter>\" [\"<json>\"]",
    )
    println(
      "Example (stdin): echo '{\"foo\": 1}' | moon run --target native cmd/jqx -- \".foo\"",
    )
    println(
      "Example (arg):   moon run --target native cmd/jqx -- \".foo\" '{\"foo\": 1}'",
    )
    println("Options: -r (raw strings), -c (compact; default)")
    return
  }
  let mut raw = false
  let mut idx = 1
  while idx < args.length() {
    let a = args[idx]
    if a == "-r" {
      raw = true
      idx += 1
      continue
    }
    if a == "-c" {
      idx += 1
      continue
    }
    break
  }
  if idx >= args.length() {
    println("jqx: error: missing filter")
    println(
      "Usage: moon run --target native cmd/jqx -- [options] \"<filter>\" [\"<json>\"]",
    )
    return
  }
  let filter = args[idx]
  idx += 1
  let input = if idx < args.length() { args[idx] } else { read_stdin_all() }
  try {
    let f = @lib.parse_filter(filter)
    let j = @lib.parse(input)
    let outputs = @lib.eval(f, j)
    for v in outputs {
      println(format_output(raw, v))
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
