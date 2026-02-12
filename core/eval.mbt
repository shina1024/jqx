///|
/// Minimal jq evaluator (streaming outputs as Array[Json])
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
  UnknownFunction(String)
  UnknownVariable(String)
} derive(Eq)

///|
pub impl Show for EvalError with output(self, logger) {
  match self {
    TypeError(msg) => logger.write_string(msg)
    UnknownFunction(name) => logger.write_string("Unknown function: " + name)
    UnknownVariable(name) => logger.write_string("Unknown variable: $" + name)
  }
}

///|
fn json_type_name(j : Json) -> String {
  match j {
    JNull => "null"
    JTrue | JFalse => "boolean"
    Number(_, _) => "number"
    String(_) => "string"
    Array(_) => "array"
    Object(_) => "object"
  }
}

///|
fn json_type_with_value(j : Json) -> String {
  json_type_name(j) + " (" + j.to_json_string() + ")"
}

///|
fn json_number_value(n : Double) -> Json {
  Json::number(n)
}

///|
fn[T] contains_type_error(haystack : Json, needle : Json) -> T raise EvalError {
  raise TypeError(
    json_type_with_value(haystack) +
    " and " +
    json_type_with_value(needle) +
    " cannot have their containment checked",
  )
}

///|
fn contains_match(haystack : Json, needle : Json) -> Bool {
  match (haystack, needle) {
    (JNull, JNull) => true
    (JTrue, JTrue) => true
    (JFalse, JFalse) => true
    (Number(x, _), Number(y, _)) => x == y
    (String(h), String(n)) => h.contains(n)
    (Array(h), Array(n)) => {
      for needle_item in n {
        let mut found = false
        for hay_item in h {
          if contains_match(hay_item, needle_item) {
            found = true
            break
          }
        }
        if !found {
          return false
        }
      }
      true
    }
    (Object(h), Object(n)) => {
      for kv in n.iter() {
        let key = kv.0
        let needle_value = kv.1
        match h.get(key) {
          Some(hay_value) =>
            if !contains_match(hay_value, needle_value) {
              return false
            }
          None => return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn contains_checked(haystack : Json, needle : Json) -> Bool raise EvalError {
  match (haystack, needle) {
    (JTrue, JFalse) | (JFalse, JTrue) => contains_type_error(haystack, needle)
    (JNull, JNull)
    | (JTrue, JTrue)
    | (JFalse, JFalse)
    | (Number(_, _), Number(_, _))
    | (String(_), String(_))
    | (Array(_), Array(_))
    | (Object(_), Object(_)) => contains_match(haystack, needle)
    _ => contains_type_error(haystack, needle)
  }
}

///|
fn has_key(collection : Json, key : Json) -> Bool raise EvalError {
  match collection {
    JNull => false
    Object(o) =>
      match key {
        String(name) => o.contains(name)
        _ =>
          raise TypeError(
            "Cannot check whether " +
            json_type_name(collection) +
            " has a " +
            json_type_name(key) +
            " key",
          )
      }
    Array(a) =>
      match key {
        Number(n, _) =>
          if n == @double.infinity || n == @double.neg_infinity || n != n {
            false
          } else {
            let idx = n.to_int()
            idx >= 0 && idx < a.length()
          }
        _ =>
          raise TypeError(
            "Cannot check whether " +
            json_type_name(collection) +
            " has a " +
            json_type_name(key) +
            " key",
          )
      }
    _ =>
      raise TypeError(
        "Cannot check whether " +
        json_type_name(collection) +
        " has a " +
        json_type_name(key) +
        " key",
      )
  }
}

///|
fn[T] index_type_error(input : Json, key : Json) -> T raise EvalError {
  let key_desc = match key {
    String(_) => "string " + key.to_json_string()
    _ => json_type_name(key)
  }
  raise TypeError("Cannot index " + json_type_name(input) + " with " + key_desc)
}

///|
fn nth_on_input(input : Json, key : Json) -> Json raise EvalError {
  match input {
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
        _ => index_type_error(input, key)
      }
    JNull =>
      match key {
        Number(_, _) | String(_) => Json::null()
        _ => index_type_error(input, key)
      }
    _ => index_type_error(input, key)
  }
}

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

///|
fn append_recurse_values(input : Json, out : Array[Json]) -> Unit {
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
fn collection_values(input : Json) -> Array[Json] raise EvalError {
  match input {
    Array(a) => a
    Object(o) => {
      let out = []
      for kv in object_entries_sorted(o) {
        out.push(kv.1)
      }
      out
    }
    _ => raise TypeError("Cannot iterate over " + json_type_with_value(input))
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
  for {
    if start < end && is_ascii_ws(s.unsafe_get(start).to_int().unsafe_to_char()) {
      start += 1
    } else {
      break
    }
  }
  for {
    if end > start &&
      is_ascii_ws(s.unsafe_get(end - 1).to_int().unsafe_to_char()) {
      end -= 1
    } else {
      break
    }
  }
  s.view(start_offset=start, end_offset=end).to_string()
}

///|
fn fromjson_fallback_token(s : String) -> Json? {
  let t = ascii_downcase_string(trim_ascii_ws(s))
  match t {
    "nan" | "+nan" | "-nan" => Some(Json::null())
    "inf" | "+inf" | "infinity" | "+infinity" =>
      Some(Json::number(1.7976931348623157e+308))
    "-inf" | "-infinity" => Some(Json::number(-1.7976931348623157e+308))
    _ => None
  }
}

///|
fn parse_fromjson_string(s : String) -> Json raise EvalError {
  try parse(s) catch {
    err =>
      match fromjson_fallback_token(s) {
        Some(v) => v
        None =>
          raise TypeError(err.to_string() + " (while parsing '" + s + "')")
      }
  } noraise {
    j =>
      match j {
        Number(n, _) =>
          if n != n {
            Json::null()
          } else if n == @double.infinity {
            Json::number(1.7976931348623157e+308)
          } else if n == @double.neg_infinity {
            Json::number(-1.7976931348623157e+308)
          } else {
            j
          }
        _ => j
      }
  }
}

///|
fn flatten_array_full(a : Array[Json]) -> Array[Json] {
  let out = []
  for v in a {
    match v {
      Array(inner) =>
        for x in flatten_array_full(inner) {
          out.push(x)
        }
      _ => out.push(v)
    }
  }
  out
}

///|
fn flatten_array_depth(a : Array[Json], depth : Int) -> Array[Json] {
  if depth <= 0 {
    return a
  }
  let out = []
  for v in a {
    match v {
      Array(inner) =>
        if depth == 1 {
          for x in inner {
            out.push(x)
          }
        } else {
          for x in flatten_array_depth(inner, depth - 1) {
            out.push(x)
          }
        }
      _ => out.push(v)
    }
  }
  out
}

///|
fn flatten_default(input : Json) -> Json raise EvalError {
  match input {
    Array(a) => Json::array(flatten_array_full(a))
    _ => raise TypeError("Cannot iterate over " + json_type_with_value(input))
  }
}

///|
fn flatten_with_depth(input : Json, depth : Json) -> Json raise EvalError {
  match input {
    Array(a) =>
      match depth {
        Number(n, _) =>
          if n != n || n == @double.neg_infinity || n < 0.0 {
            raise TypeError("flatten depth must not be negative")
          } else if n == @double.infinity {
            Json::array(flatten_array_full(a))
          } else {
            let d = n.to_int()
            if d.to_double() == n {
              Json::array(flatten_array_depth(a, d))
            } else {
              // jq behavior: non-integer positive depths flatten fully.
              Json::array(flatten_array_full(a))
            }
          }
        String(_) =>
          raise TypeError(
            json_type_with_value(depth) + " and number (1) cannot be subtracted",
          )
        _ => raise TypeError("flatten depth must not be negative")
      }
    _ => raise TypeError("Cannot iterate over " + json_type_with_value(input))
  }
}

///|
fn transpose_row_length(row : Json) -> Int raise EvalError {
  match row {
    Array(a) => a.length()
    Object(o) => o.length()
    String(s) => s.length()
    JNull => 0
    Number(n, _) => if n == 0.0 { 0 } else { 1 }
    JTrue | JFalse =>
      raise TypeError(json_type_with_value(row) + " has no length")
  }
}

///|
fn transpose_row_index(row : Json, i : Int) -> Json raise EvalError {
  match row {
    Array(a) => if i >= 0 && i < a.length() { a[i] } else { Json::null() }
    JNull => Json::null()
    _ => index_type_error(row, Json::number(i.to_double()))
  }
}

///|
fn transpose_json(input : Json) -> Json raise EvalError {
  match input {
    Array(rows) => {
      let mut max_len = 0
      for row in rows {
        let n = transpose_row_length(row)
        if n > max_len {
          max_len = n
        }
      }
      let out = []
      for i in 0..<max_len {
        let col = []
        for row in rows {
          col.push(transpose_row_index(row, i))
        }
        out.push(Json::array(col))
      }
      Json::array(out)
    }
    _ => raise TypeError("Cannot iterate over " + json_type_with_value(input))
  }
}

///|
fn to_entries_json(input : Json) -> Json raise EvalError {
  match input {
    Object(o) => {
      let out = []
      for kv in object_entries_sorted(o) {
        out.push(Json::object({ "key": Json::string(kv.0), "value": kv.1 }))
      }
      Json::array(out)
    }
    Array(a) => {
      let out = []
      for i in 0..<a.length() {
        out.push(
          Json::object({ "key": Json::number(i.to_double()), "value": a[i] }),
        )
      }
      Json::array(out)
    }
    _ => raise TypeError(json_type_with_value(input) + " has no keys")
  }
}

///|
fn entry_key_value(entry : Json) -> (Json, Json) raise EvalError {
  match entry {
    Object(o) => {
      let key = match o.get("key") {
        Some(v) => v
        None =>
          match o.get("Key") {
            Some(v) => v
            None =>
              match o.get("name") {
                Some(v) => v
                None =>
                  match o.get("Name") {
                    Some(v) => v
                    None => Json::null()
                  }
              }
          }
      }
      let value = match o.get("value") {
        Some(v) => v
        None =>
          match o.get("Value") {
            Some(v) => v
            None => Json::null()
          }
      }
      (key, value)
    }
    _ => index_type_error(entry, Json::string("key"))
  }
}

///|
fn from_entries_json(input : Json) -> Json raise EvalError {
  match input {
    Array(a) => {
      let out = Map::new()
      for entry in a {
        let (key, value) = entry_key_value(entry)
        match key {
          String(name) => out[name] = value
          _ =>
            raise TypeError(
              "Cannot use " + json_type_with_value(key) + " as object key",
            )
        }
      }
      Json::object(out)
    }
    _ => raise TypeError("Cannot iterate over " + json_type_with_value(input))
  }
}

///|
pub fn eval(filter : Filter, input : Json) -> Array[Json] raise EvalError {
  let env = Map::new()
  eval_with_env(filter, input, env)
}

///|
fn eval_with_env(
  filter : Filter,
  input : Json,
  env : Map[String, Json],
) -> Array[Json] raise EvalError {
  match filter {
    Identity => [input]
    Literal(v) => [v]
    Field(name) =>
      match input {
        Object(o) =>
          match o.get(name) {
            Some(v) => [v]
            None => [Json::null()]
          }
        JNull => [Json::null()]
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
            None => [Json::null()]
          }
        JNull => [Json::null()]
        _ => []
      }
    Index(i) =>
      match input {
        Array(a) => {
          let idx = if i < 0 { a.length() + i } else { i }
          if idx >= 0 && idx < a.length() {
            [a[idx]]
          } else {
            [Json::null()]
          }
        }
        JNull => [Json::null()]
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
            [Json::null()]
          }
        }
        JNull => [Json::null()]
        _ => []
      }
    Slice(start, end) => eval_slice(start, end, input, optional=false)
    SliceOpt(start, end) => eval_slice(start, end, input, optional=true)
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
        None => raise UnknownVariable(name)
      }
    As(value, name, body) => {
      let out = []
      let values = eval_with_env(value, input, env)
      for v in values {
        let next_env = env.copy()
        next_env[name] = v
        for v2 in eval_with_env(body, input, next_env) {
          out.push(v2)
        }
      }
      out
    }
    Try(inner) =>
      try eval_with_env(inner, input, env) catch {
        _ => []
      } noraise {
        values => values
      }
    TryCatch(inner, handler) =>
      try eval_with_env(inner, input, env) catch {
        _ => eval_with_env(handler, input, env)
      } noraise {
        values => values
      }
    Reduce(source, name, init, update) => {
      let mut accs = eval_with_env(init, input, env)
      let items = eval_with_env(source, input, env)
      for item in items {
        let next_env = env.copy()
        next_env[name] = item
        let next_accs = []
        for acc in accs {
          for v in eval_with_env(update, acc, next_env) {
            next_accs.push(v)
          }
        }
        accs = next_accs
      }
      accs
    }
    Foreach(source, name, init, update, extract) => {
      let mut accs = eval_with_env(init, input, env)
      let items = eval_with_env(source, input, env)
      let out = []
      for item in items {
        let next_env = env.copy()
        next_env[name] = item
        let next_accs = []
        for acc in accs {
          for v in eval_with_env(update, acc, next_env) {
            next_accs.push(v)
          }
        }
        for acc in next_accs {
          for v in eval_with_env(extract, acc, next_env) {
            out.push(v)
          }
        }
        accs = next_accs
      }
      out
    }
    Pipe(left, right) => {
      let out = []
      for v in eval_with_env(left, input, env) {
        for v2 in eval_with_env(right, v, env) {
          out.push(v2)
        }
      }
      out
    }
    Comma(left, right) => {
      let out = []
      for v in eval_with_env(left, input, env) {
        out.push(v)
      }
      for v in eval_with_env(right, input, env) {
        out.push(v)
      }
      out
    }
    Array(items) => {
      let out = []
      for f in items {
        for v in eval_with_env(f, input, env) {
          out.push(v)
        }
      }
      [Json::array(out)]
    }
    Object(items) => {
      let mut partials = [Map::new()]
      for kv in items {
        let key = kv.0
        let f = kv.1
        let vals = eval_with_env(f, input, env)
        if vals.length() == 0 {
          return []
        }
        let next = []
        for partial in partials {
          for i in 0..<vals.length() {
            let v = vals[i]
            let m = partial.copy()
            m[key] = v
            next.push(m)
          }
        }
        partials = next
      }
      let out = []
      for m in partials {
        out.push(Json::object(m))
      }
      out
    }
    Builtin(name) => eval_builtin(name, input)
    Call(name, args) => eval_call(name, args, input, env)
    Eq(left, right) => {
      let l = eval_with_env(left, input, env)
      let r = eval_with_env(right, input, env)
      let out = []
      for j in 0..<r.length() {
        let b = r[j]
        for i in 0..<l.length() {
          let a = l[i]
          out.push(Json::boolean(a == b))
        }
      }
      out
    }
    Neq(left, right) => {
      let l = eval_with_env(left, input, env)
      let r = eval_with_env(right, input, env)
      let out = []
      for j in 0..<r.length() {
        let b = r[j]
        for i in 0..<l.length() {
          let a = l[i]
          out.push(Json::boolean(a != b))
        }
      }
      out
    }
    Lt(left, right) => eval_compare("<", left, right, input, env)
    Lte(left, right) => eval_compare("<=", left, right, input, env)
    Gt(left, right) => eval_compare(">", left, right, input, env)
    Gte(left, right) => eval_compare(">=", left, right, input, env)
    And(left, right) => {
      let l = eval_to_bool(left, input, env)
      if l {
        [Json::boolean(eval_to_bool(right, input, env))]
      } else {
        [Json::boolean(false)]
      }
    }
    Or(left, right) => {
      let l = eval_to_bool(left, input, env)
      if l {
        [Json::boolean(true)]
      } else {
        [Json::boolean(eval_to_bool(right, input, env))]
      }
    }
    Not(inner) => [Json::boolean(!eval_to_bool(inner, input, env))]
    Add(left, right) => eval_add(left, right, input, env)
    Sub(left, right) => eval_arith("-", left, right, input, env)
    Mul(left, right) => eval_arith("*", left, right, input, env)
    Div(left, right) => eval_arith("/", left, right, input, env)
    Mod(left, right) => eval_arith("%", left, right, input, env)
    IfElse(cond, then_branch, else_branch) =>
      if eval_to_bool(cond, input, env) {
        eval_with_env(then_branch, input, env)
      } else {
        eval_with_env(else_branch, input, env)
      }
    Fallback(left, right) => {
      let l = eval_with_env(left, input, env)
      let truthy_values = []
      for v in l {
        if is_truthy(v) {
          truthy_values.push(v)
        }
      }
      if truthy_values.length() > 0 {
        truthy_values
      } else {
        eval_with_env(right, input, env)
      }
    }
    Empty => []
  }
}

///|
fn eval_with_env_prefix(
  filter : Filter,
  input : Json,
  env : Map[String, Json],
  max_count : Int,
) -> Array[Json] raise EvalError {
  if max_count <= 0 {
    return []
  }

  let out = []
  fn collect(current : Filter, value : Json) -> Unit raise EvalError {
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
        let left_values = eval_with_env(left, value, env)
        for next in left_values {
          if out.length() >= max_count {
            break
          }
          collect(right, next)
        }
      }
      _ => {
        let values = eval_with_env(current, value, env)
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
fn is_truthy(j : Json) -> Bool {
  match j {
    JNull => false
    JFalse => false
    _ => true
  }
}

///|
fn eval_to_bool(
  filter : Filter,
  input : Json,
  env : Map[String, Json],
) -> Bool raise EvalError {
  let results = eval_with_env(filter, input, env)
  for v in results {
    if is_truthy(v) {
      return true
    }
  }
  false
}

///|
fn eval_compare(
  op : String,
  left : Filter,
  right : Filter,
  input : Json,
  env : Map[String, Json],
) -> Array[Json] raise EvalError {
  let l = eval_with_env(left, input, env)
  let r = eval_with_env(right, input, env)
  let out = []
  for j in 0..<r.length() {
    let b = r[j]
    for i in 0..<l.length() {
      let a = l[i]
      match (a, b) {
        (Number(x, _), Number(y, _)) => {
          let ok = match op {
            "<" => x < y
            "<=" => x <= y
            ">" => x > y
            _ => x >= y
          }
          out.push(Json::boolean(ok))
        }
        (String(x), String(y)) => {
          let cmp = x.compare(y)
          let ok = match op {
            "<" => cmp < 0
            "<=" => cmp <= 0
            ">" => cmp > 0
            _ => cmp >= 0
          }
          out.push(Json::boolean(ok))
        }
        _ =>
          raise TypeError(
            "Cannot compare " +
            json_type_with_value(a) +
            " and " +
            json_type_with_value(b),
          )
      }
    }
  }
  out
}

///|
fn eval_arith(
  op : String,
  left : Filter,
  right : Filter,
  input : Json,
  env : Map[String, Json],
) -> Array[Json] raise EvalError {
  let l = eval_with_env(left, input, env)
  let r = eval_with_env(right, input, env)
  let out = []
  for j in 0..<r.length() {
    let b = r[j]
    for i in 0..<l.length() {
      let a = l[i]
      match (a, b) {
        (Number(x, _), Number(y, _)) => {
          let v = match op {
            "-" => x - y
            "*" => x * y
            "%" =>
              if y == 0.0 {
                raise TypeError(
                  json_type_with_value(a) +
                  " and " +
                  json_type_with_value(b) +
                  " cannot be divided because the divisor is zero",
                )
              } else {
                x.mod(y)
              }
            _ =>
              if y == 0.0 {
                raise TypeError(
                  json_type_with_value(a) +
                  " and " +
                  json_type_with_value(b) +
                  " cannot be divided because the divisor is zero",
                )
              } else {
                x / y
              }
          }
          out.push(json_number_value(v))
        }
        (String(s), Number(n, _)) =>
          if op == "*" {
            out.push(eval_mul_string_number(s, n))
          } else {
            raise TypeError(
              "Cannot apply " +
              op +
              " to " +
              json_type_with_value(a) +
              " and " +
              json_type_with_value(b),
            )
          }
        (Number(n, _), String(s)) =>
          if op == "*" {
            out.push(eval_mul_string_number(s, n))
          } else {
            raise TypeError(
              "Cannot apply " +
              op +
              " to " +
              json_type_with_value(a) +
              " and " +
              json_type_with_value(b),
            )
          }
        (Object(x), Object(y)) =>
          if op == "*" {
            out.push(Json::object(merge_objects_recursive(x, y)))
          } else {
            raise TypeError(
              "Cannot apply " +
              op +
              " to " +
              json_type_with_value(a) +
              " and " +
              json_type_with_value(b),
            )
          }
        (Array(x), Array(y)) =>
          if op == "-" {
            let filtered = []
            for xv in x {
              let mut removed = false
              for yv in y {
                if xv == yv {
                  removed = true
                  break
                }
              }
              if !removed {
                filtered.push(xv)
              }
            }
            out.push(Json::array(filtered))
          } else {
            raise TypeError(
              "Cannot apply " +
              op +
              " to " +
              json_type_with_value(a) +
              " and " +
              json_type_with_value(b),
            )
          }
        _ =>
          raise TypeError(
            "Cannot apply " +
            op +
            " to " +
            json_type_with_value(a) +
            " and " +
            json_type_with_value(b),
          )
      }
    }
  }
  out
}

///|
fn eval_mul_string_number(s : String, n : Double) -> Json raise EvalError {
  if n != n || n < 0.0 || n == @double.neg_infinity {
    return Json::null()
  }
  if s.length() == 0 {
    return Json::string("")
  }
  if n == @double.infinity {
    raise TypeError("Repeat string result too long")
  }
  if n > 2147483647.0 {
    raise TypeError("Repeat string result too long")
  }
  let count = n.to_int()
  if count <= 0 {
    return Json::string("")
  }
  let max_result_len = 16777216
  if count > max_result_len / s.length() {
    raise TypeError("Repeat string result too long")
  }
  let buf = StringBuilder::new()
  for _ in 0..<count {
    buf.write_string(s)
  }
  Json::string(buf.to_string())
}

///|
fn merge_objects_recursive(
  left : Map[String, Json],
  right : Map[String, Json],
) -> Map[String, Json] {
  let merged = Map::new()
  for kv in left.iter() {
    merged[kv.0] = kv.1
  }
  for kv in right.iter() {
    let key = kv.0
    let right_value = kv.1
    match (merged.get(key), right_value) {
      (Some(Object(left_obj)), Object(right_obj)) =>
        merged[key] = Json::object(merge_objects_recursive(left_obj, right_obj))
      _ => merged[key] = right_value
    }
  }
  merged
}

///|
fn eval_add(
  left : Filter,
  right : Filter,
  input : Json,
  env : Map[String, Json],
) -> Array[Json] raise EvalError {
  let l = eval_with_env(left, input, env)
  let r = eval_with_env(right, input, env)
  let out = []
  for j in 0..<r.length() {
    let b = r[j]
    for i in 0..<l.length() {
      let a = l[i]
      out.push(json_add_pair(a, b))
    }
  }
  out
}

///|
fn eval_join(a : Array[Json], sep : Json) -> Json raise EvalError {
  let mut acc = Json::string("")
  for i in 0..<a.length() {
    if i > 0 {
      acc = json_add_pair(acc, sep)
    }
    acc = json_add_pair(acc, join_item(a[i]))
  }
  acc
}

///|
fn split_string(s : String, sep : String) -> Array[Json] {
  if s.length() == 0 {
    return []
  }
  if sep.length() == 0 {
    let out = []
    for ch in s {
      out.push(Json::string(char_to_string(ch)))
    }
    return out
  }
  let out = []
  let mut start = 0
  let sep_len = sep.length()
  for {
    let rest = s.view(start_offset=start)
    match rest.find(sep) {
      Some(i) => {
        out.push(
          Json::string(
            s.view(start_offset=start, end_offset=start + i).to_string(),
          ),
        )
        start = start + i + sep_len
        continue
      }
      None => {
        out.push(Json::string(s.view(start_offset=start).to_string()))
        return out
      }
    }
  }
}

///|
fn json_sort_rank(j : Json) -> Int {
  match j {
    JNull => 0
    JFalse => 1
    JTrue => 2
    Number(_, _) => 3
    String(_) => 4
    Array(_) => 5
    Object(_) => 6
  }
}

///|
fn compare_string_arrays(a : Array[String], b : Array[String]) -> Int {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let c = a[i].compare(b[i])
    if c != 0 {
      return c
    }
  }
  if a.length() < b.length() {
    -1
  } else if a.length() > b.length() {
    1
  } else {
    0
  }
}

///|
fn compare_json(a : Json, b : Json) -> Int {
  let ra = json_sort_rank(a)
  let rb = json_sort_rank(b)
  if ra < rb {
    return -1
  }
  if ra > rb {
    return 1
  }
  match (a, b) {
    (JNull, JNull) | (JFalse, JFalse) | (JTrue, JTrue) => 0
    (Number(x, _), Number(y, _)) =>
      if x < y {
        -1
      } else if x > y {
        1
      } else {
        0
      }
    (String(x), String(y)) => x.compare(y)
    (Array(x), Array(y)) => {
      let n = if x.length() < y.length() { x.length() } else { y.length() }
      for i in 0..<n {
        let c = compare_json(x[i], y[i])
        if c != 0 {
          return c
        }
      }
      if x.length() < y.length() {
        -1
      } else if x.length() > y.length() {
        1
      } else {
        0
      }
    }
    (Object(x), Object(y)) => {
      let kx = Array::from_iter(x.keys())
      let ky = Array::from_iter(y.keys())
      kx.sort()
      ky.sort()
      let key_cmp = compare_string_arrays(kx, ky)
      if key_cmp != 0 {
        return key_cmp
      }
      for key in kx {
        let vx = match x.get(key) {
          Some(v) => v
          None => Json::null()
        }
        let vy = match y.get(key) {
          Some(v) => v
          None => Json::null()
        }
        let c = compare_json(vx, vy)
        if c != 0 {
          return c
        }
      }
      0
    }
    _ => 0
  }
}

///|
fn sort_json_array(a : Array[Json]) -> Array[Json] {
  let mut sorted = []
  for v in a {
    let mut inserted = false
    let next = []
    for cur in sorted {
      if !inserted && compare_json(v, cur) < 0 {
        next.push(v)
        inserted = true
      }
      next.push(cur)
    }
    if !inserted {
      next.push(v)
    }
    sorted = next
  }
  sorted
}

///|
fn min_json_array(a : Array[Json]) -> Json {
  if a.length() == 0 {
    return Json::null()
  }
  let mut best = a[0]
  for i in 1..<a.length() {
    if compare_json(a[i], best) < 0 {
      best = a[i]
    }
  }
  best
}

///|
fn max_json_array(a : Array[Json]) -> Json {
  if a.length() == 0 {
    return Json::null()
  }
  let mut best = a[0]
  for i in 1..<a.length() {
    if compare_json(a[i], best) > 0 {
      best = a[i]
    }
  }
  best
}

///|
fn minmax_by_json_array(
  a : Array[Json],
  key_filter : Filter,
  env : Map[String, Json],
  choose_max~ : Bool,
) -> Json raise EvalError {
  if a.length() == 0 {
    return Json::null()
  }
  let mut best_value = a[0]
  let first_keys = eval_with_env(key_filter, best_value, env)
  let mut best_key = if first_keys.length() == 0 {
    Json::null()
  } else {
    first_keys[0]
  }
  for i in 1..<a.length() {
    let v = a[i]
    let keys = eval_with_env(key_filter, v, env)
    let key = if keys.length() == 0 { Json::null() } else { keys[0] }
    let cmp = compare_json(key, best_key)
    if choose_max {
      if cmp >= 0 {
        best_value = v
        best_key = key
      }
    } else if cmp < 0 {
      best_value = v
      best_key = key
    }
  }
  best_value
}

///|
fn unique_sorted_json_array(a : Array[Json]) -> Array[Json] {
  let out = []
  let mut prev = Json::null()
  let mut has_prev = false
  for v in a {
    if !has_prev || compare_json(prev, v) != 0 {
      out.push(v)
      prev = v
      has_prev = true
    }
  }
  out
}

///|
fn sort_keyed_pairs(items : Array[(Json, Json)]) -> Array[(Json, Json)] {
  let mut sorted : Array[(Json, Json)] = []
  for item in items {
    let mut inserted = false
    let next : Array[(Json, Json)] = []
    for cur in sorted {
      if !inserted && compare_json(item.0, cur.0) < 0 {
        next.push(item)
        inserted = true
      }
      next.push(cur)
    }
    if !inserted {
      next.push(item)
    }
    sorted = next
  }
  sorted
}

///|
fn bsearch_json_array(a : Array[Json], needle : Json) -> Int {
  let mut lo = 0
  let mut hi = a.length()
  for {
    if lo >= hi {
      break
    }
    let mid = (lo + hi) / 2
    let cmp = compare_json(a[mid], needle)
    if cmp < 0 {
      lo = mid + 1
    } else if cmp > 0 {
      hi = mid
    } else {
      return mid
    }
  }
  -(lo + 1)
}

///|
fn find_string_indices(haystack : String, pattern : String) -> Array[Int] {
  if pattern.length() == 0 {
    return []
  }
  let out = []
  let mut start = 0
  for {
    let rest = haystack.view(start_offset=start)
    match rest.find(pattern) {
      Some(i) => {
        let found = start + i
        out.push(found)
        start = found + 1
        continue
      }
      None => return out
    }
  }
}

///|
fn find_array_indices(haystack : Array[Json], pattern : Json) -> Array[Int] {
  match pattern {
    Array(needle) => {
      let n = needle.length()
      if n == 0 || n > haystack.length() {
        return []
      }
      let out = []
      for i in 0..<(haystack.length() - n + 1) {
        let mut matched = true
        for j in 0..<n {
          if haystack[i + j] != needle[j] {
            matched = false
            break
          }
        }
        if matched {
          out.push(i)
        }
      }
      out
    }
    _ => {
      let out = []
      for i in 0..<haystack.length() {
        if haystack[i] == pattern {
          out.push(i)
        }
      }
      out
    }
  }
}

///|
fn char_to_string(ch : Char) -> String {
  let buf = StringBuilder::new()
  buf.write_char(ch)
  buf.to_string()
}

///|
fn explode_string(s : String) -> Array[Json] {
  let out = []
  for ch in s {
    out.push(Json::number(ch.to_int().to_double()))
  }
  out
}

///|
fn implode_array(a : Array[Json]) -> String raise EvalError {
  let buf = StringBuilder::new()
  for v in a {
    match v {
      Number(n, _) => {
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
fn join_item(v : Json) -> Json {
  match v {
    String(_) => v
    Number(n, repr) => Json::string(Json::number(n, repr?).to_json_string())
    JTrue => Json::string("true")
    JFalse => Json::string("false")
    JNull => Json::string("")
    _ => v
  }
}

///|
fn json_add_pair(a : Json, b : Json) -> Json raise EvalError {
  match (a, b) {
    (JNull, x) => x
    (x, JNull) => x
    (Number(x, _), Number(y, _)) => json_number_value(x + y)
    (String(x), String(y)) => Json::string(x + y)
    (Array(x), Array(y)) => {
      let merged = x.copy()
      for v in y {
        merged.push(v)
      }
      Json::array(merged)
    }
    (Object(x), Object(y)) => {
      let merged = Map::new()
      for kv in x.iter() {
        merged[kv.0] = kv.1
      }
      for kv in y.iter() {
        merged[kv.0] = kv.1
      }
      Json::object(merged)
    }
    _ =>
      raise TypeError(
        json_type_with_value(a) +
        " and " +
        json_type_with_value(b) +
        " cannot be added",
      )
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
fn eval_slice_array(a : Array[Json], start : Int?, end : Int?) -> Array[Json] {
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
  a : Array[Json],
  start : Int?,
  end : Int?,
  replacement : Array[Json],
) -> Array[Json] {
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
  input : Json,
  start : Int?,
  end : Int?,
  value : Json,
) -> Json raise EvalError {
  let replacement = match value {
    Array(a) => a
    _ =>
      raise TypeError("A slice of an array can only be assigned another array")
  }
  match input {
    Array(a) => Json::array(set_slice_array(a, start, end, replacement))
    JNull => Json::array(set_slice_array([], start, end, replacement))
    String(_) => raise TypeError("Cannot update string slices")
    _ => index_type_error(input, Json::object(Map::new()))
  }
}

///|
fn eval_slice_string(s : String, start : Int?, end : Int?) -> String {
  let len = s.length()
  let lo = normalize_slice_index(start, len, 0)
  let hi = normalize_slice_index(end, len, len)
  if hi <= lo {
    ""
  } else {
    s.view(start_offset=lo, end_offset=hi).to_string()
  }
}

///|
fn eval_slice(
  start : Int?,
  end : Int?,
  input : Json,
  optional~ : Bool,
) -> Array[Json] raise EvalError {
  match input {
    Array(a) => [Json::array(eval_slice_array(a, start, end))]
    String(s) => [Json::string(eval_slice_string(s, start, end))]
    JNull => [Json::null()]
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
