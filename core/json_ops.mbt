///|
fn json_type_name(j : Value) -> String {
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
fn json_type_with_value(j : Value) -> String {
  json_type_name(j) + " (" + j.to_json_string() + ")"
}

///|
fn json_value_preview(s : String) -> String {
  let max_preview = 26
  if s.length() <= max_preview {
    return s
  }
  let mut cut = max_preview
  for i in 0..<max_preview {
    match s.unsafe_get(i) {
      '{' | '[' | ',' => cut = i + 1
      _ => ()
    }
  }
  if cut <= 0 {
    cut = max_preview
  }
  s.view(start_offset=0, end_offset=cut).to_owned() + "..."
}

///|
fn json_type_with_value_preview(j : Value) -> String {
  match j {
    Number(_, _) | Object(_) | Array(_) =>
      json_type_name(j) + " (" + json_value_preview(j.to_json_string()) + ")"
    _ => json_type_with_value(j)
  }
}

///|
fn json_number_value(n : Double) -> Value {
  Value::number(n)
}

///|
fn json_number_negated_value(n : Double, repr : String?) -> Value {
  match repr {
    Some(s) =>
      match decimal_negated_repr(s) {
        Some(next_repr) => Value::number(-n, repr=next_repr)
        None => Value::number(-n)
      }
    None => Value::number(-n)
  }
}

///|
fn json_number_abs_value(n : Double, repr : String?) -> Value {
  match repr {
    Some(s) =>
      match decimal_abs_repr(s) {
        Some(next_repr) => Value::number(builtin_fabs_number(n), repr=next_repr)
        None => json_number_value(builtin_fabs_number(n))
      }
    None => json_number_value(builtin_fabs_number(n))
  }
}

///|
fn[T] contains_type_error(
  haystack : Value,
  needle : Value,
) -> T raise EvalError {
  raise TypeError(
    json_type_with_value(haystack) +
    " and " +
    json_type_with_value(needle) +
    " cannot have their containment checked",
  )
}

///|
priv enum ContainsTask {
  CheckContains(Value, Value, Int)
  ResumeArrayContains(Array[Value], Array[Value], Int, Int, Int)
  ResumeObjectContains(JsonObject, Array[(String, Value)], Int, Int)
}

///|
fn contains_match(haystack : Value, needle : Value) -> Bool raise EvalError {
  let pending : Array[ContainsTask] = [CheckContains(haystack, needle, 0)]
  let mut last_result = false
  while pending.length() > 0 {
    match pending.pop().unwrap() {
      CheckContains(haystack, needle, depth) => {
        if depth > 10000 {
          raise TypeError("Containment check too deep")
        }
        match (haystack, needle) {
          (JNull, JNull) | (JTrue, JTrue) | (JFalse, JFalse) =>
            last_result = true
          (Number(x, rx), Number(y, ry)) =>
            last_result = match (rx, ry) {
              (Some(a), Some(b)) =>
                match decimal_compare_repr(a, b) {
                  Some(cmp) => cmp == 0
                  None => x == y
                }
              _ => x == y
            }
          (String(h), String(n)) => last_result = h.contains(n)
          (Array(h), Array(n)) =>
            if n.length() == 0 {
              last_result = true
            } else if h.length() == 0 {
              last_result = false
            } else {
              pending.push(ResumeArrayContains(h, n, 0, 0, depth))
              pending.push(CheckContains(h[0], n[0], depth + 1))
            }
          (Object(h), Object(n)) => {
            let entries = n.iter()
            if entries.length() == 0 {
              last_result = true
            } else {
              match h.get(entries[0].0) {
                Some(value) => {
                  pending.push(ResumeObjectContains(h, entries, 0, depth))
                  pending.push(CheckContains(value, entries[0].1, depth + 1))
                }
                None => last_result = false
              }
            }
          }
          _ => last_result = false
        }
      }
      ResumeArrayContains(haystack, needle, needle_index, haystack_index, depth) =>
        if last_result {
          let next_needle = needle_index + 1
          if next_needle >= needle.length() {
            last_result = true
          } else {
            pending.push(
              ResumeArrayContains(haystack, needle, next_needle, 0, depth),
            )
            pending.push(
              CheckContains(haystack[0], needle[next_needle], depth + 1),
            )
          }
        } else {
          let next_haystack = haystack_index + 1
          if next_haystack >= haystack.length() {
            last_result = false
          } else {
            pending.push(
              ResumeArrayContains(
                haystack, needle, needle_index, next_haystack, depth,
              ),
            )
            pending.push(
              CheckContains(
                haystack[next_haystack],
                needle[needle_index],
                depth + 1,
              ),
            )
          }
        }
      ResumeObjectContains(haystack, entries, index, depth) =>
        if last_result {
          let next_index = index + 1
          if next_index >= entries.length() {
            last_result = true
          } else {
            match haystack.get(entries[next_index].0) {
              Some(value) => {
                pending.push(
                  ResumeObjectContains(haystack, entries, next_index, depth),
                )
                pending.push(
                  CheckContains(value, entries[next_index].1, depth + 1),
                )
              }
              None => last_result = false
            }
          }
        }
    }
  }
  last_result
}

///|
fn contains_checked(haystack : Value, needle : Value) -> Bool raise EvalError {
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
fn has_key(collection : Value, key : Value) -> Bool raise EvalError {
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
fn[T] index_type_error(input : Value, key : Value) -> T raise EvalError {
  let key_desc = match key {
    String(_) => "string (" + key.to_json_string() + ")"
    Number(_, _) => "number (" + key.to_json_string() + ")"
    _ => json_type_name(key)
  }
  raise TypeError("Cannot index " + json_type_name(input) + " with " + key_desc)
}

///|
fn nth_on_input(input : Value, key : Value) -> Value raise EvalError {
  match input {
    Array(a) =>
      match key {
        Number(n, _) =>
          if n != n || n == @double.infinity || n == @double.neg_infinity {
            Value::null()
          } else {
            let i = n.to_int()
            let idx = if i < 0 { a.length() + i } else { i }
            if idx >= 0 && idx < a.length() {
              a[idx]
            } else {
              Value::null()
            }
          }
        _ => index_type_error(input, key)
      }
    JNull =>
      match key {
        Number(_, _) | String(_) => Value::null()
        _ => index_type_error(input, key)
      }
    _ => index_type_error(input, key)
  }
}

///|
fn is_truthy(j : Value) -> Bool {
  match j {
    JNull => false
    JFalse => false
    _ => true
  }
}

///|
fn execute_to_bool(
  runtime : RuntimeContext,
  filter : Filter,
  input : Value,
  env : Map[String, Value],
) -> Bool raise EvalError {
  let results = execute_with_runtime(runtime, filter, input, env)
  for v in results {
    if is_truthy(v) {
      return true
    }
  }
  false
}

///|
fn compare_ok(op : String, cmp : Int) -> Bool {
  match op {
    "<" => cmp < 0
    "<=" => cmp <= 0
    ">" => cmp > 0
    _ => cmp >= 0
  }
}

///|
fn execute_compare(
  runtime : RuntimeContext,
  op : String,
  left : Filter,
  right : Filter,
  input : Value,
  env : Map[String, Value],
) -> Array[Value] raise EvalError {
  let l = execute_with_runtime(runtime, left, input, env)
  let r = execute_with_runtime(runtime, right, input, env)
  let out = []
  for j in 0..<r.length() {
    let b = r[j]
    for i in 0..<l.length() {
      let a = l[i]
      match (a, b) {
        (Number(x, rx), Number(y, ry)) => {
          let decimal_cmp = match (rx, ry) {
            (Some(a), Some(b)) => decimal_compare_repr(a, b)
            _ => None
          }
          let ok = match (op, decimal_cmp) {
            ("<", Some(cmp)) => cmp < 0
            ("<=", Some(cmp)) => cmp <= 0
            (">", Some(cmp)) => cmp > 0
            (_, Some(cmp)) => cmp >= 0
            ("<", None) => x < y
            ("<=", None) => x <= y
            (">", None) => x > y
            _ => x >= y
          }
          out.push(Value::boolean(ok))
        }
        _ => out.push(Value::boolean(compare_ok(op, compare_json(a, b))))
      }
    }
  }
  out
}

///|
fn arith_operand_desc(op : String, value : Value) -> String {
  match (op, value) {
    ("-", String(s)) => format_filter_string_type_with_preview(s)
    (_, Object(_) | Array(_)) => json_type_with_value_preview(value)
    _ => json_type_with_value(value)
  }
}

///|
fn arith_type_error_message(op : String, left : Value, right : Value) -> String {
  let l = arith_operand_desc(op, left)
  let r = arith_operand_desc(op, right)
  match op {
    "-" => l + " and " + r + " cannot be subtracted"
    "/" => l + " and " + r + " cannot be divided"
    "%" => l + " and " + r + " cannot be divided (remainder)"
    "*" => l + " and " + r + " cannot be multiplied"
    _ => "Cannot apply " + op + " to " + l + " and " + r
  }
}

///|
fn execute_arith(
  runtime : RuntimeContext,
  op : String,
  left : Filter,
  right : Filter,
  input : Value,
  env : Map[String, Value],
) -> Array[Value] raise EvalError {
  let l = execute_with_runtime(runtime, left, input, env)
  let r = execute_with_runtime(runtime, right, input, env)
  let out = []
  for j in 0..<r.length() {
    let b = r[j]
    for i in 0..<l.length() {
      let a = l[i]
      match (a, b) {
        (Number(x, _), Number(y, _)) => {
          fn modulo_operand(n : Double) -> Double {
            if n == @double.infinity {
              9223372036854775807.0
            } else if n == @double.neg_infinity {
              -9223372036854775808.0
            } else {
              n
            }
          }
          let v = match op {
            "-" => x - y
            "*" => x * y
            "%" => {
              let mx = modulo_operand(x)
              let my = modulo_operand(y)
              if my == 0.0 {
                raise TypeError(
                  json_type_with_value(a) +
                  " and " +
                  json_type_with_value(b) +
                  " cannot be divided (remainder) because the divisor is zero",
                )
              } else if x == @double.neg_infinity && y == @double.infinity {
                -1.0
              } else {
                mx.mod(my)
              }
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
            out.push(Value::array(split_string(s, sep)))
          } else {
            raise TypeError(arith_type_error_message(op, a, b))
          }
        (String(s), Number(n, _)) =>
          if op == "*" {
            out.push(multiply_string_number(s, n))
          } else {
            raise TypeError(arith_type_error_message(op, a, b))
          }
        (Number(n, _), String(s)) =>
          if op == "*" {
            out.push(multiply_string_number(s, n))
          } else {
            raise TypeError(arith_type_error_message(op, a, b))
          }
        (Object(x), Object(y)) =>
          if op == "*" {
            out.push(Object(merge_objects_recursive(x, y)))
          } else {
            raise TypeError(arith_type_error_message(op, a, b))
          }
        (Array(x), Array(y)) =>
          if op == "-" {
            let filtered = []
            for xv in x {
              let mut removed = false
              for yv in y {
                if json_equal_checked(xv, yv) {
                  removed = true
                  break
                }
              }
              if !removed {
                filtered.push(xv)
              }
            }
            out.push(Value::array(filtered))
          } else {
            raise TypeError(arith_type_error_message(op, a, b))
          }
        _ => raise TypeError(arith_type_error_message(op, a, b))
      }
    }
  }
  out
}

///|
fn multiply_string_number(s : String, n : Double) -> Value raise EvalError {
  if n != n || n < 0.0 || n == @double.neg_infinity {
    return Value::null()
  }
  if s.length() == 0 {
    return Value::string("")
  }
  if n == @double.infinity {
    raise TypeError("Repeat string result too long")
  }
  if n > 2147483647.0 {
    raise TypeError("Repeat string result too long")
  }
  let count = n.to_int()
  if count <= 0 {
    return Value::string("")
  }
  let max_result_len = 16777216
  if count > max_result_len / s.length() {
    raise TypeError("Repeat string result too long")
  }
  let buf = StringBuilder()
  for _ in 0..<count {
    buf.write_string(s)
  }
  Value::string(buf.to_string())
}

///|
priv struct ObjectMergeState {
  merged : Map[String, Value]
  merged_order : Array[String]
  entries : Array[(String, Value)]
  index : Int
  depth : Int
}

///|
priv enum ObjectMergeTask {
  StartObjectMerge(JsonObject, JsonObject, Int)
  ProcessObjectMerge(ObjectMergeState)
  StoreMergedObject(ObjectMergeState, String)
}

///|
fn merge_objects_recursive(
  left : JsonObject,
  right : JsonObject,
) -> JsonObject raise EvalError {
  let pending : Array[ObjectMergeTask] = [StartObjectMerge(left, right, 0)]
  let mut last_result : JsonObject? = None
  while pending.length() > 0 {
    match pending.pop().unwrap() {
      StartObjectMerge(left, right, depth) => {
        if depth > 10000 {
          raise TypeError("Object merge too deep")
        }
        pending.push(
          ProcessObjectMerge({
            merged: left.to_map().copy(),
            merged_order: left.keys(),
            entries: right.iter(),
            index: 0,
            depth,
          }),
        )
      }
      ProcessObjectMerge(state) =>
        if state.index >= state.entries.length() {
          last_result = Some(
            JsonObject::with_order(state.merged, state.merged_order),
          )
        } else {
          let entry = state.entries[state.index]
          let key = entry.0
          let right_value = entry.1
          if !state.merged.contains(key) {
            state.merged_order.push(key)
          }
          let next_state = {
            merged: state.merged,
            merged_order: state.merged_order,
            entries: state.entries,
            index: state.index + 1,
            depth: state.depth,
          }
          match (state.merged.get(key), right_value) {
            (Some(Object(left_obj)), Object(right_obj)) => {
              pending.push(StoreMergedObject(next_state, key))
              pending.push(
                StartObjectMerge(left_obj, right_obj, state.depth + 1),
              )
            }
            _ => {
              state.merged[key] = right_value
              pending.push(ProcessObjectMerge(next_state))
            }
          }
        }
      StoreMergedObject(state, key) => {
        state.merged[key] = Object(last_result.unwrap())
        pending.push(ProcessObjectMerge(state))
      }
    }
  }
  last_result.unwrap()
}

///|
fn execute_add(
  runtime : RuntimeContext,
  left : Filter,
  right : Filter,
  input : Value,
  env : Map[String, Value],
) -> Array[Value] raise EvalError {
  let l = execute_with_runtime(runtime, left, input, env)
  let r = execute_with_runtime(runtime, right, input, env)
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
fn json_add_pair(a : Value, b : Value) -> Value raise EvalError {
  match (a, b) {
    (JNull, x) => x
    (x, JNull) => x
    (Number(x, _), Number(y, _)) => json_number_value(x + y)
    (String(x), String(y)) => Value::string(x + y)
    (Array(x), Array(y)) => {
      let merged = x.copy()
      for v in y {
        merged.push(v)
      }
      Value::array(merged)
    }
    (Object(x), Object(y)) => {
      let merged = x.to_map().copy()
      let merged_order = x.keys()
      for kv in y.iter() {
        if !merged.contains(kv.0) {
          merged_order.push(kv.0)
        }
        merged[kv.0] = kv.1
      }
      Value::object_with_order(merged, merged_order)
    }
    _ =>
      raise TypeError(
        json_type_with_value_preview(a) +
        " and " +
        json_type_with_value_preview(b) +
        " cannot be added",
      )
  }
}
