///|
/// Minimal jq filter parser (dot/field/index/iter, pipe, comma)
///
/// This intentionally supports a small core and can be extended later.

///|

///|
pub suberror FilterError {
  InvalidChar(Position, Char)
  InvalidEof
  Expected(String, Position)
  InvalidNumber(Position, String)
  UnsupportedLiteral(Position)
} derive(Eq)

///|
pub impl Show for FilterError with output(self, logger) {
  match self {
    InvalidChar({ line, column }, c) =>
      logger
      ..write_string("Invalid character ")
      ..write_string(repr(c))
      ..write_string(" at line ")
      ..write_object(line)
      ..write_string(", column ")
      ..write_object(column)
    InvalidEof => logger.write_string("Unexpected end of file")
    Expected(msg, { line, column }) =>
      logger
      ..write_string("Expected ")
      ..write_string(msg)
      ..write_string(" at line ")
      ..write_object(line)
      ..write_string(", column ")
      ..write_object(column)
    InvalidNumber({ line, column }, s) =>
      logger
      ..write_string("Invalid number ")
      ..write_string(s)
      ..write_string(" at line ")
      ..write_object(line)
      ..write_string(", column ")
      ..write_object(column)
    UnsupportedLiteral({ line, column }) =>
      logger
      ..write_string("Unsupported literal at line ")
      ..write_object(line)
      ..write_string(", column ")
      ..write_object(column)
  }
}

///|
priv struct FilterCursor {
  mut offset : Int
  input : StringView
  end_offset : Int
}

///|
fn FilterCursor::make(input : StringView) -> FilterCursor {
  { offset: 0, input, end_offset: input.length() }
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
    Some(c) if c is ('0'..='9') => ()
    Some(_) => ctx.invalid_char(shift=-1)
    None => raise InvalidEof
  }
  for {
    match ctx.read_char() {
      Some(c) if c is ('0'..='9' | '.' | 'e' | 'E' | '+' | '-') => continue
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
  let parsed_double = try? @strconv.parse_double(s)
  match parsed_double {
    Ok(d) =>
      if !s.contains(".") && !s.contains("e") && !s.contains("E") {
        let parsed_int = try? @strconv.parse_int64(s)
        match parsed_int {
          Ok(i) if i <= 9007199254740991 && i >= -9007199254740991 =>
            Json::number(d)
          Ok(_) => Json::number(d, repr=s_str)
          Err(_) => Json::number(d, repr=s_str)
        }
      } else {
        Json::number(d)
      }
    Err(_) =>
      raise InvalidNumber(filter_offset_to_position(ctx.input, start), s_str)
  }
}

///|
fn FilterCursor::parse_dot_suffix(
  ctx : FilterCursor,
) -> Filter raise FilterError {
  ctx.skip_ws()
  let base = match ctx.peek_char() {
    Some('[') => {
      ctx.read_char() |> ignore
      ctx.skip_ws()
      match ctx.peek_char() {
        Some(']') => {
          ctx.read_char() |> ignore
          Filter::iter()
        }
        Some('\"') => {
          let name = ctx.parse_string_literal()
          ctx.skip_ws()
          ctx.expect_char(']')
          Filter::field(name)
        }
        _ => {
          let idx = ctx.parse_int()
          ctx.skip_ws()
          ctx.expect_char(']')
          Filter::index(idx)
        }
      }
    }
    Some(c) if c is ('a'..='z' | 'A'..='Z' | '_') =>
      Filter::field(ctx.parse_identifier())
    Some('.') => {
      ctx.read_char() |> ignore
      Filter::identity()
    }
    _ => Filter::identity()
  }
  ctx.skip_ws()
  match ctx.peek_char() {
    Some('?') => {
      ctx.read_char() |> ignore
      match base {
        Field(name) => Filter::field_opt(name)
        Index(i) => Filter::index_opt(i)
        Iter => Filter::iter_opt()
        _ => base
      }
    }
    _ => base
  }
}

///|
fn FilterCursor::parse_dot_expr(ctx : FilterCursor) -> Filter raise FilterError {
  ctx.expect_char('.')
  let mut current = Filter::identity()
  let first = ctx.parse_dot_suffix()
  if first is Identity {
    ()
  } else {
    current = Filter::pipe(current, first)
  }
  for {
    ctx.skip_ws()
    match ctx.peek_char() {
      Some('.') => {
        ctx.read_char() |> ignore
        let suffix = ctx.parse_dot_suffix()
        if suffix is Identity {
          continue
        } else {
          current = Filter::pipe(current, suffix)
        }
      }
      _ => break
    }
  }
  current
}

///|
fn FilterCursor::parse_primary(ctx : FilterCursor) -> Filter raise FilterError {
  ctx.skip_ws()
  match ctx.peek_char() {
    Some('.') => ctx.parse_dot_expr()
    Some('[') => ctx.parse_array_literal()
    Some('{') => ctx.parse_object_literal()
    Some('(') => ctx.parse_paren_expr()
    Some('\"') => Filter::literal(Json::string(ctx.parse_string_literal()))
    Some('t') =>
      if ctx.try_keyword("true") {
        Filter::literal(Json::boolean(true))
      } else {
        ctx.parse_identifier_or_call()
      }
    Some('f') =>
      if ctx.try_keyword("false") {
        Filter::literal(Json::boolean(false))
      } else {
        ctx.parse_identifier_or_call()
      }
    Some('n') =>
      if ctx.try_keyword("null") {
        Filter::literal(Json::null())
      } else if ctx.try_keyword("not") {
        Filter::not(ctx.parse_primary())
      } else {
        ctx.parse_identifier_or_call()
      }
    Some('e') =>
      if ctx.try_keyword("empty") {
        Filter::empty()
      } else {
        ctx.parse_identifier_or_call()
      }
    Some('i') =>
      if ctx.try_keyword("if") {
        ctx.skip_ws()
        let cond = ctx.parse_comma()
        ctx.skip_ws()
        guard ctx.try_keyword("then") else { ctx.invalid_char() }
        let then_branch = ctx.parse_comma()
        ctx.skip_ws()
        guard ctx.try_keyword("else") else { ctx.invalid_char() }
        let else_branch = ctx.parse_comma()
        ctx.skip_ws()
        guard ctx.try_keyword("end") else { ctx.invalid_char() }
        Filter::if_else(cond, then_branch, else_branch)
      } else {
        ctx.parse_identifier_or_call()
      }
    Some('-') | Some('0'..='9') => Filter::literal(ctx.parse_number_literal())
    Some(c) if c is ('a'..='z' | 'A'..='Z' | '_') =>
      ctx.parse_identifier_or_call()
    Some(_) => ctx.invalid_char()
    None => raise InvalidEof
  }
}

///|
fn FilterCursor::parse_identifier_or_call(
  ctx : FilterCursor,
) -> Filter raise FilterError {
  let name = ctx.parse_identifier()
  ctx.skip_ws()
  match ctx.peek_char() {
    Some('(') => {
      ctx.read_char() |> ignore
      ctx.skip_ws()
      if ctx.peek_char() is Some(')') {
        ctx.read_char() |> ignore
        Filter::call(name, [])
      } else {
        let inner = ctx.parse_comma()
        ctx.skip_ws()
        ctx.expect_char(')')
        Filter::call(name, [inner])
      }
    }
    _ => Filter::builtin(name)
  }
}

///|
fn FilterCursor::parse_paren_expr(
  ctx : FilterCursor,
) -> Filter raise FilterError {
  ctx.expect_char('(')
  let inner = ctx.parse_comma()
  ctx.expect_char(')')
  inner
}

///|
fn FilterCursor::parse_array_literal(
  ctx : FilterCursor,
) -> Filter raise FilterError {
  ctx.expect_char('[')
  ctx.skip_ws()
  if ctx.peek_char() is Some(']') {
    ctx.read_char() |> ignore
    return Filter::Array([])
  }
  let items = []
  for {
    let elem = ctx.parse_pipe()
    items.push(elem)
    ctx.skip_ws()
    match ctx.peek_char() {
      Some(',') => {
        ctx.read_char() |> ignore
        continue
      }
      Some(']') => {
        ctx.read_char() |> ignore
        break
      }
      Some(_) => ctx.invalid_char()
      None => raise InvalidEof
    }
  }
  Filter::Array(items)
}

///|
fn FilterCursor::parse_object_literal(
  ctx : FilterCursor,
) -> Filter raise FilterError {
  ctx.expect_char('{')
  ctx.skip_ws()
  if ctx.peek_char() is Some('}') {
    ctx.read_char() |> ignore
    return Filter::Object([])
  }
  let items = []
  for {
    ctx.skip_ws()
    let key = match ctx.peek_char() {
      Some('\"') => ctx.parse_string_literal()
      Some(c) if c is ('a'..='z' | 'A'..='Z' | '_') => ctx.parse_identifier()
      Some(_) => ctx.invalid_char()
      None => raise InvalidEof
    }
    ctx.expect_char(':')
    let value = ctx.parse_pipe()
    items.push((key, value))
    ctx.skip_ws()
    match ctx.peek_char() {
      Some(',') => {
        ctx.read_char() |> ignore
        continue
      }
      Some('}') => {
        ctx.read_char() |> ignore
        break
      }
      Some(_) => ctx.invalid_char()
      None => raise InvalidEof
    }
  }
  Filter::Object(items)
}

///|
fn FilterCursor::parse_mul(ctx : FilterCursor) -> Filter raise FilterError {
  let mut left = ctx.parse_primary()
  for {
    ctx.skip_ws()
    match ctx.peek_char() {
      Some('*') => {
        ctx.read_char() |> ignore
        let right = ctx.parse_primary()
        left = Filter::mul(left, right)
      }
      Some('/') => {
        // Don't consume '//' here; it's handled by fallback.
        let saved = ctx.offset
        ctx.read_char() |> ignore
        match ctx.peek_char() {
          Some('/') => {
            ctx.offset = saved
            break
          }
          _ => ()
        }
        let right = ctx.parse_primary()
        left = Filter::div(left, right)
      }
      _ => break
    }
  }
  left
}

///|
fn FilterCursor::parse_add(ctx : FilterCursor) -> Filter raise FilterError {
  let mut left = ctx.parse_mul()
  for {
    ctx.skip_ws()
    match ctx.peek_char() {
      Some('+') => {
        ctx.read_char() |> ignore
        let right = ctx.parse_mul()
        left = Filter::add(left, right)
      }
      Some('-') => {
        ctx.read_char() |> ignore
        let right = ctx.parse_mul()
        left = Filter::sub(left, right)
      }
      _ => break
    }
  }
  left
}

///|
fn FilterCursor::parse_pipe(ctx : FilterCursor) -> Filter raise FilterError {
  let mut left = ctx.parse_add()
  for {
    ctx.skip_ws()
    match ctx.peek_char() {
      Some('|') => {
        ctx.read_char() |> ignore
        let right = ctx.parse_add()
        left = Filter::pipe(left, right)
      }
      _ => break
    }
  }
  left
}

///|
fn FilterCursor::parse_compare(ctx : FilterCursor) -> Filter raise FilterError {
  let mut left = ctx.parse_pipe()
  for {
    ctx.skip_ws()
    match ctx.peek_char() {
      Some('=') => {
        ctx.read_char() |> ignore
        match ctx.read_char() {
          Some('=') => {
            let right = ctx.parse_pipe()
            left = Filter::eq(left, right)
          }
          Some(_) => ctx.invalid_char(shift=-1)
          None => raise InvalidEof
        }
      }
      Some('!') => {
        ctx.read_char() |> ignore
        match ctx.read_char() {
          Some('=') => {
            let right = ctx.parse_pipe()
            left = Filter::neq(left, right)
          }
          Some(_) => ctx.invalid_char(shift=-1)
          None => raise InvalidEof
        }
      }
      Some('<') => {
        ctx.read_char() |> ignore
        match ctx.peek_char() {
          Some('=') => {
            ctx.read_char() |> ignore
            let right = ctx.parse_pipe()
            left = Filter::lte(left, right)
          }
          _ => {
            let right = ctx.parse_pipe()
            left = Filter::lt(left, right)
          }
        }
      }
      Some('>') => {
        ctx.read_char() |> ignore
        match ctx.peek_char() {
          Some('=') => {
            ctx.read_char() |> ignore
            let right = ctx.parse_pipe()
            left = Filter::gte(left, right)
          }
          _ => {
            let right = ctx.parse_pipe()
            left = Filter::gt(left, right)
          }
        }
      }
      _ => break
    }
  }
  left
}

///|
fn FilterCursor::parse_and(ctx : FilterCursor) -> Filter raise FilterError {
  let mut left = ctx.parse_compare()
  for {
    ctx.skip_ws()
    if ctx.try_keyword("and") {
      let right = ctx.parse_compare()
      left = Filter::and_(left, right)
    } else {
      break
    }
  }
  left
}

///|
fn FilterCursor::parse_or(ctx : FilterCursor) -> Filter raise FilterError {
  let mut left = ctx.parse_and()
  for {
    ctx.skip_ws()
    if ctx.try_keyword("or") {
      let right = ctx.parse_and()
      left = Filter::or_(left, right)
    } else {
      break
    }
  }
  left
}

///|
fn FilterCursor::parse_fallback(ctx : FilterCursor) -> Filter raise FilterError {
  let mut left = ctx.parse_or()
  for {
    ctx.skip_ws()
    match ctx.peek_char() {
      Some('/') => {
        ctx.read_char() |> ignore
        match ctx.peek_char() {
          Some('/') => {
            ctx.read_char() |> ignore
            let right = ctx.parse_or()
            left = Filter::fallback(left, right)
          }
          _ => {
            ctx.offset -= 1
            break
          }
        }
      }
      _ => break
    }
  }
  left
}

///|
fn FilterCursor::parse_comma(ctx : FilterCursor) -> Filter raise FilterError {
  let mut left = ctx.parse_fallback()
  for {
    ctx.skip_ws()
    match ctx.peek_char() {
      Some(',') => {
        ctx.read_char() |> ignore
        let right = ctx.parse_fallback()
        left = Filter::comma(left, right)
      }
      _ => break
    }
  }
  left
}

///|
pub fn parse_filter(input : StringView) -> Filter raise FilterError {
  let ctx = FilterCursor::make(input)
  let filter = ctx.parse_comma()
  ctx.skip_ws()
  if ctx.offset >= ctx.end_offset {
    filter
  } else {
    ctx.invalid_char()
  }
}
