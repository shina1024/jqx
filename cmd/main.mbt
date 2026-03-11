///|
fn parse_cli_inputs(
  cfg : CliArgs,
  stdin_text : String,
) -> Array[@lib.Value] raise @lib.ParseError {
  if cfg.no_input {
    [@lib.Value::null()]
  } else {
    let text = match cfg.input {
      Some(v) => v
      None => stdin_text
    }
    if cfg.raw_input {
      if cfg.slurp {
        [@lib.Value::string(text)]
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
) -> Array[@lib.Value] raise @lib.ParseError {
  if slurp {
    [@lib.Value::array(parse_slurp_values(text))]
  } else {
    parse_json_stream_values(text)
  }
}

///|
fn parse_slurp_values(text : String) -> Array[@lib.Value] raise @lib.ParseError {
  parse_json_stream_values(text)
}

///|
fn parse_json_stream_values(
  text : String,
) -> Array[@lib.Value] raise @lib.ParseError {
  let values = []
  let mut start = 0
  let len = text.length()
  while start < len {
    start = skip_ascii_ws_offset(text, start)
    if start >= len {
      return values
    }
    let end_ = parse_json_value_end(text, start)
    values.push(parse_json_piece(text, start, end_))
    start = end_
  }
  values
}

///|
fn skip_ascii_ws_offset(text : String, start : Int) -> Int {
  let mut i = start
  while i < text.length() {
    let ch = text.unsafe_get(i).to_int().unsafe_to_char()
    if is_ascii_ws(ch) || ch.to_int() == 0xFEFF {
      i += 1
    } else {
      return i
    }
  }
  i
}

///|
fn is_scalar_boundary(ch : Char) -> Bool {
  is_ascii_ws(ch) || ch == '{' || ch == '[' || ch == '"'
}

///|
fn parse_json_value_end(
  text : String,
  start : Int,
) -> Int raise @lib.ParseError {
  let first = text.unsafe_get(start).to_int().unsafe_to_char()
  match first {
    '{' | '[' => parse_structured_value_end(text, start)
    '"' => parse_string_value_end(text, start)
    _ => parse_scalar_value_end(text, start)
  }
}

///|
fn parse_structured_value_end(
  text : String,
  start : Int,
) -> Int raise @lib.ParseError {
  let stack = []
  let mut i = start
  let mut in_string = false
  let mut escaped = false
  while i < text.length() {
    let ch = text.unsafe_get(i).to_int().unsafe_to_char()
    if in_string {
      if escaped {
        escaped = false
      } else if ch == '\\' {
        escaped = true
      } else if ch == '"' {
        in_string = false
      }
      i += 1
      continue
    }
    if ch == '"' {
      in_string = true
    } else if ch == '{' {
      stack.push('}')
    } else if ch == '[' {
      stack.push(']')
    } else if ch == '}' || ch == ']' {
      if stack.length() == 0 || stack[stack.length() - 1] != ch {
        return raise_parse_error_end_from_offset(text, start)
      }
      ignore(stack.pop())
      if stack.length() == 0 {
        return i + 1
      }
    }
    i += 1
  }
  raise_parse_error_end_from_offset(text, start)
}

///|
fn parse_string_value_end(
  text : String,
  start : Int,
) -> Int raise @lib.ParseError {
  let mut i = start + 1
  let mut escaped = false
  while i < text.length() {
    let ch = text.unsafe_get(i).to_int().unsafe_to_char()
    if escaped {
      escaped = false
    } else if ch == '\\' {
      escaped = true
    } else if ch == '"' {
      return i + 1
    }
    i += 1
  }
  raise_parse_error_end_from_offset(text, start)
}

///|
fn parse_scalar_value_end(text : String, start : Int) -> Int {
  let mut i = start
  while i < text.length() {
    let ch = text.unsafe_get(i).to_int().unsafe_to_char()
    if i > start && is_scalar_boundary(ch) {
      return i
    }
    i += 1
  }
  i
}

///|
fn parse_json_piece(
  text : String,
  start_offset : Int,
  end_ : Int,
) -> @lib.Value raise @lib.ParseError {
  @lib.parse(text.view(start_offset~, end_offset=end_).to_string())
}

///|
fn raise_parse_error_end_from_offset(
  text : String,
  start : Int,
) -> Int raise @lib.ParseError {
  let piece = text.view(start_offset=start).to_string()
  try {
    ignore(@lib.parse(piece))
    return start
  } catch {
    err => raise err
  }
}

///|
fn parse_raw_lines(text : String) -> Array[@lib.Value] {
  if text.length() == 0 {
    return []
  }
  let values = []
  let mut start = 0
  for i in 0..<text.length() {
    if text.unsafe_get(i) == '\n' {
      let line = text.view(start_offset=start, end_offset=i).to_string()
      values.push(@lib.Value::string(trim_single_trailing_cr(line)))
      start = i + 1
    }
  }
  if start < text.length() {
    let line = text.view(start_offset=start).to_string()
    values.push(@lib.Value::string(trim_single_trailing_cr(line)))
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
