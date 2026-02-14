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
fn builtin_utf8_byte_length(s : String) -> Int {
  let mut total = 0
  for ch in s {
    let code = ch.to_int()
    if code <= 0x7f {
      total += 1
    } else if code <= 0x7ff {
      total += 2
    } else if code <= 0xffff {
      total += 3
    } else {
      total += 4
    }
  }
  total
}

///|
fn builtin_to_boolean(input : Json) -> Json raise EvalError {
  match input {
    JTrue | JFalse => input
    String(s) =>
      if s == "true" {
        Json::boolean(true)
      } else if s == "false" {
        Json::boolean(false)
      } else {
        raise TypeError(
          json_type_with_value(input) + " cannot be parsed as a boolean",
        )
      }
    _ =>
      raise TypeError(
        json_type_with_value(input) + " cannot be parsed as a boolean",
      )
  }
}

///|
fn builtin_fabs_number(n : Double) -> Double {
  if n == 0.0 {
    0.0
  } else if n < 0.0 {
    -n
  } else {
    n
  }
}

///|
fn format_filter_input_string(input : Json) -> String {
  match input {
    String(s) => s
    _ => input.to_json_string()
  }
}

///|
fn format_filter_string_preview(s : String) -> String {
  let max_preview = 10
  if s.length() <= max_preview {
    s
  } else {
    s.view(start_offset=0, end_offset=max_preview).to_string() + "..."
  }
}

///|
fn format_filter_string_type_with_value(s : String) -> String {
  "string (" + Json::string(s).to_json_string() + ")"
}

///|
fn format_filter_string_type_with_preview(s : String) -> String {
  "string (" +
  Json::string(format_filter_string_preview(s)).to_json_string() +
  ")"
}

///|
fn hex_upper_digit(d : Int) -> Char {
  if d < 10 {
    (d + '0'.to_int()).unsafe_to_char()
  } else {
    (d - 10 + 'A'.to_int()).unsafe_to_char()
  }
}

///|
fn append_utf8_codepoint_bytes(out : Array[Int], code : Int) -> Unit {
  if code <= 0x7F {
    out.push(code)
  } else if code <= 0x7FF {
    out.push(0xC0 | (code >> 6))
    out.push(0x80 | (code & 0x3F))
  } else if code <= 0xFFFF {
    out.push(0xE0 | (code >> 12))
    out.push(0x80 | ((code >> 6) & 0x3F))
    out.push(0x80 | (code & 0x3F))
  } else {
    out.push(0xF0 | (code >> 18))
    out.push(0x80 | ((code >> 12) & 0x3F))
    out.push(0x80 | ((code >> 6) & 0x3F))
    out.push(0x80 | (code & 0x3F))
  }
}

///|
fn utf8_bytes_of_string(s : String) -> Array[Int] {
  let out = []
  for ch in s {
    append_utf8_codepoint_bytes(out, ch.to_int())
  }
  out
}

///|
fn is_utf8_continuation_byte(b : Int) -> Bool {
  b >= 0x80 && b <= 0xBF
}

///|
fn utf8_decode_next_strict(bytes : Array[Int], i : Int) -> (Int, Int)? {
  guard i < bytes.length() else { return None }
  let b0 = bytes[i]
  if b0 <= 0x7F {
    return Some((b0, 1))
  }
  if b0 < 0xC2 || b0 > 0xF4 {
    return None
  }
  if b0 <= 0xDF {
    guard i + 1 < bytes.length() else { return None }
    let b1 = bytes[i + 1]
    guard is_utf8_continuation_byte(b1) else { return None }
    let code = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
    return Some((code, 2))
  }
  if b0 <= 0xEF {
    guard i + 2 < bytes.length() else { return None }
    let b1 = bytes[i + 1]
    let b2 = bytes[i + 2]
    guard is_utf8_continuation_byte(b1) && is_utf8_continuation_byte(b2) else {
      return None
    }
    if b0 == 0xE0 && b1 < 0xA0 {
      return None
    }
    if b0 == 0xED && b1 > 0x9F {
      return None
    }
    let code = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
    return Some((code, 3))
  }
  guard i + 3 < bytes.length() else { return None }
  let b1 = bytes[i + 1]
  let b2 = bytes[i + 2]
  let b3 = bytes[i + 3]
  guard is_utf8_continuation_byte(b1) &&
    is_utf8_continuation_byte(b2) &&
    is_utf8_continuation_byte(b3) else {
    return None
  }
  if b0 == 0xF0 && b1 < 0x90 {
    return None
  }
  if b0 == 0xF4 && b1 > 0x8F {
    return None
  }
  let code = ((b0 & 0x07) << 18) |
    ((b1 & 0x3F) << 12) |
    ((b2 & 0x3F) << 6) |
    (b3 & 0x3F)
  Some((code, 4))
}

///|
fn utf8_decode_bytes_strict(bytes : Array[Int]) -> String? {
  let buf = StringBuilder::new()
  let mut i = 0
  for {
    if i >= bytes.length() {
      break
    }
    match utf8_decode_next_strict(bytes, i) {
      Some((code, width)) => {
        buf.write_char(code.unsafe_to_char())
        i += width
      }
      None => return None
    }
  }
  Some(buf.to_string())
}

///|
fn utf8_decode_bytes_lossy(bytes : Array[Int]) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  for {
    if i >= bytes.length() {
      break
    }
    match utf8_decode_next_strict(bytes, i) {
      Some((code, width)) => {
        buf.write_char(code.unsafe_to_char())
        i += width
      }
      None => {
        buf.write_char('\u{fffd}')
        i += 1
      }
    }
  }
  buf.to_string()
}

///|
fn is_uri_unreserved_byte(b : Int) -> Bool {
  (b >= 'A'.to_int() && b <= 'Z'.to_int()) ||
  (b >= 'a'.to_int() && b <= 'z'.to_int()) ||
  (b >= '0'.to_int() && b <= '9'.to_int()) ||
  b == '-'.to_int() ||
  b == '_'.to_int() ||
  b == '.'.to_int() ||
  b == '~'.to_int()
}

///|
fn uri_hex_nibble(ch : Char) -> Int? {
  if ch is ('0'..='9') {
    Some(ch.to_int() - '0'.to_int())
  } else if ch is ('A'..='F') {
    Some(ch.to_int() - 'A'.to_int() + 10)
  } else if ch is ('a'..='f') {
    Some(ch.to_int() - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn format_uri_encode(input : String) -> String {
  let bytes = utf8_bytes_of_string(input)
  let buf = StringBuilder::new()
  for b in bytes {
    if is_uri_unreserved_byte(b) {
      buf.write_char(b.unsafe_to_char())
    } else {
      buf.write_char('%')
      buf.write_char(hex_upper_digit((b >> 4) & 0xF))
      buf.write_char(hex_upper_digit(b & 0xF))
    }
  }
  buf.to_string()
}

///|
fn format_uri_decode(input : String) -> String? {
  let bytes = []
  let mut i = 0
  for {
    if i >= input.length() {
      break
    }
    let ch = input.unsafe_get(i).to_int().unsafe_to_char()
    if ch == '%' {
      guard i + 2 < input.length() else { return None }
      let h1 = input.unsafe_get(i + 1).to_int().unsafe_to_char()
      let h2 = input.unsafe_get(i + 2).to_int().unsafe_to_char()
      match (uri_hex_nibble(h1), uri_hex_nibble(h2)) {
        (Some(d1), Some(d2)) => {
          bytes.push((d1 << 4) | d2)
          i += 3
        }
        _ => return None
      }
    } else {
      append_utf8_codepoint_bytes(bytes, ch.to_int())
      i += 1
    }
  }
  utf8_decode_bytes_strict(bytes)
}

///|
fn base64_value_of_char(ch : Char) -> Int? {
  if ch is ('A'..='Z') {
    Some(ch.to_int() - 'A'.to_int())
  } else if ch is ('a'..='z') {
    Some(ch.to_int() - 'a'.to_int() + 26)
  } else if ch is ('0'..='9') {
    Some(ch.to_int() - '0'.to_int() + 52)
  } else if ch == '+' {
    Some(62)
  } else if ch == '/' {
    Some(63)
  } else {
    None
  }
}

///|
fn format_base64_encode(input : String) -> String {
  let bytes = utf8_bytes_of_string(input)
  let alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let buf = StringBuilder::new()
  let mut i = 0
  for {
    if i >= bytes.length() {
      break
    }
    let b0 = bytes[i]
    let has_b1 = i + 1 < bytes.length()
    let has_b2 = i + 2 < bytes.length()
    let b1 = if has_b1 { bytes[i + 1] } else { 0 }
    let b2 = if has_b2 { bytes[i + 2] } else { 0 }
    let v0 = b0 >> 2
    let v1 = ((b0 & 0x03) << 4) | (b1 >> 4)
    let v2 = ((b1 & 0x0F) << 2) | (b2 >> 6)
    let v3 = b2 & 0x3F
    buf.write_char(alpha.unsafe_get(v0).to_int().unsafe_to_char())
    buf.write_char(alpha.unsafe_get(v1).to_int().unsafe_to_char())
    if has_b1 {
      buf.write_char(alpha.unsafe_get(v2).to_int().unsafe_to_char())
    } else {
      buf.write_char('=')
    }
    if has_b2 {
      buf.write_char(alpha.unsafe_get(v3).to_int().unsafe_to_char())
    } else {
      buf.write_char('=')
    }
    i += 3
  }
  buf.to_string()
}

///|
priv enum Base64DecodeError {
  InvalidData
  TrailingByte
}

///|
fn format_base64_decode(
  input : String,
) -> Result[Array[Int], Base64DecodeError] {
  let chars = []
  for ch in input {
    chars.push(ch)
  }
  let out = []
  let len = chars.length()
  let full_groups = len / 4
  for g in 0..<full_groups {
    let i = g * 4
    let c0 = chars[i]
    let c1 = chars[i + 1]
    let c2 = chars[i + 2]
    let c3 = chars[i + 3]
    guard c0 != '=' && c1 != '=' else { return Err(InvalidData) }
    let v0 = match base64_value_of_char(c0) {
      Some(v) => v
      None => return Err(InvalidData)
    }
    let v1 = match base64_value_of_char(c1) {
      Some(v) => v
      None => return Err(InvalidData)
    }
    if c2 == '=' {
      guard c3 == '=' && i + 4 == len else { return Err(InvalidData) }
      out.push((v0 << 2) | (v1 >> 4))
      return Ok(out)
    }
    let v2 = match base64_value_of_char(c2) {
      Some(v) => v
      None => return Err(InvalidData)
    }
    if c3 == '=' {
      guard i + 4 == len else { return Err(InvalidData) }
      out.push((v0 << 2) | (v1 >> 4))
      out.push(((v1 & 0x0F) << 4) | (v2 >> 2))
      return Ok(out)
    }
    let v3 = match base64_value_of_char(c3) {
      Some(v) => v
      None => return Err(InvalidData)
    }
    out.push((v0 << 2) | (v1 >> 4))
    out.push(((v1 & 0x0F) << 4) | (v2 >> 2))
    out.push(((v2 & 0x03) << 6) | v3)
  }

  let rem = len % 4
  if rem == 0 {
    return Ok(out)
  }
  let start = full_groups * 4
  if rem == 1 {
    match base64_value_of_char(chars[start]) {
      Some(_) => Err(TrailingByte)
      None => Err(InvalidData)
    }
  } else {
    for i in start..<len {
      if chars[i] == '=' {
        return Err(InvalidData)
      }
    }
    let v0 = match base64_value_of_char(chars[start]) {
      Some(v) => v
      None => return Err(InvalidData)
    }
    let v1 = match base64_value_of_char(chars[start + 1]) {
      Some(v) => v
      None => return Err(InvalidData)
    }
    out.push((v0 << 2) | (v1 >> 4))
    if rem == 3 {
      let v2 = match base64_value_of_char(chars[start + 2]) {
        Some(v) => v
        None => return Err(InvalidData)
      }
      out.push(((v1 & 0x0F) << 4) | (v2 >> 2))
    }
    Ok(out)
  }
}

///|
fn builtin_list() -> Array[Json] {
  let names = [
    "abs/0", "add/0", "all/0", "any/0", "ascii_downcase/0", "ascii_upcase/0", "atan/0",
    "builtins/0", "combinations/0", "cos/0", "endswith/1", "env/0", "error/0", "error/1",
    "explode/0", "fabs/0", "first/0", "flatten/0", "floor/0", "from_entries/0", "fromdate/0",
    "fromjson/0", "group_by/1", "implode/0", "infinite/0", "inside/1", "isfinite/0",
    "isinfinite/0", "isempty/0", "isnan/0", "join/1", "keys/0", "last/0", "length/0",
    "log2/0", "ltrim/0", "map/1", "map_values/1", "max/0", "min/0", "modulemeta/0",
    "nan/0", "paths/0", "pow/2", "reverse/0", "round/0", "rtrim/0", "sin/0", "sort/0",
    "split/1", "sqrt/0", "startswith/1", "to_entries/0", "toboolean/0", "tojson/0",
    "tonumber/0", "tostream/0", "tostring/0", "utf8bytelength/0", "transpose/0",
    "trim/0", "type/0", "unique/0", "values/0",
  ]
  let out = []
  for name in names {
    out.push(Json::string(name))
  }
  out
}

///|
fn builtin_call0(name : String, input : Json) -> Array[Json] raise EvalError {
  match name {
    "have_decnum" => [Json::boolean(true)]
    "modulemeta" =>
      [Json::object({ "deps": Json::array([]), "defs": Json::object({}) })]
    "env" => [Json::object(Map::new())]
    "builtins" => [Json::array(builtin_list())]
    "nan" => [Json::number(@double.infinity - @double.infinity)]
    "infinite" => [Json::number(@double.infinity)]
    "isnan" =>
      match input {
        Number(n, _) => [Json::boolean(n != n)]
        _ => [Json::boolean(false)]
      }
    "isfinite" =>
      match input {
        Number(n, _) =>
          [
            Json::boolean(
              n == n && n != @double.infinity && n != @double.neg_infinity,
            ),
          ]
        _ => [Json::boolean(false)]
      }
    "isinfinite" =>
      match input {
        Number(n, _) =>
          [Json::boolean(n == @double.infinity || n == @double.neg_infinity)]
        _ => [Json::boolean(false)]
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
        String(s) => [Json::number(builtin_utf8_byte_length(s).to_double())]
        _ =>
          raise TypeError(
            json_type_with_value(input) + " only strings have UTF-8 byte length",
          )
      }
    "error" => raise TypeError(input.to_json_string())
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
    "fabs" =>
      match input {
        Number(n, _) => [json_number_value(builtin_fabs_number(n))]
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
    "@uri" =>
      [Json::string(format_uri_encode(format_filter_input_string(input)))]
    "@urid" => {
      let s = format_filter_input_string(input)
      match format_uri_decode(s) {
        Some(decoded) => [Json::string(decoded)]
        None =>
          raise TypeError(
            format_filter_string_type_with_value(s) +
            " is not a valid uri encoding",
          )
      }
    }
    "@base64" =>
      [Json::string(format_base64_encode(format_filter_input_string(input)))]
    "@base64d" => {
      let s = format_filter_input_string(input)
      match format_base64_decode(s) {
        Ok(bytes) => [Json::string(utf8_decode_bytes_lossy(bytes))]
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
    "tojson" => [Json::string(input.to_json_string())]
    "tostream" => [Json::array([Json::array([]), input])]
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
