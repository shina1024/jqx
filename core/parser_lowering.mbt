///|
fn FilterCursor::fresh_as_tmp(ctx : FilterCursor) -> String {
  let n = ctx.gensym
  ctx.gensym += 1
  "__jqx_as_" + n.to_string()
}

///|
fn append_as_pattern_var_once(vars : Array[String], name : String) -> Unit {
  if !vars.contains(name) {
    vars.push(name)
  }
}

///|
fn collect_as_pattern_vars(pattern : AsPattern, vars : Array[String]) -> Unit {
  match pattern {
    Var(name) => append_as_pattern_var_once(vars, name)
    Array(items) =>
      for item in items {
        collect_as_pattern_vars(item, vars)
      }
    Object(entries) =>
      for entry in entries {
        for binding in entry.bindings {
          collect_as_pattern_vars(binding, vars)
        }
      }
  }
}

///|
fn lower_with_null_defaults_for_patterns(
  body : Filter,
  patterns : Array[AsPattern],
) -> Filter {
  let vars = []
  for pattern in patterns {
    collect_as_pattern_vars(pattern, vars)
  }
  let mut out = body
  for i in 0..<vars.length() {
    let idx = vars.length() - 1 - i
    out = Filter::as_(Filter::literal(Json::null()), vars[idx], out)
  }
  out
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
      let current_value = Filter::call("getpath", [
        Filter::literal(Json::array(path.copy())),
      ])
      match op {
        Update => {
          let rhs_values = Filter::pipe(current_value, right)
          let is_empty = Filter::call("isempty", [rhs_values])
          let set_value = Filter::call("first", [
            Filter::pipe(current_value, right),
          ])
          let set_expr = Filter::call("setpath", [
            Filter::literal(Json::array(path.copy())),
            set_value,
          ])
          let del_expr = Filter::call("delpaths", [
            Filter::literal(Json::array([Json::array(path)])),
          ])
          Filter::if_else(is_empty, del_expr, set_expr)
        }
        _ => {
          let updated_value = lower_update_assign_op(op, current_value, right)
          Filter::call("setpath", [
            Filter::literal(Json::array(path)),
            updated_value,
          ])
        }
      }
    }
    None => {
      // Lower dynamic/complex update lhs via reduce(path(lhs)).
      let input_tmp = ctx.fresh_as_tmp()
      let path_tmp = ctx.fresh_as_tmp()
      let paths_tmp = ctx.fresh_as_tmp()
      let updated_tmp = ctx.fresh_as_tmp()
      let input_var = Filter::var_(input_tmp)
      let source = Filter::pipe(input_var, Filter::call("path", [left]))
      let init = input_var
      match op {
        Update => {
          let paths_var = Filter::var_(paths_tmp)
          let updated_var = Filter::var_(updated_tmp)
          let path_stream = Filter::pipe(paths_var, Filter::iter())
          let original_value = Filter::pipe(
            input_var,
            Filter::call("getpath", [Filter::var_(path_tmp)]),
          )
          let update_step = Filter::if_else(
            Filter::call("isempty", [Filter::pipe(original_value, right)]),
            Filter::identity(),
            Filter::call("setpath", [
              Filter::var_(path_tmp),
              Filter::call("first", [Filter::pipe(original_value, right)]),
            ]),
          )
          let updated_root = Filter::reduce(
            path_stream, path_tmp, init, update_step,
          )
          let delete_step = Filter::if_else(
            Filter::call("isempty", [Filter::pipe(original_value, right)]),
            Filter::add(
              Filter::identity(),
              Filter::Array([Filter::var_(path_tmp)]),
            ),
            Filter::identity(),
          )
          let delete_paths = Filter::reduce(
            path_stream,
            path_tmp,
            Filter::Array([]),
            delete_step,
          )
          Filter::as_(
            Filter::identity(),
            input_tmp,
            Filter::as_(
              Filter::Array([source]),
              paths_tmp,
              Filter::as_(
                updated_root,
                updated_tmp,
                Filter::pipe(
                  updated_var,
                  Filter::call("delpaths", [delete_paths]),
                ),
              ),
            ),
          )
        }
        _ => {
          let path_var = Filter::var_(path_tmp)
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
fn find_filter_definition_arity(
  defs : Array[(String, Array[String], Filter)],
  name : String,
  arity : Int,
) -> (Array[String], Filter)? {
  for i in 0..<defs.length() {
    let idx = defs.length() - 1 - i
    let kv = defs[idx]
    if kv.0 == name && kv.1.length() == arity {
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
          match find_filter_definition_arity(defs, name, 0) {
            Some((params, replaced)) =>
              if params.length() == 0 {
                lower_filter_with_defs(replaced, defs)
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
      match find_filter_definition_arity(defs, name, 0) {
        Some((params, replaced)) =>
          if params.length() == 0 {
            lower_filter_with_defs(replaced, defs)
          } else {
            filter
          }
        None => filter
      }
    Call(name, args) => {
      let lowered_args = args.map(f => lower_filter_with_defs(f, defs))
      match find_filter_definition_arity(defs, name, lowered_args.length()) {
        Some((params, replaced)) =>
          if params.length() == lowered_args.length() {
            lower_filter_with_defs(
              lower_filter_def_call(replaced, params, lowered_args),
              defs,
            )
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
  let mut nested_def_depth = 0
  let mut in_string = false
  let mut escaped = false

  fn char_at_offset(offset : Int) -> Char? {
    if offset < ctx.end_offset {
      Some(ctx.input.unsafe_get(offset).to_int().unsafe_to_char())
    } else {
      None
    }
  }

  fn is_def_keyword_start(offset : Int) -> Bool {
    if offset + 2 >= ctx.end_offset {
      return false
    }
    match
      (
        char_at_offset(offset),
        char_at_offset(offset + 1),
        char_at_offset(offset + 2),
      ) {
      (Some('d'), Some('e'), Some('f')) => ()
      _ => return false
    }
    let prev_is_ident = if offset > start {
      match char_at_offset(offset - 1) {
        Some(prev) => is_ident_continue(prev)
        None => false
      }
    } else {
      false
    }
    if prev_is_ident {
      return false
    }
    let next_is_ident = match char_at_offset(offset + 3) {
      Some(next) => is_ident_continue(next)
      None => false
    }
    !next_is_ident
  }

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
            'd' =>
              if paren_depth == 0 && bracket_depth == 0 && brace_depth == 0 {
                let keyword_start = ctx.offset - 1
                if is_def_keyword_start(keyword_start) {
                  ctx.read_char() |> ignore
                  ctx.read_char() |> ignore
                  nested_def_depth += 1
                }
              }
            ';' =>
              if paren_depth == 0 && bracket_depth == 0 && brace_depth == 0 {
                if nested_def_depth > 0 {
                  nested_def_depth -= 1
                } else {
                  let end = ctx.offset - 1
                  return ctx.input.view(start_offset=start, end_offset=end)
                }
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
    defs.push((name, params, compile(body_source)))
  }
  defs
}

///|
fn FilterCursor::parse_scoped(
  ctx : FilterCursor,
  allow_as? : Bool = true,
) -> Filter raise FilterError {
  let defs = ctx.parse_definition_prefix()
  let raw_filter = ctx.parse_comma(allow_as~)
  if defs.length() == 0 {
    raw_filter
  } else {
    let lowered_defs = lower_definition_sequence(defs)
    lower_filter_with_defs(raw_filter, lowered_defs)
  }
}
