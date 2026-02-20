///|

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
fn slice_start_index_from_filter(filter : Filter) -> Int? {
  match filter {
    Literal(Number(n, _)) =>
      if n == n && n != @double.infinity && n != @double.neg_infinity {
        Some(n.floor().to_int())
      } else {
        None
      }
    _ => None
  }
}

///|
fn slice_end_index_from_filter(filter : Filter) -> Int? {
  match filter {
    Literal(Number(n, _)) =>
      if n == n && n != @double.infinity && n != @double.neg_infinity {
        Some(n.ceil().to_int())
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
    Some(v) => slice_start_index_from_filter(v)
    None => None
  }
  let end_static = match end_expr {
    Some(v) => slice_end_index_from_filter(v)
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
    Some(ctx.parse_pipe_no_comma(allow_as=false))
  }
  ctx.skip_ws()

  if ctx.peek_char() is Some(':') {
    ctx.read_char() |> ignore
    ctx.skip_ws()
    let end_expr = if ctx.peek_char() is Some(']') {
      None
    } else {
      Some(ctx.parse_pipe_no_comma(allow_as=false))
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
        keys.push(ctx.parse_pipe_no_comma(allow_as=false))
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

  fn parse_label_expr() -> Filter raise FilterError {
    ctx.skip_ws()
    ctx.expect_char('$')
    let name = ctx.parse_identifier()
    ctx.skip_ws()
    ctx.expect_char('|')
    let body = ctx.parse_comma()
    Filter::label(name, body)
  }

  fn parse_break_expr() -> Filter raise FilterError {
    ctx.skip_ws()
    ctx.expect_char('$')
    Filter::break_(ctx.parse_identifier())
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
      let name = "@" + ctx.parse_identifier()
      ctx.skip_ws()
      if ctx.peek_char() is Some('\"') {
        ctx.parse_format_string_expr(name)
      } else {
        Filter::builtin(name)
      }
    }
    Some('\"') => ctx.parse_string_expr()
    Some('t') =>
      if ctx.try_keyword("true") {
        Filter::literal(Json::boolean(true))
      } else if ctx.try_keyword("try") {
        // jq's `try` binds only to the next unary expression unless grouped.
        let inner = ctx.parse_unary()
        ctx.skip_ws()
        if ctx.try_keyword("catch") {
          let handler = ctx.parse_unary()
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
    Some('l') =>
      if ctx.try_keyword("label") {
        parse_label_expr()
      } else {
        ctx.parse_identifier_or_call()
      }
    Some('b') =>
      if ctx.try_keyword("break") {
        parse_break_expr()
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
          Filter::identity()
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
  let inner = ctx.parse_scoped()
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
  let expr = ctx.parse_comma()
  ctx.skip_ws()
  ctx.expect_char(']')
  Filter::Array([expr])
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
      ctx.parse_pipe_scoped()
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
