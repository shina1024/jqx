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
fn FilterCursor::parse_pipe_no_comma(
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
        let body = if ctx.peek_keyword("def") {
          ctx.parse_scoped(allow_as~)
        } else {
          ctx.parse_pipe_no_comma(allow_as~)
        }
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
        branch = lower_with_null_defaults_for_patterns(branch, patterns)
        return Filter::as_(left, source_tmp, branch)
      } else {
        ctx.expect_char('|')
        let right = if ctx.peek_keyword("def") {
          ctx.parse_scoped(allow_as~)
        } else {
          ctx.parse_pipe_no_comma(allow_as~)
        }
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
        let right = if ctx.peek_keyword("def") {
          ctx.parse_scoped(allow_as~)
        } else {
          ctx.parse_fallback(allow_as~)
        }
        left = Filter::pipe(left, right)
      }
      _ => break
    }
  }
  left
}

///|
fn FilterCursor::parse_comma_tight(
  ctx : FilterCursor,
  allow_as? : Bool = true,
) -> Filter raise FilterError {
  let mut left = ctx.parse_fallback(allow_as~)
  for {
    ctx.skip_ws()
    match ctx.peek_char() {
      Some(',') => {
        ctx.read_char() |> ignore
        let right = if ctx.peek_keyword("def") {
          ctx.parse_scoped(allow_as~)
        } else {
          ctx.parse_fallback(allow_as~)
        }
        left = Filter::comma(left, right)
      }
      _ => break
    }
  }
  left
}

///|
fn FilterCursor::parse_pipe(
  ctx : FilterCursor,
  allow_as? : Bool = true,
) -> Filter raise FilterError {
  let mut left = ctx.parse_comma_tight(allow_as~)
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
        let body = if ctx.peek_keyword("def") {
          ctx.parse_scoped(allow_as~)
        } else {
          ctx.parse_comma(allow_as~)
        }
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
        branch = lower_with_null_defaults_for_patterns(branch, patterns)
        return Filter::as_(left, source_tmp, branch)
      } else {
        ctx.expect_char('|')
        let right = if ctx.peek_keyword("def") {
          ctx.parse_scoped(allow_as~)
        } else {
          ctx.parse_comma(allow_as~)
        }
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
        let right = if ctx.peek_keyword("def") {
          ctx.parse_scoped(allow_as~)
        } else {
          ctx.parse_comma_tight(allow_as~)
        }
        left = Filter::pipe(left, right)
      }
      _ => break
    }
  }
  left
}

///|
fn FilterCursor::parse_pipe_scoped(
  ctx : FilterCursor,
  allow_as? : Bool = true,
) -> Filter raise FilterError {
  let defs = ctx.parse_definition_prefix()
  let raw_filter = ctx.parse_pipe_no_comma(allow_as~)
  if defs.length() == 0 {
    raw_filter
  } else {
    let lowered_defs = lower_definition_sequence(defs)
    lower_filter_with_defs(raw_filter, lowered_defs)
  }
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
  ctx.parse_pipe(allow_as~)
}

///|
