///|
fn call_parse_regex_flags(
  name : String,
  value : Json,
) -> String raise EvalError {
  match value {
    JNull => ""
    String(flags) => flags
    _ => raise TypeError(name + " flags must be a string or null")
  }
}

///|
fn builtin_call_string(
  name : String,
  args : Array[Filter],
  input : Json,
  env : Map[String, Json],
) -> Array[Json]? raise EvalError {
  match name {
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
        Some(out)
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
        Some(out)
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
        Some(out)
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
        Some(out)
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
        Some(out)
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
            Some(out)
          }
          _ =>
            raise TypeError(
              "Cannot iterate over " + json_type_with_value(input),
            )
        }
      }
    "split" =>
      if args.length() == 1 {
        let seps = eval_with_env(args[0], input, env)
        let out = []
        for sep in seps {
          match (input, sep) {
            (String(s), String(d)) => out.push(Json::array(split_string(s, d)))
            _ => raise TypeError("split input and separator must be strings")
          }
        }
        Some(out)
      } else if args.length() == 2 {
        let patterns = eval_with_env(args[0], input, env)
        let flag_values = eval_with_env(args[1], input, env)
        let out = []
        for pattern_value in patterns {
          match pattern_value {
            String(pattern) =>
              for flag_value in flag_values {
                let flags = call_parse_regex_flags("split", flag_value)
                match input {
                  String(s) =>
                    out.push(
                      Json::array(split_string_regex_tokens(s, pattern, flags)),
                    )
                  _ =>
                    raise TypeError("split input and separator must be strings")
                }
              }
            _ => raise TypeError("split input and separator must be strings")
          }
        }
        Some(out)
      } else {
        raise UnknownFunction("split")
      }
    "splits" =>
      if args.length() == 1 || args.length() == 2 {
        let patterns = eval_with_env(args[0], input, env)
        let flag_values = if args.length() == 2 {
          eval_with_env(args[1], input, env)
        } else {
          [Json::null()]
        }
        let out = []
        for pattern_value in patterns {
          match pattern_value {
            String(pattern) =>
              for flag_value in flag_values {
                let flags = call_parse_regex_flags("splits", flag_value)
                match input {
                  String(s) =>
                    for part in split_string_regex_tokens(s, pattern, flags) {
                      out.push(part)
                    }
                  _ =>
                    raise TypeError(
                      "splits input and separator must be strings",
                    )
                }
              }
            _ => raise TypeError("splits input and separator must be strings")
          }
        }
        Some(out)
      } else {
        raise UnknownFunction("splits")
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
        Some(out)
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
        Some(out)
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
        Some(out)
      }
    _ => None
  }
}
