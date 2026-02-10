///|
fn builtin_ltrim_ascii_ws(s : String) -> String {
  let mut start = 0
  let end = s.length()
  for {
    if start < end && is_ascii_ws(s.unsafe_get(start).to_int().unsafe_to_char()) {
      start += 1
    } else {
      break
    }
  }
  s.view(start_offset=start, end_offset=end).to_string()
}

///|
fn builtin_rtrim_ascii_ws(s : String) -> String {
  let start = 0
  let mut end = s.length()
  for {
    if end > start &&
      is_ascii_ws(s.unsafe_get(end - 1).to_int().unsafe_to_char()) {
      end -= 1
    } else {
      break
    }
  }
  s.view(start_offset=start, end_offset=end).to_string()
}

///|
fn builtin_trim_ascii_ws(s : String) -> String {
  let left = builtin_ltrim_ascii_ws(s)
  builtin_rtrim_ascii_ws(left)
}

///|
fn eval_builtin(name : String, input : Json) -> Array[Json] raise EvalError {
  match name {
    "have_decnum" => [Json::boolean(true)]
    "abs" =>
      match input {
        Number(n, _) =>
          if n < 0.0 {
            [Json::number(-n)]
          } else {
            [Json::number(n)]
          }
        _ => raise TypeError(json_type_with_value(input) + " cannot be negated")
      }
    "trim" =>
      match input {
        String(s) => [Json::string(builtin_trim_ascii_ws(s))]
        _ => raise TypeError("trim input must be a string")
      }
    "ltrim" =>
      match input {
        String(s) => [Json::string(builtin_ltrim_ascii_ws(s))]
        _ => raise TypeError("trim input must be a string")
      }
    "rtrim" =>
      match input {
        String(s) => [Json::string(builtin_rtrim_ascii_ws(s))]
        _ => raise TypeError("trim input must be a string")
      }
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
          let out = []
          for k in object_keys_sorted(o) {
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
          for k in object_keys_sorted(o) {
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
    "paths" => collect_paths(input, [], None, Map::new())
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
          for kv in object_entries_sorted(o) {
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
    "tojson" => [Json::string(input.to_json_string())]
    "tonumber" =>
      match input {
        Number(_, _) => [input]
        String(s) => {
          let parsed_double = try? @strconv.parse_double(s)
          match parsed_double {
            Ok(n) => [json_number_value(n)]
            Err(_) =>
              try parse(s) catch {
                _ =>
                  raise TypeError(
                    json_type_with_value(input) +
                    " cannot be parsed as a number",
                  )
              } noraise {
                j =>
                  match j {
                    Number(_, _) => [j]
                    _ =>
                      raise TypeError(
                        json_type_with_value(input) +
                        " cannot be parsed as a number",
                      )
                  }
              }
          }
        }
        _ =>
          raise TypeError(
            json_type_with_value(input) + " cannot be parsed as a number",
          )
      }
    "fromjson" =>
      match input {
        String(s) => [parse_fromjson_string(s)]
        _ =>
          raise TypeError(
            json_type_with_value(input) + " only strings can be parsed",
          )
      }
    "first" => [nth_on_input(input, Json::number(0.0))]
    "last" => [nth_on_input(input, Json::number(-1.0))]
    "any" => {
      let values = collection_values(input)
      let mut ok = false
      for v in values {
        if is_truthy(v) {
          ok = true
          break
        }
      }
      [Json::boolean(ok)]
    }
    "all" => {
      let values = collection_values(input)
      let mut ok = true
      for v in values {
        if !is_truthy(v) {
          ok = false
          break
        }
      }
      [Json::boolean(ok)]
    }
    "flatten" => [flatten_default(input)]
    "transpose" => [transpose_json(input)]
    "to_entries" => [to_entries_json(input)]
    "from_entries" => [from_entries_json(input)]
    "sort" =>
      match input {
        Array(a) => [Json::array(sort_json_array(a))]
        _ =>
          raise TypeError(
            json_type_with_value(input) +
            " cannot be sorted, as it is not an array",
          )
      }
    "min" =>
      match input {
        Array(a) => [min_json_array(a)]
        _ =>
          raise TypeError(
            json_type_with_value(input) +
            " and " +
            json_type_with_value(input) +
            " cannot be iterated over",
          )
      }
    "max" =>
      match input {
        Array(a) => [max_json_array(a)]
        _ =>
          raise TypeError(
            json_type_with_value(input) +
            " and " +
            json_type_with_value(input) +
            " cannot be iterated over",
          )
      }
    "unique" =>
      match input {
        Array(a) => [Json::array(unique_sorted_json_array(sort_json_array(a)))]
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
        _ => raise TypeError("ascii_upcase input must be a string")
      }
    "ascii_downcase" =>
      match input {
        String(s) => [Json::string(ascii_downcase_string(s))]
        _ => raise TypeError("ascii_downcase input must be a string")
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
