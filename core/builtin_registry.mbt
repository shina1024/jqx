///|
fn builtin_list() -> Array[Value] {
  let names = [
    "@base64/0", "@base64d/0", "@csv/0", "@html/0", "@json/0", "@sh/0", "@text/0",
    "@tsv/0", "@uri/0", "@urid/0", "abs/0", "add/0", "all/0", "any/0", "ascii_downcase/0",
    "ascii_upcase/0", "atan/0", "builtins/0", "capture/1", "capture/2", "combinations/0",
    "cos/0", "debug/0", "endswith/1", "env/0", "error/0", "error/1", "explode/0",
    "fabs/0", "first/0", "flatten/0", "floor/0", "from_entries/0", "fromdate/0",
    "fromjson/0", "gmtime/0", "group_by/1", "gsub/2", "gsub/3", "implode/0", "infinite/0",
    "input/0", "inside/1", "isfinite/0", "isinfinite/0", "isempty/0", "isnan/0",
    "join/1", "keys/0", "last/0", "length/0", "localtime/0", "log2/0", "ltrim/0",
    "map/1", "map_values/1", "match/1", "match/2", "max/0", "min/0", "mktime/0",
    "modulemeta/0", "nan/0", "now/0", "paths/0", "pow/2", "reverse/0", "round/0",
    "rtrim/0", "scan/1", "scan/2", "sin/0", "sort/0", "split/1", "split/2", "splits/1",
    "splits/2", "sqrt/0", "startswith/1", "strflocaltime/1", "strftime/1", "strptime/1",
    "sub/2", "sub/3", "test/1", "test/2", "to_entries/0", "toboolean/0", "tojson/0",
    "tonumber/0", "tostream/0", "tostring/0", "utf8bytelength/0", "transpose/0",
    "trim/0", "type/0", "unique/0", "until/2", "values/0", "walk/1", "while/2", "recurse/0",
    "recurse/1", "recurse/2",
  ]
  let out = []
  for name in names {
    out.push(Value::string(name))
  }
  out
}

///|
fn dispatch_nullary_builtin(
  runtime : RuntimeContext,
  name : String,
  input : Value,
) -> Array[Value] raise EvalError {
  match name {
    "have_decnum" => [Value::boolean(false)]
    "modulemeta" =>
      match input {
        String(name) => raise TypeError("module not found: " + name)
        _ =>
          [
            Value::object_from_entries([
              ("deps", Value::array([])),
              ("defs", Value::object(Map([]))),
            ]),
          ]
      }
    "env" => [Value::object(Map([]))]
    "builtins" => [Value::array(builtin_list())]
    "now" => [json_number_value(@env.now().to_double() / 1000.0)]
    "gmtime" => [gmtime_json(input)]
    "localtime" => [gmtime_json(input)]
    "mktime" => [mktime_json(input)]
    "nan" => [Value::number(@double.infinity - @double.infinity)]
    "infinite" => [Value::number(@double.infinity)]
    "isnan" =>
      match input {
        Number(n, _) => [Value::boolean(n != n)]
        _ => [Value::boolean(false)]
      }
    "isfinite" =>
      match input {
        Number(n, _) =>
          [
            Value::boolean(
              n == n && n != @double.infinity && n != @double.neg_infinity,
            ),
          ]
        _ => [Value::boolean(false)]
      }
    "isinfinite" =>
      match input {
        Number(n, _) =>
          [Value::boolean(n == @double.infinity || n == @double.neg_infinity)]
        _ => [Value::boolean(false)]
      }
    "toboolean" => [builtin_to_boolean(input)]
    "floor" =>
      match input {
        Number(n, _) => [json_number_value(n.floor())]
        _ =>
          raise TypeError(
            json_type_with_value(input) + " only numbers have floor",
          )
      }
    "sqrt" =>
      match input {
        Number(n, _) => [json_number_value(n.sqrt())]
        _ =>
          raise TypeError(
            json_type_with_value(input) + " only numbers have sqrt",
          )
      }
    "log2" =>
      match input {
        Number(n, _) => [json_number_value(@math.log2(n))]
        _ =>
          raise TypeError(
            json_type_with_value(input) + " only numbers have log2",
          )
      }
    "round" =>
      match input {
        Number(n, _) => [json_number_value(@math.round(n))]
        _ =>
          raise TypeError(
            json_type_with_value(input) + " only numbers have round",
          )
      }
    "sin" =>
      match input {
        Number(n, _) => [json_number_value(@math.sin(n))]
        _ =>
          raise TypeError(
            json_type_with_value(input) + " only numbers have sin",
          )
      }
    "cos" =>
      match input {
        Number(n, _) => [json_number_value(@math.cos(n))]
        _ =>
          raise TypeError(
            json_type_with_value(input) + " only numbers have cos",
          )
      }
    "atan" =>
      match input {
        Number(n, _) => [json_number_value(@math.atan(n))]
        _ =>
          raise TypeError(
            json_type_with_value(input) + " only numbers have atan",
          )
      }
    "utf8bytelength" =>
      match input {
        String(s) => [Value::number(builtin_utf8_byte_length(s).to_double())]
        _ =>
          raise TypeError(
            json_type_with_value(input) + " only strings have UTF-8 byte length",
          )
      }
    "error" => raise Thrown(input)
    "abs" =>
      match input {
        Number(n, repr) =>
          if n == @double.infinity || n == @double.neg_infinity || n != n {
            [json_number_value(builtin_fabs_number(n))]
          } else if n < 0.0 {
            match repr {
              Some(s) =>
                if s.has_prefix("-") {
                  [
                    Value::number(
                      -n,
                      repr=s
                        .view(start_offset=1, end_offset=s.length())
                        .to_owned(),
                    ),
                  ]
                } else {
                  [json_number_value(-n)]
                }
              None => [json_number_value(-n)]
            }
          } else if builtin_is_negative_zero(n) || repr == Some("-0") {
            [Value::number(-0.0, repr="-0")]
          } else {
            [Value::number(n, repr?)]
          }
        JNull | JTrue | JFalse =>
          raise TypeError(json_type_with_value(input) + " cannot be negated")
        _ => [input]
      }
    "fabs" =>
      match input {
        Number(n, _) => [json_number_value(builtin_fabs_number(n))]
        _ => raise TypeError(json_type_with_value(input) + " cannot be negated")
      }
    "trim" =>
      match input {
        String(s) => [Value::string(builtin_trim_ascii_ws(s))]
        _ => raise TypeError("trim input must be a string")
      }
    "debug" => [input, Value::array([Value::string("DEBUG:"), input])]
    "input" => raise TypeError("break")
    "ltrim" =>
      match input {
        String(s) => [Value::string(builtin_ltrim_ascii_ws(s))]
        _ => raise TypeError("trim input must be a string")
      }
    "rtrim" =>
      match input {
        String(s) => [Value::string(builtin_rtrim_ascii_ws(s))]
        _ => raise TypeError("trim input must be a string")
      }
    "length" =>
      match input {
        Array(a) => [Value::number(a.length().to_double())]
        Object(o) => [Value::number(o.length().to_double())]
        String(s) => [Value::number(s.length().to_double())]
        JNull => [Value::number(0.0)]
        Number(n, _) =>
          if n < 0.0 {
            [Value::number(-n)]
          } else {
            [Value::number(n)]
          }
        _ =>
          raise TypeError("Cannot get length of " + json_type_with_value(input))
      }
    "type" => [Value::string(json_type_name(input))]
    "keys" =>
      match input {
        Object(o) => {
          let out = []
          for k in object_keys_lex_sorted(o) {
            out.push(Value::string(k))
          }
          [Value::array(out)]
        }
        Array(a) => {
          let out = []
          for i in 0..<a.length() {
            out.push(Value::number(i.to_double()))
          }
          [Value::array(out)]
        }
        _ => raise TypeError(json_type_with_value(input) + " has no keys")
      }
    "keys_unsorted" =>
      match input {
        Object(o) => {
          let out = []
          for k in object_keys_sorted(o) {
            out.push(Value::string(k))
          }
          [Value::array(out)]
        }
        Array(a) => {
          let out = []
          for i in 0..<a.length() {
            out.push(Value::number(i.to_double()))
          }
          [Value::array(out)]
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
    "paths" => collect_paths(runtime, input, [], None, Map([]))
    "add" =>
      match input {
        Array(a) => {
          let mut acc = Value::null()
          for v in a {
            acc = json_add_pair(acc, v)
          }
          [acc]
        }
        Object(o) => {
          let mut acc = Value::null()
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
        Number(n, _) => [Value::string(Value::number(n).to_json_string())]
        _ => [Value::string(input.to_json_string())]
      }
    "@text" => [Value::string(format_filter_input_string(input))]
    "@json" => [Value::string(input.to_json_string())]
    "@csv" => [Value::string(format_csv_row(input))]
    "@tsv" => [Value::string(format_tsv_row(input))]
    "@html" =>
      [Value::string(format_html_escape(format_filter_input_string(input)))]
    "@sh" => [Value::string(format_sh_quote(format_filter_input_string(input)))]
    "@uri" =>
      [Value::string(format_uri_encode(format_filter_input_string(input)))]
    "@urid" => {
      let s = format_filter_input_string(input)
      match format_uri_decode(s) {
        Some(decoded) => [Value::string(decoded)]
        None =>
          raise TypeError(
            format_filter_string_type_with_value(s) +
            " is not a valid uri encoding",
          )
      }
    }
    "@base64" =>
      [Value::string(format_base64_encode(format_filter_input_string(input)))]
    "@base64d" => {
      let s = format_filter_input_string(input)
      match format_base64_decode(s) {
        Ok(bytes) => [Value::string(utf8_decode_bytes_lossy(bytes))]
        Err(InvalidData) =>
          raise TypeError(
            format_filter_string_type_with_preview(s) +
            " is not valid base64 data",
          )
        Err(TrailingByte) =>
          raise TypeError(
            format_filter_string_type_with_preview(s) +
            " trailing base64 byte found",
          )
      }
    }
    "tojson" =>
      match input {
        Number(n, _) => [Value::string(Value::number(n).to_json_string())]
        _ => [Value::string(input.to_json_string())]
      }
    "tostream" => [Value::array([Value::array([]), input])]
    "tonumber" =>
      match input {
        Number(_, _) => [input]
        String(s) => {
          let parse_input = s
          if builtin_has_outer_trim_ws(parse_input) {
            raise TypeError(
              json_type_with_value(input) + " cannot be parsed as a number",
            )
          }
          try @string.parse_double(parse_input) catch {
            _ =>
              try parse(parse_input) catch {
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
          } noraise {
            n => [json_number_value(n)]
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
    "first" => [nth_on_input(input, Value::number(0.0))]
    "last" => [nth_on_input(input, Value::number(-1.0))]
    "any" => {
      let values = collection_values(input)
      let mut ok = false
      for v in values {
        if is_truthy(v) {
          ok = true
          break
        }
      }
      [Value::boolean(ok)]
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
      [Value::boolean(ok)]
    }
    "flatten" => [flatten_default(input)]
    "combinations" =>
      match input {
        Array(groups_raw) => {
          let groups = []
          for entry in groups_raw {
            match entry {
              Array(group) => groups.push(group)
              _ =>
                raise TypeError("combinations input must be an array of arrays")
            }
          }
          combinations_from_groups(groups)
        }
        _ => raise TypeError("combinations input must be an array")
      }
    "transpose" => [transpose_json(input)]
    "to_entries" => [to_entries_json(input)]
    "from_entries" => [from_entries_json(input)]
    "sort" =>
      match input {
        Array(a) => [Value::array(sort_json_array(a))]
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
        Array(a) => [Value::array(unique_sorted_json_array(sort_json_array(a)))]
        _ =>
          raise TypeError(
            json_type_with_value(input) +
            " cannot be sorted, as it is not an array",
          )
      }
    "explode" =>
      match input {
        String(s) => [Value::array(explode_string(s))]
        _ => raise TypeError("explode input must be a string")
      }
    "ascii_upcase" =>
      match input {
        String(s) => [Value::string(ascii_upcase_string(s))]
        _ => raise TypeError("ascii_upcase input must be a string")
      }
    "ascii_downcase" =>
      match input {
        String(s) => [Value::string(ascii_downcase_string(s))]
        _ => raise TypeError("ascii_downcase input must be a string")
      }
    "implode" =>
      match input {
        Array(a) => [Value::string(implode_array(a))]
        _ => raise TypeError("implode input must be an array")
      }
    "fromdate" =>
      match input {
        String(s) =>
          match parse_rfc3339_utc_seconds(s) {
            Some(seconds) => [json_number_value(seconds)]
            None =>
              raise TypeError(
                "fromdate input must be RFC3339 UTC (YYYY-MM-DDTHH:MM:SSZ)",
              )
          }
        _ => raise TypeError("fromdate input must be a string")
      }
    "reverse" =>
      match input {
        Array(a) => {
          let out = []
          for i in 0..<a.length() {
            out.push(a[a.length() - 1 - i])
          }
          [Value::array(out)]
        }
        JNull => [Value::array([])]
        Number(n, _) =>
          if n == 0.0 {
            [Value::array([])]
          } else {
            index_type_error(input, Value::number(0.0))
          }
        String(s) =>
          if s.length() == 0 {
            [Value::array([])]
          } else {
            index_type_error(input, Value::number((s.length() - 1).to_double()))
          }
        Object(o) =>
          if o.length() == 0 {
            [Value::array([])]
          } else {
            index_type_error(input, Value::number(0.0))
          }
        JTrue | JFalse =>
          raise TypeError(json_type_with_value(input) + " has no length")
      }
    "recurse" => {
      let out = []
      append_recurse_values(input, out)
      out
    }
    _ => raise UnknownFunction(name)
  }
}
