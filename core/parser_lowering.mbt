///|
fn FilterCursor::fresh_as_tmp(ctx : FilterCursor) -> String {
  let n = ctx.gensym
  ctx.gensym += 1
  "__jqx_as_" + n.to_string()
}

///|
priv struct ModuleSourceState {
  mut sources : Map[String, String]
}

///|
priv struct ModuleSearchPathState {
  mut search_paths : Array[String]
}

///|
let module_source_state : ModuleSourceState = { sources: Map::new() }

///|
let module_search_path_state : ModuleSearchPathState = { search_paths: [] }

///|
pub fn clear_module_sources() -> Unit {
  module_source_state.sources = Map::new()
}

///|
pub fn register_module_source(name : String, source : String) -> Unit {
  module_source_state.sources.set(name, source)
}

///|
fn normalize_module_search_paths(paths : Array[String]) -> Array[String] {
  let out = []
  for path in paths {
    if path.length() > 0 && !out.contains(path) {
      out.push(path)
    }
  }
  out
}

///|
pub fn clear_module_search_paths() -> Unit {
  module_search_path_state.search_paths = []
}

///|
pub fn set_module_search_paths(paths : Array[String]) -> Unit {
  module_search_path_state.search_paths = normalize_module_search_paths(paths)
}

///|
fn module_default_search_paths() -> Array[String] {
  module_search_path_state.search_paths.copy()
}

///|
priv enum ModuleLoadResult {
  Loaded(Array[(String, Array[String], Filter)])
  Missing(String)
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
    out = Filter::as_(Filter::literal(Value::null()), vars[idx], out)
  }
  out
}

///|
fn as_pattern_key_access(base : Filter, key : Filter) -> Filter {
  Filter::pipe(base, Filter::call("getpath", [Filter::Array([key])]))
}

///|
fn filter_constant_json_for_diagnostics(filter : Filter) -> Value? {
  match filter {
    Literal(v) => Some(v)
    Add(left, right) =>
      match
        (
          filter_constant_json_for_diagnostics(left),
          filter_constant_json_for_diagnostics(right),
        ) {
        (Some(String(a)), Some(String(b))) => Some(Value::string(a + b))
        _ => None
      }
    Array(items) =>
      if items.length() == 0 {
        Some(Value::array([]))
      } else {
        None
      }
    Object(items) => {
      let out = Map::new()
      for kv in items {
        match filter_constant_json_for_diagnostics(kv.1) {
          Some(value) => out[kv.0] = value
          None => return None
        }
      }
      Some(Value::object(out))
    }
    _ => None
  }
}

///|
fn object_key_diagnostic_prefix_from_filter(filter : Filter) -> String? {
  match filter {
    Literal(Number(n, repr)) =>
      Some(
        "Cannot use number (" +
        Value::number(n, repr?).to_json_string() +
        ") as object key",
      )
    Literal(JTrue) => Some("Cannot use boolean (true) as object key")
    Literal(JFalse) => Some("Cannot use boolean (false) as object key")
    Literal(JNull) => Some("Cannot use null (null) as object key")
    _ => None
  }
}

///|
fn FilterCursor::require_constant_object_metadata(
  ctx : FilterCursor,
  metadata : Filter,
  metadata_offset : Int,
) -> Unit raise FilterError {
  match filter_constant_json_for_diagnostics(metadata) {
    Some(Object(_)) => ()
    Some(_) =>
      ctx.raise_diagnostic_at(
        metadata_offset, "Module metadata must be an object",
      )
    None =>
      ctx.raise_diagnostic_at(
        metadata_offset, "Module metadata must be constant",
      )
  }
}

///|
fn FilterCursor::parse_module_path_string(
  ctx : FilterCursor,
) -> String raise FilterError {
  ctx.skip_ws()
  let path_offset = ctx.offset
  if !(ctx.peek_char() is Some('\"')) {
    ctx.invalid_char()
  }
  let path_expr = ctx.parse_string_expr()
  match filter_constant_json_for_diagnostics(path_expr) {
    Some(String(path)) => path
    _ => ctx.raise_diagnostic_at(path_offset, "Import path must be constant")
  }
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
        ctx.raise_syntax_error_at(
          ctx.offset,
          "']'",
          expecting="BINDING or '[' or '{'",
        )
      } else {
        let items = []
        let mut closed = false
        while !closed {
          items.push(ctx.parse_as_pattern())
          ctx.skip_ws()
          match ctx.peek_char() {
            Some(',') => ctx.read_char() |> ignore
            Some(']') => {
              ctx.read_char() |> ignore
              closed = true
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
        ctx.raise_syntax_error_at(ctx.offset, "'}'")
      } else {
        let entries = []
        let mut closed = false
        while !closed {
          ctx.skip_ws()
          let mut key = Filter::identity()
          let bindings = []
          match ctx.peek_char() {
            Some('$') => {
              ctx.read_char() |> ignore
              let name = ctx.parse_identifier()
              key = Filter::literal(Value::string(name))
              bindings.push(AsPattern::Var(name))
              ctx.skip_ws()
              if ctx.peek_char() is Some(':') {
                ctx.read_char() |> ignore
                bindings.push(ctx.parse_as_pattern())
              }
            }
            Some('\"') => {
              let name = ctx.parse_string_literal()
              key = Filter::literal(Value::string(name))
              ctx.skip_ws()
              ctx.expect_char(':')
              bindings.push(ctx.parse_as_pattern())
            }
            Some('(') => {
              ctx.read_char() |> ignore
              ctx.skip_ws()
              let key_offset = ctx.offset
              let key_expr = ctx.parse_comma()
              ctx.skip_ws()
              ctx.expect_char(')')
              let key_diag = object_key_diagnostic_prefix_from_filter(key_expr)
              key = key_expr
              match key_diag {
                Some(prefix) => ctx.raise_diagnostic_at(key_offset, prefix)
                None => ()
              }
              ctx.skip_ws()
              ctx.expect_char(':')
              bindings.push(ctx.parse_as_pattern())
            }
            Some(c) if c is ('a'..='z' | 'A'..='Z' | '_') => {
              let name = ctx.parse_identifier()
              key = Filter::literal(Value::string(name))
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
            Some(',') => ctx.read_char() |> ignore
            Some('}') => {
              ctx.read_char() |> ignore
              closed = true
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
fn update_path_segment(filter : Filter) -> Value? {
  match filter {
    Field(name) => Some(Value::string(name))
    Index(i) => Some(Value::number(i.to_double()))
    _ => None
  }
}

///|
fn update_path_from_filter(filter : Filter) -> Array[Value]? {
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
fn update_static_slice_target(filter : Filter) -> (Array[Value], Int?, Int?)? {
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
    Some(v) => Filter::literal(Value::number(v.to_double()))
    None => Filter::literal(Value::null())
  }
}

///|
fn update_dynamic_slice_target(filter : Filter) -> (Filter, Filter, Filter)? {
  match filter {
    As(
      base,
      base_tmp,
      As(start_filter, start_tmp, As(end_filter, end_tmp, slice_access0))
    ) => {
      let slice_access = match slice_access0 {
        Try(inner) => inner
        _ => slice_access0
      }
      match slice_access {
        Pipe(Var(bound_base), Call("_slice", args)) =>
          if args.length() != 2 {
            None
          } else {
            match (args[0], args[1]) {
              (Var(bound_start), Var(bound_end)) =>
                if bound_base == base_tmp &&
                  bound_start == start_tmp &&
                  bound_end == end_tmp {
                  Some((base, start_filter, end_filter))
                } else {
                  None
                }
              _ => None
            }
          }
        _ => None
      }
    }
    _ => None
  }
}

///|
fn update_strip_identity_pipe(filter : Filter) -> Filter {
  match filter {
    Pipe(Identity, inner) => inner
    _ => filter
  }
}

///|
fn update_merge_slice_base(prefix : Filter, suffix_base : Filter) -> Filter {
  match suffix_base {
    Identity => prefix
    _ => Filter::pipe(prefix, suffix_base)
  }
}

///|
fn update_slice_target(filter : Filter) -> (Filter, Filter, Filter)? {
  match filter {
    Pipe(base, Slice(start, end)) =>
      Some(
        (base, update_slice_bound_filter(start), update_slice_bound_filter(end)),
      )
    Pipe(prefix, right) => {
      let right0 = update_strip_identity_pipe(right)
      match right0 {
        Slice(start, end) =>
          Some(
            (
              prefix,
              update_slice_bound_filter(start),
              update_slice_bound_filter(end),
            ),
          )
        _ =>
          match update_dynamic_slice_target(right0) {
            Some((suffix_base, start_filter, end_filter)) =>
              Some(
                (
                  update_merge_slice_base(prefix, suffix_base),
                  start_filter,
                  end_filter,
                ),
              )
            None => update_dynamic_slice_target(filter)
          }
      }
    }
    _ => update_dynamic_slice_target(filter)
  }
}

///|
fn FilterCursor::lower_dynamic_slice_update_assignment(
  ctx : FilterCursor,
  base : Filter,
  start_arg : Filter,
  end_arg : Filter,
  op : UpdateAssignOp,
  right : Filter,
) -> Filter {
  let input_tmp = ctx.fresh_as_tmp()
  let path_tmp = ctx.fresh_as_tmp()
  let start_tmp = ctx.fresh_as_tmp()
  let end_tmp = ctx.fresh_as_tmp()
  let input_var = Filter::var_(input_tmp)
  let path_var = Filter::var_(path_tmp)
  let start_var = Filter::var_(start_tmp)
  let end_var = Filter::var_(end_tmp)
  let source = Filter::pipe(input_var, Filter::call("path", [base]))
  let init = input_var
  let current_base = Filter::call("getpath", [path_var])
  let current_slice = Filter::pipe(
    current_base,
    Filter::call("_slice", [start_var, end_var]),
  )

  let lowered = match op {
    Update => {
      let updated_slice = Filter::if_else(
        Filter::call("isempty", [Filter::pipe(current_slice, right)]),
        Filter::literal(Value::array([])),
        Filter::call("first", [Filter::pipe(current_slice, right)]),
      )
      let value_tmp = ctx.fresh_as_tmp()
      let value_var = Filter::var_(value_tmp)
      let updated_base = Filter::pipe(
        current_base,
        Filter::call("_set_slice", [start_var, end_var, value_var]),
      )
      let update_step = Filter::as_(
        updated_slice,
        value_tmp,
        Filter::call("setpath", [path_var, updated_base]),
      )
      Filter::reduce(source, path_tmp, init, update_step)
    }
    _ => {
      let value_tmp = ctx.fresh_as_tmp()
      let value_var = Filter::var_(value_tmp)
      let updated_slice = lower_update_assign_op(op, current_slice, value_var)
      let updated_tmp = ctx.fresh_as_tmp()
      let updated_var = Filter::var_(updated_tmp)
      let updated_base = Filter::pipe(
        current_base,
        Filter::call("_set_slice", [start_var, end_var, updated_var]),
      )
      let update_step = Filter::as_(
        updated_slice,
        updated_tmp,
        Filter::call("setpath", [path_var, updated_base]),
      )
      let right_values = Filter::pipe(input_var, right)
      Filter::as_(
        right_values,
        value_tmp,
        Filter::reduce(source, path_tmp, init, update_step),
      )
    }
  }

  Filter::as_(
    Filter::identity(),
    input_tmp,
    Filter::as_(start_arg, start_tmp, Filter::as_(end_arg, end_tmp, lowered)),
  )
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
      let base_for_getpath = Filter::literal(Value::array(base_path.copy()))
      let base_for_setpath = Filter::literal(Value::array(base_path))
      let base_value = if base_path.length() == 0 {
        input_var
      } else {
        Filter::call("getpath", [base_for_getpath])
      }
      let current_slice = Filter::pipe(
        base_value,
        Filter::call("_slice", [start_arg, end_arg]),
      )
      let updated_slice = match op {
        Update => {
          let rhs_values = Filter::pipe(current_slice, right)
          Filter::if_else(
            Filter::call("isempty", [rhs_values]),
            Filter::literal(Value::array([])),
            Filter::call("first", [Filter::pipe(current_slice, right)]),
          )
        }
        _ => lower_update_assign_op(op, current_slice, right)
      }
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

  match update_slice_target(left) {
    Some((base, start_arg, end_arg)) =>
      return ctx.lower_dynamic_slice_update_assignment(
        base, start_arg, end_arg, op, right,
      )
    None => ()
  }

  match update_path_from_filter(left) {
    Some(path) => {
      let current_value = Filter::call("getpath", [
        Filter::literal(Value::array(path.copy())),
      ])
      match op {
        Update => {
          let rhs_values = Filter::pipe(current_value, right)
          let is_empty = Filter::call("isempty", [rhs_values])
          let set_value = Filter::call("first", [
            Filter::pipe(current_value, right),
          ])
          let set_expr = Filter::call("setpath", [
            Filter::literal(Value::array(path.copy())),
            set_value,
          ])
          let del_expr = Filter::call("delpaths", [
            Filter::literal(Value::array([Value::array(path)])),
          ])
          Filter::if_else(is_empty, del_expr, set_expr)
        }
        _ => {
          let updated_value = lower_update_assign_op(op, current_value, right)
          Filter::call("setpath", [
            Filter::literal(Value::array(path)),
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
          let path_var = Filter::var_(path_tmp)
          let path_stream = Filter::pipe(paths_var, Filter::iter())
          let current_value = Filter::call("getpath", [path_var])
          let original_value = Filter::pipe(
            input_var,
            Filter::call("getpath", [path_var]),
          )
          let update_step = Filter::if_else(
            Filter::call("isempty", [Filter::pipe(current_value, right)]),
            Filter::identity(),
            Filter::call("setpath", [
              path_var,
              Filter::call("first", [Filter::pipe(current_value, right)]),
            ]),
          )
          let updated_root = Filter::reduce(
            path_stream, path_tmp, init, update_step,
          )
          let delete_step = Filter::if_else(
            Filter::call("isempty", [Filter::pipe(original_value, right)]),
            Filter::add(Filter::identity(), Filter::Array([path_var])),
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
    Scope(local_defs, body) => {
      let lowered_locals = []
      let available = defs.copy()
      for def_ in local_defs {
        let lowered_body = lower_filter_with_defs(def_.2, available)
        let lowered_def = (def_.0, def_.1, lowered_body)
        lowered_locals.push(lowered_def)
        available.push(lowered_def)
      }
      Filter::scope(lowered_locals, body)
    }
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
      if lowered_args.length() == 0 {
        match find_filter_definition_arity(defs, name, 0) {
          Some((params, replaced)) =>
            if params.length() == 0 {
              lower_filter_with_defs(replaced, defs)
            } else {
              Filter::call(name, lowered_args)
            }
          None => Filter::call(name, lowered_args)
        }
      } else {
        Filter::call(name, lowered_args)
      }
    }
    As(value, name, body) =>
      Filter::as_(
        lower_filter_with_defs(value, defs),
        name,
        lower_filter_with_defs(body, defs),
      )
    Label(name, body) => Filter::label(name, lower_filter_with_defs(body, defs))
    Break(_) => filter
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
fn def_param_is_value(param : String) -> Bool {
  param.length() > 0 && param.unsafe_get(0).to_int().unsafe_to_char() == '$'
}

///|
fn def_param_name(param : String) -> String {
  if def_param_is_value(param) {
    param.view(start_offset=1).to_string()
  } else {
    param
  }
}

///|
fn find_filter_param_arg(
  params : Array[String],
  args : Array[Filter],
  name : String,
) -> Filter? {
  for i in 0..<params.length() {
    if !def_param_is_value(params[i]) && def_param_name(params[i]) == name {
      return Some(args[i])
    }
  }
  None
}

///|
fn lower_filter_param_refs(
  filter : Filter,
  params : Array[String],
  args : Array[Filter],
) -> Filter {
  match filter {
    Scope(local_defs, body) =>
      Filter::scope(
        local_defs.map(def_ => {
          (def_.0, def_.1, lower_filter_param_refs(def_.2, params, args))
        }),
        lower_filter_param_refs(body, params, args),
      )
    Builtin(name) =>
      match find_filter_param_arg(params, args, name) {
        Some(arg) => arg
        None => filter
      }
    Call(name, call_args) => {
      let lowered_args = call_args.map(arg => {
        lower_filter_param_refs(arg, params, args)
      })
      match find_filter_param_arg(params, args, name) {
        Some(arg) if call_args.length() == 0 => arg
        _ => Filter::call(name, lowered_args)
      }
    }
    Pipe(left, right) =>
      Filter::pipe(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    Comma(left, right) =>
      Filter::comma(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    Array(items) =>
      Filter::Array(
        items.map(item => lower_filter_param_refs(item, params, args)),
      )
    Object(items) =>
      Filter::Object(
        items.map(kv => (kv.0, lower_filter_param_refs(kv.1, params, args))),
      )
    As(value, name, body) =>
      Filter::as_(
        lower_filter_param_refs(value, params, args),
        name,
        lower_filter_param_refs(body, params, args),
      )
    Label(name, body) =>
      Filter::label(name, lower_filter_param_refs(body, params, args))
    Break(_) => filter
    Try(inner) => Filter::try_(lower_filter_param_refs(inner, params, args))
    TryCatch(inner, handler) =>
      Filter::try_catch(
        lower_filter_param_refs(inner, params, args),
        lower_filter_param_refs(handler, params, args),
      )
    Reduce(source, name, init, update) =>
      Filter::reduce(
        lower_filter_param_refs(source, params, args),
        name,
        lower_filter_param_refs(init, params, args),
        lower_filter_param_refs(update, params, args),
      )
    Foreach(source, name, init, update, extract) =>
      Filter::foreach(
        lower_filter_param_refs(source, params, args),
        name,
        lower_filter_param_refs(init, params, args),
        lower_filter_param_refs(update, params, args),
        lower_filter_param_refs(extract, params, args),
      )
    Eq(left, right) =>
      Filter::eq(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    Neq(left, right) =>
      Filter::neq(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    Lt(left, right) =>
      Filter::lt(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    Lte(left, right) =>
      Filter::lte(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    Gt(left, right) =>
      Filter::gt(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    Gte(left, right) =>
      Filter::gte(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    And(left, right) =>
      Filter::and_(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    Or(left, right) =>
      Filter::or_(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    Not(inner) => Filter::not(lower_filter_param_refs(inner, params, args))
    Add(left, right) =>
      Filter::add(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    Sub(left, right) =>
      Filter::sub(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    Mul(left, right) =>
      Filter::mul(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    Div(left, right) =>
      Filter::div(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    Mod(left, right) =>
      Filter::mod_(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    IfElse(cond, then_branch, else_branch) =>
      Filter::if_else(
        lower_filter_param_refs(cond, params, args),
        lower_filter_param_refs(then_branch, params, args),
        lower_filter_param_refs(else_branch, params, args),
      )
    Fallback(left, right) =>
      Filter::fallback(
        lower_filter_param_refs(left, params, args),
        lower_filter_param_refs(right, params, args),
      )
    _ => filter
  }
}

///|
fn lower_filter_def_call(
  body : Filter,
  params : Array[String],
  args : Array[Filter],
  captured_env : Map[String, Value],
) -> Filter {
  let mut out = lower_filter_param_refs(body, params, args)
  let value_param_names = []
  for param in params {
    if def_param_is_value(param) {
      value_param_names.push(def_param_name(param))
    }
  }
  for binding in captured_env {
    let name = binding.0
    if !name.has_prefix("__jqx_as_") && !value_param_names.contains(name) {
      out = Filter::as_(Filter::literal(binding.1), name, out)
    }
  }
  for i in 0..<params.length() {
    let idx = params.length() - 1 - i
    let param = params[idx]
    if def_param_is_value(param) {
      out = Filter::as_(args[idx], def_param_name(param), out)
    }
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

  while ctx.offset < ctx.end_offset {
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
  raise InvalidEof
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
      let mut closed = false
      while !closed {
        ctx.skip_ws()
        let (name, is_value_param) = if ctx.peek_char() is Some('$') {
          ctx.read_char() |> ignore
          (ctx.parse_identifier(), true)
        } else {
          (ctx.parse_identifier(), false)
        }
        if is_value_param {
          params.push("$" + name)
        } else {
          params.push(name)
        }
        ctx.skip_ws()
        match ctx.peek_char() {
          Some(';') => ctx.read_char() |> ignore
          Some(')') => {
            ctx.read_char() |> ignore
            closed = true
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
  ctx.skip_ws()
  while ctx.try_keyword("def") {
    let name = ctx.parse_identifier()
    let params = parse_params()
    ctx.expect_char(':')
    let body_source = ctx.read_until_top_level_semicolon()
    defs.push((name, params, parse_filter(body_source)))
    ctx.skip_ws()
  }
  defs
}

///|
fn module_source_lookup_in_registry(module_name : String) -> String? {
  match module_source_state.sources.get(module_name) {
    Some(source) => Some(source)
    None => module_source_state.sources.get(module_name + ".jq")
  }
}

///|
fn module_search_dirs_with_front(
  front : String,
  search_dirs : Array[String],
) -> Array[String] {
  let out = []
  if front.length() > 0 && !out.contains(front) {
    out.push(front)
  }
  for dir in search_dirs {
    if dir.length() > 0 && !out.contains(dir) {
      out.push(dir)
    }
  }
  out
}

///|
fn module_source_lookup(
  module_name : String,
  search_dirs : Array[String],
) -> (String, String?)? {
  match module_source_lookup_in_registry(module_name) {
    Some(source) => Some((source, None))
    None =>
      match load_module_source_from_filesystem(module_name, search_dirs) {
        Some(file_source) =>
          Some((file_source.source, Some(file_source.directory)))
        None => None
      }
  }
}

///|
fn module_signature_is_shadowed(
  shadowed : Array[(String, Int)],
  name : String,
  arity : Int,
) -> Bool {
  for kv in shadowed {
    if kv.0 == name && kv.1 == arity {
      return true
    }
  }
  false
}

///|
fn maybe_prefix_module_name(
  name : String,
  arity : Int,
  module_defs : Array[(String, Array[String], Filter)],
  module_alias : String,
  shadowed : Array[(String, Int)],
) -> String {
  if module_signature_is_shadowed(shadowed, name, arity) {
    return name
  }
  match find_filter_definition_arity(module_defs, name, arity) {
    Some(_) => module_alias + "::" + name
    None => name
  }
}

///|
fn prefix_module_filter_refs(
  filter : Filter,
  module_defs : Array[(String, Array[String], Filter)],
  module_alias : String,
  shadowed : Array[(String, Int)],
) -> Filter {
  match filter {
    Identity
    | Iter
    | IterOpt
    | Recurse
    | Empty
    | Var(_)
    | Literal(_)
    | Field(_)
    | FieldOpt(_)
    | Index(_)
    | IndexOpt(_)
    | Slice(_, _)
    | SliceOpt(_, _)
    | Break(_) => filter
    Scope(local_defs, body) => {
      let next_shadowed = shadowed.copy()
      for def_ in local_defs {
        next_shadowed.push((def_.0, def_.1.length()))
      }
      Filter::scope(
        local_defs.map(def_ => {
          (
            def_.0,
            def_.1,
            prefix_module_filter_refs(
              def_.2,
              module_defs,
              module_alias,
              next_shadowed,
            ),
          )
        }),
        prefix_module_filter_refs(
          body, module_defs, module_alias, next_shadowed,
        ),
      )
    }
    Pipe(left, right) =>
      Filter::pipe(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
    Comma(left, right) =>
      Filter::comma(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
    Array(items) =>
      Filter::Array(
        items.map(item => {
          prefix_module_filter_refs(item, module_defs, module_alias, shadowed)
        }),
      )
    Object(items) =>
      Filter::Object(
        items.map(kv => {
          (
            kv.0,
            prefix_module_filter_refs(kv.1, module_defs, module_alias, shadowed),
          )
        }),
      )
    Builtin(name) => {
      let next_name = maybe_prefix_module_name(
        name, 0, module_defs, module_alias, shadowed,
      )
      Filter::builtin(next_name)
    }
    Call(name, args) => {
      let lowered_args = args.map(arg => {
        prefix_module_filter_refs(arg, module_defs, module_alias, shadowed)
      })
      let next_name = maybe_prefix_module_name(
        name,
        lowered_args.length(),
        module_defs,
        module_alias,
        shadowed,
      )
      Filter::call(next_name, lowered_args)
    }
    As(value, name, body) =>
      Filter::as_(
        prefix_module_filter_refs(value, module_defs, module_alias, shadowed),
        name,
        prefix_module_filter_refs(body, module_defs, module_alias, shadowed),
      )
    Label(name, body) =>
      Filter::label(
        name,
        prefix_module_filter_refs(body, module_defs, module_alias, shadowed),
      )
    Try(inner) =>
      Filter::try_(
        prefix_module_filter_refs(inner, module_defs, module_alias, shadowed),
      )
    TryCatch(inner, handler) =>
      Filter::try_catch(
        prefix_module_filter_refs(inner, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(handler, module_defs, module_alias, shadowed),
      )
    Reduce(source, name, init, update) =>
      Filter::reduce(
        prefix_module_filter_refs(source, module_defs, module_alias, shadowed),
        name,
        prefix_module_filter_refs(init, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(update, module_defs, module_alias, shadowed),
      )
    Foreach(source, name, init, update, extract) =>
      Filter::foreach(
        prefix_module_filter_refs(source, module_defs, module_alias, shadowed),
        name,
        prefix_module_filter_refs(init, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(update, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(extract, module_defs, module_alias, shadowed),
      )
    Eq(left, right) =>
      Filter::eq(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
    Neq(left, right) =>
      Filter::neq(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
    Lt(left, right) =>
      Filter::lt(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
    Lte(left, right) =>
      Filter::lte(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
    Gt(left, right) =>
      Filter::gt(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
    Gte(left, right) =>
      Filter::gte(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
    And(left, right) =>
      Filter::and_(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
    Or(left, right) =>
      Filter::or_(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
    Not(inner) =>
      Filter::not(
        prefix_module_filter_refs(inner, module_defs, module_alias, shadowed),
      )
    Add(left, right) =>
      Filter::add(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
    Sub(left, right) =>
      Filter::sub(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
    Mul(left, right) =>
      Filter::mul(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
    Div(left, right) =>
      Filter::div(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
    Mod(left, right) =>
      Filter::mod_(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
    IfElse(cond, then_branch, else_branch) =>
      Filter::if_else(
        prefix_module_filter_refs(cond, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(
          then_branch, module_defs, module_alias, shadowed,
        ),
        prefix_module_filter_refs(
          else_branch, module_defs, module_alias, shadowed,
        ),
      )
    Fallback(left, right) =>
      Filter::fallback(
        prefix_module_filter_refs(left, module_defs, module_alias, shadowed),
        prefix_module_filter_refs(right, module_defs, module_alias, shadowed),
      )
  }
}

///|
fn prefix_module_defs(
  module_alias : String,
  defs : Array[(String, Array[String], Filter)],
) -> Array[(String, Array[String], Filter)] {
  let out = []
  for def_ in defs {
    out.push(
      (
        module_alias + "::" + def_.0,
        def_.1,
        prefix_module_filter_refs(def_.2, defs, module_alias, []),
      ),
    )
  }
  out
}

///|
fn append_defs(
  out : Array[(String, Array[String], Filter)],
  defs : Array[(String, Array[String], Filter)],
) -> Unit {
  for def_ in defs {
    out.push(def_)
  }
}

///|
fn FilterCursor::parse_optional_module_declaration(
  ctx : FilterCursor,
) -> Unit raise FilterError {
  ctx.skip_ws()
  if !ctx.try_keyword("module") {
    return
  }
  ctx.skip_ws()
  let metadata_offset = ctx.offset
  let metadata = ctx.parse_comma(allow_as=false)
  ctx.require_constant_object_metadata(metadata, metadata_offset)
  ctx.skip_ws()
  ctx.expect_char(';')
}

///|
fn load_module_defs(
  module_name : String,
  loading_stack : Array[String],
  search_dirs : Array[String],
) -> ModuleLoadResult raise FilterError {
  if loading_stack.contains(module_name) {
    return Missing(module_name)
  }
  match module_source_lookup(module_name, search_dirs) {
    None => Missing(module_name)
    Some((source, source_dir)) => {
      let nested_stack = loading_stack.copy()
      nested_stack.push(module_name)
      let nested_search_dirs = match source_dir {
        Some(dir) => module_search_dirs_with_front(dir, search_dirs)
        None => search_dirs
      }
      let module_ctx = FilterCursor::make(source.view())
      module_ctx.parse_optional_module_declaration()
      let (imported_defs, missing_module) = module_ctx.parse_module_prefix_with_stack(
        nested_stack, nested_search_dirs,
      )
      match missing_module {
        Some(missing_name) => Missing(missing_name)
        None => {
          let defs = module_ctx.parse_definition_prefix()
          module_ctx.skip_ws()
          if module_ctx.offset < module_ctx.end_offset {
            module_ctx.invalid_char()
          }
          let out = imported_defs.copy()
          append_defs(out, defs)
          Loaded(out)
        }
      }
    }
  }
}

///|
fn FilterCursor::parse_module_prefix(
  ctx : FilterCursor,
) -> (Array[(String, Array[String], Filter)], String?) raise FilterError {
  ctx.parse_module_prefix_with_stack([], module_default_search_paths())
}

///|
fn FilterCursor::parse_module_prefix_with_stack(
  ctx : FilterCursor,
  loading_stack : Array[String],
  search_dirs : Array[String],
) -> (Array[(String, Array[String], Filter)], String?) raise FilterError {
  let imported_defs = []
  let mut missing_module : String? = None
  let mut parsing = true
  while parsing {
    ctx.skip_ws()
    if ctx.try_keyword("import") {
      ctx.skip_ws()
      let module_name = ctx.parse_module_path_string()
      ctx.skip_ws()
      if !ctx.try_keyword("as") {
        ctx.invalid_char()
      }
      ctx.skip_ws()
      if ctx.peek_char() is Some('$') {
        ctx.read_char() |> ignore
      }
      let module_alias = ctx.parse_identifier()
      ctx.skip_ws()
      if !(ctx.peek_char() is Some(';')) {
        let metadata_offset = ctx.offset
        let metadata = ctx.parse_comma(allow_as=false)
        ctx.require_constant_object_metadata(metadata, metadata_offset)
      }
      ctx.skip_ws()
      ctx.expect_char(';')
      match load_module_defs(module_name, loading_stack, search_dirs) {
        Loaded(defs) =>
          append_defs(imported_defs, prefix_module_defs(module_alias, defs))
        Missing(missing_name) => missing_module = Some(missing_name)
      }
      continue
    }
    if ctx.try_keyword("include") {
      ctx.skip_ws()
      let module_name = ctx.parse_module_path_string()
      ctx.skip_ws()
      if !(ctx.peek_char() is Some(';')) {
        let metadata_offset = ctx.offset
        let metadata = ctx.parse_comma(allow_as=false)
        ctx.require_constant_object_metadata(metadata, metadata_offset)
      }
      ctx.skip_ws()
      ctx.expect_char(';')
      match load_module_defs(module_name, loading_stack, search_dirs) {
        Loaded(defs) => append_defs(imported_defs, defs)
        Missing(missing_name) => missing_module = Some(missing_name)
      }
      continue
    }
    parsing = false
  }
  (imported_defs, missing_module)
}

///|
fn FilterCursor::parse_scoped(
  ctx : FilterCursor,
  allow_as? : Bool = true,
) -> Filter raise FilterError {
  ctx.parse_optional_module_declaration()
  let (module_defs, missing_module) = ctx.parse_module_prefix()
  match missing_module {
    Some(module_name) => {
      ctx.offset = ctx.end_offset
      return Filter::call("error", [
        Filter::literal(Value::string("module not found: " + module_name)),
      ])
    }
    None => ()
  }
  let all_defs = module_defs.copy()
  append_defs(all_defs, ctx.parse_definition_prefix())
  let raw_filter = ctx.parse_comma(allow_as~)
  if all_defs.length() == 0 {
    raw_filter
  } else {
    let lowered_defs = lower_definition_sequence(all_defs)
    Filter::scope(lowered_defs, raw_filter)
  }
}
