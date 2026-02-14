///|
/// Minimal jq filter parser (dot/field/index/iter, pipe, comma)
///
/// This intentionally supports a small core and can be extended later.

///|

///|
pub suberror FilterError {
  InvalidChar(Position, Char)
  InvalidEof
  InvalidNumber(Position, String)
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
      .write_object(column)
    InvalidEof => logger.write_string("Unexpected end of file")
    InvalidNumber({ line, column }, s) =>
      logger
      ..write_string("Invalid number ")
      ..write_string(s)
      ..write_string(" at line ")
      ..write_object(line)
      ..write_string(", column ")
      .write_object(column)
  }
}

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
fn bracket_static_selector_from_filter(filter : Filter) -> Filter? {
  match filter {
    Literal(String(name)) => Some(Filter::field(name))
    Literal(Number(n, _)) =>
      if n == n && n != @double.infinity && n != @double.neg_infinity {
        Some(Filter::index(n.to_int()))
      } else {
        None
      }
    _ => None
  }
}

///|
fn apply_optional_suffix(base : Filter, optional : Bool) -> Filter {
  if !optional {
    return base
  }
  match base {
    Field(name) => Filter::field_opt(name)
    Index(i) => Filter::index_opt(i)
    Slice(start, end) => Filter::slice_opt(start, end)
    Iter => Filter::iter_opt()
    _ => Filter::try_(base)
  }
}

///|
fn FilterCursor::lower_bracket_dynamic_on_bound(
  ctx : FilterCursor,
  bound : Filter,
  key : Filter,
  optional : Bool,
) -> Filter {
  let key_tmp = ctx.fresh_as_tmp()
  let key_var = Filter::var_(key_tmp)
  let access = Filter::pipe(
    bound,
    Filter::call("getpath", [Filter::Array([key_var])]),
  )
  let access = if optional { Filter::try_(access) } else { access }
  Filter::as_(key, key_tmp, access)
}

///|
fn FilterCursor::lower_bracket_keys_on_base(
  ctx : FilterCursor,
  base : Filter,
  keys : Array[Filter],
  optional : Bool,
) -> Filter {
  let static_selectors : Array[Filter]? = {
    let out = []
    let mut ok = true
    for key in keys {
      match bracket_static_selector_from_filter(key) {
        Some(selector) => out.push(apply_optional_suffix(selector, optional))
        None => {
          ok = false
          break
        }
      }
    }
    if ok {
      Some(out)
    } else {
      None
    }
  }
  match static_selectors {
    Some(selectors) => {
      let mut combined = selectors[0]
      for i in 1..<selectors.length() {
        combined = Filter::comma(combined, selectors[i])
      }
      Filter::pipe(base, combined)
    }
    None =>
      if keys.length() == 1 {
        let base_tmp = ctx.fresh_as_tmp()
        let base_var = Filter::var_(base_tmp)
        Filter::as_(
          base,
          base_tmp,
          ctx.lower_bracket_dynamic_on_bound(base_var, keys[0], optional),
        )
      } else {
        let base_tmp = ctx.fresh_as_tmp()
        let base_var = Filter::var_(base_tmp)
        let mut body : Filter? = None
        for key in keys {
          let current = match bracket_static_selector_from_filter(key) {
            Some(selector) =>
              Filter::pipe(base_var, apply_optional_suffix(selector, optional))
            None => ctx.lower_bracket_dynamic_on_bound(base_var, key, optional)
          }
          body = match body {
            Some(prev) => Some(Filter::comma(prev, current))
            None => Some(current)
          }
        }
        match body {
          Some(compiled) => Filter::as_(base, base_tmp, compiled)
          None => abort("unreachable")
        }
      }
  }
}

///|
fn slice_index_from_filter(filter : Filter) -> Int? {
  match filter {
    Literal(Number(n, _)) =>
      if n == n && n != @double.infinity && n != @double.neg_infinity {
        Some(n.to_int())
      } else {
        None
      }
    _ => None
  }
}

///|
fn slice_endpoint_filter(expr : Filter?) -> Filter {
  match expr {
    Some(v) => v
    None => Filter::literal(Json::null())
  }
}

///|
fn FilterCursor::lower_bracket_slice_on_base(
  ctx : FilterCursor,
  base : Filter,
  start_expr : Filter?,
  end_expr : Filter?,
  optional : Bool,
) -> Filter raise FilterError {
  if start_expr is None && end_expr is None {
    ctx.invalid_char()
  }

  let start_static = match start_expr {
    Some(v) => slice_index_from_filter(v)
    None => None
  }
  let end_static = match end_expr {
    Some(v) => slice_index_from_filter(v)
    None => None
  }
  let start_is_static = match start_expr {
    Some(_) => start_static is Some(_)
    None => true
  }
  let end_is_static = match end_expr {
    Some(_) => end_static is Some(_)
    None => true
  }
  let can_lower_static = start_is_static && end_is_static
  if can_lower_static {
    return Filter::pipe(
      base,
      apply_optional_suffix(Filter::slice(start_static, end_static), optional),
    )
  }

  let base_tmp = ctx.fresh_as_tmp()
  let start_tmp = ctx.fresh_as_tmp()
  let end_tmp = ctx.fresh_as_tmp()
  let base_var = Filter::var_(base_tmp)
  let start_var = Filter::var_(start_tmp)
  let end_var = Filter::var_(end_tmp)
  let access0 = Filter::pipe(
    base_var,
    Filter::call("_slice", [start_var, end_var]),
  )
  let access = if optional { Filter::try_(access0) } else { access0 }
  Filter::as_(
    base,
    base_tmp,
    Filter::as_(
      slice_endpoint_filter(start_expr),
      start_tmp,
      Filter::as_(slice_endpoint_filter(end_expr), end_tmp, access),
    ),
  )
}

///|
fn FilterCursor::parse_bracket_postfix(
  ctx : FilterCursor,
  base : Filter,
) -> Filter raise FilterError {
  ctx.expect_char('[')
  ctx.skip_ws()
  if ctx.peek_char() is Some(']') {
    ctx.read_char() |> ignore
    ctx.skip_ws()
    let optional = if ctx.peek_char() is Some('?') {
      ctx.read_char() |> ignore
      true
    } else {
      false
    }
    return Filter::pipe(base, apply_optional_suffix(Filter::iter(), optional))
  }

  let first = if ctx.peek_char() is Some(':') {
    None
  } else {
    Some(ctx.parse_pipe(allow_as=false))
  }
  ctx.skip_ws()

  if ctx.peek_char() is Some(':') {
    ctx.read_char() |> ignore
    ctx.skip_ws()
    let end_expr = if ctx.peek_char() is Some(']') {
      None
    } else {
      Some(ctx.parse_pipe(allow_as=false))
    }
    ctx.skip_ws()
    ctx.expect_char(']')
    ctx.skip_ws()
    let optional = if ctx.peek_char() is Some('?') {
      ctx.read_char() |> ignore
      true
    } else {
      false
    }
    return ctx.lower_bracket_slice_on_base(base, first, end_expr, optional)
  }

  let keys = []
  match first {
    Some(v) => keys.push(v)
    None => ctx.invalid_char()
  }
  for {
    ctx.skip_ws()
    match ctx.peek_char() {
      Some(',') => {
        ctx.read_char() |> ignore
        keys.push(ctx.parse_pipe(allow_as=false))
      }
      Some(']') => {
        ctx.read_char() |> ignore
        break
      }
      Some(_) => ctx.invalid_char()
      None => raise InvalidEof
    }
  }
  ctx.skip_ws()
  let optional = if ctx.peek_char() is Some('?') {
    ctx.read_char() |> ignore
    true
  } else {
    false
  }
  ctx.lower_bracket_keys_on_base(base, keys, optional)
}

///|
fn FilterCursor::parse_dot_suffix(
  ctx : FilterCursor,
) -> Filter raise FilterError {
  ctx.skip_ws()
  fn parse_index_or_field_item() -> Filter raise FilterError {
    ctx.skip_ws()
    match ctx.peek_char() {
      Some('\"') => Filter::field(ctx.parse_string_literal())
      _ =>
        match ctx.parse_optional_int() {
          Some(idx) => Filter::index(idx)
          None => ctx.invalid_char()
        }
    }
  }

  let base = match ctx.peek_char() {
    Some('[') => {
      ctx.read_char() |> ignore
      ctx.skip_ws()
      match ctx.peek_char() {
        Some(']') => {
          ctx.read_char() |> ignore
          Filter::iter()
        }
        _ => {
          let first_opt = if ctx.peek_char() is Some(':') {
            None
          } else {
            Some(parse_index_or_field_item())
          }
          ctx.skip_ws()
          if ctx.peek_char() is Some(':') {
            ctx.read_char() |> ignore
            ctx.skip_ws()
            let end = ctx.parse_optional_int()
            let start = match first_opt {
              Some(Index(start_i)) => Some(start_i)
              Some(_) => ctx.invalid_char()
              None => None
            }
            if start is None && end is None {
              ctx.invalid_char()
            }
            ctx.skip_ws()
            ctx.expect_char(']')
            Filter::slice(start, end)
          } else {
            match first_opt {
              Some(first) => {
                let mut combined = first
                for {
                  ctx.skip_ws()
                  match ctx.peek_char() {
                    Some(',') => {
                      ctx.read_char() |> ignore
                      let next = parse_index_or_field_item()
                      combined = Filter::comma(combined, next)
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
                combined
              }
              None => ctx.invalid_char()
            }
          }
        }
      }
    }
    Some('\"') => Filter::field(ctx.parse_string_literal())
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
        Slice(start, end) => Filter::slice_opt(start, end)
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
  if ctx.peek_char() is Some('.') {
    ctx.read_char() |> ignore
    return Filter::recurse()
  }
  let mut current = Filter::identity()
  match ctx.peek_char() {
    Some('[') => current = ctx.parse_bracket_postfix(current)
    Some('\"' | '.') => {
      let first = ctx.parse_dot_suffix()
      if first is Identity {
        ()
      } else {
        current = Filter::pipe(current, first)
      }
    }
    Some(c) if c is ('a'..='z' | 'A'..='Z' | '_') => {
      let first = ctx.parse_dot_suffix()
      if first is Identity {
        ()
      } else {
        current = Filter::pipe(current, first)
      }
    }
    _ => ()
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
      Some('[') => current = ctx.parse_bracket_postfix(current)
      _ => break
    }
  }
  current
}

///|
fn FilterCursor::parse_primary(ctx : FilterCursor) -> Filter raise FilterError {
  ctx.skip_ws()
  fn parse_postfix(base0 : Filter) -> Filter raise FilterError {
    let mut base = base0
    for {
      ctx.skip_ws()
      match ctx.peek_char() {
        Some('[') => base = ctx.parse_bracket_postfix(base)
        Some('.') => {
          ctx.read_char() |> ignore
          let suffix = ctx.parse_dot_suffix()
          if suffix is Identity {
            continue
          } else {
            base = Filter::pipe(base, suffix)
          }
        }
        _ => break
      }
    }
    base
  }

  fn parse_not_operand_or_identity() -> Filter raise FilterError {
    ctx.skip_ws()
    let saved = ctx.offset
    if ctx.try_keyword("and") || ctx.try_keyword("or") {
      ctx.offset = saved
      return Filter::identity()
    }
    ctx.offset = saved
    match ctx.peek_char() {
      None => Filter::identity()
      Some('|' | ',' | ')' | ']' | '}') => Filter::identity()
      Some('+' | '-' | '*' | '/' | '<' | '>' | '=' | '!') => Filter::identity()
      _ => ctx.parse_primary()
    }
  }

  fn parse_reduce_like(is_foreach : Bool) -> Filter raise FilterError {
    let source = ctx.parse_comma(allow_as=false)
    ctx.skip_ws()
    guard ctx.try_keyword("as") else { ctx.invalid_char() }
    let pattern = ctx.parse_as_pattern()
    ctx.skip_ws()
    ctx.expect_char('(')
    let init = ctx.parse_comma()
    ctx.skip_ws()
    ctx.expect_char(';')
    let update = ctx.parse_comma()
    if is_foreach {
      ctx.skip_ws()
      let extract = if ctx.peek_char() is Some(';') {
        ctx.read_char() |> ignore
        ctx.parse_comma()
      } else {
        Filter::identity()
      }
      ctx.skip_ws()
      ctx.expect_char(')')
      match pattern {
        Var(name) => Filter::foreach(source, name, init, update, extract)
        _ => {
          let tmp = ctx.fresh_as_tmp()
          let source_var = Filter::var_(tmp)
          Filter::foreach(
            source,
            tmp,
            init,
            ctx.lower_as_pattern_with_source(source_var, pattern, update),
            ctx.lower_as_pattern_with_source(source_var, pattern, extract),
          )
        }
      }
    } else {
      ctx.skip_ws()
      ctx.expect_char(')')
      match pattern {
        Var(name) => Filter::reduce(source, name, init, update)
        _ => {
          let tmp = ctx.fresh_as_tmp()
          let source_var = Filter::var_(tmp)
          Filter::reduce(
            source,
            tmp,
            init,
            ctx.lower_as_pattern_with_source(source_var, pattern, update),
          )
        }
      }
    }
  }

  let base = match ctx.peek_char() {
    Some('.') => {
      let saved = ctx.offset
      ctx.read_char() |> ignore
      let next = ctx.peek_char()
      ctx.offset = saved
      match next {
        Some(c) if c is ('0'..='9') =>
          Filter::literal(ctx.parse_number_literal())
        _ => ctx.parse_dot_expr()
      }
    }
    Some('[') => ctx.parse_array_literal()
    Some('{') => ctx.parse_object_literal()
    Some('(') => ctx.parse_paren_expr()
    Some('$') => {
      ctx.read_char() |> ignore
      Filter::var_(ctx.parse_identifier())
    }
    Some('@') => {
      ctx.read_char() |> ignore
      let name = ctx.parse_identifier()
      Filter::builtin("@" + name)
    }
    Some('\"') => ctx.parse_string_expr()
    Some('t') =>
      if ctx.try_keyword("true") {
        Filter::literal(Json::boolean(true))
      } else if ctx.try_keyword("try") {
        let inner = ctx.parse_update()
        ctx.skip_ws()
        if ctx.try_keyword("catch") {
          let handler = ctx.parse_update()
          Filter::try_catch(inner, handler)
        } else {
          Filter::try_catch(inner, Filter::empty())
        }
      } else {
        ctx.parse_identifier_or_call()
      }
    Some('f') =>
      if ctx.try_keyword("false") {
        Filter::literal(Json::boolean(false))
      } else if ctx.try_keyword("foreach") {
        parse_reduce_like(true)
      } else {
        ctx.parse_identifier_or_call()
      }
    Some('n') =>
      if ctx.try_keyword("null") {
        Filter::literal(Json::null())
      } else if ctx.try_keyword("not") {
        Filter::not(parse_not_operand_or_identity())
      } else {
        ctx.parse_identifier_or_call()
      }
    Some('e') =>
      if ctx.try_keyword("empty") {
        Filter::empty()
      } else {
        ctx.parse_identifier_or_call()
      }
    Some('r') =>
      if ctx.try_keyword("reduce") {
        parse_reduce_like(false)
      } else {
        ctx.parse_identifier_or_call()
      }
    Some('i') =>
      if ctx.try_keyword("if") {
        ctx.skip_ws()
        let cond0 = ctx.parse_comma()
        ctx.skip_ws()
        guard ctx.try_keyword("then") else { ctx.invalid_char() }
        let then0 = ctx.parse_comma()
        let branches = [(cond0, then0)]
        for {
          ctx.skip_ws()
          if ctx.try_keyword("elif") {
            let elif_cond = ctx.parse_comma()
            ctx.skip_ws()
            guard ctx.try_keyword("then") else { ctx.invalid_char() }
            let elif_then = ctx.parse_comma()
            branches.push((elif_cond, elif_then))
            continue
          }
          break
        }
        let else_branch = if ctx.try_keyword("else") {
          ctx.parse_comma()
        } else {
          Filter::empty()
        }
        ctx.skip_ws()
        guard ctx.try_keyword("end") else { ctx.invalid_char() }
        let mut out = else_branch
        for i in 0..<branches.length() {
          let idx = branches.length() - 1 - i
          let (c, t) = branches[idx]
          out = Filter::if_else(c, t, out)
        }
        out
      } else {
        ctx.parse_identifier_or_call()
      }
    Some('-') | Some('0'..='9') => Filter::literal(ctx.parse_number_literal())
    Some(c) if c is ('a'..='z' | 'A'..='Z' | '_') =>
      ctx.parse_identifier_or_call()
    Some(_) => ctx.invalid_char()
    None => raise InvalidEof
  }
  let base = parse_postfix(base)
  ctx.skip_ws()
  match ctx.peek_char() {
    Some('?') => {
      ctx.read_char() |> ignore
      Filter::try_(base)
    }
    _ => base
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
        let args = []
        for {
          let arg = ctx.parse_comma()
          args.push(arg)
          ctx.skip_ws()
          match ctx.peek_char() {
            Some(';') => {
              ctx.read_char() |> ignore
              ctx.skip_ws()
              continue
            }
            Some(')') => {
              ctx.read_char() |> ignore
              break
            }
            Some(_) => ctx.invalid_char()
            None => raise InvalidEof
          }
        }
        Filter::call(name, args)
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
fn FilterCursor::lower_object_item_filter(
  ctx : FilterCursor,
  key_filter : Filter,
  value_filter : Filter,
  shorthand_dynamic : Bool,
) -> Filter {
  let input_tmp = ctx.fresh_as_tmp()
  let input_var = Filter::var_(input_tmp)
  let key_tmp = ctx.fresh_as_tmp()
  let key_var = Filter::var_(key_tmp)
  let key_on_input = Filter::pipe(input_var, key_filter)
  let value_on_input = if shorthand_dynamic {
    Filter::pipe(input_var, Filter::call("getpath", [Filter::Array([key_var])]))
  } else {
    Filter::pipe(input_var, value_filter)
  }
  let path = Filter::Array([key_var])
  let set_expr = Filter::pipe(
    Filter::literal(Json::object(Map::new())),
    Filter::call("setpath", [path, value_on_input]),
  )
  Filter::as_(
    Filter::identity(),
    input_tmp,
    Filter::as_(key_on_input, key_tmp, set_expr),
  )
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
  let static_items = []
  let dynamic_items = []
  let mut use_dynamic_lowering = false
  for {
    ctx.skip_ws()
    let (key_filter0, var_key_name) = match ctx.peek_char() {
      Some('\"') => (ctx.parse_string_expr(), None)
      Some('(') => (ctx.parse_paren_expr(), None)
      Some('$') => {
        ctx.read_char() |> ignore
        let name = ctx.parse_identifier()
        (Filter::literal(Json::string(name)), Some(name))
      }
      Some(c) if c is ('a'..='z' | 'A'..='Z' | '_') =>
        (Filter::literal(Json::string(ctx.parse_identifier())), None)
      Some(_) => ctx.invalid_char()
      None => raise InvalidEof
    }
    let mut key_filter = key_filter0
    let mut static_key = filter_string_literal_value(key_filter)
    ctx.skip_ws()
    let mut shorthand_dynamic = false
    let value = if ctx.peek_char() is Some(':') {
      ctx.read_char() |> ignore
      match var_key_name {
        Some(name) => {
          key_filter = Filter::var_(name)
          static_key = None
        }
        None => ()
      }
      ctx.parse_pipe()
    } else {
      match var_key_name {
        Some(name) => Filter::var_(name)
        None =>
          match static_key {
            Some(name) => Filter::pipe(Filter::identity(), Filter::field(name))
            None => {
              shorthand_dynamic = true
              Filter::identity()
            }
          }
      }
    }

    if use_dynamic_lowering {
      dynamic_items.push(
        ctx.lower_object_item_filter(key_filter, value, shorthand_dynamic),
      )
    } else {
      match static_key {
        Some(name) if !shorthand_dynamic => static_items.push((name, value))
        _ => {
          use_dynamic_lowering = true
          for kv in static_items {
            dynamic_items.push(
              ctx.lower_object_item_filter(
                Filter::literal(Json::string(kv.0)),
                kv.1,
                false,
              ),
            )
          }
          dynamic_items.push(
            ctx.lower_object_item_filter(key_filter, value, shorthand_dynamic),
          )
        }
      }
    }

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
  if !use_dynamic_lowering {
    return Filter::Object(static_items)
  }
  if dynamic_items.length() == 0 {
    return Filter::Object([])
  }
  let mut out = dynamic_items[0]
  for i in 1..<dynamic_items.length() {
    out = Filter::add(out, dynamic_items[i])
  }
  out
}

///|
fn FilterCursor::fresh_as_tmp(ctx : FilterCursor) -> String {
  let n = ctx.gensym
  ctx.gensym += 1
  "__jqx_as_" + n.to_string()
}

///|
fn as_pattern_key_access(base : Filter, key : Filter) -> Filter {
  Filter::pipe(base, Filter::call("getpath", [Filter::Array([key])]))
}

///|
fn FilterCursor::parse_as_pattern(
  ctx : FilterCursor,
) -> AsPattern raise FilterError {
  ctx.skip_ws()
  match ctx.peek_char() {
    Some('$') => {
      ctx.read_char() |> ignore
      AsPattern::Var(ctx.parse_identifier())
    }
    Some('[') => {
      ctx.expect_char('[')
      ctx.skip_ws()
      if ctx.peek_char() is Some(']') {
        ctx.read_char() |> ignore
        AsPattern::Array([])
      } else {
        let items = []
        for {
          items.push(ctx.parse_as_pattern())
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
        AsPattern::Array(items)
      }
    }
    Some('{') => {
      ctx.expect_char('{')
      ctx.skip_ws()
      if ctx.peek_char() is Some('}') {
        ctx.read_char() |> ignore
        AsPattern::Object([])
      } else {
        let entries = []
        for {
          ctx.skip_ws()
          let mut key = Filter::identity()
          let bindings = []
          match ctx.peek_char() {
            Some('$') => {
              ctx.read_char() |> ignore
              let name = ctx.parse_identifier()
              key = Filter::literal(Json::string(name))
              bindings.push(AsPattern::Var(name))
              ctx.skip_ws()
              if ctx.peek_char() is Some(':') {
                ctx.read_char() |> ignore
                bindings.push(ctx.parse_as_pattern())
              }
            }
            Some('\"') => {
              let name = ctx.parse_string_literal()
              key = Filter::literal(Json::string(name))
              ctx.skip_ws()
              ctx.expect_char(':')
              bindings.push(ctx.parse_as_pattern())
            }
            Some('(') => {
              ctx.read_char() |> ignore
              let key_expr = ctx.parse_comma()
              ctx.skip_ws()
              ctx.expect_char(')')
              key = key_expr
              ctx.skip_ws()
              ctx.expect_char(':')
              bindings.push(ctx.parse_as_pattern())
            }
            Some(c) if c is ('a'..='z' | 'A'..='Z' | '_') => {
              let name = ctx.parse_identifier()
              key = Filter::literal(Json::string(name))
              ctx.skip_ws()
              if ctx.peek_char() is Some(':') {
                ctx.read_char() |> ignore
                bindings.push(ctx.parse_as_pattern())
              } else {
                bindings.push(AsPattern::Var(name))
              }
            }
            Some(_) => ctx.invalid_char()
            None => raise InvalidEof
          }
          entries.push({ key, bindings })
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
        AsPattern::Object(entries)
      }
    }
    _ => ctx.invalid_char()
  }
}

///|
fn FilterCursor::lower_as_pattern_on_bound(
  ctx : FilterCursor,
  bound : Filter,
  pattern : AsPattern,
  body : Filter,
) -> Filter {
  match pattern {
    Var(name) => Filter::as_(bound, name, body)
    Array(items) => {
      let mut out = body
      for i in 0..<items.length() {
        let idx = items.length() - 1 - i
        let value_filter = Filter::pipe(bound, Filter::index(idx))
        out = ctx.lower_as_pattern_with_source(value_filter, items[idx], out)
      }
      out
    }
    Object(entries) => {
      let mut out = body
      for i in 0..<entries.length() {
        let idx = entries.length() - 1 - i
        let entry = entries[idx]
        let value_filter = as_pattern_key_access(bound, entry.key)
        for j in 0..<entry.bindings.length() {
          let bidx = entry.bindings.length() - 1 - j
          out = ctx.lower_as_pattern_with_source(
            value_filter,
            entry.bindings[bidx],
            out,
          )
        }
      }
      out
    }
  }
}

///|
fn FilterCursor::lower_as_pattern_with_source(
  ctx : FilterCursor,
  value_filter : Filter,
  pattern : AsPattern,
  body : Filter,
) -> Filter {
  match pattern {
    Var(name) => Filter::as_(value_filter, name, body)
    _ => {
      let tmp = ctx.fresh_as_tmp()
      let tmp_var = Filter::var_(tmp)
      Filter::as_(
        value_filter,
        tmp,
        ctx.lower_as_pattern_on_bound(tmp_var, pattern, body),
      )
    }
  }
}

///|
fn FilterCursor::parse_unary(ctx : FilterCursor) -> Filter raise FilterError {
  ctx.skip_ws()
  match ctx.peek_char() {
    Some('-') => {
      let saved = ctx.offset
      ctx.read_char() |> ignore
      match ctx.peek_char() {
        Some(c) if c is ('0'..='9') => {
          ctx.offset = saved
          ctx.parse_primary()
        }
        _ => {
          let right = ctx.parse_unary()
          Filter::sub(Filter::literal(Json::number(0.0)), right)
        }
      }
    }
    _ => ctx.parse_primary()
  }
}

///|
fn FilterCursor::parse_mul(ctx : FilterCursor) -> Filter raise FilterError {
  let mut left = ctx.parse_unary()
  for {
    ctx.skip_ws()
    match ctx.peek_char() {
      Some('*') => {
        let saved = ctx.offset
        ctx.read_char() |> ignore
        if ctx.peek_char() is Some('=') {
          ctx.offset = saved
          break
        }
        let right = ctx.parse_unary()
        left = Filter::mul(left, right)
      }
      Some('/') => {
        // Don't consume '/=' or '//' / '//=' here; update/fallback handle them.
        let saved = ctx.offset
        ctx.read_char() |> ignore
        match ctx.peek_char() {
          Some('/' | '=') => {
            ctx.offset = saved
            break
          }
          _ => ()
        }
        let right = ctx.parse_unary()
        left = Filter::div(left, right)
      }
      Some('%') => {
        let saved = ctx.offset
        ctx.read_char() |> ignore
        if ctx.peek_char() is Some('=') {
          ctx.offset = saved
          break
        }
        let right = ctx.parse_unary()
        left = Filter::mod_(left, right)
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
        let saved = ctx.offset
        ctx.read_char() |> ignore
        if ctx.peek_char() is Some('=') {
          ctx.offset = saved
          break
        }
        let right = ctx.parse_mul()
        left = Filter::add(left, right)
      }
      Some('-') => {
        let saved = ctx.offset
        ctx.read_char() |> ignore
        if ctx.peek_char() is Some('=') {
          ctx.offset = saved
          break
        }
        let right = ctx.parse_mul()
        left = Filter::sub(left, right)
      }
      _ => break
    }
  }
  left
}

///|
fn update_path_segment(filter : Filter) -> Json? {
  match filter {
    Field(name) => Some(Json::string(name))
    Index(i) => Some(Json::number(i.to_double()))
    _ => None
  }
}

///|
fn update_path_from_filter(filter : Filter) -> Array[Json]? {
  match filter {
    Identity => Some([])
    Pipe(left, right) =>
      match update_path_from_filter(left) {
        Some(segments) =>
          match update_path_segment(right) {
            Some(segment) => {
              let out = segments.copy()
              out.push(segment)
              Some(out)
            }
            None => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn update_static_slice_target(filter : Filter) -> (Array[Json], Int?, Int?)? {
  match filter {
    Pipe(base, Slice(start, end)) =>
      match update_path_from_filter(base) {
        Some(path) => Some((path, start, end))
        None => None
      }
    _ => None
  }
}

///|
fn update_slice_bound_filter(index : Int?) -> Filter {
  match index {
    Some(v) => Filter::literal(Json::number(v.to_double()))
    None => Filter::literal(Json::null())
  }
}

///|
fn lower_update_assign_op(
  op : UpdateAssignOp,
  current : Filter,
  right : Filter,
) -> Filter {
  match op {
    Set => right
    Update => Filter::call("first", [Filter::pipe(current, right)])
    Add => Filter::add(current, right)
    Sub => Filter::sub(current, right)
    Mul => Filter::mul(current, right)
    Div => Filter::div(current, right)
    Mod => Filter::mod_(current, right)
    Fallback => Filter::fallback(current, right)
  }
}

///|
fn FilterCursor::lower_update_assignment(
  ctx : FilterCursor,
  left : Filter,
  op : UpdateAssignOp,
  right : Filter,
) -> Filter {
  match update_static_slice_target(left) {
    Some((base_path, start, end)) => {
      let input_tmp = ctx.fresh_as_tmp()
      let value_tmp = ctx.fresh_as_tmp()
      let input_var = Filter::var_(input_tmp)
      let value_var = Filter::var_(value_tmp)
      let start_arg = update_slice_bound_filter(start)
      let end_arg = update_slice_bound_filter(end)
      let base_for_getpath = Filter::literal(Json::array(base_path.copy()))
      let base_for_setpath = Filter::literal(Json::array(base_path))
      let base_value = if base_path.length() == 0 {
        input_var
      } else {
        Filter::call("getpath", [base_for_getpath])
      }
      let current_slice = Filter::pipe(
        base_value,
        Filter::call("_slice", [start_arg, end_arg]),
      )
      let updated_slice = lower_update_assign_op(op, current_slice, right)
      let updated_base = Filter::pipe(
        base_value,
        Filter::call("_set_slice", [start_arg, end_arg, value_var]),
      )
      let updated_root = if base_path.length() == 0 {
        updated_base
      } else {
        Filter::pipe(
          input_var,
          Filter::call("setpath", [base_for_setpath, updated_base]),
        )
      }
      return Filter::as_(
        Filter::identity(),
        input_tmp,
        Filter::as_(updated_slice, value_tmp, updated_root),
      )
    }
    None => ()
  }

  match update_path_from_filter(left) {
    Some(path) => {
      let getpath_arg = Filter::literal(Json::array(path.copy()))
      let setpath_arg = Filter::literal(Json::array(path))
      let current_value = Filter::call("getpath", [getpath_arg])
      let updated_value = lower_update_assign_op(op, current_value, right)
      Filter::call("setpath", [setpath_arg, updated_value])
    }
    None => {
      // Lower dynamic/complex update lhs via reduce(path(lhs)).
      let input_tmp = ctx.fresh_as_tmp()
      let path_tmp = ctx.fresh_as_tmp()
      let input_var = Filter::var_(input_tmp)
      let path_var = Filter::var_(path_tmp)
      let source = Filter::pipe(input_var, Filter::call("path", [left]))
      let init = input_var
      match op {
        Update => {
          let current_value = Filter::call("getpath", [path_var])
          let updated_value = lower_update_assign_op(op, current_value, right)
          let update = Filter::call("setpath", [path_var, updated_value])
          Filter::as_(
            Filter::identity(),
            input_tmp,
            Filter::reduce(source, path_tmp, init, update),
          )
        }
        _ => {
          let value_tmp = ctx.fresh_as_tmp()
          let value_var = Filter::var_(value_tmp)
          let current_value = Filter::call("getpath", [path_var])
          let right_values = Filter::pipe(input_var, right)
          let updated_value = lower_update_assign_op(
            op, current_value, value_var,
          )
          let update = Filter::call("setpath", [path_var, updated_value])
          Filter::as_(
            Filter::identity(),
            input_tmp,
            Filter::as_(
              right_values,
              value_tmp,
              Filter::reduce(source, path_tmp, init, update),
            ),
          )
        }
      }
    }
  }
}

///|
fn FilterCursor::parse_pipe(
  ctx : FilterCursor,
  allow_as? : Bool = true,
) -> Filter raise FilterError {
  let mut left = ctx.parse_fallback(allow_as~)
  for {
    ctx.skip_ws()
    if allow_as && ctx.try_keyword("as") {
      let pattern = ctx.parse_as_pattern()
      ctx.skip_ws()
      if ctx.try_qslash_fallback_sep() {
        let patterns = [pattern]
        for {
          patterns.push(ctx.parse_as_pattern())
          if ctx.try_qslash_fallback_sep() {
            continue
          }
          break
        }
        ctx.skip_ws()
        ctx.expect_char('|')
        let body = ctx.parse_pipe()
        let source_tmp = ctx.fresh_as_tmp()
        let source_var = Filter::var_(source_tmp)
        let mut branch = ctx.lower_as_pattern_with_source(
          source_var,
          patterns[patterns.length() - 1],
          body,
        )
        for i in 0..<(patterns.length() - 1) {
          let idx = patterns.length() - 2 - i
          let candidate = ctx.lower_as_pattern_with_source(
            source_var,
            patterns[idx],
            body,
          )
          branch = Filter::try_catch(candidate, branch)
        }
        return Filter::as_(left, source_tmp, branch)
      } else {
        ctx.expect_char('|')
        let right = ctx.parse_pipe()
        return ctx.lower_as_pattern_with_source(left, pattern, right)
      }
    }
    match ctx.peek_char() {
      Some('|') => {
        let saved = ctx.offset
        ctx.read_char() |> ignore
        if ctx.peek_char() is Some('=') {
          ctx.offset = saved
          break
        }
        let right = ctx.parse_fallback(allow_as~)
        left = Filter::pipe(left, right)
      }
      _ => break
    }
  }
  left
}

///|
fn FilterCursor::try_parse_update_assign_op(
  ctx : FilterCursor,
) -> UpdateAssignOp? {
  ctx.skip_ws()
  let saved = ctx.offset
  match ctx.read_char() {
    Some('=') => Some(Set)
    Some('|') =>
      match ctx.read_char() {
        Some('=') => Some(Update)
        _ => {
          ctx.offset = saved
          None
        }
      }
    Some('+') =>
      match ctx.read_char() {
        Some('=') => Some(Add)
        _ => {
          ctx.offset = saved
          None
        }
      }
    Some('-') =>
      match ctx.read_char() {
        Some('=') => Some(Sub)
        _ => {
          ctx.offset = saved
          None
        }
      }
    Some('*') =>
      match ctx.read_char() {
        Some('=') => Some(Mul)
        _ => {
          ctx.offset = saved
          None
        }
      }
    Some('/') =>
      match ctx.read_char() {
        Some('=') => Some(Div)
        Some('/') =>
          match ctx.read_char() {
            Some('=') => Some(Fallback)
            _ => {
              ctx.offset = saved
              None
            }
          }
        _ => {
          ctx.offset = saved
          None
        }
      }
    Some('%') =>
      match ctx.read_char() {
        Some('=') => Some(Mod)
        _ => {
          ctx.offset = saved
          None
        }
      }
    _ => {
      ctx.offset = saved
      None
    }
  }
}

///|
fn FilterCursor::parse_update(
  ctx : FilterCursor,
  allow_as? : Bool = true,
) -> Filter raise FilterError {
  let left = ctx.parse_or(allow_as~)
  match ctx.try_parse_update_assign_op() {
    Some(op) => {
      let right = ctx.parse_or(allow_as~)
      ctx.lower_update_assignment(left, op, right)
    }
    None => left
  }
}

///|
fn FilterCursor::parse_compare(
  ctx : FilterCursor,
  allow_as? : Bool = true,
) -> Filter raise FilterError {
  allow_as |> ignore
  let mut left = ctx.parse_add()
  for {
    ctx.skip_ws()
    match ctx.peek_char() {
      Some('=') => {
        let saved = ctx.offset
        ctx.read_char() |> ignore
        match ctx.peek_char() {
          Some('=') => {
            ctx.read_char() |> ignore
            let right = ctx.parse_add()
            left = Filter::eq(left, right)
          }
          _ => {
            ctx.offset = saved
            break
          }
        }
      }
      Some('!') => {
        ctx.read_char() |> ignore
        match ctx.read_char() {
          Some('=') => {
            let right = ctx.parse_add()
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
            let right = ctx.parse_add()
            left = Filter::lte(left, right)
          }
          _ => {
            let right = ctx.parse_add()
            left = Filter::lt(left, right)
          }
        }
      }
      Some('>') => {
        ctx.read_char() |> ignore
        match ctx.peek_char() {
          Some('=') => {
            ctx.read_char() |> ignore
            let right = ctx.parse_add()
            left = Filter::gte(left, right)
          }
          _ => {
            let right = ctx.parse_add()
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
fn FilterCursor::parse_and(
  ctx : FilterCursor,
  allow_as? : Bool = true,
) -> Filter raise FilterError {
  let mut left = ctx.parse_compare(allow_as~)
  for {
    ctx.skip_ws()
    if ctx.try_keyword("and") {
      let right = ctx.parse_compare(allow_as~)
      left = Filter::and_(left, right)
    } else {
      break
    }
  }
  left
}

///|
fn FilterCursor::parse_or(
  ctx : FilterCursor,
  allow_as? : Bool = true,
) -> Filter raise FilterError {
  let mut left = ctx.parse_and(allow_as~)
  for {
    ctx.skip_ws()
    if ctx.try_keyword("or") {
      let right = ctx.parse_and(allow_as~)
      left = Filter::or_(left, right)
    } else {
      break
    }
  }
  left
}

///|
fn FilterCursor::parse_fallback(
  ctx : FilterCursor,
  allow_as? : Bool = true,
) -> Filter raise FilterError {
  let mut left = ctx.parse_update(allow_as~)
  for {
    ctx.skip_ws()
    match ctx.peek_char() {
      Some('?') => {
        let saved = ctx.offset
        ctx.read_char() |> ignore
        match ctx.read_char() {
          Some('/') =>
            match ctx.read_char() {
              Some('/') => {
                let right = ctx.parse_update(allow_as~)
                left = Filter::fallback(Filter::try_(left), right)
              }
              _ => {
                ctx.offset = saved
                break
              }
            }
          _ => {
            ctx.offset = saved
            break
          }
        }
      }
      Some('/') => {
        let saved = ctx.offset
        ctx.read_char() |> ignore
        match ctx.peek_char() {
          Some('/') => {
            ctx.read_char() |> ignore
            if ctx.peek_char() is Some('=') {
              ctx.offset = saved
              break
            }
            let right = ctx.parse_update(allow_as~)
            left = Filter::fallback(left, right)
          }
          _ => {
            ctx.offset = saved
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
fn FilterCursor::parse_comma(
  ctx : FilterCursor,
  allow_as? : Bool = true,
) -> Filter raise FilterError {
  let mut left = ctx.parse_pipe(allow_as~)
  for {
    ctx.skip_ws()
    match ctx.peek_char() {
      Some(',') => {
        ctx.read_char() |> ignore
        let right = ctx.parse_pipe(allow_as~)
        left = Filter::comma(left, right)
      }
      _ => break
    }
  }
  left
}

///|
fn find_filter_definition(
  defs : Array[(String, Array[String], Filter)],
  name : String,
) -> (Array[String], Filter)? {
  for i in 0..<defs.length() {
    let idx = defs.length() - 1 - i
    let kv = defs[idx]
    if kv.0 == name {
      return Some((kv.1, kv.2))
    }
  }
  None
}

///|
fn lower_filter_with_defs(
  filter : Filter,
  defs : Array[(String, Array[String], Filter)],
) -> Filter {
  match filter {
    Identity
    | Iter
    | IterOpt
    | Recurse
    | Empty
    | Var(_)
    | Builtin("@uri")
    | Builtin("@urid")
    | Builtin("@base64")
    | Builtin("@base64d") =>
      match filter {
        Builtin(name) =>
          match find_filter_definition(defs, name) {
            Some((params, replaced)) =>
              if params.length() == 0 {
                replaced
              } else {
                filter
              }
            None => filter
          }
        _ => filter
      }
    Literal(_)
    | Field(_)
    | FieldOpt(_)
    | Index(_)
    | IndexOpt(_)
    | Slice(_, _)
    | SliceOpt(_, _) => filter
    Pipe(left, right) =>
      Filter::pipe(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
    Comma(left, right) =>
      Filter::comma(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
    Array(items) =>
      Filter::Array(items.map(f => lower_filter_with_defs(f, defs)))
    Object(items) =>
      Filter::Object(
        items.map(kv => (kv.0, lower_filter_with_defs(kv.1, defs))),
      )
    Builtin(name) =>
      match find_filter_definition(defs, name) {
        Some((params, replaced)) =>
          if params.length() == 0 {
            replaced
          } else {
            filter
          }
        None => filter
      }
    Call(name, args) => {
      let lowered_args = args.map(f => lower_filter_with_defs(f, defs))
      match find_filter_definition(defs, name) {
        Some((params, replaced)) =>
          if params.length() == lowered_args.length() {
            lower_filter_def_call(replaced, params, lowered_args)
          } else if params.length() == 0 && lowered_args.length() == 0 {
            replaced
          } else {
            Filter::call(name, lowered_args)
          }
        None => Filter::call(name, lowered_args)
      }
    }
    As(value, name, body) =>
      Filter::as_(
        lower_filter_with_defs(value, defs),
        name,
        lower_filter_with_defs(body, defs),
      )
    Try(inner) => Filter::try_(lower_filter_with_defs(inner, defs))
    TryCatch(inner, handler) =>
      Filter::try_catch(
        lower_filter_with_defs(inner, defs),
        lower_filter_with_defs(handler, defs),
      )
    Reduce(source, name, init, update) =>
      Filter::reduce(
        lower_filter_with_defs(source, defs),
        name,
        lower_filter_with_defs(init, defs),
        lower_filter_with_defs(update, defs),
      )
    Foreach(source, name, init, update, extract) =>
      Filter::foreach(
        lower_filter_with_defs(source, defs),
        name,
        lower_filter_with_defs(init, defs),
        lower_filter_with_defs(update, defs),
        lower_filter_with_defs(extract, defs),
      )
    Eq(left, right) =>
      Filter::eq(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
    Neq(left, right) =>
      Filter::neq(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
    Lt(left, right) =>
      Filter::lt(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
    Lte(left, right) =>
      Filter::lte(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
    Gt(left, right) =>
      Filter::gt(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
    Gte(left, right) =>
      Filter::gte(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
    And(left, right) =>
      Filter::and_(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
    Or(left, right) =>
      Filter::or_(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
    Not(inner) => Filter::not(lower_filter_with_defs(inner, defs))
    Add(left, right) =>
      Filter::add(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
    Sub(left, right) =>
      Filter::sub(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
    Mul(left, right) =>
      Filter::mul(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
    Div(left, right) =>
      Filter::div(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
    Mod(left, right) =>
      Filter::mod_(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
    IfElse(cond, then_branch, else_branch) =>
      Filter::if_else(
        lower_filter_with_defs(cond, defs),
        lower_filter_with_defs(then_branch, defs),
        lower_filter_with_defs(else_branch, defs),
      )
    Fallback(left, right) =>
      Filter::fallback(
        lower_filter_with_defs(left, defs),
        lower_filter_with_defs(right, defs),
      )
  }
}

///|
fn lower_filter_param_refs(filter : Filter, params : Array[String]) -> Filter {
  match filter {
    Builtin(name) =>
      if params.contains(name) {
        Filter::var_(name)
      } else {
        filter
      }
    Call(name, args) =>
      if params.contains(name) && args.length() == 0 {
        Filter::var_(name)
      } else {
        Filter::call(
          name,
          args.map(arg => lower_filter_param_refs(arg, params)),
        )
      }
    Pipe(left, right) =>
      Filter::pipe(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    Comma(left, right) =>
      Filter::comma(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    Array(items) =>
      Filter::Array(items.map(item => lower_filter_param_refs(item, params)))
    Object(items) =>
      Filter::Object(
        items.map(kv => (kv.0, lower_filter_param_refs(kv.1, params))),
      )
    As(value, name, body) =>
      Filter::as_(
        lower_filter_param_refs(value, params),
        name,
        lower_filter_param_refs(body, params),
      )
    Try(inner) => Filter::try_(lower_filter_param_refs(inner, params))
    TryCatch(inner, handler) =>
      Filter::try_catch(
        lower_filter_param_refs(inner, params),
        lower_filter_param_refs(handler, params),
      )
    Reduce(source, name, init, update) =>
      Filter::reduce(
        lower_filter_param_refs(source, params),
        name,
        lower_filter_param_refs(init, params),
        lower_filter_param_refs(update, params),
      )
    Foreach(source, name, init, update, extract) =>
      Filter::foreach(
        lower_filter_param_refs(source, params),
        name,
        lower_filter_param_refs(init, params),
        lower_filter_param_refs(update, params),
        lower_filter_param_refs(extract, params),
      )
    Eq(left, right) =>
      Filter::eq(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    Neq(left, right) =>
      Filter::neq(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    Lt(left, right) =>
      Filter::lt(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    Lte(left, right) =>
      Filter::lte(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    Gt(left, right) =>
      Filter::gt(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    Gte(left, right) =>
      Filter::gte(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    And(left, right) =>
      Filter::and_(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    Or(left, right) =>
      Filter::or_(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    Not(inner) => Filter::not(lower_filter_param_refs(inner, params))
    Add(left, right) =>
      Filter::add(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    Sub(left, right) =>
      Filter::sub(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    Mul(left, right) =>
      Filter::mul(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    Div(left, right) =>
      Filter::div(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    Mod(left, right) =>
      Filter::mod_(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    IfElse(cond, then_branch, else_branch) =>
      Filter::if_else(
        lower_filter_param_refs(cond, params),
        lower_filter_param_refs(then_branch, params),
        lower_filter_param_refs(else_branch, params),
      )
    Fallback(left, right) =>
      Filter::fallback(
        lower_filter_param_refs(left, params),
        lower_filter_param_refs(right, params),
      )
    _ => filter
  }
}

///|
fn lower_filter_def_call(
  body : Filter,
  params : Array[String],
  args : Array[Filter],
) -> Filter {
  let mut out = lower_filter_param_refs(body, params)
  for i in 0..<params.length() {
    let idx = params.length() - 1 - i
    out = Filter::as_(args[idx], params[idx], out)
  }
  out
}

///|
fn lower_definition_sequence(
  defs : Array[(String, Array[String], Filter)],
) -> Array[(String, Array[String], Filter)] {
  let lowered = []
  for kv in defs {
    let body = lower_filter_with_defs(kv.2, lowered)
    lowered.push((kv.0, kv.1, body))
  }
  lowered
}

///|
fn FilterCursor::read_until_top_level_semicolon(
  ctx : FilterCursor,
) -> StringView raise FilterError {
  ctx.skip_ws()
  let start = ctx.offset
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut brace_depth = 0
  let mut in_string = false
  let mut escaped = false
  for {
    match ctx.read_char() {
      Some(c) =>
        if in_string {
          if escaped {
            escaped = false
          } else if c == '\\' {
            escaped = true
          } else if c == '"' {
            in_string = false
          }
          continue
        } else {
          match c {
            '"' => in_string = true
            '(' => paren_depth += 1
            ')' => if paren_depth > 0 { paren_depth -= 1 }
            '[' => bracket_depth += 1
            ']' => if bracket_depth > 0 { bracket_depth -= 1 }
            '{' => brace_depth += 1
            '}' => if brace_depth > 0 { brace_depth -= 1 }
            ';' =>
              if paren_depth == 0 && bracket_depth == 0 && brace_depth == 0 {
                let end = ctx.offset - 1
                return ctx.input.view(start_offset=start, end_offset=end)
              }
            _ => ()
          }
          continue
        }
      None => raise InvalidEof
    }
  }
}

///|
fn FilterCursor::parse_definition_prefix(
  ctx : FilterCursor,
) -> Array[(String, Array[String], Filter)] raise FilterError {
  fn parse_params() -> Array[String] raise FilterError {
    ctx.skip_ws()
    if ctx.peek_char() is Some('(') {
      ctx.read_char() |> ignore
      ctx.skip_ws()
      if ctx.peek_char() is Some(')') {
        ctx.read_char() |> ignore
        return []
      }
      let params = []
      for {
        ctx.skip_ws()
        let name = if ctx.peek_char() is Some('$') {
          ctx.read_char() |> ignore
          ctx.parse_identifier()
        } else {
          ctx.parse_identifier()
        }
        params.push(name)
        ctx.skip_ws()
        match ctx.peek_char() {
          Some(';') => {
            ctx.read_char() |> ignore
            continue
          }
          Some(')') => {
            ctx.read_char() |> ignore
            break
          }
          Some(_) => ctx.invalid_char()
          None => raise InvalidEof
        }
      }
      params
    } else {
      []
    }
  }

  let defs = []
  for {
    ctx.skip_ws()
    if !ctx.try_keyword("def") {
      break
    }
    let name = ctx.parse_identifier()
    let params = parse_params()
    ctx.expect_char(':')
    let body_source = ctx.read_until_top_level_semicolon()
    defs.push((name, params, parse_filter(body_source)))
  }
  defs
}

///|
pub fn parse_filter(input : StringView) -> Filter raise FilterError {
  let ctx = FilterCursor::make(input)
  let defs = ctx.parse_definition_prefix()
  let raw_filter = ctx.parse_comma()
  let filter = if defs.length() == 0 {
    raw_filter
  } else {
    let lowered_defs = lower_definition_sequence(defs)
    lower_filter_with_defs(raw_filter, lowered_defs)
  }
  ctx.skip_ws()
  if ctx.offset >= ctx.end_offset {
    filter
  } else {
    ctx.invalid_char()
  }
}
