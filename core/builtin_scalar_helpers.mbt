///|
fn builtin_ltrim_ascii_ws(s : String) -> String {
  let mut start = 0
  let end = s.length()
  while start < end &&
        builtin_is_trim_ws(s.unsafe_get(start).to_int().unsafe_to_char()) {
    start += 1
  }
  s.view(start_offset=start, end_offset=end).to_owned()
}

///|
fn builtin_rtrim_ascii_ws(s : String) -> String {
  let start = 0
  let mut end = s.length()
  while end > start &&
        builtin_is_trim_ws(s.unsafe_get(end - 1).to_int().unsafe_to_char()) {
    end -= 1
  }
  s.view(start_offset=start, end_offset=end).to_owned()
}

///|
fn builtin_is_trim_ws(ch : Char) -> Bool {
  let code = ch.to_int()
  code == 0x09 || // \t
  code == 0x0A || // \n
  code == 0x0B || // \v
  code == 0x0C || // \f
  code == 0x0D || // \r
  code == 0x20 || // space
  code == 0x85 ||
  code == 0xA0 ||
  code == 0x1680 ||
  (code >= 0x2000 && code <= 0x200A) ||
  code == 0x2028 ||
  code == 0x2029 ||
  code == 0x202F ||
  code == 0x205F ||
  code == 0x3000
}

///|
fn builtin_trim_ascii_ws(s : String) -> String {
  let left = builtin_ltrim_ascii_ws(s)
  builtin_rtrim_ascii_ws(left)
}

///|
fn builtin_has_outer_trim_ws(s : String) -> Bool {
  if s.length() == 0 {
    false
  } else {
    let first = s.unsafe_get(0).to_int().unsafe_to_char()
    let last = s.unsafe_get(s.length() - 1).to_int().unsafe_to_char()
    builtin_is_trim_ws(first) || builtin_is_trim_ws(last)
  }
}

///|
fn builtin_utf8_byte_length(s : String) -> Int {
  let mut total = 0
  for ch in s {
    let code = ch.to_int()
    if code <= 0x7f {
      total += 1
    } else if code <= 0x7ff {
      total += 2
    } else if code <= 0xffff {
      total += 3
    } else {
      total += 4
    }
  }
  total
}

///|
fn builtin_to_boolean(input : Value) -> Value raise EvalError {
  match input {
    JTrue | JFalse => input
    String(s) =>
      if s == "true" {
        Value::boolean(true)
      } else if s == "false" {
        Value::boolean(false)
      } else {
        raise TypeError(
          json_type_with_value(input) + " cannot be parsed as a boolean",
        )
      }
    _ =>
      raise TypeError(
        json_type_with_value(input) + " cannot be parsed as a boolean",
      )
  }
}

///|
fn builtin_fabs_number(n : Double) -> Double {
  if n == 0.0 {
    0.0
  } else if n < 0.0 {
    -n
  } else {
    n
  }
}

///|
fn builtin_is_negative_zero(n : Double) -> Bool {
  n == 0.0 && 1.0 / n == @double.neg_infinity
}

///|
fn format_filter_input_string(input : Value) -> String {
  match input {
    String(s) => s
    _ => input.to_json_string()
  }
}

///|
fn format_filter_string_preview(s : String) -> String {
  if builtin_utf8_byte_length(s) <= 26 {
    return s
  }
  let max_preview_bytes = 24
  let buf = StringBuilder()
  let mut used = 0
  for ch in s {
    let code = ch.to_int()
    let bytes = if code <= 0x7f {
      1
    } else if code <= 0x7ff {
      2
    } else if code <= 0xffff {
      3
    } else {
      4
    }
    if used + bytes > max_preview_bytes {
      break
    }
    used += bytes
    buf.write_char(ch)
  }
  let preview = buf.to_string()
  if preview == s {
    preview
  } else {
    preview + "..."
  }
}

///|
fn format_filter_string_type_with_value(s : String) -> String {
  "string (" + Value::string(s).to_json_string() + ")"
}

///|
fn format_filter_string_type_with_preview(s : String) -> String {
  let preview = format_filter_string_preview(s)
  let quoted = Value::string(preview).to_json_string()
  "string (" + quoted + ")"
}
