///|
/// Minimal jq evaluator (streaming outputs as Array[Value])
///
/// Supported filters:
/// - Identity: .
/// - Pipe: a | b
/// - Comma: a, b
/// - Field: .foo
/// - Index: .[n]
/// - Iter: .[]
/// - Literal JSON values

///|
pub suberror EvalError {
  TypeError(String)
  Thrown(Value)
  UnknownFunction(String)
  UnknownVariable(String)
  BreakSignal(String, Array[Value])
  Partial(Array[Value], Value, String)
} derive(Eq)

///|
pub impl Show for EvalError with output(self, logger) {
  match self {
    TypeError(msg) => logger.write_string(msg)
    Thrown(value) =>
      match value {
        String(s) => logger.write_string(s)
        _ => logger.write_string(value.to_json_string())
      }
    UnknownFunction(name) => logger.write_string("Unknown function: " + name)
    UnknownVariable(name) => logger.write_string("Unknown variable: $" + name)
    BreakSignal(name, _) => logger.write_string("break $" + name)
    Partial(_, _, message) => logger.write_string(message)
  }
}

///|
fn eval_error_to_message(err : EvalError) -> String {
  match err {
    BreakSignal(name, _) => "break $" + name
    Partial(_, _, message) => message
    _ => err.to_string()
  }
}

///|
fn eval_error_prefix(err : EvalError) -> Array[Value] {
  match err {
    BreakSignal(_, values) => values.copy()
    Partial(values, _, _) => values.copy()
    _ => []
  }
}

///|
fn eval_error_to_catch_input(err : EvalError) -> Value {
  match err {
    BreakSignal(name, _) => Value::string("break $" + name)
    Partial(_, catch_input, _) => catch_input
    Thrown(value) => value
    _ => Value::string(eval_error_to_message(err))
  }
}

///|
pub fn eval_error_outputs(err : EvalError) -> Array[Value] {
  eval_error_prefix(err)
}

///|
pub fn eval_error_message(err : EvalError) -> String {
  eval_error_to_message(err)
}

///|
fn append_json_values(out : Array[Value], values : Array[Value]) -> Unit {
  for v in values {
    out.push(v)
  }
}

///|
fn env_bind_temp(
  env : Map[String, Value],
  name : String,
  value : Value,
) -> Value? {
  let previous = env.get(name)
  env[name] = value
  previous
}

///|
fn env_restore_temp(
  env : Map[String, Value],
  name : String,
  previous : Value?,
) -> Unit {
  match previous {
    Some(value) => env[name] = value
    None => env.remove(name)
  }
}

///|
fn[T] raise_with_prefix(
  prefix : Array[Value],
  err : EvalError,
) -> T raise EvalError {
  match err {
    BreakSignal(name, values) => {
      let merged = prefix.copy()
      append_json_values(merged, values)
      raise BreakSignal(name, merged)
    }
    _ => ()
  }
  if prefix.length() == 0 {
    raise err
  }
  let merged = prefix.copy()
  append_json_values(merged, eval_error_prefix(err))
  raise Partial(
    merged,
    eval_error_to_catch_input(err),
    eval_error_to_message(err),
  )
}

///|
fn eval_error_without_prefix(err : EvalError) -> EvalError {
  match err {
    BreakSignal(name, _) => BreakSignal(name, [])
    Partial(_, catch_input, message) => Partial([], catch_input, message)
    _ => err
  }
}

///|
fn append_recurse_values(input : Value, out : Array[Value]) -> Unit {
  out.push(input)
  match input {
    Object(o) =>
      for kv in object_entries_sorted(o) {
        append_recurse_values(kv.1, out)
      }
    Array(a) =>
      for v in a {
        append_recurse_values(v, out)
      }
    _ => ()
  }
}

///|
fn is_ascii_ws(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n'
}

///|
fn trim_ascii_ws(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  while start < end &&
        is_ascii_ws(s.unsafe_get(start).to_int().unsafe_to_char()) {
    start += 1
  }
  while end > start &&
        is_ascii_ws(s.unsafe_get(end - 1).to_int().unsafe_to_char()) {
    end -= 1
  }
  s.view(start_offset=start, end_offset=end).to_owned()
}

///|
fn fromjson_fallback_token(s : String) -> Value? {
  let t = ascii_downcase_string(trim_ascii_ws(s))
  match t {
    "nan" | "+nan" | "-nan" =>
      Some(Value::number(@double.infinity - @double.infinity))
    "inf" | "+inf" | "infinity" | "+infinity" =>
      Some(Value::number(@double.infinity))
    "-inf" | "-infinity" => Some(Value::number(@double.neg_infinity))
    _ => None
  }
}

///|
fn parse_fromjson_string(s : String) -> Value raise EvalError {
  try parse(s) catch {
    err =>
      match fromjson_fallback_token(s) {
        Some(v) => v
        None =>
          raise TypeError(err.to_string() + " (while parsing '" + s + "')")
      }
  } noraise {
    j => j
  }
}

///|
priv struct RuntimeDef {
  name : String
  params : Array[String]
  body : Filter
  env : Map[String, Value]
  parent : RuntimeDef?
}

///|
priv struct RuntimeDefState {
  mut current : RuntimeDef?
}

///|
let runtime_def_state : RuntimeDefState = { current: None }

///|
priv struct RuntimeFilterClosure {
  name : String
  arg : Filter
  env : Map[String, Value]
  defs : RuntimeDef?
  closures : RuntimeFilterClosure?
  parent : RuntimeFilterClosure?
}

///|
priv struct RuntimeFilterClosureState {
  mut current : RuntimeFilterClosure?
  mut next_id : Int
}

///|
let runtime_filter_closure_state : RuntimeFilterClosureState = {
  current: None,
  next_id: 0,
}

///|
fn append_runtime_defs(
  parent : RuntimeDef?,
  defs : Array[(String, Array[String], Filter)],
  env : Map[String, Value],
) -> RuntimeDef? {
  let mut out = parent
  for def_ in defs {
    out = Some({
      name: def_.0,
      params: def_.1,
      body: def_.2,
      env: clone_runtime_env(env),
      parent: out,
    })
  }
  out
}

///|
fn find_runtime_def(
  scope : RuntimeDef?,
  name : String,
  arity : Int,
) -> RuntimeDef? {
  match scope {
    Some(def_) =>
      if def_.name == name && def_.params.length() == arity {
        Some(def_)
      } else {
        find_runtime_def(def_.parent, name, arity)
      }
    None => None
  }
}

///|
fn collect_runtime_defs(
  scope : RuntimeDef?,
) -> Array[(String, Array[String], Filter)] {
  match scope {
    Some(def_) => {
      let out = collect_runtime_defs(def_.parent)
      out.push((def_.name, def_.params, def_.body))
      out
    }
    None => []
  }
}

///|
fn lower_scope_defs_with_runtime_context(
  defs : Array[(String, Array[String], Filter)],
) -> Array[(String, Array[String], Filter)] {
  let available = collect_runtime_defs(runtime_def_state.current)
  let lowered = []
  for def_ in defs {
    let lowered_body = lower_filter_with_defs(def_.2, available)
    let lowered_def = (def_.0, def_.1, lowered_body)
    lowered.push(lowered_def)
    available.push(lowered_def)
  }
  lowered
}

///|
fn filter_param_needs_direct_inline(filter : Filter, name : String) -> Bool {
  match filter {
    Call("path", args) =>
      if args.length() == 1 {
        match args[0] {
          Builtin(n) if n == name => true
          Call(n, call_args) if n == name && call_args.length() == 0 => true
          _ => filter_param_needs_direct_inline(args[0], name)
        }
      } else {
        false
      }
    Pipe(left, right)
    | Comma(left, right)
    | Eq(left, right)
    | Neq(left, right)
    | Lt(left, right)
    | Lte(left, right)
    | Gt(left, right)
    | Gte(left, right)
    | And(left, right)
    | Or(left, right)
    | Add(left, right)
    | Sub(left, right)
    | Mul(left, right)
    | Div(left, right)
    | Mod(left, right)
    | Fallback(left, right) =>
      filter_param_needs_direct_inline(left, name) ||
      filter_param_needs_direct_inline(right, name)
    Not(inner) | Try(inner) => filter_param_needs_direct_inline(inner, name)
    TryCatch(inner, handler) =>
      filter_param_needs_direct_inline(inner, name) ||
      filter_param_needs_direct_inline(handler, name)
    As(value, _, body) =>
      filter_param_needs_direct_inline(value, name) ||
      filter_param_needs_direct_inline(body, name)
    Label(_, body) => filter_param_needs_direct_inline(body, name)
    Reduce(source, _, init, update) =>
      filter_param_needs_direct_inline(source, name) ||
      filter_param_needs_direct_inline(init, name) ||
      filter_param_needs_direct_inline(update, name)
    Foreach(source, _, init, update, extract) =>
      filter_param_needs_direct_inline(source, name) ||
      filter_param_needs_direct_inline(init, name) ||
      filter_param_needs_direct_inline(update, name) ||
      filter_param_needs_direct_inline(extract, name)
    Array(items) => {
      for item in items {
        if filter_param_needs_direct_inline(item, name) {
          return true
        }
      }
      false
    }
    Object(items) => {
      for item in items {
        if filter_param_needs_direct_inline(item.1, name) {
          return true
        }
      }
      false
    }
    IfElse(cond, then_branch, else_branch) =>
      filter_param_needs_direct_inline(cond, name) ||
      filter_param_needs_direct_inline(then_branch, name) ||
      filter_param_needs_direct_inline(else_branch, name)
    Scope(local_defs, body) => {
      for def_ in local_defs {
        if filter_param_needs_direct_inline(def_.2, name) {
          return true
        }
      }
      filter_param_needs_direct_inline(body, name)
    }
    Call(_, args) => {
      for arg in args {
        if filter_param_needs_direct_inline(arg, name) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn clone_runtime_env(env : Map[String, Value]) -> Map[String, Value] {
  let out = Map::new()
  for kv in env {
    out[kv.0] = kv.1
  }
  out
}

///|
fn fresh_runtime_filter_closure_name() -> String {
  let id = runtime_filter_closure_state.next_id
  runtime_filter_closure_state.next_id += 1
  "__jqx_filter_param_" + id.to_string()
}

///|
priv struct RuntimeFilterClosureSeed {
  name : String
  arg : Filter
  env : Map[String, Value]
  defs : RuntimeDef?
  closures : RuntimeFilterClosure?
}

///|
fn append_runtime_filter_closures(
  parent : RuntimeFilterClosure?,
  seeds : Array[RuntimeFilterClosureSeed],
) -> RuntimeFilterClosure? {
  let mut out = parent
  for seed in seeds {
    out = Some({
      name: seed.name,
      arg: seed.arg,
      env: seed.env,
      defs: seed.defs,
      closures: seed.closures,
      parent: out,
    })
  }
  out
}

///|
fn find_runtime_filter_closure(
  scope : RuntimeFilterClosure?,
  name : String,
) -> RuntimeFilterClosure? {
  match scope {
    Some(closure) =>
      if closure.name == name {
        Some(closure)
      } else {
        find_runtime_filter_closure(closure.parent, name)
      }
    None => None
  }
}

///|
fn execute_runtime_filter_closure(
  closure : RuntimeFilterClosure,
  input : Value,
) -> Array[Value] raise EvalError {
  let prev_defs = runtime_def_state.current
  let prev_closures = runtime_filter_closure_state.current
  runtime_def_state.current = closure.defs
  runtime_filter_closure_state.current = closure.closures
  try
    execute_with_env(closure.arg, input, clone_runtime_env(closure.env))
  catch {
    err => {
      runtime_def_state.current = prev_defs
      runtime_filter_closure_state.current = prev_closures
      raise err
    }
  } noraise {
    values => {
      runtime_def_state.current = prev_defs
      runtime_filter_closure_state.current = prev_closures
      values
    }
  }
}

///|
fn execute_runtime_def_call(
  def_ : RuntimeDef,
  args : Array[Filter],
  input : Value,
  env : Map[String, Value],
) -> Array[Value] raise EvalError {
  let closure_args = []
  let closure_seeds = []
  for i in 0..<def_.params.length() {
    let param = def_.params[i]
    if def_param_is_value(param) {
      closure_args.push(args[i])
    } else if filter_param_needs_direct_inline(def_.body, def_param_name(param)) {
      closure_args.push(args[i])
    } else {
      let closure_name = fresh_runtime_filter_closure_name()
      closure_args.push(Filter::builtin(closure_name))
      closure_seeds.push({
        name: closure_name,
        arg: args[i],
        env: clone_runtime_env(env),
        defs: runtime_def_state.current,
        closures: runtime_filter_closure_state.current,
      })
    }
  }

  let expanded = lower_filter_def_call(
    def_.body,
    def_.params,
    closure_args,
    def_.env,
  )

  let prev_defs = runtime_def_state.current
  let prev_closures = runtime_filter_closure_state.current
  runtime_def_state.current = Some(def_)
  runtime_filter_closure_state.current = append_runtime_filter_closures(
    runtime_filter_closure_state.current,
    closure_seeds,
  )
  try execute_with_env(expanded, input, env) catch {
    err => {
      runtime_def_state.current = prev_defs
      runtime_filter_closure_state.current = prev_closures
      raise err
    }
  } noraise {
    values => {
      runtime_def_state.current = prev_defs
      runtime_filter_closure_state.current = prev_closures
      values
    }
  }
}

///|
pub fn execute(filter : Filter, input : Value) -> Array[Value] raise EvalError {
  let env = Map::new()
  let prev_defs = runtime_def_state.current
  let prev_closures = runtime_filter_closure_state.current
  runtime_def_state.current = None
  runtime_filter_closure_state.current = None
  try execute_with_env(filter, input, env) catch {
    err => {
      runtime_def_state.current = prev_defs
      runtime_filter_closure_state.current = prev_closures
      raise err
    }
  } noraise {
    values => {
      runtime_def_state.current = prev_defs
      runtime_filter_closure_state.current = prev_closures
      values
    }
  }
}

///|
pub fn execute_for_cli(
  filter : Filter,
  input : Value,
) -> (Array[Value], String?) {
  try (execute(filter, input), None) catch {
    err => (eval_error_outputs(err), Some(eval_error_message(err)))
  } noraise {
    result => result
  }
}

///|
fn execute_with_env(
  filter : Filter,
  input : Value,
  env : Map[String, Value],
) -> Array[Value] raise EvalError {
  match filter {
    Identity => [input]
    Scope(defs, body) => {
      let prev_defs = runtime_def_state.current
      let lowered_defs = lower_scope_defs_with_runtime_context(defs)
      runtime_def_state.current = append_runtime_defs(
        runtime_def_state.current,
        lowered_defs,
        env,
      )
      try execute_with_env(body, input, env) catch {
        err => {
          runtime_def_state.current = prev_defs
          raise err
        }
      } noraise {
        values => {
          runtime_def_state.current = prev_defs
          values
        }
      }
    }
    Literal(v) => [v]
    Field(name) =>
      match input {
        Object(o) =>
          match o.get(name) {
            Some(v) => [v]
            None => [Value::null()]
          }
        JNull => [Value::null()]
        _ =>
          raise TypeError(
            "Cannot index " +
            json_type_name(input) +
            " with string \"" +
            name +
            "\"",
          )
      }
    FieldOpt(name) =>
      match input {
        Object(o) =>
          match o.get(name) {
            Some(v) => [v]
            None => [Value::null()]
          }
        JNull => [Value::null()]
        _ => []
      }
    Index(i) =>
      match input {
        Array(a) => {
          let idx = if i < 0 { a.length() + i } else { i }
          if idx >= 0 && idx < a.length() {
            [a[idx]]
          } else {
            [Value::null()]
          }
        }
        JNull => [Value::null()]
        _ =>
          raise TypeError(
            "Cannot index " + json_type_name(input) + " with number",
          )
      }
    IndexOpt(i) =>
      match input {
        Array(a) => {
          let idx = if i < 0 { a.length() + i } else { i }
          if idx >= 0 && idx < a.length() {
            [a[idx]]
          } else {
            [Value::null()]
          }
        }
        JNull => [Value::null()]
        _ => []
      }
    Slice(start, end) => execute_slice(start, end, input, optional=false)
    SliceOpt(start, end) => execute_slice(start, end, input, optional=true)
    Iter =>
      match input {
        Array(a) => a
        Object(o) => {
          let out = []
          for kv in object_entries_sorted(o) {
            out.push(kv.1)
          }
          out
        }
        _ =>
          raise TypeError("Cannot iterate over " + json_type_with_value(input))
      }
    IterOpt =>
      match input {
        Array(a) => a
        Object(o) => {
          let out = []
          for kv in object_entries_sorted(o) {
            out.push(kv.1)
          }
          out
        }
        _ => []
      }
    Recurse => {
      let out = []
      append_recurse_values(input, out)
      out
    }
    Var(name) =>
      match env.get(name) {
        Some(v) => [v]
        None =>
          if name == "ENV" {
            [Value::object(Map::new())]
          } else if name == "__loc__" {
            [
              Value::object_from_entries([
                ("file", Value::string("<top-level>")),
                ("line", Value::number(1.0)),
              ]),
            ]
          } else {
            raise UnknownVariable(name)
          }
      }
    As(value, name, body) => {
      let out = []
      let values = execute_with_env(value, input, env)
      for v in values {
        let previous = env_bind_temp(env, name, v)
        let body_values = try execute_with_env(body, input, env) catch {
          err => {
            env_restore_temp(env, name, previous)
            raise err
          }
        } noraise {
          values => values
        }
        env_restore_temp(env, name, previous)
        for v2 in body_values {
          out.push(v2)
        }
      }
      out
    }
    Label(name, body) =>
      try execute_with_env(body, input, env) catch {
        err =>
          match err {
            BreakSignal(target, values) =>
              if target == name {
                values
              } else {
                raise err
              }
            _ => raise err
          }
      } noraise {
        values => values
      }
    Break(name) => raise BreakSignal(name, [])
    Try(inner) =>
      try execute_with_env(inner, input, env) catch {
        err =>
          match err {
            BreakSignal(_, _) => raise err
            Partial(values, _, _) => values
            _ => []
          }
      } noraise {
        values => values
      }
    TryCatch(inner, handler) =>
      try execute_with_env(inner, input, env) catch {
        err =>
          match err {
            BreakSignal(_, _) => raise err
            _ => {
              let prefix = eval_error_prefix(err)
              let handled = try
                execute_with_env(handler, eval_error_to_catch_input(err), env)
              catch {
                err2 => raise_with_prefix(prefix, err2)
              } noraise {
                values => values
              }
              append_json_values(prefix, handled)
              prefix
            }
          }
      } noraise {
        values => values
      }
    Reduce(source, name, init, update) => {
      let mut accs = execute_with_env(init, input, env)
      let items = execute_with_env(source, input, env)
      for item in items {
        let previous = env_bind_temp(env, name, item)
        let next_accs = try {
          let next_accs = []
          for acc in accs {
            for v in execute_with_env(update, acc, env) {
              next_accs.push(v)
            }
          }
          next_accs
        } catch {
          err => {
            env_restore_temp(env, name, previous)
            raise err
          }
        } noraise {
          values => values
        }
        env_restore_temp(env, name, previous)
        accs = next_accs
      }
      accs
    }
    Foreach(source, name, init, update, extract) => {
      let items = execute_with_env(source, input, env)
      let accs = execute_with_env(init, input, env)
      let out = []
      for seed in accs {
        let mut states = [seed]
        for item in items {
          let previous = env_bind_temp(env, name, item)
          let next_states = try {
            let next_states = []
            for acc in states {
              let update_values = try execute_with_env(update, acc, env) catch {
                err => raise_with_prefix(out, err)
              } noraise {
                values => values
              }
              for v in update_values {
                next_states.push(v)
              }
            }
            for acc in next_states {
              let extract_values = try
                execute_with_env(extract, acc, env)
              catch {
                err => raise_with_prefix(out, err)
              } noraise {
                values => values
              }
              append_json_values(out, extract_values)
            }
            next_states
          } catch {
            err => {
              env_restore_temp(env, name, previous)
              raise err
            }
          } noraise {
            values => values
          }
          env_restore_temp(env, name, previous)
          states = next_states
        }
      }
      out
    }
    Pipe(left, right) => {
      let out = []
      let left_values = try execute_with_env(left, input, env) catch {
        err => raise_with_prefix(out, err)
      } noraise {
        values => values
      }
      for v in left_values {
        let right_values = try execute_with_env(right, v, env) catch {
          err => raise_with_prefix(out, err)
        } noraise {
          values => values
        }
        append_json_values(out, right_values)
      }
      out
    }
    Comma(left, right) => {
      let out = []
      let left_values = try execute_with_env(left, input, env) catch {
        err => raise_with_prefix(out, err)
      } noraise {
        values => values
      }
      append_json_values(out, left_values)
      let right_values = try execute_with_env(right, input, env) catch {
        err => raise_with_prefix(out, err)
      } noraise {
        values => values
      }
      append_json_values(out, right_values)
      out
    }
    Array(items) => {
      let out = []
      for f in items {
        let values = try execute_with_env(f, input, env) catch {
          err => raise eval_error_without_prefix(err)
        } noraise {
          values => values
        }
        for v in values {
          out.push(v)
        }
      }
      [Value::array(out)]
    }
    Object(items) => {
      let mut partials = [(Map::new(), [])]
      for kv in items {
        let key = kv.0
        let f = kv.1
        let vals = try execute_with_env(f, input, env) catch {
          err => raise eval_error_without_prefix(err)
        } noraise {
          values => values
        }
        if vals.length() == 0 {
          return []
        }
        let next = []
        for partial in partials {
          let base_map = partial.0
          let base_order = partial.1
          for i in 0..<vals.length() {
            let v = vals[i]
            let m = base_map.copy()
            let order = base_order.copy()
            if !m.contains(key) {
              order.push(key)
            }
            m[key] = v
            next.push((m, order))
          }
        }
        partials = next
      }
      let out = []
      for partial in partials {
        out.push(Value::object_with_order(partial.0, partial.1))
      }
      out
    }
    Builtin(name) =>
      match
        find_runtime_filter_closure(runtime_filter_closure_state.current, name) {
        Some(closure) => execute_runtime_filter_closure(closure, input)
        None =>
          match find_runtime_def(runtime_def_state.current, name, 0) {
            Some(def_) => execute_runtime_def_call(def_, [], input, env)
            None => builtin_call0(name, input)
          }
      }
    Call(name, args) =>
      match
        find_runtime_filter_closure(runtime_filter_closure_state.current, name) {
        Some(closure) if args.length() == 0 =>
          execute_runtime_filter_closure(closure, input)
        _ =>
          match
            find_runtime_def(runtime_def_state.current, name, args.length()) {
            Some(def_) => execute_runtime_def_call(def_, args, input, env)
            None => builtin_call(name, args, input, env)
          }
      }
    Eq(left, right) => {
      let l = execute_with_env(left, input, env)
      let r = execute_with_env(right, input, env)
      let out = []
      for j in 0..<r.length() {
        let b = r[j]
        for i in 0..<l.length() {
          let a = l[i]
          out.push(Value::boolean(a == b))
        }
      }
      out
    }
    Neq(left, right) => {
      let l = execute_with_env(left, input, env)
      let r = execute_with_env(right, input, env)
      let out = []
      for j in 0..<r.length() {
        let b = r[j]
        for i in 0..<l.length() {
          let a = l[i]
          out.push(Value::boolean(a != b))
        }
      }
      out
    }
    Lt(left, right) => execute_compare("<", left, right, input, env)
    Lte(left, right) => execute_compare("<=", left, right, input, env)
    Gt(left, right) => execute_compare(">", left, right, input, env)
    Gte(left, right) => execute_compare(">=", left, right, input, env)
    And(left, right) => {
      let out = []
      for l in execute_with_env(left, input, env) {
        if is_truthy(l) {
          for r in execute_with_env(right, input, env) {
            out.push(Value::boolean(is_truthy(r)))
          }
        } else {
          out.push(Value::boolean(false))
        }
      }
      out
    }
    Or(left, right) => {
      let out = []
      for l in execute_with_env(left, input, env) {
        if is_truthy(l) {
          out.push(Value::boolean(true))
        } else {
          for r in execute_with_env(right, input, env) {
            out.push(Value::boolean(is_truthy(r)))
          }
        }
      }
      out
    }
    Not(inner) => {
      let out = []
      for v in execute_with_env(inner, input, env) {
        out.push(Value::boolean(!is_truthy(v)))
      }
      out
    }
    Add(left, right) => execute_add(left, right, input, env)
    Sub(left, right) => execute_arith("-", left, right, input, env)
    Mul(left, right) => execute_arith("*", left, right, input, env)
    Div(left, right) => execute_arith("/", left, right, input, env)
    Mod(left, right) => execute_arith("%", left, right, input, env)
    IfElse(cond, then_branch, else_branch) => {
      let out = []
      for cond_value in execute_with_env(cond, input, env) {
        if is_truthy(cond_value) {
          for v in execute_with_env(then_branch, input, env) {
            out.push(v)
          }
        } else {
          for v in execute_with_env(else_branch, input, env) {
            out.push(v)
          }
        }
      }
      out
    }
    Fallback(left, right) => {
      let l = execute_with_env(left, input, env)
      let truthy_values = []
      for v in l {
        if is_truthy(v) {
          truthy_values.push(v)
        }
      }
      if truthy_values.length() > 0 {
        truthy_values
      } else {
        execute_with_env(right, input, env)
      }
    }
    Empty => []
  }
}

///|
fn execute_with_env_prefix(
  filter : Filter,
  input : Value,
  env : Map[String, Value],
  max_count : Int,
) -> Array[Value] raise EvalError {
  if max_count <= 0 {
    return []
  }

  let out = []
  fn collect(current : Filter, value : Value) -> Unit raise EvalError {
    if out.length() >= max_count {
      return
    }
    match current {
      Comma(left, right) => {
        collect(left, value)
        if out.length() < max_count {
          collect(right, value)
        }
      }
      Pipe(left, right) => {
        let left_values = execute_with_env(left, value, env)
        for next in left_values {
          if out.length() >= max_count {
            break
          }
          collect(right, next)
        }
      }
      _ => {
        let values = execute_with_env(current, value, env)
        for v in values {
          if out.length() >= max_count {
            break
          }
          out.push(v)
        }
      }
    }
  }

  collect(filter, input)
  out
}

///|
fn join_values(a : Array[Value], sep : Value) -> Value raise EvalError {
  let mut acc = Value::string("")
  for i in 0..<a.length() {
    if i > 0 {
      acc = json_add_pair(acc, sep)
    }
    acc = json_add_pair(acc, join_item(a[i]))
  }
  acc
}

///|
fn split_string(s : String, sep : String) -> Array[Value] {
  if s.length() == 0 {
    return []
  }
  if sep.length() == 0 {
    let out = []
    for ch in s {
      out.push(Value::string(char_to_string(ch)))
    }
    return out
  }
  let out = []
  let mut start = 0
  let sep_len = sep.length()
  while start <= s.length() {
    let rest = s.view(start_offset=start)
    match rest.find(sep) {
      Some(i) => {
        out.push(
          Value::string(
            s.view(start_offset=start, end_offset=start + i).to_owned(),
          ),
        )
        start = start + i + sep_len
        continue
      }
      None => {
        out.push(Value::string(s.view(start_offset=start).to_owned()))
        return out
      }
    }
  }
  out
}

///|
fn char_to_string(ch : Char) -> String {
  let buf = StringBuilder::new()
  buf.write_char(ch)
  buf.to_string()
}

///|
fn explode_string(s : String) -> Array[Value] {
  let out = []
  for ch in s {
    out.push(Value::number(ch.to_int().to_double()))
  }
  out
}

///|
fn implode_array(a : Array[Value]) -> String raise EvalError {
  let buf = StringBuilder::new()
  for v in a {
    match v {
      Number(n, _) =>
        if n != n || n == @double.infinity || n == @double.neg_infinity {
          raise TypeError(
            json_type_with_value(v) +
            " can't be imploded, unicode codepoint needs to be numeric",
          )
        } else {
          let code = n.to_int()
          let ch = codepoint_or_replacement(code)
          buf.write_char(ch)
        }
      _ =>
        raise TypeError(
          json_type_with_value(v) +
          " can't be imploded, unicode codepoint needs to be numeric",
        )
    }
  }
  buf.to_string()
}

///|
fn codepoint_or_replacement(code : Int) -> Char {
  if code < 0 || code > 0x10FFFF || (code >= 0xD800 && code <= 0xDFFF) {
    '\u{fffd}'
  } else {
    code.unsafe_to_char()
  }
}

///|
fn ascii_upcase_string(s : String) -> String {
  let buf = StringBuilder::new()
  for ch in s {
    let code = ch.to_int()
    if code >= 'a'.to_int() && code <= 'z'.to_int() {
      buf.write_char((code - 32).unsafe_to_char())
    } else {
      buf.write_char(ch)
    }
  }
  buf.to_string()
}

///|
fn ascii_downcase_string(s : String) -> String {
  let buf = StringBuilder::new()
  for ch in s {
    let code = ch.to_int()
    if code >= 'A'.to_int() && code <= 'Z'.to_int() {
      buf.write_char((code + 32).unsafe_to_char())
    } else {
      buf.write_char(ch)
    }
  }
  buf.to_string()
}

///|
fn join_item(v : Value) -> Value {
  match v {
    String(_) => v
    Number(n, repr) => Value::string(Value::number(n, repr?).to_json_string())
    JTrue => Value::string("true")
    JFalse => Value::string("false")
    JNull => Value::string("")
    _ => v
  }
}

///|
fn clamp_slice_index(i : Int, len : Int) -> Int {
  if i < 0 {
    0
  } else if i > len {
    len
  } else {
    i
  }
}

///|
fn normalize_slice_index(i : Int?, len : Int, default : Int) -> Int {
  match i {
    Some(v) => {
      let idx = if v < 0 { len + v } else { v }
      clamp_slice_index(idx, len)
    }
    None => default
  }
}

///|
fn execute_slice_array(
  a : Array[Value],
  start : Int?,
  end : Int?,
) -> Array[Value] {
  let len = a.length()
  let lo = normalize_slice_index(start, len, 0)
  let hi = normalize_slice_index(end, len, len)
  if hi <= lo {
    []
  } else {
    let out = []
    for i in lo..<hi {
      out.push(a[i])
    }
    out
  }
}

///|
fn set_slice_array(
  a : Array[Value],
  start : Int?,
  end : Int?,
  replacement : Array[Value],
) -> Array[Value] {
  let len = a.length()
  let lo = normalize_slice_index(start, len, 0)
  let hi0 = normalize_slice_index(end, len, len)
  let hi = if hi0 < lo { lo } else { hi0 }
  let out = []
  for i in 0..<lo {
    out.push(a[i])
  }
  for v in replacement {
    out.push(v)
  }
  for i in hi..<len {
    out.push(a[i])
  }
  out
}

///|
fn set_slice_on_input(
  input : Value,
  start : Int?,
  end : Int?,
  value : Value,
) -> Value raise EvalError {
  match input {
    Array(a) => {
      let replacement = match value {
        Array(v) => v
        _ =>
          raise TypeError(
            "A slice of an array can only be assigned another array",
          )
      }
      Value::array(set_slice_array(a, start, end, replacement))
    }
    JNull => {
      let replacement = match value {
        Array(v) => v
        _ =>
          raise TypeError(
            "A slice of an array can only be assigned another array",
          )
      }
      Value::array(set_slice_array([], start, end, replacement))
    }
    String(_) => raise TypeError("Cannot update string slices")
    _ => index_type_error(input, Value::object(Map::new()))
  }
}

///|
fn execute_slice_string(s : String, start : Int?, end : Int?) -> String {
  let len = s.length()
  let lo = normalize_slice_index(start, len, 0)
  let hi = normalize_slice_index(end, len, len)
  if hi <= lo {
    ""
  } else {
    s.view(start_offset=lo, end_offset=hi).to_owned()
  }
}

///|
fn execute_slice(
  start : Int?,
  end : Int?,
  input : Value,
  optional~ : Bool,
) -> Array[Value] raise EvalError {
  match input {
    Array(a) => [Value::array(execute_slice_array(a, start, end))]
    String(s) => [Value::string(execute_slice_string(s, start, end))]
    JNull => [Value::null()]
    _ =>
      if optional {
        []
      } else {
        raise TypeError(
          "Cannot index " + json_type_name(input) + " with object",
        )
      }
  }
}
