///|
fn format_html_escape(input : String) -> String {
  let buf = StringBuilder()
  for ch in input {
    if ch == '<' {
      buf.write_string("&lt;")
    } else if ch == '>' {
      buf.write_string("&gt;")
    } else if ch == '&' {
      buf.write_string("&amp;")
    } else if ch.to_int() == 39 {
      buf.write_string("&apos;")
    } else if ch == '\"' {
      buf.write_string("&quot;")
    } else {
      buf.write_char(ch)
    }
  }
  buf.to_string()
}

///|
fn format_sh_quote(input : String) -> String {
  let squote = (39).unsafe_to_char()
  let buf = StringBuilder()
  buf.write_char(squote)
  for ch in input {
    if ch.to_int() == 39 {
      buf.write_char(squote)
      buf.write_char('\\')
      buf.write_char(squote)
      buf.write_char(squote)
    } else {
      buf.write_char(ch)
    }
  }
  buf.write_char(squote)
  buf.to_string()
}

///|
fn format_csv_field_string(input : String) -> String {
  let buf = StringBuilder()
  buf.write_char('\"')
  for ch in input {
    if ch == '\"' {
      buf.write_string("\"\"")
    } else {
      buf.write_char(ch)
    }
  }
  buf.write_char('\"')
  buf.to_string()
}

///|
fn format_csv_scalar(value : Value) -> String raise EvalError {
  match value {
    JNull => ""
    String(s) => format_csv_field_string(s)
    Number(_, _) | JTrue | JFalse => value.to_json_string()
    _ =>
      raise TypeError("@csv only supports null, booleans, numbers, and strings")
  }
}

///|
fn format_tsv_escape(input : String) -> String {
  let buf = StringBuilder()
  for ch in input {
    if ch == '\\' {
      buf.write_string("\\\\")
    } else if ch == '\t' {
      buf.write_string("\\t")
    } else if ch == '\r' {
      buf.write_string("\\r")
    } else if ch == '\n' {
      buf.write_string("\\n")
    } else {
      buf.write_char(ch)
    }
  }
  buf.to_string()
}

///|
fn format_tsv_scalar(value : Value) -> String raise EvalError {
  match value {
    JNull => ""
    String(s) => format_tsv_escape(s)
    Number(_, _) | JTrue | JFalse => value.to_json_string()
    _ =>
      raise TypeError("@tsv only supports null, booleans, numbers, and strings")
  }
}

///|
fn format_csv_row(input : Value) -> String raise EvalError {
  match input {
    Array(items) => {
      let buf = StringBuilder()
      for i in 0..<items.length() {
        if i > 0 {
          buf.write_char(',')
        }
        buf.write_string(format_csv_scalar(items[i]))
      }
      buf.to_string()
    }
    _ => raise TypeError("@csv input must be an array")
  }
}

///|
fn format_tsv_row(input : Value) -> String raise EvalError {
  match input {
    Array(items) => {
      let buf = StringBuilder()
      for i in 0..<items.length() {
        if i > 0 {
          buf.write_char('\t')
        }
        buf.write_string(format_tsv_scalar(items[i]))
      }
      buf.to_string()
    }
    _ => raise TypeError("@tsv input must be an array")
  }
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
  let buf = StringBuilder()
  let mut i = 0
  while i < bytes.length() {
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
  let buf = StringBuilder()
  let mut i = 0
  while i < bytes.length() {
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
  let buf = StringBuilder()
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
fn format_uri_decode_percent_run(input : String, start : Int) -> (String, Int)? {
  let bytes = []
  let mut i = start
  while i < input.length() {
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
      break
    }
  }
  match utf8_decode_bytes_strict(bytes) {
    Some(decoded) => Some((decoded, i))
    None => None
  }
}

///|
fn format_uri_decode(input : String) -> String? {
  let c_input = builtin_c_string_prefix(input)
  let buf = StringBuilder()
  let mut i = 0
  while i < c_input.length() {
    let ch = c_input.unsafe_get(i).to_int().unsafe_to_char()
    if ch == '%' {
      match format_uri_decode_percent_run(c_input, i) {
        Some((decoded, next_i)) => {
          buf.write_string(decoded)
          i = next_i
        }
        None => return None
      }
    } else {
      if ch.to_int() <= 0x7F {
        buf.write_char(ch)
      } else {
        for b in utf8_bytes_of_string(ch.to_string()) {
          buf.write_string(utf8_decode_bytes_lossy([b]))
        }
      }
      i += 1
    }
  }
  Some(buf.to_string())
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
  let buf = StringBuilder()
  let mut i = 0
  while i < bytes.length() {
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
  let mut len = chars.length()
  // jq accepts lax trailing '=' padding, including the degenerate "=" case.
  while len > 0 && chars[len - 1] == '=' {
    len -= 1
  }
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
