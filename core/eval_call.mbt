///|

///|
fn call_require_number(name : String, value : Json) -> Double raise EvalError {
  match value {
    Number(n, _) => n
    _ => raise TypeError(name + "() requires numeric arguments")
  }
}

///|
fn call_parse_non_negative_count(
  value : Json,
  negative_msg : String,
) -> Int? raise EvalError {
  match value {
    Number(n, _) =>
      if n != n || n == @double.neg_infinity || n < 0.0 {
        raise TypeError(negative_msg)
      } else if n == @double.infinity || n > 2147483647.0 {
        None
      } else {
        let count = n.to_int()
        if count < 0 {
          raise TypeError(negative_msg)
        } else {
          Some(count)
        }
      }
    _ => raise TypeError("count must be a number")
  }
}

///|
fn call_parse_nth_index(value : Json) -> Int? raise EvalError {
  match value {
    Number(n, _) =>
      if n != n || n == @double.neg_infinity || n < 0.0 {
        raise TypeError("nth doesn't support negative indices")
      } else if n == @double.infinity || n > 2147483647.0 {
        None
      } else {
        Some(n.to_int())
      }
    _ => raise TypeError("nth index must be a number")
  }
}

///|
fn call_parse_slice_index(value : Json) -> Int? raise EvalError {
  let int_min = -2147483647 - 1
  let int_max = 2147483647
  match value {
    JNull => None
    Number(n, _) =>
      if n != n {
        None
      } else if n == @double.infinity {
        Some(int_max)
      } else if n == @double.neg_infinity {
        Some(int_min)
      } else {
        let index = if n > int_max.to_double() {
          int_max
        } else if n < int_min.to_double() {
          int_min
        } else {
          n.to_int()
        }
        Some(index)
      }
    _ => raise TypeError("Array/string slice indices must be integers")
  }
}

///|
fn append_range_outputs(
  out : Array[Json],
  start : Double,
  end : Double,
  step : Double,
) -> Unit raise EvalError {
  if step == 0.0 || step != step {
    raise TypeError("range() step cannot be zero")
  }
  let mut current = start
  if step > 0.0 {
    for {
      if current < end {
        out.push(json_number_value(current))
        current += step
        continue
      }
      break
    }
  } else {
    for {
      if current > end {
        out.push(json_number_value(current))
        current += step
        continue
      }
      break
    }
  }
}

///|
fn[T] raise_error_value(value : Json) -> T raise EvalError {
  match value {
    String(s) => raise TypeError(s)
    _ => raise TypeError(value.to_json_string())
  }
}

///|
fn eval_any_with_short_circuit(
  source : Filter,
  cond : Filter,
  input : Json,
  env : Map[String, Json],
) -> Bool raise EvalError {
  match source {
    Comma(left, right) =>
      if eval_any_with_short_circuit(left, cond, input, env) {
        true
      } else {
        eval_any_with_short_circuit(right, cond, input, env)
      }
    _ => {
      let values = eval_with_env(source, input, env)
      for v in values {
        for cond_out in eval_with_env(cond, v, env) {
          if is_truthy(cond_out) {
            return true
          }
        }
      }
      false
    }
  }
}

///|
fn eval_all_with_short_circuit(
  source : Filter,
  cond : Filter,
  input : Json,
  env : Map[String, Json],
) -> Bool raise EvalError {
  match source {
    Comma(left, right) =>
      if !eval_all_with_short_circuit(left, cond, input, env) {
        false
      } else {
        eval_all_with_short_circuit(right, cond, input, env)
      }
    _ => {
      let values = eval_with_env(source, input, env)
      for v in values {
        for cond_out in eval_with_env(cond, v, env) {
          if !is_truthy(cond_out) {
            return false
          }
        }
      }
      true
    }
  }
}

///|
fn pick_static_path_segments(filter : Filter) -> Array[Json]? {
  match filter {
    Builtin("first") => Some([Json::number(0.0)])
    Builtin("last") => Some([Json::number(-1.0)])
    Pipe(left, right) =>
      match
        (pick_static_path_segments(left), pick_static_path_segments(right)) {
        (Some(l), Some(r)) => {
          let out = l.copy()
          for segment in r {
            out.push(segment)
          }
          Some(out)
        }
        _ => None
      }
    _ => None
  }
}

///|
fn eval_call(
  name : String,
  args : Array[Filter],
  input : Json,
  env : Map[String, Json],
) -> Array[Json] raise EvalError {
  match name {
    "error" =>
      if args.length() == 0 {
        raise_error_value(input)
      } else if args.length() == 1 {
        let values = eval_with_env(args[0], input, env)
        if values.length() == 0 {
          raise_error_value(input)
        } else {
          raise_error_value(values[0])
        }
      } else {
        raise UnknownFunction("error")
      }
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
            for kv in object_entries_sorted(o) {
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
            for kv in object_entries_sorted(o) {
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
    "first" =>
      if args.length() != 1 {
        raise UnknownFunction("first")
      } else {
        let values = eval_with_env_prefix(args[0], input, env, 1)
        if values.length() == 0 {
          []
        } else {
          [values[0]]
        }
      }
    "last" =>
      if args.length() != 1 {
        raise UnknownFunction("last")
      } else {
        let values = eval_with_env(args[0], input, env)
        if values.length() == 0 {
          []
        } else {
          [values[values.length() - 1]]
        }
      }
    "nth" =>
      if args.length() == 1 {
        let keys = eval_with_env(args[0], input, env)
        let out = []
        for key in keys {
          out.push(nth_on_input(input, key))
        }
        out
      } else if args.length() == 2 {
        let indexes = eval_with_env(args[0], input, env)
        let stream = args[1]
        let out = []
        for index in indexes {
          match call_parse_nth_index(index) {
            Some(i) => {
              let values = eval_with_env_prefix(stream, input, env, i + 1)
              if i < values.length() {
                out.push(values[i])
              }
            }
            None => ()
          }
        }
        out
      } else {
        raise UnknownFunction("nth")
      }
    "pow" =>
      if args.length() != 2 {
        raise UnknownFunction("pow")
      } else {
        let bases = eval_with_env(args[0], input, env)
        let exponents = eval_with_env(args[1], input, env)
        let out = []
        for base_value in bases {
          let base = call_require_number("pow", base_value)
          for exponent_value in exponents {
            let exponent = call_require_number("pow", exponent_value)
            out.push(json_number_value(@math.pow(base, exponent)))
          }
        }
        out
      }
    "range" =>
      if args.length() == 0 || args.length() > 3 {
        raise UnknownFunction("range")
      } else {
        let starts = if args.length() == 1 {
          [Json::number(0.0)]
        } else {
          eval_with_env(args[0], input, env)
        }
        let ends = if args.length() == 1 {
          eval_with_env(args[0], input, env)
        } else {
          eval_with_env(args[1], input, env)
        }
        let steps = if args.length() >= 3 {
          eval_with_env(args[2], input, env)
        } else {
          [Json::number(1.0)]
        }
        let out = []
        for start_value in starts {
          let start = call_require_number("range", start_value)
          for end_value in ends {
            let end = call_require_number("range", end_value)
            for step_value in steps {
              let step = call_require_number("range", step_value)
              append_range_outputs(out, start, end, step)
            }
          }
        }
        out
      }
    "limit" =>
      if args.length() != 2 {
        raise UnknownFunction("limit")
      } else {
        let counts = eval_with_env(args[0], input, env)
        let stream = args[1]
        let out = []
        for count_value in counts {
          match
            call_parse_non_negative_count(
              count_value, "limit doesn't support negative count",
            ) {
            Some(0) => ()
            Some(count) =>
              for v in eval_with_env_prefix(stream, input, env, count) {
                out.push(v)
              }
            None =>
              for v in eval_with_env(stream, input, env) {
                out.push(v)
              }
          }
        }
        out
      }
    "skip" =>
      if args.length() != 2 {
        raise UnknownFunction("skip")
      } else {
        let counts = eval_with_env(args[0], input, env)
        let stream = args[1]
        let out = []
        for count_value in counts {
          let values = eval_with_env(stream, input, env)
          match
            call_parse_non_negative_count(
              count_value, "skip doesn't support negative count",
            ) {
            Some(skip_count) => {
              let start = if skip_count < values.length() {
                skip_count
              } else {
                values.length()
              }
              for i in start..<values.length() {
                out.push(values[i])
              }
            }
            None => ()
          }
        }
        out
      }
    "any" =>
      if args.length() == 1 {
        let values = collection_values(input)
        let cond = args[0]
        let mut ok = false
        for v in values {
          for cond_out in eval_with_env(cond, v, env) {
            if is_truthy(cond_out) {
              ok = true
              break
            }
          }
          if ok {
            break
          }
        }
        [Json::boolean(ok)]
      } else if args.length() == 2 {
        [
          Json::boolean(
            eval_any_with_short_circuit(args[0], args[1], input, env),
          ),
        ]
      } else {
        raise UnknownFunction("any")
      }
    "all" =>
      if args.length() == 1 {
        let values = collection_values(input)
        let cond = args[0]
        let mut ok = true
        for v in values {
          for cond_out in eval_with_env(cond, v, env) {
            if !is_truthy(cond_out) {
              ok = false
              break
            }
          }
          if !ok {
            break
          }
        }
        [Json::boolean(ok)]
      } else if args.length() == 2 {
        [
          Json::boolean(
            eval_all_with_short_circuit(args[0], args[1], input, env),
          ),
        ]
      } else {
        raise UnknownFunction("all")
      }
    "add" =>
      if args.length() == 0 {
        raise UnknownFunction("add")
      } else {
        let mut acc = Json::null()
        let mut seen = false
        for arg in args {
          for value in eval_with_env(arg, input, env) {
            if !seen {
              acc = value
              seen = true
            } else {
              acc = json_add_pair(acc, value)
            }
          }
        }
        [acc]
      }
    "isempty" =>
      if args.length() != 1 {
        raise UnknownFunction("isempty")
      } else {
        let values = eval_with_env_prefix(args[0], input, env, 1)
        [Json::boolean(values.length() == 0)]
      }
    "flatten" =>
      if args.length() != 1 {
        raise UnknownFunction("flatten")
      } else {
        let depths = eval_with_env(args[0], input, env)
        let out = []
        for depth in depths {
          out.push(flatten_with_depth(input, depth))
        }
        out
      }
    "with_entries" =>
      if args.length() != 1 {
        raise UnknownFunction("with_entries")
      } else {
        match to_entries_json(input) {
          Array(entries) => {
            let mapped = []
            for entry in entries {
              for mapped_entry in eval_with_env(args[0], entry, env) {
                mapped.push(mapped_entry)
              }
            }
            [from_entries_json(Json::array(mapped))]
          }
          _ => abort("unreachable")
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
    "IN" =>
      if args.length() != 1 {
        raise UnknownFunction("IN")
      } else {
        let candidates = eval_with_env(args[0], input, env)
        let mut found = false
        for candidate in candidates {
          if candidate == input {
            found = true
            break
          }
        }
        [Json::boolean(found)]
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
            _ => raise TypeError("ltrimstr() requires string inputs")
          }
        }
        out
      }
    "trimstr" =>
      if args.length() != 1 {
        raise UnknownFunction("trimstr")
      } else {
        let needles = eval_with_env(args[0], input, env)
        let out = []
        for needle in needles {
          match (input, needle) {
            (String(h), String(n)) => {
              let mut trimmed = h
              if trimmed.has_prefix(n) {
                trimmed = trimmed.view(start_offset=n.length()).to_string()
              }
              if trimmed.has_suffix(n) {
                trimmed = trimmed
                  .view(
                    start_offset=0,
                    end_offset=trimmed.length() - n.length(),
                  )
                  .to_string()
              }
              out.push(Json::string(trimmed))
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
            _ => raise TypeError("rtrimstr() requires string inputs")
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
    "group_by" =>
      if args.length() != 1 {
        raise UnknownFunction("group_by")
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
            let groups = []
            let mut current : Array[Json] = []
            let mut current_key = Json::null()
            let mut has_current = false
            for kv in sorted {
              if !has_current || compare_json(current_key, kv.0) != 0 {
                if has_current {
                  groups.push(Json::array(current))
                }
                current = []
                current_key = kv.0
                has_current = true
              }
              current.push(kv.1)
            }
            if has_current {
              groups.push(Json::array(current))
            }
            [Json::array(groups)]
          }
          _ =>
            raise TypeError(
              "Cannot iterate over " + json_type_with_value(input),
            )
        }
      }
    "min_by" =>
      if args.length() != 1 {
        raise UnknownFunction("min_by")
      } else {
        match input {
          Array(a) => [minmax_by_json_array(a, args[0], env, choose_max=false)]
          _ =>
            raise TypeError(
              "Cannot iterate over " + json_type_with_value(input),
            )
        }
      }
    "max_by" =>
      if args.length() != 1 {
        raise UnknownFunction("max_by")
      } else {
        match input {
          Array(a) => [minmax_by_json_array(a, args[0], env, choose_max=true)]
          _ =>
            raise TypeError(
              "Cannot iterate over " + json_type_with_value(input),
            )
        }
      }
    "unique_by" =>
      if args.length() != 1 {
        raise UnknownFunction("unique_by")
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
            let mut prev_key = Json::null()
            let mut has_prev = false
            for kv in sorted {
              if !has_prev || compare_json(prev_key, kv.0) != 0 {
                out.push(kv.1)
                prev_key = kv.0
                has_prev = true
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
    "bsearch" =>
      if args.length() != 1 {
        raise UnknownFunction("bsearch")
      } else {
        let needles = eval_with_env(args[0], input, env)
        let out = []
        for needle in needles {
          match input {
            Array(a) =>
              out.push(Json::number(bsearch_json_array(a, needle).to_double()))
            _ =>
              raise TypeError(
                json_type_with_value(input) + " cannot be searched from",
              )
          }
        }
        out
      }
    "getpath" =>
      if args.length() != 1 {
        raise UnknownFunction("getpath")
      } else {
        let paths = eval_with_env(args[0], input, env)
        let out = []
        for path in paths {
          out.push(getpath_on_input(input, path))
        }
        out
      }
    "setpath" =>
      if args.length() != 2 {
        raise UnknownFunction("setpath")
      } else {
        let values = eval_with_env(args[1], input, env)
        if values.length() == 0 {
          []
        } else {
          let paths = eval_with_env(args[0], input, env)
          let out = []
          for value in values {
            for path in paths {
              let parts = normalize_setpath_arg(path)
              out.push(setpath_on_input(input, parts, value))
            }
          }
          out
        }
      }
    "delpaths" =>
      if args.length() != 1 {
        raise UnknownFunction("delpaths")
      } else {
        let pathsets = eval_with_env(args[0], input, env)
        let out = []
        for pathset in pathsets {
          let normalized = normalize_delpaths_arg(pathset)
          out.push(delpaths_on_input(input, normalized))
        }
        out
      }
    "path" =>
      if args.length() != 1 {
        raise UnknownFunction("path")
      } else {
        eval_path_expression(args[0], input, env)
      }
    "_slice" =>
      if args.length() != 2 {
        raise UnknownFunction("_slice")
      } else {
        let starts = eval_with_env(args[0], input, env)
        let ends = eval_with_env(args[1], input, env)
        let out = []
        for start_value in starts {
          let start = call_parse_slice_index(start_value)
          for end_value in ends {
            let end = call_parse_slice_index(end_value)
            for v in eval_slice(start, end, input, optional=false) {
              out.push(v)
            }
          }
        }
        out
      }
    "_set_slice" =>
      if args.length() != 3 {
        raise UnknownFunction("_set_slice")
      } else {
        let starts = eval_with_env(args[0], input, env)
        let ends = eval_with_env(args[1], input, env)
        let values = eval_with_env(args[2], input, env)
        let out = []
        for start_value in starts {
          let start = call_parse_slice_index(start_value)
          for end_value in ends {
            let end = call_parse_slice_index(end_value)
            for value in values {
              out.push(set_slice_on_input(input, start, end, value))
            }
          }
        }
        out
      }
    "del" =>
      if args.length() == 0 {
        raise UnknownFunction("del")
      } else {
        let normalized_paths = []
        for arg in args {
          for path_json in eval_path_expression(arg, input, env) {
            match path_json {
              Array(parts) => normalized_paths.push(parts)
              _ => raise TypeError("Path must be specified as an array")
            }
          }
        }
        if normalized_paths.length() == 0 {
          [input]
        } else {
          [delpaths_on_input(input, normalized_paths)]
        }
      }
    "pick" =>
      if args.length() == 0 {
        raise UnknownFunction("pick")
      } else {
        let normalized_paths = []
        for arg in args {
          let path_values = try eval_path_expression(arg, input, env) catch {
            err =>
              match pick_static_path_segments(arg) {
                Some(parts) => [Json::array(parts)]
                None => raise err
              }
          } noraise {
            values => values
          }
          for path_json in path_values {
            match path_json {
              Array(parts) => normalized_paths.push(parts)
              _ => raise TypeError("Path must be specified as an array")
            }
          }
        }
        let mut out = Json::null()
        for parts in normalized_paths {
          let value = getpath_on_input(input, Json::array(parts))
          out = setpath_on_input(out, parts, value)
        }
        [out]
      }
    "paths" =>
      if args.length() != 1 {
        raise UnknownFunction("paths")
      } else {
        collect_paths(input, [], Some(args[0]), env)
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
