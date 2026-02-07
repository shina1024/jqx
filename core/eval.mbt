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
        String(s) => {
          let idx = if i < 0 { s.length() + i } else { i }
          if idx >= 0 && idx < s.length() {
            [
              Json::string(
                s.view(start_offset=idx, end_offset=idx + 1).to_string(),
              ),
            ]
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
        String(s) => {
          let idx = if i < 0 { s.length() + i } else { i }
          if idx >= 0 && idx < s.length() {
            [
              Json::string(
                s.view(start_offset=idx, end_offset=idx + 1).to_string(),
              ),
            ]
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
          for kv in o.iter() {
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
          for kv in o.iter() {
            out.push(kv.1)
          }
          out
        }
        _ => []
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
fn eval_builtin(name : String, input : Json) -> Array[Json] raise EvalError {
  match name {
    "length" =>
      match input {
        Array(a) => [Json::number(a.length().to_double())]
        Object(o) => [Json::number(o.length().to_double())]
        String(s) => [Json::number(s.length().to_double())]
        JNull => [Json::number(0.0)]
        Number(n, _) =>
          if n < 0.0 {
            [Json::number(-n)]
          } else {
            [Json::number(n)]
          }
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
        Array(a) => {
          let out = []
          for i in 0..<a.length() {
            out.push(Json::number(i.to_double()))
          }
          [Json::array(out)]
        }
        _ => raise TypeError(json_type_with_value(input) + " has no keys")
      }
    "keys_unsorted" =>
      match input {
        Object(o) => {
          let out = []
          for kv in o.iter() {
            out.push(Json::string(kv.0))
          }
          [Json::array(out)]
        }
        Array(a) => {
          let out = []
          for i in 0..<a.length() {
            out.push(Json::number(i.to_double()))
          }
          [Json::array(out)]
        }
        _ => raise TypeError(json_type_with_value(input) + " has no keys")
      }
    "values" =>
      match input {
        JNull => []
        _ => [input]
      }
    "nulls" =>
      match input {
        JNull => [input]
        _ => []
      }
    "booleans" =>
      match input {
        JTrue | JFalse => [input]
        _ => []
      }
    "numbers" =>
      match input {
        Number(_, _) => [input]
        _ => []
      }
    "strings" =>
      match input {
        String(_) => [input]
        _ => []
      }
    "arrays" =>
      match input {
        Array(_) => [input]
        _ => []
      }
    "objects" =>
      match input {
        Object(_) => [input]
        _ => []
      }
    "iterables" =>
      match input {
        Array(_) | Object(_) => [input]
        _ => []
      }
    "scalars" =>
      match input {
        Array(_) | Object(_) => []
        _ => [input]
      }
    "add" =>
      match input {
        Array(a) => {
          let mut acc = Json::null()
          for v in a {
            acc = json_add_pair(acc, v)
          }
          [acc]
        }
        Object(o) => {
          let mut acc = Json::null()
          for kv in o.iter() {
            acc = json_add_pair(acc, kv.1)
          }
          [acc]
        }
        _ =>
          raise TypeError("Cannot iterate over " + json_type_with_value(input))
      }
    "tostring" =>
      match input {
        String(_) => [input]
        _ => [Json::string(input.to_json_string())]
      }
    "tonumber" =>
      match input {
        Number(_, _) => [input]
        String(s) =>
          try @strconv.parse_double(s) catch {
            _ =>
              raise TypeError(
                json_type_with_value(input) + " cannot be parsed as a number",
              )
          } noraise {
            n => if n != n { [Json::null()] } else { [Json::number(n)] }
          }
        _ =>
          raise TypeError(
            json_type_with_value(input) + " cannot be parsed as a number",
          )
      }
    "sort" =>
      match input {
        Array(a) => [Json::array(sort_json_array(a))]
        _ =>
          raise TypeError(
            json_type_with_value(input) +
            " cannot be sorted, as it is not an array",
          )
      }
    "explode" =>
      match input {
        String(s) => [Json::array(explode_string(s))]
        _ => raise TypeError("explode input must be a string")
      }
    "ascii_upcase" =>
      match input {
        String(s) => [Json::string(ascii_upcase_string(s))]
        _ => raise TypeError("explode input must be a string")
      }
    "ascii_downcase" =>
      match input {
        String(s) => [Json::string(ascii_downcase_string(s))]
        _ => raise TypeError("explode input must be a string")
      }
    "implode" =>
      match input {
        Array(a) => [Json::string(implode_array(a))]
        _ => raise TypeError("implode input must be an array")
      }
    "reverse" =>
      match input {
        Array(a) => {
          let out = []
          for i in 0..<a.length() {
            out.push(a[a.length() - 1 - i])
          }
          [Json::array(out)]
        }
        JNull => [Json::array([])]
        Number(n, _) =>
          if n == 0.0 {
            [Json::array([])]
          } else {
            raise TypeError("Cannot index number with number")
          }
        String(s) =>
          if s.length() == 0 {
            [Json::array([])]
          } else {
            raise TypeError("Cannot index string with number")
          }
        Object(o) =>
          if o.length() == 0 {
            [Json::array([])]
          } else {
            raise TypeError("Cannot index object with number")
          }
        JTrue | JFalse =>
          raise TypeError(json_type_with_value(input) + " has no length")
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
fn eval_call(
  name : String,
  args : Array[Filter],
  input : Json,
  env : Map[String, Json],
) -> Array[Json] raise EvalError {
  match name {
    "select" =>
      if args.length() != 1 {
        raise UnknownFunction("select")
      } else {
        let cond = args[0]
        let results = eval_with_env(cond, input, env)
        let out = []
        for v in results {
          if is_truthy(v) {
            out.push(input)
          }
        }
        out
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
              for v2 in eval_with_env(f, v, env) {
                out.push(v2)
              }
            }
            [Json::array(out)]
          }
          Object(o) => {
            let out = []
            let f = args[0]
            for kv in o.iter() {
              for v2 in eval_with_env(f, kv.1, env) {
                out.push(v2)
              }
            }
            [Json::array(out)]
          }
          _ =>
            raise TypeError(
              "Cannot iterate over " + json_type_with_value(input),
            )
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
              let vals = eval_with_env(f, kv.1, env)
              if vals.length() > 0 {
                out[kv.0] = vals[0]
              }
            }
            [Json::object(out)]
          }
          Array(a) => {
            let out = []
            let f = args[0]
            for v in a {
              let vals = eval_with_env(f, v, env)
              if vals.length() > 0 {
                out.push(vals[0])
              }
            }
            [Json::array(out)]
          }
          _ =>
            raise TypeError(
              "Cannot iterate over " + json_type_with_value(input),
            )
        }
      }
    "contains" =>
      if args.length() != 1 {
        raise UnknownFunction("contains")
      } else {
        let target = args[0]
        let needles = eval_with_env(target, input, env)
        let out = []
        for needle in needles {
          out.push(Json::boolean(contains_checked(input, needle)))
        }
        out
      }
    "inside" =>
      if args.length() != 1 {
        raise UnknownFunction("inside")
      } else {
        let target = args[0]
        let haystacks = eval_with_env(target, input, env)
        let out = []
        for haystack in haystacks {
          out.push(Json::boolean(contains_checked(haystack, input)))
        }
        out
      }
    "has" =>
      if args.length() != 1 {
        raise UnknownFunction("has")
      } else {
        let key_filter = args[0]
        let keys = eval_with_env(key_filter, input, env)
        let out = []
        for key in keys {
          out.push(Json::boolean(has_key(input, key)))
        }
        out
      }
    "in" =>
      if args.length() != 1 {
        raise UnknownFunction("in")
      } else {
        let collection_filter = args[0]
        let collections = eval_with_env(collection_filter, input, env)
        let out = []
        for collection in collections {
          out.push(Json::boolean(has_key(collection, input)))
        }
        out
      }
    "startswith" =>
      if args.length() != 1 {
        raise UnknownFunction("startswith")
      } else {
        let target = args[0]
        let needles = eval_with_env(target, input, env)
        let out = []
        for needle in needles {
          match (input, needle) {
            (String(h), String(n)) => out.push(Json::boolean(h.has_prefix(n)))
            _ => raise TypeError("startswith() requires string inputs")
          }
        }
        out
      }
    "endswith" =>
      if args.length() != 1 {
        raise UnknownFunction("endswith")
      } else {
        let target = args[0]
        let needles = eval_with_env(target, input, env)
        let out = []
        for needle in needles {
          match (input, needle) {
            (String(h), String(n)) => out.push(Json::boolean(h.has_suffix(n)))
            _ => raise TypeError("endswith() requires string inputs")
          }
        }
        out
      }
    "ltrimstr" =>
      if args.length() != 1 {
        raise UnknownFunction("ltrimstr")
      } else {
        let needles = eval_with_env(args[0], input, env)
        let out = []
        for needle in needles {
          match (input, needle) {
            (String(h), String(n)) =>
              if h.has_prefix(n) {
                out.push(
                  Json::string(h.view(start_offset=n.length()).to_string()),
                )
              } else {
                out.push(Json::string(h))
              }
            _ => raise TypeError("startswith() requires string inputs")
          }
        }
        out
      }
    "rtrimstr" =>
      if args.length() != 1 {
        raise UnknownFunction("rtrimstr")
      } else {
        let needles = eval_with_env(args[0], input, env)
        let out = []
        for needle in needles {
          match (input, needle) {
            (String(h), String(n)) =>
              if h.has_suffix(n) {
                out.push(
                  Json::string(
                    h
                    .view(start_offset=0, end_offset=h.length() - n.length())
                    .to_string(),
                  ),
                )
              } else {
                out.push(Json::string(h))
              }
            _ => raise TypeError("startswith() requires string inputs")
          }
        }
        out
      }
    "join" =>
      if args.length() != 1 {
        raise UnknownFunction("join")
      } else {
        match input {
          Array(a) => {
            let seps = eval_with_env(args[0], input, env)
            let out = []
            for sep in seps {
              out.push(eval_join(a, sep))
            }
            out
          }
          _ =>
            raise TypeError(
              "Cannot iterate over " + json_type_with_value(input),
            )
        }
      }
    "split" =>
      if args.length() != 1 {
        raise UnknownFunction("split")
      } else {
        let seps = eval_with_env(args[0], input, env)
        let out = []
        for sep in seps {
          match (input, sep) {
            (String(s), String(d)) => out.push(Json::array(split_string(s, d)))
            _ => raise TypeError("split input and separator must be strings")
          }
        }
        out
      }
    "sort_by" =>
      if args.length() != 1 {
        raise UnknownFunction("sort_by")
      } else {
        match input {
          Array(a) => {
            let keyed = []
            let key_filter = args[0]
            for v in a {
              let key_values = eval_with_env(key_filter, v, env)
              let key = if key_values.length() == 0 {
                Json::null()
              } else {
                key_values[0]
              }
              keyed.push((key, v))
            }
            let sorted = sort_keyed_pairs(keyed)
            let out = []
            for kv in sorted {
              out.push(kv.1)
            }
            [Json::array(out)]
          }
          _ =>
            raise TypeError(
              "Cannot iterate over " + json_type_with_value(input),
            )
        }
      }
    "index" =>
      if args.length() != 1 {
        raise UnknownFunction("index")
      } else {
        let needles = eval_with_env(args[0], input, env)
        let out = []
        for needle in needles {
          let indices = match input {
            String(haystack) =>
              match needle {
                String(pattern) => find_string_indices(haystack, pattern)
                _ => index_type_error(input, needle)
              }
            Array(haystack) => find_array_indices(haystack, needle)
            _ => index_type_error(input, needle)
          }
          if indices.length() == 0 {
            out.push(Json::null())
          } else {
            out.push(Json::number(indices[0].to_double()))
          }
        }
        out
      }
    "rindex" =>
      if args.length() != 1 {
        raise UnknownFunction("rindex")
      } else {
        let needles = eval_with_env(args[0], input, env)
        let out = []
        for needle in needles {
          let indices = match input {
            String(haystack) =>
              match needle {
                String(pattern) => find_string_indices(haystack, pattern)
                _ => index_type_error(input, needle)
              }
            Array(haystack) => find_array_indices(haystack, needle)
            _ => index_type_error(input, needle)
          }
          if indices.length() == 0 {
            out.push(Json::null())
          } else {
            out.push(Json::number(indices[indices.length() - 1].to_double()))
          }
        }
        out
      }
    "indices" =>
      if args.length() != 1 {
        raise UnknownFunction("indices")
      } else {
        let needles = eval_with_env(args[0], input, env)
        let out = []
        for needle in needles {
          let indices = match input {
            String(haystack) =>
              match needle {
                String(pattern) => find_string_indices(haystack, pattern)
                _ => index_type_error(input, needle)
              }
            Array(haystack) => find_array_indices(haystack, needle)
            _ => index_type_error(input, needle)
          }
          let arr = []
          for i in indices {
            arr.push(Json::number(i.to_double()))
          }
          out.push(Json::array(arr))
        }
        out
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
          out.push(Json::number(v))
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
    (Number(x, _), Number(y, _)) => Json::number(x + y)
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
