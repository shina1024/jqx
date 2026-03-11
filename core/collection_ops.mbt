///|
fn collection_values(input : Value) -> Array[Value] raise EvalError {
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
fn flatten_array_full(a : Array[Value]) -> Array[Value] {
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
fn flatten_array_depth(a : Array[Value], depth : Int) -> Array[Value] {
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
fn flatten_default(input : Value) -> Value raise EvalError {
  match input {
    Array(a) => Value::array(flatten_array_full(a))
    _ => raise TypeError("Cannot iterate over " + json_type_with_value(input))
  }
}

///|
fn flatten_with_depth(input : Value, depth : Value) -> Value raise EvalError {
  match input {
    Array(a) =>
      match depth {
        Number(n, _) =>
          if n != n || n == @double.neg_infinity || n < 0.0 {
            raise TypeError("flatten depth must not be negative")
          } else if n == @double.infinity {
            Value::array(flatten_array_full(a))
          } else {
            let d = n.to_int()
            if d.to_double() == n {
              Value::array(flatten_array_depth(a, d))
            } else {
              // jq behavior: non-integer positive depths flatten fully.
              Value::array(flatten_array_full(a))
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
fn transpose_row_length(row : Value) -> Int raise EvalError {
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
fn transpose_row_index(row : Value, i : Int) -> Value raise EvalError {
  match row {
    Array(a) => if i >= 0 && i < a.length() { a[i] } else { Value::null() }
    JNull => Value::null()
    _ => index_type_error(row, Value::number(i.to_double()))
  }
}

///|
fn transpose_json(input : Value) -> Value raise EvalError {
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
        out.push(Value::array(col))
      }
      Value::array(out)
    }
    _ => raise TypeError("Cannot iterate over " + json_type_with_value(input))
  }
}

///|
fn to_entries_json(input : Value) -> Value raise EvalError {
  match input {
    Object(o) => {
      let out = []
      for kv in object_entries_sorted(o) {
        out.push(
          Value::object_from_entries([
            ("key", Value::string(kv.0)),
            ("value", kv.1),
          ]),
        )
      }
      Value::array(out)
    }
    Array(a) => {
      let out = []
      for i in 0..<a.length() {
        out.push(
          Value::object_from_entries([
            ("key", Value::number(i.to_double())),
            ("value", a[i]),
          ]),
        )
      }
      Value::array(out)
    }
    _ => raise TypeError(json_type_with_value(input) + " has no keys")
  }
}

///|
fn entry_key_value(entry : Value) -> (Value, Value) raise EvalError {
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
                    None => Value::null()
                  }
              }
          }
      }
      let value = match o.get("value") {
        Some(v) => v
        None =>
          match o.get("Value") {
            Some(v) => v
            None => Value::null()
          }
      }
      (key, value)
    }
    _ => index_type_error(entry, Value::string("key"))
  }
}

///|
fn from_entries_json(input : Value) -> Value raise EvalError {
  match input {
    Array(a) => {
      let out = Map::new()
      let out_order = []
      for entry in a {
        let (key, value) = entry_key_value(entry)
        match key {
          String(name) => {
            if !out.contains(name) {
              out_order.push(name)
            }
            out[name] = value
          }
          _ =>
            raise TypeError(
              "Cannot use " + json_type_with_value(key) + " as object key",
            )
        }
      }
      Value::object_with_order(out, out_order)
    }
    _ => raise TypeError("Cannot iterate over " + json_type_with_value(input))
  }
}

///|
fn json_sort_rank(j : Value) -> Int {
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
fn compare_json(a : Value, b : Value) -> Int {
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
      let kx = x.lex_key_order
      let ky = y.lex_key_order
      let key_cmp = compare_string_arrays(kx, ky)
      if key_cmp != 0 {
        return key_cmp
      }
      for key in kx {
        let vx = match x.get(key) {
          Some(v) => v
          None => Value::null()
        }
        let vy = match y.get(key) {
          Some(v) => v
          None => Value::null()
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
fn sort_json_array(a : Array[Value]) -> Array[Value] {
  fn merge_sorted_json(
    left : Array[Value],
    right : Array[Value],
  ) -> Array[Value] {
    let merged = []
    let mut i = 0
    let mut j = 0
    while i < left.length() && j < right.length() {
      if compare_json(left[i], right[j]) <= 0 {
        merged.push(left[i])
        i += 1
      } else {
        merged.push(right[j])
        j += 1
      }
    }
    for k in i..<left.length() {
      merged.push(left[k])
    }
    for k in j..<right.length() {
      merged.push(right[k])
    }
    merged
  }

  let n = a.length()
  if n <= 1 {
    return a.copy()
  }
  let mid = n / 2
  let left = []
  let right = []
  for i in 0..<mid {
    left.push(a[i])
  }
  for i in mid..<n {
    right.push(a[i])
  }
  merge_sorted_json(sort_json_array(left), sort_json_array(right))
}

///|
fn min_json_array(a : Array[Value]) -> Value {
  if a.length() == 0 {
    return Value::null()
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
fn max_json_array(a : Array[Value]) -> Value {
  if a.length() == 0 {
    return Value::null()
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
  a : Array[Value],
  key_filter : Filter,
  env : Map[String, Value],
  choose_max~ : Bool,
) -> Value raise EvalError {
  if a.length() == 0 {
    return Value::null()
  }
  fn key_for(value : Value) -> Value raise EvalError {
    Value::array(execute_with_env(key_filter, value, env))
  }
  let mut best_value = a[0]
  let mut best_key = key_for(best_value)
  for i in 1..<a.length() {
    let v = a[i]
    let key = key_for(v)
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
fn unique_sorted_json_array(a : Array[Value]) -> Array[Value] {
  let out = []
  let mut prev = Value::null()
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
fn sort_keyed_pairs(items : Array[(Value, Value)]) -> Array[(Value, Value)] {
  fn merge_sorted_pairs(
    left : Array[(Value, Value)],
    right : Array[(Value, Value)],
  ) -> Array[(Value, Value)] {
    let merged : Array[(Value, Value)] = []
    let mut i = 0
    let mut j = 0
    while i < left.length() && j < right.length() {
      if compare_json(left[i].0, right[j].0) <= 0 {
        merged.push(left[i])
        i += 1
      } else {
        merged.push(right[j])
        j += 1
      }
    }
    for k in i..<left.length() {
      merged.push(left[k])
    }
    for k in j..<right.length() {
      merged.push(right[k])
    }
    merged
  }

  let n = items.length()
  if n <= 1 {
    return items.copy()
  }
  let mid = n / 2
  let left : Array[(Value, Value)] = []
  let right : Array[(Value, Value)] = []
  for i in 0..<mid {
    left.push(items[i])
  }
  for i in mid..<n {
    right.push(items[i])
  }
  merge_sorted_pairs(sort_keyed_pairs(left), sort_keyed_pairs(right))
}

///|
fn bsearch_json_array(a : Array[Value], needle : Value) -> Int {
  let mut lo = 0
  let mut hi = a.length()
  while lo < hi {
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
  let source_chars = []
  for ch in haystack {
    source_chars.push(ch)
  }
  let pattern_chars = []
  for ch in pattern {
    pattern_chars.push(ch)
  }
  if pattern_chars.length() == 0 {
    return []
  }
  if pattern_chars.length() > source_chars.length() {
    return []
  }
  let out = []
  let last_start = source_chars.length() - pattern_chars.length()
  for start in 0..<(last_start + 1) {
    let mut matched = true
    for i in 0..<pattern_chars.length() {
      if source_chars[start + i] != pattern_chars[i] {
        matched = false
        break
      }
    }
    if matched {
      out.push(start)
    }
  }
  out
}

///|
fn find_array_indices(haystack : Array[Value], pattern : Value) -> Array[Int] {
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
