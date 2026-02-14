///|
fn getpath_on_input(input : Json, path : Json) -> Json raise EvalError {
  match path {
    Array(parts) => {
      let mut current = input
      for key in parts {
        let cur = current
        current = match cur {
          Object(o) =>
            match key {
              String(name) =>
                match o.get(name) {
                  Some(v) => v
                  None => Json::null()
                }
              _ => index_type_error(cur, key)
            }
          Array(a) =>
            match key {
              Number(n, _) => {
                let i = n.to_int()
                let idx = if i < 0 { a.length() + i } else { i }
                if idx >= 0 && idx < a.length() {
                  a[idx]
                } else {
                  Json::null()
                }
              }
              _ => index_type_error(cur, key)
            }
          JNull =>
            match key {
              Number(_, _) | String(_) | Object(_) => Json::null()
              _ => index_type_error(cur, key)
            }
          _ => index_type_error(cur, key)
        }
      }
      current
    }
    _ => raise TypeError("Path must be specified as an array")
  }
}

///|
fn normalize_setpath_arg(path : Json) -> Array[Json] raise EvalError {
  match path {
    Array(parts) => parts
    _ => raise TypeError("Path must be specified as an array")
  }
}

///|
fn setpath_on_input(
  input : Json,
  path : Array[Json],
  value : Json,
) -> Json raise EvalError {
  if path.length() == 0 {
    return value
  }
  let key = path[0]
  let rest = path_tail(path)
  match input {
    Object(o) =>
      match key {
        String(name) => {
          let child = match o.get(name) {
            Some(v) => v
            None => Json::null()
          }
          let updated = setpath_on_input(child, rest, value)
          let out = Map::new()
          for kv in object_entries_sorted(o) {
            out[kv.0] = kv.1
          }
          out[name] = updated
          Json::object(out)
        }
        _ => index_type_error(input, key)
      }
    Array(a) =>
      match key {
        Number(n, _) =>
          if n != n {
            raise TypeError("Cannot set array element at NaN index")
          } else if n == @double.infinity || n == @double.neg_infinity {
            raise TypeError("Array index too large")
          } else if n > 2147483647.0 || n < -2147483648.0 {
            raise TypeError("Array index too large")
          } else {
            let i = n.to_int()
            if i < 0 {
              let idx = a.length() + i
              if idx < 0 {
                raise TypeError("Out of bounds negative array index")
              } else {
                let out = a.copy()
                out[idx] = setpath_on_input(out[idx], rest, value)
                Json::array(out)
              }
            } else {
              let out = a.copy()
              for {
                if out.length() <= i {
                  out.push(Json::null())
                } else {
                  break
                }
              }
              out[i] = setpath_on_input(out[i], rest, value)
              Json::array(out)
            }
          }
        Object(_) =>
          raise TypeError("Array/string slice indices must be integers")
        Array(_) =>
          raise TypeError("Cannot update field at array index of array")
        _ => index_type_error(input, key)
      }
    JNull =>
      match key {
        String(name) => {
          let updated = setpath_on_input(Json::null(), rest, value)
          let out = Map::new()
          out[name] = updated
          Json::object(out)
        }
        Number(n, _) =>
          if n != n {
            raise TypeError("Cannot set array element at NaN index")
          } else if n == @double.infinity || n == @double.neg_infinity {
            raise TypeError("Array index too large")
          } else if n > 2147483647.0 || n < -2147483648.0 {
            raise TypeError("Array index too large")
          } else {
            let i = n.to_int()
            if i < 0 {
              raise TypeError("Out of bounds negative array index")
            } else {
              let out = []
              for {
                if out.length() <= i {
                  out.push(Json::null())
                } else {
                  break
                }
              }
              out[i] = setpath_on_input(out[i], rest, value)
              Json::array(out)
            }
          }
        _ => index_type_error(input, key)
      }
    _ => index_type_error(input, key)
  }
}

///|
fn path_tail(path : Array[Json]) -> Array[Json] {
  let out = []
  for i in 1..<path.length() {
    out.push(path[i])
  }
  out
}

///|
fn add_object_path_group(
  groups : Map[String, Array[Array[Json]]],
  key : String,
  rest : Array[Json],
) -> Unit {
  match groups.get(key) {
    Some(paths) => {
      let next = paths.copy()
      next.push(rest)
      groups[key] = next
    }
    None => groups[key] = [rest]
  }
}

///|
fn add_array_path_group(
  groups : Map[Int, Array[Array[Json]]],
  key : Int,
  rest : Array[Json],
) -> Unit {
  match groups.get(key) {
    Some(paths) => {
      let next = paths.copy()
      next.push(rest)
      groups[key] = next
    }
    None => groups[key] = [rest]
  }
}

///|
fn has_empty_path(paths : Array[Array[Json]]) -> Bool {
  for p in paths {
    if p.length() == 0 {
      return true
    }
  }
  false
}

///|
fn normalize_delpaths_arg(paths : Json) -> Array[Array[Json]] raise EvalError {
  match paths {
    Array(path_list) => {
      let out = []
      for p in path_list {
        match p {
          Array(parts) => out.push(parts)
          _ =>
            raise TypeError(
              "Path must be specified as array, not " + json_type_name(p),
            )
        }
      }
      out
    }
    _ => raise TypeError("Paths must be specified as an array")
  }
}

///|
fn delpaths_on_input(
  input : Json,
  paths : Array[Array[Json]],
) -> Json raise EvalError {
  if has_empty_path(paths) {
    return Json::null()
  }
  match input {
    JNull => Json::null()
    Object(o) => {
      let groups = Map::new()
      for path in paths {
        if path.length() == 0 {
          continue
        }
        let key = path[0]
        let rest = path_tail(path)
        match key {
          String(name) => add_object_path_group(groups, name, rest)
          _ =>
            raise TypeError(
              "Cannot delete " + json_type_name(key) + " field of object",
            )
        }
      }
      let out = Map::new()
      for kv in object_entries_sorted(o) {
        let name = kv.0
        let value = kv.1
        match groups.get(name) {
          Some(subpaths) =>
            if has_empty_path(subpaths) {
              ()
            } else {
              out[name] = delpaths_on_input(value, subpaths)
            }
          None => out[name] = value
        }
      }
      Json::object(out)
    }
    Array(a) => {
      let groups = Map::new()
      for path in paths {
        if path.length() == 0 {
          continue
        }
        let key = path[0]
        let rest = path_tail(path)
        match key {
          Number(n, _) => {
            let i = n.to_int()
            let idx = if i < 0 { a.length() + i } else { i }
            if idx >= 0 && idx < a.length() {
              add_array_path_group(groups, idx, rest)
            }
          }
          Object(_) =>
            raise TypeError("Array/string slice indices must be integers")
          _ =>
            raise TypeError(
              "Cannot delete " + json_type_name(key) + " element of array",
            )
        }
      }
      let out = []
      for i in 0..<a.length() {
        match groups.get(i) {
          Some(subpaths) =>
            if has_empty_path(subpaths) {
              ()
            } else {
              out.push(delpaths_on_input(a[i], subpaths))
            }
          None => out.push(a[i])
        }
      }
      Json::array(out)
    }
    _ => raise TypeError("Cannot delete fields from " + json_type_name(input))
  }
}

///|
fn collect_paths(
  input : Json,
  prefix : Array[Json],
  predicate : Filter?,
  env : Map[String, Json],
) -> Array[Json] raise EvalError {
  let out = []
  fn include_node(v : Json) -> Bool raise EvalError {
    match predicate {
      Some(pred) => eval_to_bool(pred, v, env)
      None => true
    }
  }

  match input {
    Object(o) =>
      for kv in object_entries_sorted(o) {
        let key = kv.0
        let value = kv.1
        let p = prefix.copy()
        p.push(Json::string(key))
        if include_node(value) {
          out.push(Json::array(p))
        }
        for child in collect_paths(value, p, predicate, env) {
          out.push(child)
        }
      }
    Array(a) =>
      for i in 0..<a.length() {
        let value = a[i]
        let p = prefix.copy()
        p.push(Json::number(i.to_double()))
        if include_node(value) {
          out.push(Json::array(p))
        }
        for child in collect_paths(value, p, predicate, env) {
          out.push(child)
        }
      }
    _ => ()
  }
  out
}

///|
priv struct PathEvalState {
  value : Json
  path : Array[Json]
  valid : Bool
}

///|
fn path_eval_state(
  value : Json,
  path : Array[Json],
  valid : Bool,
) -> PathEvalState {
  PathEvalState::{ value, path, valid }
}

///|
fn path_with_segment(path : Array[Json], segment : Json) -> Array[Json] {
  let out = path.copy()
  out.push(segment)
  out
}

///|
fn path_invalid_access_message(segment : String, value : Json) -> String {
  "Invalid path expression near attempt to access element " +
  segment +
  " of " +
  value.to_json_string()
}

///|
fn path_invalid_iter_message(value : Json) -> String {
  "Invalid path expression near attempt to iterate through " +
  value.to_json_string()
}

///|
fn eval_path_fallback_states(
  filter : Filter,
  state : PathEvalState,
  env : Map[String, Json],
) -> Array[PathEvalState] raise EvalError {
  let values = eval_with_env(filter, state.value, env)
  let out = []
  for value in values {
    out.push(path_eval_state(value, state.path.copy(), false))
  }
  out
}

///|
fn eval_path_field_state(
  state : PathEvalState,
  name : String,
  optional : Bool,
) -> Array[PathEvalState] raise EvalError {
  if !state.valid {
    raise TypeError(
      path_invalid_access_message(
        Json::string(name).to_json_string(),
        state.value,
      ),
    )
  }
  let next_path = path_with_segment(state.path, Json::string(name))
  match state.value {
    Object(o) =>
      match o.get(name) {
        Some(v) => [path_eval_state(v, next_path, true)]
        None => [path_eval_state(Json::null(), next_path, true)]
      }
    JNull => [path_eval_state(Json::null(), next_path, true)]
    _ =>
      if optional {
        []
      } else {
        index_type_error(state.value, Json::string(name))
      }
  }
}

///|
fn eval_path_index_state(
  state : PathEvalState,
  index : Int,
  optional : Bool,
) -> Array[PathEvalState] raise EvalError {
  if !state.valid {
    raise TypeError(path_invalid_access_message(index.to_string(), state.value))
  }
  let next_path = path_with_segment(state.path, Json::number(index.to_double()))
  match state.value {
    Array(a) => {
      let resolved = if index < 0 { a.length() + index } else { index }
      if resolved >= 0 && resolved < a.length() {
        [path_eval_state(a[resolved], next_path, true)]
      } else {
        [path_eval_state(Json::null(), next_path, true)]
      }
    }
    JNull => [path_eval_state(Json::null(), next_path, true)]
    _ =>
      if optional {
        []
      } else {
        index_type_error(state.value, Json::number(index.to_double()))
      }
  }
}

///|
fn eval_path_slice_state(
  state : PathEvalState,
  start : Int?,
  end : Int?,
  optional : Bool,
) -> Array[PathEvalState] raise EvalError {
  if !state.valid {
    raise TypeError(
      "Invalid path expression with result " + state.value.to_json_string(),
    )
  }
  match state.value {
    Array(a) => {
      let len = a.length()
      let lo = normalize_slice_index(start, len, 0)
      let hi = normalize_slice_index(end, len, len)
      if hi <= lo {
        []
      } else {
        let out = []
        for i in lo..<hi {
          let next_path = path_with_segment(
            state.path,
            Json::number(i.to_double()),
          )
          out.push(path_eval_state(a[i], next_path, true))
        }
        out
      }
    }
    JNull => []
    _ =>
      if optional {
        []
      } else {
        raise TypeError(
          "Cannot index " + json_type_name(state.value) + " with object",
        )
      }
  }
}

///|
fn eval_path_iter_state(
  state : PathEvalState,
  optional : Bool,
) -> Array[PathEvalState] raise EvalError {
  if !state.valid {
    raise TypeError(path_invalid_iter_message(state.value))
  }
  match state.value {
    Array(a) => {
      let out = []
      for i in 0..<a.length() {
        let next_path = path_with_segment(
          state.path,
          Json::number(i.to_double()),
        )
        out.push(path_eval_state(a[i], next_path, true))
      }
      out
    }
    Object(o) => {
      let out = []
      for kv in object_entries_sorted(o) {
        let next_path = path_with_segment(state.path, Json::string(kv.0))
        out.push(path_eval_state(kv.1, next_path, true))
      }
      out
    }
    _ =>
      if optional {
        []
      } else {
        raise TypeError(
          "Cannot iterate over " + json_type_with_value(state.value),
        )
      }
  }
}

///|
fn append_recurse_path_states(
  value : Json,
  path : Array[Json],
  out : Array[PathEvalState],
) -> Unit {
  out.push(path_eval_state(value, path, true))
  match value {
    Object(o) =>
      for kv in object_entries_sorted(o) {
        append_recurse_path_states(
          kv.1,
          path_with_segment(path, Json::string(kv.0)),
          out,
        )
      }
    Array(a) =>
      for i in 0..<a.length() {
        append_recurse_path_states(
          a[i],
          path_with_segment(path, Json::number(i.to_double())),
          out,
        )
      }
    _ => ()
  }
}

///|
fn eval_path_filter_state(
  filter : Filter,
  state : PathEvalState,
  env : Map[String, Json],
) -> Array[PathEvalState] raise EvalError {
  match filter {
    Identity => [state]
    Pipe(left, right) => {
      let out = []
      for left_state in eval_path_filter_state(left, state, env) {
        for right_state in eval_path_filter_state(right, left_state, env) {
          out.push(right_state)
        }
      }
      out
    }
    Comma(left, right) => {
      let out = eval_path_filter_state(left, state, env)
      for right_state in eval_path_filter_state(right, state, env) {
        out.push(right_state)
      }
      out
    }
    Field(name) => eval_path_field_state(state, name, false)
    FieldOpt(name) => eval_path_field_state(state, name, true)
    Index(index) => eval_path_index_state(state, index, false)
    IndexOpt(index) => eval_path_index_state(state, index, true)
    Slice(start, end) => eval_path_slice_state(state, start, end, false)
    SliceOpt(start, end) => eval_path_slice_state(state, start, end, true)
    Iter => eval_path_iter_state(state, false)
    IterOpt => eval_path_iter_state(state, true)
    Recurse => {
      if !state.valid {
        raise TypeError(path_invalid_iter_message(state.value))
      }
      let out = []
      append_recurse_path_states(state.value, state.path, out)
      out
    }
    Call("select", args) =>
      if args.length() != 1 {
        raise UnknownFunction("select")
      } else if eval_to_bool(args[0], state.value, env) {
        [state]
      } else {
        []
      }
    Empty => []
    _ => eval_path_fallback_states(filter, state, env)
  }
}

///|
fn eval_path_expression(
  filter : Filter,
  input : Json,
  env : Map[String, Json],
) -> Array[Json] raise EvalError {
  let states = eval_path_filter_state(
    filter,
    path_eval_state(input, [], true),
    env,
  )
  let out = []
  for state in states {
    if !state.valid {
      raise TypeError(
        "Invalid path expression with result " + state.value.to_json_string(),
      )
    }
    out.push(Json::array(state.path))
  }
  out
}
