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
priv enum JsonFormatFrame {
  WriteJsonValue(Value, Int)
  WriteJsonText(String)
  WriteEscapedString(String)
  WriteIndent(Int)
}

///|
pub fn Value::write_json_chunks(
  self : Value,
  pretty : Bool,
  write : (String) -> Unit,
) -> Unit {
  // jq 1.8.2 uses MAX_PRINT_DEPTH=10000 in src/jv_print.c and emits
  // "<skipped: too deep>" once printing recurses past that depth.
  let max_depth = 10000
  fn write_indent(depth : Int) {
    write("\n")
    let spaces = "                                                                "
    let mut remaining = depth * 2
    while remaining >= spaces.length() {
      write(spaces)
      remaining -= spaces.length()
    }
    if remaining > 0 {
      write(spaces.view(end_offset=remaining).to_owned())
    }
  }

  fn write_escaped(s : String) {
    let buf = StringBuilder()
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
    write(buf.to_string())
  }

  let pending = [WriteJsonValue(self, 0)]
  while pending.length() > 0 {
    match pending.pop().unwrap() {
      WriteJsonText(text) => write(text)
      WriteEscapedString(text) => write_escaped(text)
      WriteIndent(depth) => write_indent(depth)
      WriteJsonValue(j, depth) => {
        if depth > max_depth {
          write("<skipped: too deep>")
          continue
        }
        match j {
          JNull => write("null")
          JTrue => write("true")
          JFalse => write("false")
          Number(n, repr) =>
            match repr {
              Some(s) =>
                match decimal_canonical_repr(s) {
                  Some(canonical) => write(canonical)
                  None => write(s)
                }
              None =>
                if n != n {
                  write("null")
                } else if n == @double.infinity {
                  write("1.7976931348623157e+308")
                } else if n == @double.neg_infinity {
                  write("-1.7976931348623157e+308")
                } else {
                  write(format_finite_number_without_repr(n))
                }
            }
          String(s) => write_escaped(s)
          Array(values) => {
            write("[")
            if values.length() == 0 {
              write("]")
              continue
            }
            pending.push(WriteJsonText("]"))
            if pretty {
              pending.push(WriteIndent(depth))
            }
            let mut i = values.length() - 1
            while i >= 0 {
              pending.push(WriteJsonValue(values[i], depth + 1))
              if pretty {
                pending.push(WriteIndent(depth + 1))
              }
              if i > 0 {
                pending.push(WriteJsonText(","))
              }
              i -= 1
            }
          }
          Object(object) => {
            write("{")
            let entries = object_entries_sorted(object)
            if entries.length() == 0 {
              write("}")
              continue
            }
            pending.push(WriteJsonText("}"))
            if pretty {
              pending.push(WriteIndent(depth))
            }
            let mut i = entries.length() - 1
            while i >= 0 {
              let entry = entries[i]
              pending.push(WriteJsonValue(entry.1, depth + 1))
              if pretty {
                pending.push(WriteJsonText(" "))
              }
              pending.push(WriteJsonText(":"))
              pending.push(WriteEscapedString(entry.0))
              if pretty {
                pending.push(WriteIndent(depth + 1))
              }
              if i > 0 {
                pending.push(WriteJsonText(","))
              }
              i -= 1
            }
          }
        }
      }
    }
  }
}

///|
fn Value::to_json_string_with_layout(self : Value, pretty : Bool) -> String {
  let buf = StringBuilder()
  self.write_json_chunks(pretty, fn(chunk) { buf.write_string(chunk) })
  buf.to_string()
}

///|
/// Encode Value as a compact JSON string (jq-style output).
pub fn Value::to_json_string(self : Value) -> String {
  self.to_json_string_with_layout(false)
}

///|
/// Encode Value as an indented JSON string (jq-style output).
pub fn Value::to_json_string_pretty(self : Value) -> String {
  self.to_json_string_with_layout(true)
}
