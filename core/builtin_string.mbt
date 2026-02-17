///|
fn call_regex_flag_supported(flag : Char) -> Bool {
  flag == 'g' ||
  flag == 'i' ||
  flag == 'l' ||
  flag == 'm' ||
  flag == 'n' ||
  flag == 'p' ||
  flag == 's' ||
  flag == 'x'
}

///|
fn call_parse_regex_flags(
  name : String,
  value : Json,
) -> String raise EvalError {
  call_parse_regex_flags_with_options(name, value)
}

///|
fn call_parse_regex_flags_with_options(
  name : String,
  value : Json,
  append_global? : Bool = false,
) -> String raise EvalError {
  let base = match value {
    JNull => ""
    String(flags) => flags
    _ => raise TypeError(name + " flags must be a string or null")
  }
  let flags = if append_global && !split_regex_flag_enabled(base, 'g') {
    base + "g"
  } else {
    base
  }
  for flag in flags {
    if !call_regex_flag_supported(flag) {
      raise TypeError(flags + " is not a valid modifier string")
    }
  }
  flags
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
        let needles = execute_with_env(target, input, env)
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
        let needles = execute_with_env(target, input, env)
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
        let needles = execute_with_env(args[0], input, env)
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
        Some(out)
      }
    "trimstr" =>
      if args.length() != 1 {
        raise UnknownFunction("trimstr")
      } else {
        let needles = execute_with_env(args[0], input, env)
        let out = []
        for needle in needles {
          match (input, needle) {
            (String(h), String(n)) =>
              if n.length() == 0 {
                out.push(Json::string(""))
              } else {
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
        let needles = execute_with_env(args[0], input, env)
        let out = []
        for needle in needles {
          match (input, needle) {
            (String(h), String(n)) =>
              if n.length() == 0 {
                out.push(Json::string(""))
              } else if h.has_suffix(n) {
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
            _ => raise TypeError("endswith() requires string inputs")
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
            let seps = execute_with_env(args[0], input, env)
            let out = []
            for sep in seps {
              out.push(join_values(a, sep))
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
        let seps = execute_with_env(args[0], input, env)
        let out = []
        for sep in seps {
          match (input, sep) {
            (String(s), String(d)) => out.push(Json::array(split_string(s, d)))
            _ => raise TypeError("split input and separator must be strings")
          }
        }
        Some(out)
      } else if args.length() == 2 {
        let patterns = execute_with_env(args[0], input, env)
        let flag_values = execute_with_env(args[1], input, env)
        let out = []
        for pattern_value in patterns {
          match pattern_value {
            String(pattern) =>
              for flag_value in flag_values {
                let flags = call_parse_regex_flags_with_options(
                  "split",
                  flag_value,
                  append_global=true,
                )
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
        let patterns = execute_with_env(args[0], input, env)
        let flag_values = if args.length() == 2 {
          execute_with_env(args[1], input, env)
        } else {
          [Json::null()]
        }
        let out = []
        for pattern_value in patterns {
          match pattern_value {
            String(pattern) =>
              for flag_value in flag_values {
                let flags = call_parse_regex_flags_with_options(
                  "splits",
                  flag_value,
                  append_global=true,
                )
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
    "test" =>
      if args.length() == 1 || args.length() == 2 {
        let patterns = execute_with_env(args[0], input, env)
        let flag_values = if args.length() == 2 {
          execute_with_env(args[1], input, env)
        } else {
          [Json::null()]
        }
        let out = []
        for pattern_value in patterns {
          match pattern_value {
            String(pattern) =>
              for flag_value in flag_values {
                let flags = call_parse_regex_flags("test", flag_value)
                match input {
                  String(s) =>
                    out.push(Json::boolean(regex_has_match(s, pattern, flags)))
                  _ =>
                    raise TypeError(
                      json_type_with_value(input) +
                      " cannot be matched, as it is not a string",
                    )
                }
              }
            _ =>
              raise TypeError(
                json_type_name(pattern_value) + " not a string or array",
              )
          }
        }
        Some(out)
      } else {
        raise UnknownFunction("test")
      }
    "scan" =>
      if args.length() == 1 || args.length() == 2 {
        let patterns = execute_with_env(args[0], input, env)
        let flag_values = if args.length() == 2 {
          execute_with_env(args[1], input, env)
        } else {
          [Json::null()]
        }
        let out = []
        for pattern_value in patterns {
          match pattern_value {
            String(pattern) =>
              for flag_value in flag_values {
                let flags = call_parse_regex_flags("scan", flag_value)
                match input {
                  String(s) =>
                    for matched in regex_scan_strings(s, pattern, flags) {
                      out.push(matched)
                    }
                  _ =>
                    raise TypeError(
                      json_type_with_value(input) +
                      " cannot be matched, as it is not a string",
                    )
                }
              }
            _ =>
              raise TypeError(
                json_type_name(pattern_value) + " not a string or array",
              )
          }
        }
        Some(out)
      } else {
        raise UnknownFunction("scan")
      }
    "match" =>
      if args.length() == 1 || args.length() == 2 {
        let patterns = execute_with_env(args[0], input, env)
        let flag_values = if args.length() == 2 {
          execute_with_env(args[1], input, env)
        } else {
          [Json::null()]
        }
        let out = []
        for pattern_value in patterns {
          match pattern_value {
            String(pattern) =>
              for flag_value in flag_values {
                let flags = call_parse_regex_flags("match", flag_value)
                match input {
                  String(s) =>
                    for matched in regex_match_objects(s, pattern, flags) {
                      out.push(matched)
                    }
                  _ =>
                    raise TypeError(
                      json_type_with_value(input) +
                      " cannot be matched, as it is not a string",
                    )
                }
              }
            _ =>
              raise TypeError(
                json_type_name(pattern_value) + " not a string or array",
              )
          }
        }
        Some(out)
      } else {
        raise UnknownFunction("match")
      }
    "capture" =>
      if args.length() == 1 || args.length() == 2 {
        let patterns = execute_with_env(args[0], input, env)
        let flag_values = if args.length() == 2 {
          execute_with_env(args[1], input, env)
        } else {
          [Json::null()]
        }
        let out = []
        for pattern_value in patterns {
          match pattern_value {
            String(pattern) =>
              for flag_value in flag_values {
                let flags = call_parse_regex_flags("capture", flag_value)
                match input {
                  String(s) =>
                    if regex_has_match(s, pattern, flags) {
                      out.push(Json::object(Map::new()))
                    } else {
                      ()
                    }
                  _ =>
                    raise TypeError(
                      json_type_with_value(input) +
                      " cannot be matched, as it is not a string",
                    )
                }
              }
            _ =>
              raise TypeError(
                json_type_name(pattern_value) + " not a string or array",
              )
          }
        }
        Some(out)
      } else {
        raise UnknownFunction("capture")
      }
    "sub" =>
      if args.length() == 2 || args.length() == 3 {
        let patterns = execute_with_env(args[0], input, env)
        let replacements = execute_with_env(args[1], input, env)
        let flag_values = if args.length() == 3 {
          execute_with_env(args[2], input, env)
        } else {
          [Json::null()]
        }
        let out = []
        for pattern_value in patterns {
          match pattern_value {
            String(pattern) =>
              for replacement_value in replacements {
                match replacement_value {
                  String(replacement) =>
                    for flag_value in flag_values {
                      let flags = call_parse_regex_flags("sub", flag_value)
                      let global = split_regex_flag_enabled(flags, 'g')
                      match input {
                        String(s) =>
                          out.push(
                            Json::string(
                              regex_substitute_string(
                                s,
                                pattern,
                                replacement,
                                flags,
                                global~,
                              ),
                            ),
                          )
                        _ =>
                          raise TypeError(
                            json_type_with_value(input) +
                            " cannot be matched, as it is not a string",
                          )
                      }
                    }
                  _ => raise TypeError("sub replacement must be a string")
                }
              }
            _ =>
              raise TypeError(
                json_type_name(pattern_value) + " not a string or array",
              )
          }
        }
        Some(out)
      } else {
        raise UnknownFunction("sub")
      }
    "gsub" =>
      if args.length() == 2 || args.length() == 3 {
        let patterns = execute_with_env(args[0], input, env)
        let replacements = execute_with_env(args[1], input, env)
        let flag_values = if args.length() == 3 {
          execute_with_env(args[2], input, env)
        } else {
          [Json::null()]
        }
        let out = []
        for pattern_value in patterns {
          match pattern_value {
            String(pattern) =>
              for replacement_value in replacements {
                match replacement_value {
                  String(replacement) =>
                    for flag_value in flag_values {
                      let flags = call_parse_regex_flags_with_options(
                        "gsub",
                        flag_value,
                        append_global=true,
                      )
                      let global = split_regex_flag_enabled(flags, 'g')
                      match input {
                        String(s) =>
                          out.push(
                            Json::string(
                              regex_substitute_string(
                                s,
                                pattern,
                                replacement,
                                flags,
                                global~,
                              ),
                            ),
                          )
                        _ =>
                          raise TypeError(
                            json_type_with_value(input) +
                            " cannot be matched, as it is not a string",
                          )
                      }
                    }
                  _ => raise TypeError("gsub replacement must be a string")
                }
              }
            _ =>
              raise TypeError(
                json_type_name(pattern_value) + " not a string or array",
              )
          }
        }
        Some(out)
      } else {
        raise UnknownFunction("gsub")
      }
    "index" =>
      if args.length() != 1 {
        raise UnknownFunction("index")
      } else {
        let needles = execute_with_env(args[0], input, env)
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
        let needles = execute_with_env(args[0], input, env)
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
        let needles = execute_with_env(args[0], input, env)
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
