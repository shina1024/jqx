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
fn append_combinations_recursive(
  groups : Array[Array[Json]],
  depth : Int,
  current : Array[Json],
  out : Array[Json],
) -> Unit {
  if depth >= groups.length() {
    out.push(Json::array(current.copy()))
    return
  }
  let group = groups[depth]
  for value in group {
    current.push(value)
    append_combinations_recursive(groups, depth + 1, current, out)
    ignore(current.pop())
  }
}

///|
fn combinations_from_groups(groups : Array[Array[Json]]) -> Array[Json] {
  let out = []
  append_combinations_recursive(groups, 0, [], out)
  out
}

///|
fn truncate_stream_token(
  token : Json,
  selector : Json,
) -> Json? raise EvalError {
  match token {
    Array(entries) =>
      if entries.length() == 2 {
        match entries[0] {
          Array(path) =>
            if path.length() == 0 || path[0] != selector {
              None
            } else {
              let trimmed = []
              for i in 1..<path.length() {
                trimmed.push(path[i])
              }
              Some(Json::array([Json::array(trimmed), entries[1]]))
            }
          _ => raise TypeError("truncate_stream token path must be an array")
        }
      } else if entries.length() == 1 {
        match entries[0] {
          Array(path) =>
            if path.length() == 0 || path[0] != selector {
              None
            } else if path.length() == 1 {
              None
            } else {
              let trimmed = []
              for i in 1..<path.length() {
                trimmed.push(path[i])
              }
              Some(Json::array([Json::array(trimmed)]))
            }
          _ => raise TypeError("truncate_stream token path must be an array")
        }
      } else {
        raise TypeError("truncate_stream token must be [path] or [path, value]")
      }
    _ => raise TypeError("truncate_stream token must be an array")
  }
}

///|
fn apply_fromstream_token(root : Json, token : Json) -> Json raise EvalError {
  match token {
    Array(entries) =>
      if entries.length() == 2 {
        match entries[0] {
          Array(path) => setpath_on_input(root, path, entries[1])
          _ => raise TypeError("fromstream token path must be an array")
        }
      } else if entries.length() == 1 {
        match entries[0] {
          Array(_) => root
          _ => raise TypeError("fromstream token path must be an array")
        }
      } else {
        raise TypeError("fromstream token must be [path] or [path, value]")
      }
    _ => raise TypeError("fromstream token must be an array")
  }
}

///|
fn[T] raise_error_value(value : Json) -> T raise EvalError {
  raise Thrown(value)
}

///|
fn any_with_short_circuit(
  source : Filter,
  cond : Filter,
  input : Json,
  env : Map[String, Json],
) -> Bool raise EvalError {
  match source {
    Comma(left, right) =>
      if any_with_short_circuit(left, cond, input, env) {
        true
      } else {
        any_with_short_circuit(right, cond, input, env)
      }
    _ => {
      let values = execute_with_env(source, input, env)
      for v in values {
        for cond_out in execute_with_env(cond, v, env) {
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
fn all_with_short_circuit(
  source : Filter,
  cond : Filter,
  input : Json,
  env : Map[String, Json],
) -> Bool raise EvalError {
  match source {
    Comma(left, right) =>
      if !all_with_short_circuit(left, cond, input, env) {
        false
      } else {
        all_with_short_circuit(right, cond, input, env)
      }
    _ => {
      let values = execute_with_env(source, input, env)
      for v in values {
        for cond_out in execute_with_env(cond, v, env) {
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
fn filter_has_truthy_output(
  filter : Filter,
  input : Json,
  env : Map[String, Json],
) -> Bool raise EvalError {
  for value in execute_with_env(filter, input, env) {
    if is_truthy(value) {
      return true
    }
  }
  false
}

///|
fn append_while_outputs(
  value : Json,
  cond : Filter,
  update : Filter,
  env : Map[String, Json],
  out : Array[Json],
) -> Unit raise EvalError {
  for cond_out in execute_with_env(cond, value, env) {
    if is_truthy(cond_out) {
      out.push(value)
      for next in execute_with_env(update, value, env) {
        append_while_outputs(next, cond, update, env, out)
      }
    }
  }
}

///|
fn append_until_outputs(
  value : Json,
  cond : Filter,
  update : Filter,
  env : Map[String, Json],
  out : Array[Json],
) -> Unit raise EvalError {
  for cond_out in execute_with_env(cond, value, env) {
    if is_truthy(cond_out) {
      out.push(value)
    } else {
      for next in execute_with_env(update, value, env) {
        append_until_outputs(next, cond, update, env, out)
      }
    }
  }
}

///|
fn append_recurse_outputs(
  value : Json,
  next_filter : Filter,
  cond_filter : Filter?,
  env : Map[String, Json],
  out : Array[Json],
) -> Unit raise EvalError {
  out.push(value)
  for next in execute_with_env(next_filter, value, env) {
    let should_descend = match cond_filter {
      None => true
      Some(cond) => filter_has_truthy_output(cond, next, env)
    }
    if should_descend {
      append_recurse_outputs(next, next_filter, cond_filter, env, out)
    }
  }
}

///|
fn walk_transform(
  value : Json,
  transform : Filter,
  env : Map[String, Json],
) -> Array[Json] raise EvalError {
  let descended = match value {
    Array(items) => {
      let out = []
      for item in items {
        let mapped = walk_transform(item, transform, env)
        // Keep current evaluator simplification: update-style child transforms
        // use only the first produced output, and drop empty outputs.
        if mapped.length() > 0 {
          out.push(mapped[0])
        }
      }
      Json::array(out)
    }
    Object(obj) => {
      let out = Map::new()
      let out_order = []
      for kv in object_entries_sorted(obj) {
        let mapped = walk_transform(kv.1, transform, env)
        if mapped.length() > 0 {
          out_order.push(kv.0)
          out[kv.0] = mapped[0]
        }
      }
      Json::object_with_order(out, out_order)
    }
    _ => value
  }
  execute_with_env(transform, descended, env)
}

///|
fn builtin_call_stream(
  name : String,
  args : Array[Filter],
  input : Json,
  env : Map[String, Json],
) -> Array[Json]? raise EvalError {
  match name {
    "error" =>
      if args.length() == 0 {
        Some([raise_error_value(input)])
      } else if args.length() == 1 {
        let values = execute_with_env(args[0], input, env)
        if values.length() == 0 {
          Some([raise_error_value(input)])
        } else {
          Some([raise_error_value(values[0])])
        }
      } else {
        raise UnknownFunction("error")
      }
    "select" =>
      if args.length() != 1 {
        raise UnknownFunction("select")
      } else {
        let cond = args[0]
        let results = execute_with_env(cond, input, env)
        let out = []
        for v in results {
          if is_truthy(v) {
            out.push(input)
          }
        }
        Some(out)
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
              for v2 in execute_with_env(f, v, env) {
                out.push(v2)
              }
            }
            Some([Json::array(out)])
          }
          Object(o) => {
            let out = []
            let f = args[0]
            for kv in object_entries_sorted(o) {
              for v2 in execute_with_env(f, kv.1, env) {
                out.push(v2)
              }
            }
            Some([Json::array(out)])
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
            let out_order = []
            let f = args[0]
            for kv in object_entries_sorted(o) {
              let vals = execute_with_env(f, kv.1, env)
              if vals.length() > 0 {
                out_order.push(kv.0)
                out[kv.0] = vals[0]
              }
            }
            Some([Json::object_with_order(out, out_order)])
          }
          Array(a) => {
            let out = []
            let f = args[0]
            for v in a {
              let vals = execute_with_env(f, v, env)
              if vals.length() > 0 {
                out.push(vals[0])
              }
            }
            Some([Json::array(out)])
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
        let values = execute_with_env_prefix(args[0], input, env, 1)
        if values.length() == 0 {
          Some([])
        } else {
          Some([values[0]])
        }
      }
    "last" =>
      if args.length() != 1 {
        raise UnknownFunction("last")
      } else {
        let values = execute_with_env(args[0], input, env)
        if values.length() == 0 {
          Some([])
        } else {
          Some([values[values.length() - 1]])
        }
      }
    "nth" =>
      if args.length() == 1 {
        let keys = execute_with_env(args[0], input, env)
        let out = []
        for key in keys {
          out.push(nth_on_input(input, key))
        }
        Some(out)
      } else if args.length() == 2 {
        let indexes = execute_with_env(args[0], input, env)
        let stream = args[1]
        let out = []
        for index in indexes {
          match call_parse_nth_index(index) {
            Some(i) => {
              let values = execute_with_env_prefix(stream, input, env, i + 1)
              if i < values.length() {
                out.push(values[i])
              }
            }
            None => ()
          }
        }
        Some(out)
      } else {
        raise UnknownFunction("nth")
      }
    "limit" =>
      if args.length() != 2 {
        raise UnknownFunction("limit")
      } else {
        let counts = execute_with_env(args[0], input, env)
        let stream = args[1]
        let out = []
        for count_value in counts {
          match
            call_parse_non_negative_count(
              count_value, "limit doesn't support negative count",
            ) {
            Some(0) => ()
            Some(count) =>
              for v in execute_with_env_prefix(stream, input, env, count) {
                out.push(v)
              }
            None =>
              for v in execute_with_env(stream, input, env) {
                out.push(v)
              }
          }
        }
        Some(out)
      }
    "skip" =>
      if args.length() != 2 {
        raise UnknownFunction("skip")
      } else {
        let counts = execute_with_env(args[0], input, env)
        let stream = args[1]
        let out = []
        for count_value in counts {
          match
            call_parse_non_negative_count(
              count_value, "skip doesn't support negative count",
            ) {
            Some(skip_count) => {
              let values = execute_with_env(stream, input, env)
              let start = if skip_count < values.length() {
                skip_count
              } else {
                values.length()
              }
              for i in start..<values.length() {
                out.push(values[i])
              }
            }
            None => ignore(execute_with_env(stream, input, env))
          }
        }
        Some(out)
      }
    "repeat" =>
      if args.length() != 1 {
        raise UnknownFunction("repeat")
      } else {
        let out = []
        let mut frontier = [input]
        for {
          if frontier.length() == 0 {
            break
          }
          let next = []
          for value in frontier {
            let produced = try execute_with_env(args[0], value, env) catch {
              err => raise_with_prefix(out, err)
            } noraise {
              values => values
            }
            for v in produced {
              out.push(v)
              next.push(v)
            }
          }
          frontier = next
        }
        Some(out)
      }
    "while" =>
      if args.length() != 2 {
        raise UnknownFunction("while")
      } else {
        let out = []
        append_while_outputs(input, args[0], args[1], env, out)
        Some(out)
      }
    "until" =>
      if args.length() != 2 {
        raise UnknownFunction("until")
      } else {
        let out = []
        append_until_outputs(input, args[0], args[1], env, out)
        Some(out)
      }
    "recurse" =>
      if args.length() > 2 {
        raise UnknownFunction("recurse")
      } else {
        let next_filter = if args.length() >= 1 {
          args[0]
        } else {
          Filter::iter_opt()
        }
        let cond_filter = if args.length() == 2 { Some(args[1]) } else { None }
        let out = []
        append_recurse_outputs(input, next_filter, cond_filter, env, out)
        Some(out)
      }
    "walk" =>
      if args.length() != 1 {
        raise UnknownFunction("walk")
      } else {
        Some(walk_transform(input, args[0], env))
      }
    "any" =>
      if args.length() == 1 {
        let values = collection_values(input)
        let cond = args[0]
        let mut ok = false
        for v in values {
          for cond_out in execute_with_env(cond, v, env) {
            if is_truthy(cond_out) {
              ok = true
              break
            }
          }
          if ok {
            break
          }
        }
        Some([Json::boolean(ok)])
      } else if args.length() == 2 {
        Some([
          Json::boolean(any_with_short_circuit(args[0], args[1], input, env)),
        ])
      } else {
        raise UnknownFunction("any")
      }
    "all" =>
      if args.length() == 1 {
        let values = collection_values(input)
        let cond = args[0]
        let mut ok = true
        for v in values {
          for cond_out in execute_with_env(cond, v, env) {
            if !is_truthy(cond_out) {
              ok = false
              break
            }
          }
          if !ok {
            break
          }
        }
        Some([Json::boolean(ok)])
      } else if args.length() == 2 {
        Some([
          Json::boolean(all_with_short_circuit(args[0], args[1], input, env)),
        ])
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
          for value in execute_with_env(arg, input, env) {
            if !seen {
              acc = value
              seen = true
            } else {
              acc = json_add_pair(acc, value)
            }
          }
        }
        Some([acc])
      }
    "isempty" =>
      if args.length() != 1 {
        raise UnknownFunction("isempty")
      } else {
        let values = execute_with_env_prefix(args[0], input, env, 1)
        Some([Json::boolean(values.length() == 0)])
      }
    "flatten" =>
      if args.length() != 1 {
        raise UnknownFunction("flatten")
      } else {
        let depths = execute_with_env(args[0], input, env)
        let out = []
        for depth in depths {
          out.push(flatten_with_depth(input, depth))
        }
        Some(out)
      }
    "with_entries" =>
      if args.length() != 1 {
        raise UnknownFunction("with_entries")
      } else {
        match to_entries_json(input) {
          Array(entries) => {
            let mapped = []
            for entry in entries {
              for mapped_entry in execute_with_env(args[0], entry, env) {
                mapped.push(mapped_entry)
              }
            }
            Some([from_entries_json(Json::array(mapped))])
          }
          _ => abort("unreachable")
        }
      }
    "combinations" =>
      if args.length() == 0 {
        match input {
          Array(groups_raw) => {
            let groups = []
            for entry in groups_raw {
              match entry {
                Array(group) => groups.push(group)
                _ =>
                  raise TypeError(
                    "combinations input must be an array of arrays",
                  )
              }
            }
            Some(combinations_from_groups(groups))
          }
          _ => raise TypeError("combinations input must be an array")
        }
      } else if args.length() == 1 {
        match input {
          Array(pool) => {
            let counts = execute_with_env(args[0], input, env)
            let out = []
            for count_value in counts {
              match
                call_parse_non_negative_count(
                  count_value, "combinations doesn't support negative count",
                ) {
                Some(count) => {
                  let groups = []
                  for _ in 0..<count {
                    groups.push(pool)
                  }
                  for combo in combinations_from_groups(groups) {
                    out.push(combo)
                  }
                }
                None => ()
              }
            }
            Some(out)
          }
          _ => raise TypeError("combinations input must be an array")
        }
      } else {
        raise UnknownFunction("combinations")
      }
    "truncate_stream" =>
      if args.length() == 0 {
        raise UnknownFunction("truncate_stream")
      } else {
        let out = []
        for arg in args {
          for token in execute_with_env(arg, input, env) {
            match truncate_stream_token(token, input) {
              Some(next) => out.push(next)
              None => ()
            }
          }
        }
        Some(out)
      }
    "fromstream" =>
      if args.length() != 1 {
        raise UnknownFunction("fromstream")
      } else {
        let tokens = execute_with_env(args[0], input, env)
        let mut root = Json::null()
        for token in tokens {
          root = apply_fromstream_token(root, token)
        }
        Some([root])
      }
    _ => None
  }
}
