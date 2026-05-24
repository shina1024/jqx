///|
pub impl Show for Value with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
fn format_finite_number_without_repr(n : Double) -> String {
  let mut raw = n.to_string()
  if raw.contains("e") || raw.contains("E") {
    match decimal_expand_positive_exponent(raw) {
      Some(expanded) => raw = expanded
      None => return raw
    }
  } else if raw.contains(".") {
    return raw
  }
  let negative = raw.has_prefix("-")
  let digits = if negative {
    raw.view(start_offset=1, end_offset=raw.length()).to_owned()
  } else {
    raw
  }
  if digits.length() <= 16 {
    return raw
  }
  if digits.unsafe_get(0).to_int().unsafe_to_char() != '1' {
    return raw
  }
  for i in 1..<digits.length() {
    if digits.unsafe_get(i).to_int().unsafe_to_char() != '0' {
      return raw
    }
  }
  let sign = if negative { "-" } else { "" }
  sign + "1e+" + (digits.length() - 1).to_string()
}

///|
/// Encode Value as a compact JSON string (jq-style output).
pub fn Value::to_json_string(self : Value) -> String {
  let buf = StringBuilder()
  // jq 1.8.1 uses MAX_PRINT_DEPTH=256 in src/jv_print.c and emits
  // "<skipped: too deep>" once printing recurses past that depth.
  let max_depth = 256
  fn write_escaped(s : String) {
    buf.write_char('"')
    for ch in s {
      match ch {
        '"' => buf.write_string("\\\"")
        '\\' => buf.write_string("\\\\")
        '\b' => buf.write_string("\\b")
        '\u{0C}' => buf.write_string("\\f")
        '\n' => buf.write_string("\\n")
        '\r' => buf.write_string("\\r")
        '\t' => buf.write_string("\\t")
        _ =>
          if ch.to_int() < 32 || ch.to_int() == 0x7F {
            let code = ch.to_int()
            buf.write_string("\\u")
            let d3 = (code >> 12) & 0xF
            let d2 = (code >> 8) & 0xF
            let d1 = (code >> 4) & 0xF
            let d0 = code & 0xF
            fn hex(d : Int) -> Char {
              if d < 10 {
                (d + '0'.to_int()).unsafe_to_char()
              } else {
                (d - 10 + 'a'.to_int()).unsafe_to_char()
              }
            }

            buf.write_char(hex(d3))
            buf.write_char(hex(d2))
            buf.write_char(hex(d1))
            buf.write_char(hex(d0))
          } else {
            buf.write_char(ch)
          }
      }
    }
    buf.write_char('"')
  }

  fn write_value(j : Value, depth : Int) {
    if depth > max_depth {
      buf.write_string("<skipped: too deep>")
      return
    }
    match j {
      JNull => buf.write_string("null")
      JTrue => buf.write_string("true")
      JFalse => buf.write_string("false")
      Number(n, repr) =>
        match repr {
          Some(s) => buf.write_string(s)
          None =>
            if n != n {
              buf.write_string("null")
            } else if n == @double.infinity {
              buf.write_string("1.7976931348623157e+308")
            } else if n == @double.neg_infinity {
              buf.write_string("-1.7976931348623157e+308")
            } else {
              buf.write_string(format_finite_number_without_repr(n))
            }
        }
      String(s) => write_escaped(s)
      Array(a) => {
        buf.write_char('[')
        let mut first = true
        for v in a {
          if first {
            first = false
          } else {
            buf.write_char(',')
          }
          write_value(v, depth + 1)
        }
        buf.write_char(']')
      }
      Object(o) => {
        buf.write_char('{')
        let mut first = true
        for kv in object_entries_sorted(o) {
          let k = kv.0
          let v = kv.1
          if first {
            first = false
          } else {
            buf.write_char(',')
          }
          write_escaped(k)
          buf.write_char(':')
          write_value(v, depth + 1)
        }
        buf.write_char('}')
      }
    }
  }

  write_value(self, 0)
  buf.to_string()
}
