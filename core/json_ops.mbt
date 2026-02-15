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
        Number(n, _) =>
          if n != n || n == @double.infinity || n == @double.neg_infinity {
            Json::null()
          } else {
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
fn is_truthy(j : Json) -> Bool {
  match j {
    JNull => false
    JFalse => false
    _ => true
  }
}

///|
fn execute_to_bool(
  filter : Filter,
  input : Json,
  env : Map[String, Json],
) -> Bool raise EvalError {
  let results = execute_with_env(filter, input, env)
  for v in results {
    if is_truthy(v) {
      return true
    }
  }
  false
}

///|
fn execute_compare(
  op : String,
  left : Filter,
  right : Filter,
  input : Json,
  env : Map[String, Json],
) -> Array[Json] raise EvalError {
  let l = execute_with_env(left, input, env)
  let r = execute_with_env(right, input, env)
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
fn execute_arith(
  op : String,
  left : Filter,
  right : Filter,
  input : Json,
  env : Map[String, Json],
) -> Array[Json] raise EvalError {
  let l = execute_with_env(left, input, env)
  let r = execute_with_env(right, input, env)
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
        (String(s), String(sep)) =>
          if op == "/" {
            out.push(Json::array(split_string(s, sep)))
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
        (String(s), Number(n, _)) =>
          if op == "*" {
            out.push(multiply_string_number(s, n))
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
            out.push(multiply_string_number(s, n))
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
fn multiply_string_number(s : String, n : Double) -> Json raise EvalError {
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
fn execute_add(
  left : Filter,
  right : Filter,
  input : Json,
  env : Map[String, Json],
) -> Array[Json] raise EvalError {
  let l = execute_with_env(left, input, env)
  let r = execute_with_env(right, input, env)
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
