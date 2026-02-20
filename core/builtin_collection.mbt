///|
fn index_object_key(value : Json) -> String {
  match value {
    String(s) => s
    _ => value.to_json_string()
  }
}

///|
fn by_key_from_values(values : Array[Json]) -> Json {
  Json::array(values)
}

///|
fn builtin_call_collection(
  name : String,
  args : Array[Filter],
  input : Json,
  env : Map[String, Json],
) -> Array[Json]? raise EvalError {
  match name {
    "contains" =>
      if args.length() != 1 {
        raise UnknownFunction("contains")
      } else {
        let target = args[0]
        let needles = execute_with_env(target, input, env)
        let out = []
        for needle in needles {
          out.push(Json::boolean(contains_checked(input, needle)))
        }
        Some(out)
      }
    "inside" =>
      if args.length() != 1 {
        raise UnknownFunction("inside")
      } else {
        let target = args[0]
        let haystacks = execute_with_env(target, input, env)
        let out = []
        for haystack in haystacks {
          out.push(Json::boolean(contains_checked(haystack, input)))
        }
        Some(out)
      }
    "has" =>
      if args.length() != 1 {
        raise UnknownFunction("has")
      } else {
        let key_filter = args[0]
        let keys = execute_with_env(key_filter, input, env)
        let out = []
        for key in keys {
          out.push(Json::boolean(has_key(input, key)))
        }
        Some(out)
      }
    "in" =>
      if args.length() != 1 {
        raise UnknownFunction("in")
      } else {
        let collection_filter = args[0]
        let collections = execute_with_env(collection_filter, input, env)
        let out = []
        for collection in collections {
          out.push(Json::boolean(has_key(collection, input)))
        }
        Some(out)
      }
    "IN" =>
      if args.length() == 1 {
        let candidates = execute_with_env(args[0], input, env)
        let mut found = false
        for candidate in candidates {
          if candidate == input {
            found = true
            break
          }
        }
        Some([Json::boolean(found)])
      } else if args.length() == 2 {
        let haystack = execute_with_env(args[0], input, env)
        let needles = execute_with_env(args[1], input, env)
        let mut found = false
        for needle in needles {
          for candidate in haystack {
            if candidate == needle {
              found = true
              break
            }
          }
          if found {
            break
          }
        }
        Some([Json::boolean(found)])
      } else {
        raise UnknownFunction("IN")
      }
    "INDEX" =>
      if args.length() != 2 {
        raise UnknownFunction("INDEX")
      } else {
        let values = execute_with_env(args[0], input, env)
        let out = Map::new()
        let out_order = []
        for value in values {
          let keys = execute_with_env(args[1], value, env)
          for key in keys {
            let object_key = index_object_key(key)
            if !out.contains(object_key) {
              out_order.push(object_key)
            }
            out[object_key] = value
          }
        }
        Some([Json::object_with_order(out, out_order)])
      }
    "JOIN" =>
      if args.length() != 2 {
        raise UnknownFunction("JOIN")
      } else {
        let indices = execute_with_env(args[0], input, env)
        let rows = match input {
          Array(items) => items
          _ => [input]
        }
        let key_filter = args[1]
        let out = []
        for index_value in indices {
          match index_value {
            Object(index_obj) => {
              let joined = []
              for row in rows {
                let keys = execute_with_env(key_filter, row, env)
                for key in keys {
                  let object_key = index_object_key(key)
                  let value = match index_obj.get(object_key) {
                    Some(v) => v
                    None => Json::null()
                  }
                  joined.push(Json::array([row, value]))
                }
              }
              out.push(Json::array(joined))
            }
            _ => raise TypeError("JOIN/2 index must be an object")
          }
        }
        Some(out)
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
              let key_values = execute_with_env(key_filter, v, env)
              let key = by_key_from_values(key_values)
              keyed.push((key, v))
            }
            let sorted = sort_keyed_pairs(keyed)
            let out = []
            for kv in sorted {
              out.push(kv.1)
            }
            Some([Json::array(out)])
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
              let key_values = execute_with_env(key_filter, v, env)
              let key = by_key_from_values(key_values)
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
            Some([Json::array(groups)])
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
          Array(a) =>
            Some([minmax_by_json_array(a, args[0], env, choose_max=false)])
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
          Array(a) =>
            Some([minmax_by_json_array(a, args[0], env, choose_max=true)])
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
              let key_values = execute_with_env(key_filter, v, env)
              let key = by_key_from_values(key_values)
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
            Some([Json::array(out)])
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
        let needles = execute_with_env(args[0], input, env)
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
        Some(out)
      }
    _ => None
  }
}
