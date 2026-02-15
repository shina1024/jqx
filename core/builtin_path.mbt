///|
fn call_parse_slice_index(
  value : Json,
  end? : Bool = false,
) -> Int? raise EvalError {
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
        let rounded = if end { n.ceil() } else { n.floor() }
        let index = if rounded > int_max.to_double() {
          int_max
        } else if rounded < int_min.to_double() {
          int_min
        } else {
          rounded.to_int()
        }
        Some(index)
      }
    _ => raise TypeError("Array/string slice indices must be integers")
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
fn builtin_call_path(
  name : String,
  args : Array[Filter],
  input : Json,
  env : Map[String, Json],
) -> Array[Json]? raise EvalError {
  match name {
    "getpath" =>
      if args.length() != 1 {
        raise UnknownFunction("getpath")
      } else {
        let paths = execute_with_env(args[0], input, env)
        let out = []
        for path in paths {
          out.push(getpath_on_input(input, path))
        }
        Some(out)
      }
    "setpath" =>
      if args.length() != 2 {
        raise UnknownFunction("setpath")
      } else {
        let values = execute_with_env(args[1], input, env)
        if values.length() == 0 {
          Some([])
        } else {
          let paths = execute_with_env(args[0], input, env)
          let out = []
          for value in values {
            for path in paths {
              let parts = normalize_setpath_arg(path)
              out.push(setpath_on_input(input, parts, value))
            }
          }
          Some(out)
        }
      }
    "delpaths" =>
      if args.length() != 1 {
        raise UnknownFunction("delpaths")
      } else {
        let pathsets = execute_with_env(args[0], input, env)
        let out = []
        for pathset in pathsets {
          let normalized = normalize_delpaths_arg(pathset)
          out.push(delpaths_on_input(input, normalized))
        }
        Some(out)
      }
    "path" =>
      if args.length() != 1 {
        raise UnknownFunction("path")
      } else {
        Some(path_expression(args[0], input, env))
      }
    "_slice" =>
      if args.length() != 2 {
        raise UnknownFunction("_slice")
      } else {
        let starts = execute_with_env(args[0], input, env)
        let ends = execute_with_env(args[1], input, env)
        let out = []
        for start_value in starts {
          let start = call_parse_slice_index(start_value)
          for end_value in ends {
            let end = call_parse_slice_index(end_value, end=true)
            for v in execute_slice(start, end, input, optional=false) {
              out.push(v)
            }
          }
        }
        Some(out)
      }
    "_set_slice" =>
      if args.length() != 3 {
        raise UnknownFunction("_set_slice")
      } else {
        let starts = execute_with_env(args[0], input, env)
        let ends = execute_with_env(args[1], input, env)
        let values = execute_with_env(args[2], input, env)
        let out = []
        for start_value in starts {
          let start = call_parse_slice_index(start_value)
          for end_value in ends {
            let end = call_parse_slice_index(end_value, end=true)
            for value in values {
              out.push(set_slice_on_input(input, start, end, value))
            }
          }
        }
        Some(out)
      }
    "del" =>
      if args.length() == 0 {
        raise UnknownFunction("del")
      } else {
        let normalized_paths = []
        for arg in args {
          for path_json in path_expression(arg, input, env) {
            match path_json {
              Array(parts) => normalized_paths.push(parts)
              _ => raise TypeError("Path must be specified as an array")
            }
          }
        }
        if normalized_paths.length() == 0 {
          Some([input])
        } else {
          Some([delpaths_on_input(input, normalized_paths)])
        }
      }
    "pick" =>
      if args.length() == 0 {
        raise UnknownFunction("pick")
      } else {
        let normalized_paths = []
        for arg in args {
          let path_values = try path_expression(arg, input, env) catch {
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
        Some([out])
      }
    "paths" =>
      if args.length() != 1 {
        raise UnknownFunction("paths")
      } else {
        Some(collect_paths(input, [], Some(args[0]), env))
      }
    _ => None
  }
}
