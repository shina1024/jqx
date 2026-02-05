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
} derive(Eq)

///|
pub impl Show for EvalError with output(self, logger) {
  match self {
    TypeError(msg) => logger.write_string(msg)
    UnknownFunction(name) => logger.write_string("Unknown function: " + name)
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
pub fn eval(filter : Filter, input : Json) -> Array[Json] raise EvalError {
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
        _ => [Json::null()]
      }
    Index(i) =>
      match input {
        Array(a) =>
          if i >= 0 && i < a.length() {
            [a[i]]
          } else {
            [Json::null()]
          }
        _ => [Json::null()]
      }
    Iter =>
      match input {
        Array(a) => a
        Object(o) => {
          let out = []
          for kv in o.iter() {
            out.push(kv.1)
          }
          out
        }
        _ =>
          raise TypeError("Cannot iterate over " + json_type_with_value(input))
      }
    Pipe(left, right) => {
      let out = []
      for v in eval(left, input) {
        for v2 in eval(right, v) {
          out.push(v2)
        }
      }
      out
    }
    Comma(left, right) => {
      let out = []
      for v in eval(left, input) {
        out.push(v)
      }
      for v in eval(right, input) {
        out.push(v)
      }
      out
    }
    Array(items) => {
      let out = []
      for f in items {
        for v in eval(f, input) {
          out.push(v)
        }
      }
      [Json::array(out)]
    }
    Object(items) => {
      let map = Map::new()
      for kv in items {
        let key = kv.0
        let f = kv.1
        let vals = eval(f, input)
        if vals.length() > 0 {
          map[key] = vals[0]
        } else {
          map[key] = Json::null()
        }
      }
      [Json::object(map)]
    }
    Builtin(name) => eval_builtin(name, input)
    Call(name, args) => eval_call(name, args, input)
    Eq(left, right) => {
      let l = eval(left, input)
      let r = eval(right, input)
      if l.length() == 0 || r.length() == 0 {
        [Json::boolean(false)]
      } else {
        [Json::boolean(l[0] == r[0])]
      }
    }
    Neq(left, right) => {
      let l = eval(left, input)
      let r = eval(right, input)
      if l.length() == 0 || r.length() == 0 {
        [Json::boolean(true)]
      } else {
        [Json::boolean(l[0] != r[0])]
      }
    }
    Lt(left, right) => eval_compare("<", left, right, input)
    Lte(left, right) => eval_compare("<=", left, right, input)
    Gt(left, right) => eval_compare(">", left, right, input)
    Gte(left, right) => eval_compare(">=", left, right, input)
    And(left, right) => {
      let l = eval_to_bool(left, input)
      if l {
        [Json::boolean(eval_to_bool(right, input))]
      } else {
        [Json::boolean(false)]
      }
    }
    Or(left, right) => {
      let l = eval_to_bool(left, input)
      if l {
        [Json::boolean(true)]
      } else {
        [Json::boolean(eval_to_bool(right, input))]
      }
    }
    Not(inner) => [Json::boolean(!eval_to_bool(inner, input))]
    Add(left, right) => eval_add(left, right, input)
    Sub(left, right) => eval_arith("-", left, right, input)
    Mul(left, right) => eval_arith("*", left, right, input)
    Div(left, right) => eval_arith("/", left, right, input)
    IfElse(cond, then_branch, else_branch) =>
      if eval_to_bool(cond, input) {
        eval(then_branch, input)
      } else {
        eval(else_branch, input)
      }
    Fallback(left, right) => {
      let l = eval(left, input)
      if l.length() > 0 {
        l
      } else {
        eval(right, input)
      }
    }
    Empty => []
  }
}

///|
fn eval_builtin(name : String, input : Json) -> Array[Json] raise EvalError {
  match name {
    "length" =>
      match input {
        Array(a) => [Json::number(a.length().to_double())]
        Object(o) => [Json::number(o.length().to_double())]
        String(s) => [Json::number(s.length().to_double())]
        _ =>
          raise TypeError("Cannot get length of " + json_type_with_value(input))
      }
    "type" => [Json::string(json_type_name(input))]
    "keys" =>
      match input {
        Object(o) => {
          let keys = Array::from_iter(o.keys())
          keys.sort()
          let out = []
          for k in keys {
            out.push(Json::string(k))
          }
          [Json::array(out)]
        }
        _ =>
          raise TypeError("Cannot get keys of " + json_type_with_value(input))
      }
    _ => raise UnknownFunction(name)
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
fn eval_to_bool(filter : Filter, input : Json) -> Bool raise EvalError {
  let results = eval(filter, input)
  for v in results {
    if is_truthy(v) {
      return true
    }
  }
  false
}

///|
fn eval_call(
  name : String,
  args : Array[Filter],
  input : Json,
) -> Array[Json] raise EvalError {
  match name {
    "select" =>
      if args.length() != 1 {
        raise UnknownFunction("select")
      } else {
        let cond = args[0]
        let results = eval(cond, input)
        let mut ok = false
        for v in results {
          if is_truthy(v) {
            ok = true
            break
          }
        }
        if ok {
          [input]
        } else {
          []
        }
      }
    "map" =>
      if args.length() != 1 {
        raise UnknownFunction("map")
      } else {
        match input {
          Array(a) => {
            let out = []
            let f = args[0]
            for v in a {
              for v2 in eval(f, v) {
                out.push(v2)
              }
            }
            [Json::array(out)]
          }
          _ => raise TypeError("Cannot map over " + json_type_with_value(input))
        }
      }
    "map_values" =>
      if args.length() != 1 {
        raise UnknownFunction("map_values")
      } else {
        match input {
          Object(o) => {
            let out = Map::new()
            let f = args[0]
            for kv in o.iter() {
              let vals = eval(f, kv.1)
              if vals.length() > 0 {
                out[kv.0] = vals[0]
              } else {
                out[kv.0] = Json::null()
              }
            }
            [Json::object(out)]
          }
          _ =>
            raise TypeError(
              "Cannot map_values over " + json_type_with_value(input),
            )
        }
      }
    "contains" =>
      if args.length() != 1 {
        raise UnknownFunction("contains")
      } else {
        let target = args[0]
        let vals = eval(target, input)
        if vals.length() == 0 {
          [Json::boolean(false)]
        } else {
          let needle = vals[0]
          match (input, needle) {
            (String(h), String(n)) => [Json::boolean(h.contains(n))]
            (Array(h), _) => {
              let mut found = false
              for v in h {
                if v == needle {
                  found = true
                  break
                }
              }
              [Json::boolean(found)]
            }
            _ =>
              raise TypeError(
                "Cannot contains " +
                json_type_with_value(input) +
                " and " +
                json_type_with_value(needle),
              )
          }
        }
      }
    "startswith" =>
      if args.length() != 1 {
        raise UnknownFunction("startswith")
      } else {
        let target = args[0]
        let vals = eval(target, input)
        if vals.length() == 0 {
          [Json::boolean(false)]
        } else {
          let needle = vals[0]
          match (input, needle) {
            (String(h), String(n)) => [Json::boolean(h.has_prefix(n))]
            _ =>
              raise TypeError(
                "Cannot startswith " +
                json_type_with_value(input) +
                " and " +
                json_type_with_value(needle),
              )
          }
        }
      }
    "endswith" =>
      if args.length() != 1 {
        raise UnknownFunction("endswith")
      } else {
        let target = args[0]
        let vals = eval(target, input)
        if vals.length() == 0 {
          [Json::boolean(false)]
        } else {
          let needle = vals[0]
          match (input, needle) {
            (String(h), String(n)) => [Json::boolean(h.has_suffix(n))]
            _ =>
              raise TypeError(
                "Cannot endswith " +
                json_type_with_value(input) +
                " and " +
                json_type_with_value(needle),
              )
          }
        }
      }
    _ => raise UnknownFunction(name)
  }
}

///|
fn eval_compare(
  op : String,
  left : Filter,
  right : Filter,
  input : Json,
) -> Array[Json] raise EvalError {
  let l = eval(left, input)
  let r = eval(right, input)
  if l.length() == 0 || r.length() == 0 {
    return [Json::boolean(false)]
  }
  let a = l[0]
  let b = r[0]
  match (a, b) {
    (Number(x, _), Number(y, _)) => {
      let ok = match op {
        "<" => x < y
        "<=" => x <= y
        ">" => x > y
        _ => x >= y
      }
      [Json::boolean(ok)]
    }
    (String(x), String(y)) => {
      let cmp = x.compare(y)
      let ok = match op {
        "<" => cmp < 0
        "<=" => cmp <= 0
        ">" => cmp > 0
        _ => cmp >= 0
      }
      [Json::boolean(ok)]
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

///|
fn eval_arith(
  op : String,
  left : Filter,
  right : Filter,
  input : Json,
) -> Array[Json] raise EvalError {
  let l = eval(left, input)
  let r = eval(right, input)
  if l.length() == 0 || r.length() == 0 {
    return [Json::null()]
  }
  let a = l[0]
  let b = r[0]
  match (a, b) {
    (Number(x, _), Number(y, _)) => {
      let v = match op {
        "-" => x - y
        "*" => x * y
        _ => x / y
      }
      [Json::number(v)]
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

///|
fn eval_add(
  left : Filter,
  right : Filter,
  input : Json,
) -> Array[Json] raise EvalError {
  let l = eval(left, input)
  let r = eval(right, input)
  if l.length() == 0 || r.length() == 0 {
    return [Json::null()]
  }
  let a = l[0]
  let b = r[0]
  match (a, b) {
    (Number(x, _), Number(y, _)) => [Json::number(x + y)]
    (String(x), String(y)) => [Json::string(x + y)]
    (Array(x), Array(y)) => {
      let out = x.copy()
      for v in y {
        out.push(v)
      }
      [Json::array(out)]
    }
    (Object(x), Object(y)) => {
      let out = Map::new()
      for kv in x.iter() {
        out[kv.0] = kv.1
      }
      for kv in y.iter() {
        out[kv.0] = kv.1
      }
      [Json::object(out)]
    }
    _ =>
      raise TypeError(
        "Cannot apply + to " +
        json_type_with_value(a) +
        " and " +
        json_type_with_value(b),
      )
  }
}
