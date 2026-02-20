///|
priv struct FilterCursor {
  mut offset : Int
  input : StringView
  end_offset : Int
  mut gensym : Int
}

///|
priv enum UpdateAssignOp {
  Set
  Update
  Add
  Sub
  Mul
  Div
  Mod
  Fallback
}

///|
priv enum AsPattern {
  Var(String)
  Array(Array[AsPattern])
  Object(Array[AsObjectPatternEntry])
}

///|
priv struct AsObjectPatternEntry {
  key : Filter
  bindings : Array[AsPattern]
}

///|
fn FilterCursor::make(input : StringView) -> FilterCursor {
  { offset: 0, input, end_offset: input.length(), gensym: 0 }
}

///|
fn filter_offset_to_position(input : StringView, offset : Int) -> Position {
  let mut line = 1
  let mut column = 1
  for i in 0..<offset {
    if input.unsafe_get(i) == '\n' {
      line += 1
      column = 1
    } else {
      column += 1
    }
  }
  return Position::{ line, column }
}

///|
fn[T] FilterCursor::invalid_char(
  ctx : FilterCursor,
  shift? : Int = 0,
) -> T raise FilterError {
  let offset = ctx.offset + shift
  let replacement_char : Char = '\u{fffd}'
  raise InvalidChar(
    filter_offset_to_position(ctx.input, offset),
    ctx.input.get_char(offset).unwrap_or(replacement_char),
  )
}

///|
fn FilterCursor::read_char(ctx : FilterCursor) -> Char? {
  if ctx.offset < ctx.end_offset {
    let c = ctx.input.unsafe_get(ctx.offset).to_int()
    ctx.offset += 1
    Some(c.unsafe_to_char())
  } else {
    None
  }
}

///|
fn FilterCursor::peek_char(ctx : FilterCursor) -> Char? {
  let saved = ctx.offset
  let c = ctx.read_char()
  ctx.offset = saved
  c
}

///|
fn is_ident_continue(c : Char) -> Bool {
  c is ('a'..='z' | 'A'..='Z' | '_' | '0'..='9')
}

///|
fn FilterCursor::try_keyword(ctx : FilterCursor, kw : String) -> Bool {
  let saved = ctx.offset
  for ch in kw {
    match ctx.read_char() {
      Some(c) if c == ch => ()
      _ => {
        ctx.offset = saved
        return false
      }
    }
  }
  match ctx.peek_char() {
    Some(c) if is_ident_continue(c) => {
      ctx.offset = saved
      false
    }
    _ => true
  }
}

///|
fn FilterCursor::peek_keyword(ctx : FilterCursor, kw : String) -> Bool {
  ctx.skip_ws()
  let saved = ctx.offset
  let ok = ctx.try_keyword(kw)
  ctx.offset = saved
  ok
}

///|
fn FilterCursor::try_qslash_fallback_sep(ctx : FilterCursor) -> Bool {
  ctx.skip_ws()
  let saved = ctx.offset
  match ctx.read_char() {
    Some('?') =>
      match ctx.read_char() {
        Some('/') =>
          match ctx.read_char() {
            Some('/') => true
            _ => {
              ctx.offset = saved
              false
            }
          }
        _ => {
          ctx.offset = saved
          false
        }
      }
    _ => {
      ctx.offset = saved
      false
    }
  }
}

///|
fn FilterCursor::skip_ws(ctx : FilterCursor) -> Unit {
  let rest = ctx.input.view(start_offset=ctx.offset, end_offset=ctx.end_offset)
  lexmatch rest {
    ("[ \t\r\n]+", next) => ctx.offset = ctx.end_offset - next.length()
    _ => ()
  }
}

///|
fn FilterCursor::expect_char(
  ctx : FilterCursor,
  c : Char,
) -> Unit raise FilterError {
  ctx.skip_ws()
  match ctx.read_char() {
    Some(ch) if ch == c => ()
    Some(_) => ctx.invalid_char(shift=-1)
    None => raise InvalidEof
  }
}

///|
fn FilterCursor::parse_identifier(
  ctx : FilterCursor,
) -> String raise FilterError {
  ctx.skip_ws()
  let start = ctx.offset
  match ctx.read_char() {
    Some(c) if c is ('a'..='z' | 'A'..='Z' | '_') => ()
    Some(_) => ctx.invalid_char(shift=-1)
    None => raise InvalidEof
  }
  for {
    match ctx.read_char() {
      Some(c) if c is ('a'..='z' | 'A'..='Z' | '_' | '0'..='9') => continue
      Some(_) => {
        ctx.offset -= 1
        break
      }
      None => break
    }
  }
  ctx.input.view(start_offset=start, end_offset=ctx.offset).to_string()
}

///|
fn FilterCursor::parse_int(ctx : FilterCursor) -> Int raise FilterError {
  ctx.skip_ws()
  let start = ctx.offset
  match ctx.read_char() {
    Some('-') => ()
    Some(c) if c is ('0'..='9') => ()
    Some(_) => ctx.invalid_char(shift=-1)
    None => raise InvalidEof
  }
  for {
    match ctx.read_char() {
      Some(c) if c is ('0'..='9') => continue
      Some(_) => {
        ctx.offset -= 1
        break
      }
      None => break
    }
  }
  let end = ctx.offset
  let s = ctx.input.view(start_offset=start, end_offset=end)
  let parsed = try? @strconv.parse_int64(s)
  match parsed {
    Ok(v) => v.to_int()
    Err(_) =>
      raise InvalidNumber(
        filter_offset_to_position(ctx.input, start),
        s.to_string(),
      )
  }
}

///|
fn FilterCursor::parse_optional_int(
  ctx : FilterCursor,
) -> Int? raise FilterError {
  ctx.skip_ws()
  match ctx.peek_char() {
    Some('-') => Some(ctx.parse_int())
    Some(c) => if c is ('0'..='9') { Some(ctx.parse_int()) } else { None }
    None => None
  }
}

///|
fn FilterCursor::parse_string_literal(
  ctx : FilterCursor,
) -> String raise FilterError {
  ctx.skip_ws()
  match ctx.read_char() {
    Some('\"') => ()
    Some(_) => ctx.invalid_char(shift=-1)
    None => raise InvalidEof
  }
  let buf = StringBuilder::new()
  let mut start = ctx.offset
  fn flush(end : Int) {
    if start > 0 && end > start {
      buf.write_view(try! ctx.input[start:end])
    }
  }

  for {
    match ctx.read_char() {
      Some('\"') => {
        flush(ctx.offset - 1)
        break
      }
      Some('\n' | '\r') => ctx.invalid_char(shift=-1)
      Some('\\') => {
        flush(ctx.offset - 1)
        match ctx.read_char() {
          Some('b') => buf.write_char('\b')
          Some('f') => buf.write_char('\u{0C}')
          Some('n') => buf.write_char('\n')
          Some('r') => buf.write_char('\r')
          Some('t') => buf.write_char('\t')
          Some('\"') => buf.write_char('\"')
          Some('\\') => buf.write_char('\\')
          Some('/') => buf.write_char('/')
          Some('u') => {
            let c = ctx.parse_hex_digits(4)
            buf.write_char(c.unsafe_to_char())
          }
          Some(_) => ctx.invalid_char(shift=-1)
          None => raise InvalidEof
        }
        start = ctx.offset
      }
      Some(ch) =>
        if ch.to_int() < 32 {
          ctx.invalid_char(shift=-1)
        } else {
          continue
        }
      None => raise InvalidEof
    }
  }
  buf.to_string()
}

///|
/// Parse jq string expression.
/// Supports interpolation `\(... )` by lowering to string concatenation.
fn FilterCursor::parse_string_expr(
  ctx : FilterCursor,
) -> Filter raise FilterError {
  ctx.skip_ws()
  match ctx.read_char() {
    Some('\"') => ()
    Some(_) => ctx.invalid_char(shift=-1)
    None => raise InvalidEof
  }

  let mut text = StringBuilder::new()
  let parts = []
  fn flush_text() {
    let s = text.to_string()
    if s.length() > 0 {
      parts.push(Filter::literal(Json::string(s)))
      text = StringBuilder::new()
    }
  }

  for {
    match ctx.read_char() {
      Some('\"') => {
        flush_text()
        break
      }
      Some('\n' | '\r') => ctx.invalid_char(shift=-1)
      Some('\\') =>
        match ctx.read_char() {
          Some('(') => {
            flush_text()
            let inner = ctx.parse_comma()
            ctx.skip_ws()
            match ctx.read_char() {
              Some(')') => ()
              Some(_) => ctx.invalid_char(shift=-1)
              None => raise InvalidEof
            }
            parts.push(Filter::pipe(inner, Filter::builtin("tostring")))
          }
          Some('b') => text.write_char('\b')
          Some('f') => text.write_char('\u{0C}')
          Some('n') => text.write_char('\n')
          Some('r') => text.write_char('\r')
          Some('t') => text.write_char('\t')
          Some('\"') => text.write_char('\"')
          Some('\\') => text.write_char('\\')
          Some('/') => text.write_char('/')
          Some('u') => {
            let c = ctx.parse_hex_digits(4)
            text.write_char(c.unsafe_to_char())
          }
          Some(_) => ctx.invalid_char(shift=-1)
          None => raise InvalidEof
        }
      Some(ch) =>
        if ch.to_int() < 32 {
          ctx.invalid_char(shift=-1)
        } else {
          text.write_char(ch)
        }
      None => raise InvalidEof
    }
  }

  if parts.length() == 0 {
    return Filter::literal(Json::string(""))
  }
  let mut out = parts[0]
  for i in 1..<parts.length() {
    out = Filter::add(out, parts[i])
  }
  out
}

///|
/// Parse jq format-string expression used by `@name "..."`.
/// Literal segments are kept raw; only interpolated `\(... )` segments
/// are piped through the selected format filter.
fn FilterCursor::parse_format_string_expr(
  ctx : FilterCursor,
  format_filter_name : String,
) -> Filter raise FilterError {
  ctx.skip_ws()
  match ctx.read_char() {
    Some('\"') => ()
    Some(_) => ctx.invalid_char(shift=-1)
    None => raise InvalidEof
  }

  let mut text = StringBuilder::new()
  let parts = []
  fn flush_text() {
    let s = text.to_string()
    if s.length() > 0 {
      parts.push(Filter::literal(Json::string(s)))
      text = StringBuilder::new()
    }
  }

  for {
    match ctx.read_char() {
      Some('\"') => {
        flush_text()
        break
      }
      Some('\n' | '\r') => ctx.invalid_char(shift=-1)
      Some('\\') =>
        match ctx.read_char() {
          Some('(') => {
            flush_text()
            let inner = ctx.parse_comma()
            ctx.skip_ws()
            match ctx.read_char() {
              Some(')') => ()
              Some(_) => ctx.invalid_char(shift=-1)
              None => raise InvalidEof
            }
            parts.push(Filter::pipe(inner, Filter::builtin(format_filter_name)))
          }
          Some('b') => text.write_char('\b')
          Some('f') => text.write_char('\u{0C}')
          Some('n') => text.write_char('\n')
          Some('r') => text.write_char('\r')
          Some('t') => text.write_char('\t')
          Some('\"') => text.write_char('\"')
          Some('\\') => text.write_char('\\')
          Some('/') => text.write_char('/')
          Some('u') => {
            let c = ctx.parse_hex_digits(4)
            text.write_char(c.unsafe_to_char())
          }
          Some(_) => ctx.invalid_char(shift=-1)
          None => raise InvalidEof
        }
      Some(ch) =>
        if ch.to_int() < 32 {
          ctx.invalid_char(shift=-1)
        } else {
          text.write_char(ch)
        }
      None => raise InvalidEof
    }
  }

  if parts.length() == 0 {
    return Filter::literal(Json::string(""))
  }
  let mut out = parts[0]
  for i in 1..<parts.length() {
    out = Filter::add(out, parts[i])
  }
  out
}

///|
fn filter_string_literal_value(filter : Filter) -> String? {
  match filter {
    Literal(String(s)) => Some(s)
    _ => None
  }
}

///|
fn FilterCursor::parse_hex_digits(
  ctx : FilterCursor,
  n : Int,
) -> Int raise FilterError {
  let mut r = 0
  for i in 0..<n {
    match ctx.read_char() {
      Some(c) =>
        if c >= 'A' {
          let d = (c.to_int() & (32).lnot()) - 'A'.to_int() + 10
          if d > 15 {
            ctx.invalid_char(shift=-1)
          }
          r = (r << 4) | d
        } else if c >= '0' {
          let d = c.to_int() - '0'.to_int()
          if d > 9 {
            ctx.invalid_char(shift=-1)
          }
          r = (r << 4) | d
        } else {
          ctx.invalid_char(shift=-1)
        }
      None => raise InvalidEof
    }
  }
  r
}

///|
fn FilterCursor::parse_number_literal(
  ctx : FilterCursor,
) -> Json raise FilterError {
  ctx.skip_ws()
  let start = ctx.offset
  match ctx.read_char() {
    Some('-') => ()
    Some('.') => ()
    Some(c) if c is ('0'..='9') => ()
    Some(_) => ctx.invalid_char(shift=-1)
    None => raise InvalidEof
  }
  let mut prev_is_exp_marker = false
  for {
    match ctx.read_char() {
      Some(c) if c is ('0'..='9' | '.' | 'e' | 'E') => {
        prev_is_exp_marker = c == 'e' || c == 'E'
        continue
      }
      Some(c) if c is ('+' | '-') => {
        if prev_is_exp_marker {
          prev_is_exp_marker = false
          continue
        }
        ctx.offset -= 1
        break
      }
      Some(_) => {
        ctx.offset -= 1
        break
      }
      None => break
    }
  }
  let end = ctx.offset
  let s = ctx.input.view(start_offset=start, end_offset=end)
  let s_str = s.to_string()
  let starts_with_dot = s_str.length() > 0 &&
    s_str.unsafe_get(0).to_int().unsafe_to_char() == '.'
  let parse_input = if starts_with_dot { "0" + s_str } else { s_str }
  let parsed = try? parse(parse_input.view())
  match parsed {
    Ok(Number(n, repr)) =>
      if starts_with_dot {
        Json::number(n)
      } else {
        Json::number(n, repr?)
      }
    Ok(_) =>
      raise InvalidNumber(filter_offset_to_position(ctx.input, start), s_str)
    Err(_) =>
      raise InvalidNumber(filter_offset_to_position(ctx.input, start), s_str)
  }
}

///|
