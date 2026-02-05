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
} derive(Eq)

///|
pub impl Show for EvalError with output(self, logger) {
  match self {
    TypeError(msg) => logger.write_string(msg)
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
    Field(name) => {
      match input {
        Object(o) =>
          match o.get(name) {
            Some(v) => [v]
            None => [Json::null()]
          }
        _ => [Json::null()]
      }
    }
    Index(i) => {
      match input {
        Array(a) =>
          if i >= 0 && i < a.length() {
            [a[i]]
          } else {
            [Json::null()]
          }
        _ => [Json::null()]
      }
    }
    Iter => {
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
          raise TypeError(
            "Cannot iterate over " + json_type_with_value(input),
          )
      }
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
    Array(_) | Object(_) =>
      raise TypeError("Unsupported filter (array/object literal)")
  }
}
