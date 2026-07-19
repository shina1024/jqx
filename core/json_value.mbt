///|
pub enum Value {
  JNull
  JTrue
  JFalse
  Number(Double, String?)
  String(String)
  Array(Array[Value])
  Object(JsonObject)
} derive(Debug)

///|
struct JsonObject {
  map : Map[String, Value]
  key_order : Array[String]
  lex_key_order : Array[String]
} derive(Debug)

///|
fn object_keys_in_order(
  map : Map[String, Value],
  key_order : Array[String],
) -> Array[String] {
  let out = []
  let seen = Map([])
  for key in key_order {
    if !seen.contains(key) {
      seen[key] = true
      if map.contains(key) {
        out.push(key)
      }
    }
  }
  for key in map.keys() {
    if !seen.contains(key) {
      seen[key] = true
      out.push(key)
    }
  }
  out
}

///|
fn json_object_make(
  map : Map[String, Value],
  key_order : Array[String],
) -> JsonObject {
  let normalized_key_order = object_keys_in_order(map, key_order)
  {
    map,
    key_order: normalized_key_order,
    lex_key_order: sort_strings_lex(normalized_key_order),
  }
}

///|
fn JsonObject::from_map(map : Map[String, Value]) -> JsonObject {
  json_object_make(map, Array::from_iter(map.keys()))
}

///|
fn JsonObject::with_order(
  map : Map[String, Value],
  key_order : Array[String],
) -> JsonObject {
  json_object_make(map, key_order)
}

///|
fn JsonObject::get(self : JsonObject, key : String) -> Value? {
  self.map.get(key)
}

///|
fn JsonObject::contains(self : JsonObject, key : String) -> Bool {
  self.map.contains(key)
}

///|
fn JsonObject::length(self : JsonObject) -> Int {
  self.map.length()
}

///|
fn JsonObject::keys(self : JsonObject) -> Array[String] {
  self.key_order.copy()
}

///|
pub fn JsonObject::iter(self : JsonObject) -> Array[(String, Value)] {
  object_entries_sorted(self)
}

///|
fn JsonObject::to_map(self : JsonObject) -> Map[String, Value] {
  self.map
}

///|
fn JsonObject::set(
  self : JsonObject,
  key : String,
  value : Value,
) -> JsonObject {
  let next_map = self.map.copy()
  let next_order = self.key_order.copy()
  if !next_map.contains(key) {
    next_order.push(key)
  }
  next_map[key] = value
  json_object_make(next_map, next_order)
}

///|
fn json_equal(a : Value, b : Value) -> Bool {
  let pending = [(a, b, 0)]
  while pending.length() > 0 {
    let current = pending.pop().unwrap()
    let left = current.0
    let right = current.1
    let depth = current.2
    if physical_equal(left, right) {
      continue
    }
    if depth > 10000 {
      return false
    }
    match (left, right) {
      (JNull, JNull) | (JTrue, JTrue) | (JFalse, JFalse) => ()
      (Number(x, rx), Number(y, ry)) => {
        let equal = match (rx, ry) {
          (Some(a), Some(b)) =>
            match decimal_compare_repr(a, b) {
              Some(cmp) => cmp == 0
              None => x == y
            }
          _ => x == y
        }
        if !equal {
          return false
        }
      }
      (String(x), String(y)) => if x != y { return false }
      (Array(x), Array(y)) => {
        if x.length() != y.length() {
          return false
        }
        for i in 0..<x.length() {
          pending.push((x[i], y[i], depth + 1))
        }
      }
      (Object(x), Object(y)) => {
        if x.length() != y.length() {
          return false
        }
        for kv in x.iter() {
          match y.get(kv.0) {
            Some(v) => pending.push((kv.1, v, depth + 1))
            None => return false
          }
        }
      }
      _ => return false
    }
  }
  true
}

///|
fn json_equal_checked(a : Value, b : Value) -> Bool raise EvalError {
  let pending = [(a, b, 0)]
  while pending.length() > 0 {
    let current = pending.pop().unwrap()
    let left = current.0
    let right = current.1
    let depth = current.2
    if physical_equal(left, right) {
      continue
    }
    if depth > 10000 {
      raise TypeError("Equality check too deep")
    }
    match (left, right) {
      (JNull, JNull) | (JTrue, JTrue) | (JFalse, JFalse) => ()
      (Number(x, rx), Number(y, ry)) => {
        let equal = match (rx, ry) {
          (Some(a), Some(b)) =>
            match decimal_compare_repr(a, b) {
              Some(cmp) => cmp == 0
              None => x == y
            }
          _ => x == y
        }
        if !equal {
          return false
        }
      }
      (String(x), String(y)) => if x != y { return false }
      (Array(x), Array(y)) => {
        if x.length() != y.length() {
          return false
        }
        for i in 0..<x.length() {
          pending.push((x[i], y[i], depth + 1))
        }
      }
      (Object(x), Object(y)) => {
        if x.length() != y.length() {
          return false
        }
        for kv in x.iter() {
          match y.get(kv.0) {
            Some(v) => pending.push((kv.1, v, depth + 1))
            None => return false
          }
        }
      }
      _ => return false
    }
  }
  true
}

///|
pub impl Eq for Value with fn equal(self, other) {
  json_equal(self, other)
}

///|
pub impl Eq for Value with fn not_equal(self, other) {
  !json_equal(self, other)
}

///|
pub fn Value::null() -> Value {
  JNull
}

///|
pub fn Value::boolean(b : Bool) -> Value {
  if b {
    JTrue
  } else {
    JFalse
  }
}

///|
pub fn Value::number(n : Double, repr? : String) -> Value {
  Number(n, repr)
}

///|
pub fn Value::string(s : String) -> Value {
  String(s)
}

///|
pub fn Value::array(a : Array[Value]) -> Value {
  Array(a)
}

///|
pub fn Value::object(o : Map[String, Value]) -> Value {
  Object(JsonObject::from_map(o))
}

///|
fn Value::object_with_order(
  o : Map[String, Value],
  key_order : Array[String],
) -> Value {
  Object(JsonObject::with_order(o, key_order))
}

///|
pub fn Value::object_from_entries(entries : Array[(String, Value)]) -> Value {
  let map = Map([])
  let key_order = []
  for kv in entries {
    let key = kv.0
    let value = kv.1
    if !map.contains(key) {
      key_order.push(key)
    }
    map[key] = value
  }
  Value::object_with_order(map, key_order)
}

///|
pub fn Value::from_json(input : Json) -> Value {
  match input {
    Null => Value::null()
    True => Value::boolean(true)
    False => Value::boolean(false)
    Number(n, repr~) => Value::number(n, repr?)
    String(s) => Value::string(s)
    Array(values) => Value::array(values.map(value => Value::from_json(value)))
    Object(obj) => {
      let entries = []
      for key, value in obj {
        entries.push((key, Value::from_json(value)))
      }
      Value::object_from_entries(entries)
    }
  }
}

///|
pub fn Value::to_json(self : Value) -> Json {
  match self {
    JNull => null
    JTrue => Json::boolean(true)
    JFalse => Json::boolean(false)
    Number(n, repr) => Json::number(n, repr?)
    String(s) => Json::string(s)
    Array(values) => Json::array(values.map(value => Value::to_json(value)))
    Object(obj) => {
      let out = Map([])
      for kv in obj.iter() {
        out[kv.0] = Value::to_json(kv.1)
      }
      Json::object(out)
    }
  }
}

///|
pub fn values_to_json(values : Array[Value]) -> Array[Json] {
  values.map(value => Value::to_json(value))
}

///|
pub fn values_to_json_text(values : Array[Value]) -> Array[String] {
  values.map(value => value.to_json_string())
}

///|
fn decimal_expand_positive_exponent(raw : String) -> String? {
  let mut exp_index = -1
  for i in 0..<raw.length() {
    let ch = raw.unsafe_get(i).to_int().unsafe_to_char()
    if ch == 'e' || ch == 'E' {
      exp_index = i
      break
    }
  }
  if exp_index < 0 {
    return None
  }
  let mantissa = raw.view(start_offset=0, end_offset=exp_index).to_owned()
  let exp_part = raw
    .view(start_offset=exp_index + 1, end_offset=raw.length())
    .to_owned()
  let exp_value = try @string.parse_int64(exp_part) catch {
    _ => return None
  } noraise {
    v => v.to_int()
  }
  if exp_value < 0 {
    return None
  }
  let mut negative = false
  let mut pos = 0
  if mantissa.length() > 0 {
    let first = mantissa.unsafe_get(0).to_int().unsafe_to_char()
    if first == '-' {
      negative = true
      pos = 1
    } else if first == '+' {
      pos = 1
    }
  }
  let mut dot_index = -1
  for i in pos..<mantissa.length() {
    let ch = mantissa.unsafe_get(i).to_int().unsafe_to_char()
    if ch == '.' {
      if dot_index >= 0 {
        return None
      }
      dot_index = i
      continue
    }
    if !is_ascii_digit(ch) {
      return None
    }
  }
  let int_end = if dot_index >= 0 { dot_index } else { mantissa.length() }
  let frac_start = if dot_index >= 0 { dot_index + 1 } else { int_end }
  let int_part = mantissa.view(start_offset=pos, end_offset=int_end).to_owned()
  let frac_part = mantissa
    .view(start_offset=frac_start, end_offset=mantissa.length())
    .to_owned()
  let digits = int_part + frac_part
  if digits.length() == 0 {
    return None
  }
  let frac_len = frac_part.length()
  let exp_nonneg = exp_value
  let sign = if negative { "-" } else { "" }
  if exp_nonneg >= frac_len {
    let zero_count = exp_nonneg - frac_len
    let buf = StringBuilder()
    buf.write_string(sign)
    buf.write_string(digits)
    for _ in 0..<zero_count {
      buf.write_char('0')
    }
    Some(buf.to_string())
  } else {
    let integer_len = digits.length() - (frac_len - exp_nonneg)
    let buf = StringBuilder()
    buf.write_string(sign)
    if integer_len > 0 {
      buf.write_string(
        digits.view(start_offset=0, end_offset=integer_len).to_owned(),
      )
    } else {
      buf.write_char('0')
    }
    buf.write_char('.')
    buf.write_string(
      digits
      .view(start_offset=integer_len, end_offset=digits.length())
      .to_owned(),
    )
    Some(buf.to_string())
  }
}

///|
fn object_keys_sorted(o : JsonObject) -> Array[String] {
  o.keys()
}

///|
fn sort_strings_lex(input : Array[String]) -> Array[String] {
  fn merge_sorted_strings(
    left : Array[String],
    right : Array[String],
  ) -> Array[String] {
    let merged = []
    let mut i = 0
    let mut j = 0
    while i < left.length() && j < right.length() {
      if left[i].compare(right[j]) <= 0 {
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

  let n = input.length()
  if n <= 1 {
    return input.copy()
  }
  let mid = n / 2
  let left = []
  let right = []
  for i in 0..<mid {
    left.push(input[i])
  }
  for i in mid..<n {
    right.push(input[i])
  }
  merge_sorted_strings(sort_strings_lex(left), sort_strings_lex(right))
}

///|
fn object_keys_lex_sorted(o : JsonObject) -> Array[String] {
  o.lex_key_order.copy()
}

///|
fn object_entries_sorted(o : JsonObject) -> Array[(String, Value)] {
  let out = []
  for key in o.key_order {
    match o.get(key) {
      Some(value) => out.push((key, value))
      None => ()
    }
  }
  out
}
