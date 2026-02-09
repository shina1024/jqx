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
    "first" =>
      if args.length() != 1 {
        raise UnknownFunction("first")
      } else {
        let values = eval_with_env(args[0], input, env)
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
      if args.length() != 1 {
        raise UnknownFunction("nth")
      } else {
        let keys = eval_with_env(args[0], input, env)
        let out = []
        for key in keys {
          out.push(nth_on_input(input, key))
        }
        out
      }
    "any" =>
      if args.length() != 1 {
        raise UnknownFunction("any")
      } else {
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
      }
    "all" =>
      if args.length() != 1 {
        raise UnknownFunction("all")
      } else {
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
