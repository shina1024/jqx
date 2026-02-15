///|
pub enum Json {
  JNull
  JTrue
  JFalse
  Number(Double, String?)
  String(String)
  Array(Array[Json])
  Object(JsonObject)
}

///|
struct JsonObject {
  map : Map[String, Json]
  key_order : Array[String]
}

///|
fn object_keys_in_order(
  map : Map[String, Json],
  key_order : Array[String],
) -> Array[String] {
  let out = []
  let seen = Map::new()
  for key in key_order {
    if !seen.contains(key) {
      seen[key] = true
      if map.contains(key) {
        out.push(key)
      }
    }
  }
  for key in map.keys() {
    if !seen.contains(key) {
      seen[key] = true
      out.push(key)
    }
  }
  out
}

///|
fn json_object_make(
  map : Map[String, Json],
  key_order : Array[String],
) -> JsonObject {
  { map, key_order: object_keys_in_order(map, key_order) }
}

///|
fn JsonObject::from_map(map : Map[String, Json]) -> JsonObject {
  json_object_make(map, Array::from_iter(map.keys()))
}

///|
fn JsonObject::with_order(
  map : Map[String, Json],
  key_order : Array[String],
) -> JsonObject {
  json_object_make(map, key_order)
}

///|
fn JsonObject::get(self : JsonObject, key : String) -> Json? {
  self.map.get(key)
}

///|
fn JsonObject::contains(self : JsonObject, key : String) -> Bool {
  self.map.contains(key)
}

///|
fn JsonObject::length(self : JsonObject) -> Int {
  self.map.length()
}

///|
fn JsonObject::keys(self : JsonObject) -> Array[String] {
  object_keys_in_order(self.map, self.key_order)
}

///|
fn JsonObject::iter(self : JsonObject) -> Array[(String, Json)] {
  object_entries_sorted(self)
}

///|
fn JsonObject::to_map(self : JsonObject) -> Map[String, Json] {
  self.map
}

///|
fn JsonObject::set(self : JsonObject, key : String, value : Json) -> JsonObject {
  let next_map = self.map.copy()
  let next_order = self.key_order.copy()
  if !next_map.contains(key) {
    next_order.push(key)
  }
  next_map[key] = value
  json_object_make(next_map, next_order)
}

///|
fn json_equal(a : Json, b : Json) -> Bool {
  match (a, b) {
    (JNull, JNull) => true
    (JTrue, JTrue) => true
    (JFalse, JFalse) => true
    (Number(x, _), Number(y, _)) => x == y
    (String(x), String(y)) => x == y
    (Array(x), Array(y)) => {
      if x.length() != y.length() {
        return false
      }
      for i in 0..<x.length() {
        if !json_equal(x[i], y[i]) {
          return false
        }
      }
      true
    }
    (Object(x), Object(y)) => {
      if x.length() != y.length() {
        return false
      }
      for kv in x.iter() {
        match y.get(kv.0) {
          Some(v) => if !json_equal(kv.1, v) { return false }
          None => return false
        }
      }
      true
    }
    _ => false
  }
}

///|
pub impl Eq for Json with equal(self, other) {
  json_equal(self, other)
}

///|
pub impl Eq for Json with not_equal(self, other) {
  !json_equal(self, other)
}

///|
pub fn Json::null() -> Json {
  JNull
}

///|
pub fn Json::boolean(b : Bool) -> Json {
  if b {
    JTrue
  } else {
    JFalse
  }
}

///|
pub fn Json::number(n : Double, repr? : String) -> Json {
  Number(n, repr)
}

///|
pub fn Json::string(s : String) -> Json {
  String(s)
}

///|
pub fn Json::array(a : Array[Json]) -> Json {
  Array(a)
}

///|
pub fn Json::object(o : Map[String, Json]) -> Json {
  Object(JsonObject::from_map(o))
}

///|
fn Json::object_with_order(
  o : Map[String, Json],
  key_order : Array[String],
) -> Json {
  Object(JsonObject::with_order(o, key_order))
}

///|
fn Json::object_from_entries(entries : Array[(String, Json)]) -> Json {
  let map = Map::new()
  let key_order = []
  for kv in entries {
    let key = kv.0
    let value = kv.1
    if !map.contains(key) {
      key_order.push(key)
    }
    map[key] = value
  }
  Json::object_with_order(map, key_order)
}

///|
fn decimal_expand_positive_exponent(raw : String) -> String? {
  let mut exp_index = -1
  for i in 0..<raw.length() {
    let ch = raw.unsafe_get(i).to_int().unsafe_to_char()
    if ch == 'e' || ch == 'E' {
      exp_index = i
      break
    }
  }
  if exp_index < 0 {
    return None
  }
  let mantissa = raw.view(start_offset=0, end_offset=exp_index).to_string()
  let exp_part = raw
    .view(start_offset=exp_index + 1, end_offset=raw.length())
    .to_string()
  let parsed_exp = try? @strconv.parse_int64(exp_part)
  let exp_value = match parsed_exp {
    Ok(v) => v.to_int()
    Err(_) => return None
  }
  if exp_value < 0 {
    return None
  }
  let mut negative = false
  let mut pos = 0
  if mantissa.length() > 0 {
    let first = mantissa.unsafe_get(0).to_int().unsafe_to_char()
    if first == '-' {
      negative = true
      pos = 1
    } else if first == '+' {
      pos = 1
    }
  }
  let mut dot_index = -1
  for i in pos..<mantissa.length() {
    let ch = mantissa.unsafe_get(i).to_int().unsafe_to_char()
    if ch == '.' {
      if dot_index >= 0 {
        return None
      }
      dot_index = i
      continue
    }
    if !is_ascii_digit(ch) {
      return None
    }
  }
  let int_end = if dot_index >= 0 { dot_index } else { mantissa.length() }
  let frac_start = if dot_index >= 0 { dot_index + 1 } else { int_end }
  let int_part = mantissa.view(start_offset=pos, end_offset=int_end).to_string()
  let frac_part = mantissa
    .view(start_offset=frac_start, end_offset=mantissa.length())
    .to_string()
  let digits = int_part + frac_part
  if digits.length() == 0 {
    return None
  }
  let frac_len = frac_part.length()
  let exp_nonneg = exp_value
  let sign = if negative { "-" } else { "" }
  if exp_nonneg >= frac_len {
    let zero_count = exp_nonneg - frac_len
    let buf = StringBuilder::new()
    buf.write_string(sign)
    buf.write_string(digits)
    for _ in 0..<zero_count {
      buf.write_char('0')
    }
    Some(buf.to_string())
  } else {
    let integer_len = digits.length() - (frac_len - exp_nonneg)
    let buf = StringBuilder::new()
    buf.write_string(sign)
    if integer_len > 0 {
      buf.write_string(
        digits.view(start_offset=0, end_offset=integer_len).to_string(),
      )
    } else {
      buf.write_char('0')
    }
    buf.write_char('.')
    buf.write_string(
      digits
      .view(start_offset=integer_len, end_offset=digits.length())
      .to_string(),
    )
    Some(buf.to_string())
  }
}

///|
fn object_keys_sorted(o : JsonObject) -> Array[String] {
  o.keys()
}

///|
fn sort_strings_lex(input : Array[String]) -> Array[String] {
  let sorted = input.copy()
  for i in 1..<sorted.length() {
    let v = sorted[i]
    let mut j = i
    for {
      if j > 0 && sorted[j - 1].compare(v) > 0 {
        sorted[j] = sorted[j - 1]
        j -= 1
      } else {
        break
      }
    }
    sorted[j] = v
  }
  sorted
}

///|
fn object_keys_lex_sorted(o : JsonObject) -> Array[String] {
  sort_strings_lex(object_keys_sorted(o))
}

///|
fn object_entries_sorted(o : JsonObject) -> Array[(String, Json)] {
  let out = []
  for key in object_keys_sorted(o) {
    match o.get(key) {
      Some(value) => out.push((key, value))
      None => ()
    }
  }
  out
}

///|
pub struct Position {
  line : Int // 1-based
  column : Int // 1-based
} derive(Eq)

///|
pub suberror ParseError {
  InvalidChar(Position, Char)
  InvalidEof
  DepthLimitExceeded
  InvalidNumericLiteral(Position)
  InvalidNumericLiteralAtEof(Position)
  InvalidStringLiteral(Position)
  InvalidStringLiteralAtEof(Position)
} derive(Eq)

///|
pub impl Show for ParseError with output(self, logger) {
  match self {
    InvalidChar({ line, column }, c) =>
      logger
      ..write_string("Invalid character ")
      ..write_string(repr(c))
      ..write_string(" at line ")
      ..write_object(line)
      ..write_string(", column ")
      .write_object(column)
    InvalidEof => logger.write_string("Unexpected end of file")
    DepthLimitExceeded =>
      logger.write_string(
        "Depth limit exceeded, please increase the max_nesting_depth parameter",
      )
    InvalidNumericLiteral({ line, column }) =>
      logger
      ..write_string("Invalid numeric literal at line ")
      ..write_object(line)
      ..write_string(", column ")
      .write_object(column)
    InvalidNumericLiteralAtEof({ line, column }) =>
      logger
      ..write_string("Invalid numeric literal at EOF at line ")
      ..write_object(line)
      ..write_string(", column ")
      .write_object(column)
    InvalidStringLiteral({ line, column }) =>
      logger
      ..write_string("Invalid string literal; expected \", but got ' at line ")
      ..write_object(line)
      ..write_string(", column ")
      .write_object(column)
    InvalidStringLiteralAtEof({ line, column }) =>
      logger
      ..write_string(
        "Invalid string literal; expected \", but got ' at EOF at line ",
      )
      ..write_object(line)
      ..write_string(", column ")
      .write_object(column)
  }
}

///|
pub impl Show for Json with output(self, logger) {
  match self {
    JNull => logger.write_string("Null")
    JTrue => logger.write_string("True")
    JFalse => logger.write_string("False")
    Number(n, repr) => {
      logger.write_string("Number(")
      Show::output(n, logger)
      if repr is Some(_) {
        logger.write_string(", repr=")
        Show::output(repr, logger)
      }
      logger.write_string(")")
    }
    String(s) => {
      logger.write_string("String(")
      Show::output(s, logger)
      logger.write_string(")")
    }
    Array(a) => {
      logger.write_string("Array(")
      Show::output(a, logger)
      logger.write_string(")")
    }
    Object(o) => {
      logger.write_string("Object(")
      Show::output(o.to_map(), logger)
      logger.write_string(")")
    }
  }
}

///|
fn format_finite_number_without_repr(n : Double) -> String {
  let mut raw = n.to_string()
  if raw.contains("e") || raw.contains("E") {
    match decimal_expand_positive_exponent(raw) {
      Some(expanded) => raw = expanded
      None => return raw
    }
  } else if raw.contains(".") {
    return raw
  }
  let negative = raw.has_prefix("-")
  let digits = if negative {
    raw.view(start_offset=1, end_offset=raw.length()).to_string()
  } else {
    raw
  }
  if digits.length() <= 16 {
    return raw
  }
  if digits.unsafe_get(0).to_int().unsafe_to_char() != '1' {
    return raw
  }
  for i in 1..<digits.length() {
    if digits.unsafe_get(i).to_int().unsafe_to_char() != '0' {
      return raw
    }
  }
  let sign = if negative { "-" } else { "" }
  sign + "1e+" + (digits.length() - 1).to_string()
}

///|
/// Encode Json as a compact JSON string (jq-style output).
pub fn Json::to_json_string(self : Json) -> String {
  let buf = StringBuilder::new()
  let max_depth = 256
  fn write_escaped(s : String) {
    buf.write_char('"')
    for ch in s {
      match ch {
        '"' => buf.write_string("\\\"")
        '\\' => buf.write_string("\\\\")
        '\b' => buf.write_string("\\b")
        '\u{0C}' => buf.write_string("\\f")
        '\n' => buf.write_string("\\n")
        '\r' => buf.write_string("\\r")
        '\t' => buf.write_string("\\t")
        _ =>
          if ch.to_int() < 32 {
            let code = ch.to_int()
            buf.write_string("\\u00")
            let hi = (code >> 4) & 0xF
            let lo = code & 0xF
            fn hex(d : Int) -> Char {
              if d < 10 {
                (d + '0'.to_int()).unsafe_to_char()
              } else {
                (d - 10 + 'a'.to_int()).unsafe_to_char()
              }
            }

            buf.write_char(hex(hi))
            buf.write_char(hex(lo))
          } else {
            buf.write_char(ch)
          }
      }
    }
    buf.write_char('"')
  }

  fn write_value(j : Json, depth : Int) {
    if depth > max_depth {
      buf.write_string("<skipped: too deep>")
      return
    }
    match j {
      JNull => buf.write_string("null")
      JTrue => buf.write_string("true")
      JFalse => buf.write_string("false")
      Number(n, repr) =>
        match repr {
          Some(s) => buf.write_string(s)
          None =>
            if n != n {
              buf.write_string("null")
            } else if n == @double.infinity {
              buf.write_string("1.7976931348623157e+308")
            } else if n == @double.neg_infinity {
              buf.write_string("-1.7976931348623157e+308")
            } else {
              buf.write_string(format_finite_number_without_repr(n))
            }
        }
      String(s) => write_escaped(s)
      Array(a) => {
        buf.write_char('[')
        let mut first = true
        for v in a {
          if first {
            first = false
          } else {
            buf.write_char(',')
          }
          write_value(v, depth + 1)
        }
        buf.write_char(']')
      }
      Object(o) => {
        buf.write_char('{')
        let mut first = true
        for kv in object_entries_sorted(o) {
          let k = kv.0
          let v = kv.1
          if first {
            first = false
          } else {
            buf.write_char(',')
          }
          write_escaped(k)
          buf.write_char(':')
          write_value(v, depth + 1)
        }
        buf.write_char('}')
      }
    }
  }

  write_value(self, 0)
  buf.to_string()
}

///|
priv struct ParseContext {
  mut offset : Int
  input : StringView
  end_offset : Int
  mut remaining_available_depth : Int
}

///|
fn ParseContext::make(
  input : StringView,
  max_nesting_depth : Int,
) -> ParseContext {
  {
    offset: 0,
    input,
    end_offset: input.length(),
    remaining_available_depth: max_nesting_depth,
  }
}

///|
priv enum Token {
  Null
  True
  False
  Number(Double, String?)
  String(String)
  LBrace
  RBrace
  LBracket
  RBracket
  Comma
}

///|
pub fn valid(input : StringView) -> Bool {
  try {
    parse(input) |> ignore
    true
  } catch {
    _ => return false
  }
}

///|
pub fn parse(
  input : StringView,
  max_nesting_depth? : Int = 1024,
) -> Json raise ParseError {
  let ctx = ParseContext::make(input, max_nesting_depth)
  let val = ctx.parse_value()
  ctx.lex_skip_whitespace()
  if ctx.offset >= ctx.end_offset {
    val
  } else {
    ctx.invalid_char()
  }
}

///|
fn ParseContext::parse_value(ctx : ParseContext) -> Json raise ParseError {
  let tok = ctx.lex_value(allow_rbracket=false)
  ctx.parse_value2(tok)
}

///|
fn ParseContext::parse_value2(
  ctx : ParseContext,
  tok : Token,
) -> Json raise ParseError {
  match tok {
    Null => Json::null()
    True => Json::boolean(true)
    False => Json::boolean(false)
    Number(n, repr) => Json::number(n, repr?)
    String(s) => Json::string(s)
    LBrace => ctx.parse_object()
    LBracket => ctx.parse_array()
    RBracket | RBrace | Comma => abort("unreachable")
  }
}

///|
fn ParseContext::parse_object(ctx : ParseContext) -> Json raise ParseError {
  if ctx.remaining_available_depth <= 0 {
    raise DepthLimitExceeded
  }
  ctx.remaining_available_depth -= 1
  let map = Map::new()
  let key_order = []
  loop ctx.lex_property_name() {
    RBrace => {
      ctx.remaining_available_depth += 1
      Json::object_with_order(map, key_order)
    }
    String(name) => {
      ctx.lex_after_property_name()
      if !map.contains(name) {
        key_order.push(name)
      }
      map[name] = ctx.parse_value()
      match ctx.lex_after_object_value() {
        Comma => continue ctx.lex_property_name2()
        RBrace => {
          ctx.remaining_available_depth += 1
          Json::object_with_order(map, key_order)
        }
        _ => abort("unreachable")
      }
    }
    _ => abort("unreachable")
  }
}

///|
fn ParseContext::parse_array(ctx : ParseContext) -> Json raise ParseError {
  if ctx.remaining_available_depth <= 0 {
    raise DepthLimitExceeded
  }
  ctx.remaining_available_depth -= 1
  let vec = []
  loop ctx.lex_value(allow_rbracket=true) {
    RBracket => {
      ctx.remaining_available_depth += 1
      Json::array(vec)
    }
    tok => {
      vec.push(ctx.parse_value2(tok))
      let tok2 = ctx.lex_after_array_value()
      match tok2 {
        Comma => continue ctx.lex_value(allow_rbracket=false)
        RBracket => {
          ctx.remaining_available_depth += 1
          Json::array(vec)
        }
        _ => abort("unreachable")
      }
    }
  }
}

///|
fn offset_to_position(input : StringView, offset : Int) -> Position {
  let mut line = 1
  let mut column = 1
  for i in 0..<offset {
    if input.unsafe_get(i) == '\n' {
      line += 1
      column = 1
    } else {
      column += 1
    }
  }
  return Position::{ line, column }
}

///|
fn[T] ParseContext::invalid_char(
  ctx : ParseContext,
  shift? : Int = 0,
) -> T raise ParseError {
  let offset = ctx.offset + shift
  let replacement_char : Char = '\u{fffd}'
  raise InvalidChar(
    offset_to_position(ctx.input, offset),
    ctx.input.get_char(offset).unwrap_or(replacement_char),
  )
}

///|
fn ParseContext::read_char(ctx : ParseContext) -> Char? {
  if ctx.offset < ctx.end_offset {
    let c1 = ctx.input.unsafe_get(ctx.offset).to_int()
    ctx.offset += 1
    if c1 >= 0xD800 && c1 <= 0xDBFF {
      if ctx.offset < ctx.end_offset {
        let c2 = ctx.input.unsafe_get(ctx.offset).to_int()
        if c2 >= 0xDC00 && c2 <= 0xDFFF {
          ctx.offset += 1
          let c3 = (c1 << 10) + c2 - 0x35fdc00
          return Some(c3.unsafe_to_char())
        }
      }
    }
    Some(c1.unsafe_to_char())
  } else {
    None
  }
}

///|
fn ParseContext::peek_char(ctx : ParseContext) -> Char? {
  let saved = ctx.offset
  let c = ctx.read_char()
  ctx.offset = saved
  c
}

///|
fn is_ascii_alpha(c : Char) -> Bool {
  c is ('a'..='z' | 'A'..='Z')
}

///|
fn parse_ascii_downcase_char(c : Char) -> Char {
  if c is ('A'..='Z') {
    (c.to_int() + 32).unsafe_to_char()
  } else {
    c
  }
}

///|
fn parse_ascii_downcase_string(s : String) -> String {
  let buf = StringBuilder::new()
  for ch in s {
    buf.write_char(parse_ascii_downcase_char(ch))
  }
  buf.to_string()
}

///|
fn ParseContext::lex_nonfinite_number(
  ctx : ParseContext,
  start~ : Int,
) -> Token raise ParseError {
  let mut ended_at_separator = false
  for {
    match ctx.read_char() {
      Some(c) if is_ascii_alpha(c) || c is ('0'..='9') => continue
      Some(c) => {
        ctx.offset -= c.utf16_len()
        ended_at_separator = true
        break
      }
      None => break
    }
  }
  let token = ctx.input
    .view(start_offset=start, end_offset=ctx.offset)
    .to_string()
  match parse_ascii_downcase_string(token) {
    "inf" | "+inf" | "infinity" | "+infinity" => Number(@double.infinity, None)
    "-inf" | "-infinity" => Number(@double.neg_infinity, None)
    "nan" | "+nan" | "-nan" => Number(@double.infinity - @double.infinity, None)
    _ =>
      if ended_at_separator {
        raise InvalidNumericLiteral(offset_to_position(ctx.input, ctx.offset))
      } else {
        raise InvalidNumericLiteralAtEof(
          offset_to_position(
            ctx.input,
            if ctx.offset > start {
              ctx.offset - 1
            } else {
              start
            },
          ),
        )
      }
  }
}

///|

///|
fn ParseContext::expect_ascii_char(
  ctx : ParseContext,
  c : Byte,
) -> Unit raise ParseError {
  guard ctx.offset < ctx.end_offset else { raise InvalidEof }
  let c1 = ctx.input.unsafe_get(ctx.offset).to_int()
  ctx.offset += 1
  if c.to_int() != c1 {
    ctx.invalid_char(shift=-1)
  }
}

///|
fn ParseContext::lex_skip_whitespace(ctx : ParseContext) -> Unit {
  let rest = ctx.input.view(start_offset=ctx.offset, end_offset=ctx.end_offset)
  lexmatch rest {
    ("[ \t\r\n]+", next) => ctx.offset = ctx.end_offset - next.length()
    _ => ()
  }
}

///|
fn ParseContext::lex_after_array_value(
  ctx : ParseContext,
) -> Token raise ParseError {
  ctx.lex_skip_whitespace()
  match ctx.read_char() {
    Some(']') => RBracket
    Some(',') => Comma
    Some(_) => ctx.invalid_char(shift=-1)
    None => raise InvalidEof
  }
}

///|
fn ParseContext::lex_after_property_name(
  ctx : ParseContext,
) -> Unit raise ParseError {
  ctx.lex_skip_whitespace()
  match ctx.read_char() {
    Some(':') => ()
    Some(_) => ctx.invalid_char(shift=-1)
    None => raise InvalidEof
  }
}

///|
fn ParseContext::lex_after_object_value(
  ctx : ParseContext,
) -> Token raise ParseError {
  ctx.lex_skip_whitespace()
  match ctx.read_char() {
    Some('}') => RBrace
    Some(',') => Comma
    Some(_) => ctx.invalid_char(shift=-1)
    None => raise InvalidEof
  }
}

///|
fn ParseContext::lex_property_name(
  ctx : ParseContext,
) -> Token raise ParseError {
  ctx.lex_skip_whitespace()
  match ctx.read_char() {
    Some('}') => RBrace
    Some('\'') => ctx.invalid_single_quoted_string()
    Some('"') => {
      let s = ctx.lex_string()
      String(s)
    }
    Some(_) => ctx.invalid_char(shift=-1)
    None => raise InvalidEof
  }
}

///|
fn ParseContext::lex_property_name2(
  ctx : ParseContext,
) -> Token raise ParseError {
  ctx.lex_skip_whitespace()
  match ctx.read_char() {
    Some('\'') => ctx.invalid_single_quoted_string()
    Some('"') => {
      let s = ctx.lex_string()
      String(s)
    }
    Some(_) => ctx.invalid_char(shift=-1)
    None => raise InvalidEof
  }
}

///|
fn ParseContext::lex_value(
  ctx : ParseContext,
  allow_rbracket~ : Bool,
) -> Token raise ParseError {
  ctx.lex_skip_whitespace()
  match ctx.read_char() {
    Some('{') => return LBrace
    Some('[') => return LBracket
    Some(']') =>
      if allow_rbracket {
        return RBracket
      } else {
        ctx.invalid_char(shift=-1)
      }
    Some('n') =>
      match ctx.peek_char() {
        Some('u') => {
          ctx.expect_ascii_char('u')
          ctx.expect_ascii_char('l')
          ctx.expect_ascii_char('l')
          return Null
        }
        _ => return ctx.lex_nonfinite_number(start=ctx.offset - 1)
      }
    Some('N' | 'i' | 'I') =>
      return ctx.lex_nonfinite_number(start=ctx.offset - 1)
    Some('<') => return ctx.lex_nonfinite_number(start=ctx.offset - 1)
    Some('+') =>
      match ctx.read_char() {
        Some('i' | 'I' | 'n' | 'N') =>
          return ctx.lex_nonfinite_number(start=ctx.offset - 2)
        Some(_) => ctx.invalid_char(shift=-1)
        None => raise InvalidEof
      }
    Some('t') => {
      ctx.expect_ascii_char('r')
      ctx.expect_ascii_char('u')
      ctx.expect_ascii_char('e')
      return True
    }
    Some('f') => {
      ctx.expect_ascii_char('a')
      ctx.expect_ascii_char('l')
      ctx.expect_ascii_char('s')
      ctx.expect_ascii_char('e')
      return False
    }
    Some('-') =>
      match ctx.read_char() {
        Some('0') => {
          let (n, repr) = ctx.lex_zero(start=ctx.offset - 2)
          return Number(n, repr.map(s => s.to_string()))
        }
        Some(c2) => {
          if c2 is ('1'..='9') {
            let (n, repr) = ctx.lex_decimal_integer(start=ctx.offset - 2)
            return Number(n, repr.map(s => s.to_string()))
          } else if c2 is ('i' | 'I' | 'n' | 'N') {
            return ctx.lex_nonfinite_number(start=ctx.offset - 2)
          }
          ctx.invalid_char(shift=-1)
        }
        None => raise InvalidEof
      }
    Some('0') => {
      let (n, repr) = ctx.lex_zero(start=ctx.offset - 1)
      return Number(n, repr.map(s => s.to_string()))
    }
    Some('1'..='9') => {
      let (n, repr) = ctx.lex_decimal_integer(start=ctx.offset - 1)
      return Number(n, repr.map(s => s.to_string()))
    }
    Some('"') => {
      let s = ctx.lex_string()
      return String(s)
    }
    Some('\'') => ctx.invalid_single_quoted_string()
    Some(c) => {
      let shift = -c.utf16_len()
      ctx.invalid_char(shift~)
    }
    None => raise InvalidEof
  }
}

///|
fn ParseContext::lex_string(ctx : ParseContext) -> String raise ParseError {
  let buf = StringBuilder::new()
  let mut start = ctx.offset
  fn flush(end : Int) {
    if start > 0 && end > start {
      buf.write_view(try! ctx.input[start:end])
    }
  }

  for {
    match ctx.read_char() {
      Some('"') => {
        flush(ctx.offset - 1)
        break
      }
      Some('\n' | '\r') => ctx.invalid_char(shift=-1)
      Some('\\') => {
        flush(ctx.offset - 1)
        match ctx.read_char() {
          Some('b') => buf.write_char('\b')
          Some('f') => buf.write_char('\u{0C}')
          Some('n') => buf.write_char('\n')
          Some('r') => buf.write_char('\r')
          Some('t') => buf.write_char('\t')
          Some('"') => buf.write_char('"')
          Some('\\') => buf.write_char('\\')
          Some('/') => buf.write_char('/')
          Some('u') => {
            let c = ctx.lex_hex_digits(4)
            buf.write_char(c.unsafe_to_char())
          }
          Some(_) => ctx.invalid_char(shift=-1)
          None => raise InvalidEof
        }
        start = ctx.offset
      }
      Some(ch) =>
        if ch.to_int() < 32 {
          ctx.invalid_char(shift=-1)
        } else {
          continue
        }
      None => raise InvalidEof
    }
  }
  buf.to_string()
}

///|
fn[T] ParseContext::invalid_single_quoted_string(
  ctx : ParseContext,
) -> T raise ParseError {
  let mut has_closing_quote = false
  for {
    match ctx.read_char() {
      Some('\'') => {
        has_closing_quote = true
        break
      }
      Some(_) => continue
      None => break
    }
  }
  if has_closing_quote {
    if ctx.offset < ctx.end_offset {
      raise InvalidStringLiteral(offset_to_position(ctx.input, ctx.offset))
    } else {
      raise InvalidStringLiteralAtEof(
        offset_to_position(
          ctx.input,
          if ctx.offset > 0 {
            ctx.offset - 1
          } else {
            0
          },
        ),
      )
    }
  } else {
    raise InvalidStringLiteralAtEof(
      offset_to_position(
        ctx.input,
        if ctx.offset > 0 {
          ctx.offset - 1
        } else {
          0
        },
      ),
    )
  }
}

///|
fn ParseContext::lex_hex_digits(
  ctx : ParseContext,
  n : Int,
) -> Int raise ParseError {
  let mut r = 0
  for i in 0..<n {
    match ctx.read_char() {
      Some(c) =>
        if c >= 'A' {
          let d = (c.to_int() & (32).lnot()) - 'A'.to_int() + 10
          if d > 15 {
            ctx.invalid_char(shift=-1)
          }
          r = (r << 4) | d
        } else if c >= '0' {
          let d = c.to_int() - '0'.to_int()
          if d > 9 {
            ctx.invalid_char(shift=-1)
          }
          r = (r << 4) | d
        } else {
          ctx.invalid_char(shift=-1)
        }
      None => raise InvalidEof
    }
  }
  r
}

///|
fn ParseContext::lex_decimal_integer(
  ctx : ParseContext,
  start~ : Int,
) -> (Double, StringView?) raise ParseError {
  for {
    match ctx.read_char() {
      Some('.') => return ctx.lex_decimal_point(start~)
      Some('e' | 'E') => return ctx.lex_decimal_exponent(start~)
      Some(c) => {
        if c >= '0' && c <= '9' {
          continue
        }
        ctx.offset -= 1
        return ctx.lex_number_end(start, ctx.offset)
      }
      None => return ctx.lex_number_end(start, ctx.offset)
    }
  }
}

///|
fn ParseContext::lex_decimal_point(
  ctx : ParseContext,
  start~ : Int,
) -> (Double, StringView?) raise ParseError {
  match ctx.read_char() {
    Some(c) =>
      if c >= '0' && c <= '9' {
        ctx.lex_decimal_fraction(start~)
      } else {
        ctx.invalid_char(shift=-1)
      }
    None => raise InvalidEof
  }
}

///|
fn ParseContext::lex_decimal_fraction(
  ctx : ParseContext,
  start~ : Int,
) -> (Double, StringView?) raise ParseError {
  for {
    match ctx.read_char() {
      Some('e' | 'E') => return ctx.lex_decimal_exponent(start~)
      Some(c) => {
        if c >= '0' && c <= '9' {
          continue
        }
        ctx.offset -= 1
        return ctx.lex_number_end(start, ctx.offset)
      }
      None => return ctx.lex_number_end(start, ctx.offset)
    }
  }
}

///|
fn ParseContext::lex_decimal_exponent(
  ctx : ParseContext,
  start~ : Int,
) -> (Double, StringView?) raise ParseError {
  match ctx.read_char() {
    Some('+') | Some('-') => return ctx.lex_decimal_exponent_sign(start~)
    Some(c) => {
      if c >= '0' && c <= '9' {
        return ctx.lex_decimal_exponent_integer(start~)
      }
      ctx.offset -= 1
      ctx.invalid_char()
    }
    None => raise InvalidEof
  }
}

///|
fn ParseContext::lex_decimal_exponent_sign(
  ctx : ParseContext,
  start~ : Int,
) -> (Double, StringView?) raise ParseError {
  match ctx.read_char() {
    Some(c) => {
      if c >= '0' && c <= '9' {
        return ctx.lex_decimal_exponent_integer(start~)
      }
      ctx.offset -= 1
      ctx.invalid_char()
    }
    None => raise InvalidEof
  }
}

///|
fn ParseContext::lex_decimal_exponent_integer(
  ctx : ParseContext,
  start~ : Int,
) -> (Double, StringView?) {
  for {
    match ctx.read_char() {
      Some(c) => {
        if c >= '0' && c <= '9' {
          continue
        }
        ctx.offset -= 1
        return ctx.lex_number_end(start, ctx.offset)
      }
      None => return ctx.lex_number_end(start, ctx.offset)
    }
  }
}

///|
fn ParseContext::lex_zero(
  ctx : ParseContext,
  start~ : Int,
) -> (Double, StringView?) raise ParseError {
  match ctx.read_char() {
    Some('.') => ctx.lex_decimal_point(start~)
    Some('e' | 'E') => ctx.lex_decimal_exponent(start~)
    Some(c) => {
      if c >= '0' && c <= '9' {
        ctx.offset -= 1
        ctx.invalid_char()
      }
      ctx.offset -= 1
      return ctx.lex_number_end(start, ctx.offset)
    }
    None => return ctx.lex_number_end(start, ctx.offset)
  }
}

///|
fn number_literal_exponent_index(token : StringView) -> Int? {
  for i in 0..<token.length() {
    let ch = token.unsafe_get(i).to_int().unsafe_to_char()
    if ch == 'e' || ch == 'E' {
      return Some(i)
    }
  }
  None
}

///|
fn is_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn number_literal_exponent_digit_count(token : StringView) -> Int? {
  match number_literal_exponent_index(token) {
    Some(exp_index) => {
      let mut pos = exp_index + 1
      if pos < token.length() {
        let sign = token.unsafe_get(pos).to_int().unsafe_to_char()
        if sign == '+' || sign == '-' {
          pos += 1
        }
      }
      Some(token.length() - pos)
    }
    None => None
  }
}

///|
fn number_literal_has_large_exponent(token : StringView) -> Bool {
  match number_literal_exponent_digit_count(token) {
    Some(digit_count) => {
      let mut pos = match number_literal_exponent_index(token) {
        Some(exp_index) => exp_index + 1
        None => 0
      }
      if pos < token.length() {
        let sign = token.unsafe_get(pos).to_int().unsafe_to_char()
        if sign == '+' || sign == '-' {
          pos += 1
        }
      }
      if digit_count > 3 {
        return true
      }
      let mut abs_exp = 0
      for i in pos..<token.length() {
        let ch = token.unsafe_get(i).to_int().unsafe_to_char()
        if !is_ascii_digit(ch) {
          return false
        }
        abs_exp = abs_exp * 10 + (ch.to_int() - '0'.to_int())
      }
      abs_exp > 308
    }
    None => false
  }
}

///|
fn number_literal_needs_exponent_normalization(token : StringView) -> Bool {
  match number_literal_exponent_digit_count(token) {
    Some(count) => count > 3
    None => false
  }
}

///|
fn number_literal_significant_digits(token : StringView) -> Int {
  let end = match number_literal_exponent_index(token) {
    Some(idx) => idx
    None => token.length()
  }
  let mut start = 0
  if start < end {
    let first = token.unsafe_get(start).to_int().unsafe_to_char()
    if first == '+' || first == '-' {
      start += 1
    }
  }
  let mut dot = end
  for i in start..<end {
    let ch = token.unsafe_get(i).to_int().unsafe_to_char()
    if ch == '.' {
      dot = i
      break
    }
  }
  let mut left_start = start
  for {
    if left_start < dot &&
      token.unsafe_get(left_start).to_int().unsafe_to_char() == '0' {
      left_start += 1
    } else {
      break
    }
  }
  let left_digits = if dot > left_start { dot - left_start } else { 0 }
  let mut right_start = end
  if dot < end {
    right_start = dot + 1
  }
  let mut right_end = end
  for {
    if right_end > right_start &&
      token.unsafe_get(right_end - 1).to_int().unsafe_to_char() == '0' {
      right_end -= 1
    } else {
      break
    }
  }
  let right_digits = if right_end > right_start {
    right_end - right_start
  } else {
    0
  }
  let digits = left_digits + right_digits
  if digits == 0 {
    1
  } else {
    digits
  }
}

///|
fn number_literal_should_preserve_repr(token : StringView) -> Bool {
  number_literal_has_large_exponent(token) ||
  number_literal_significant_digits(token) > 17
}

///|
fn number_literal_normalized_large_exponent_repr(token : StringView) -> String {
  let exp_index = match number_literal_exponent_index(token) {
    Some(i) => i
    None => return token.to_string()
  }
  let mut exp_pos = exp_index + 1
  let mut exp_sign = 1
  if exp_pos < token.length() {
    let ch = token.unsafe_get(exp_pos).to_int().unsafe_to_char()
    if ch == '+' {
      exp_pos += 1
    } else if ch == '-' {
      exp_sign = -1
      exp_pos += 1
    }
  }
  let mut exp_value = 0
  for i in exp_pos..<token.length() {
    let ch = token.unsafe_get(i).to_int().unsafe_to_char()
    if !is_ascii_digit(ch) {
      return token.to_string()
    }
    exp_value = exp_value * 10 + (ch.to_int() - '0'.to_int())
  }
  exp_value = exp_value * exp_sign

  let mut mant_start = 0
  let mut negative = false
  if mant_start < exp_index {
    let first = token.unsafe_get(mant_start).to_int().unsafe_to_char()
    if first == '-' {
      negative = true
      mant_start += 1
    } else if first == '+' {
      mant_start += 1
    }
  }
  let digits_raw_buf = StringBuilder::new()
  let mut frac_digits = 0
  let mut saw_dot = false
  for i in mant_start..<exp_index {
    let ch = token.unsafe_get(i).to_int().unsafe_to_char()
    if ch == '.' {
      if saw_dot {
        return token.to_string()
      }
      saw_dot = true
    } else if is_ascii_digit(ch) {
      digits_raw_buf.write_char(ch)
      if saw_dot {
        frac_digits += 1
      }
    } else {
      return token.to_string()
    }
  }
  let digits_raw = digits_raw_buf.to_string()
  if digits_raw.length() == 0 {
    return token.to_string()
  }
  let mut lead = 0
  for {
    if lead < digits_raw.length() &&
      digits_raw.unsafe_get(lead).to_int().unsafe_to_char() == '0' {
      lead += 1
    } else {
      break
    }
  }
  if lead >= digits_raw.length() {
    return "0E+0"
  }
  let trimmed = digits_raw
    .view(start_offset=lead, end_offset=digits_raw.length())
    .to_string()
  let mut end = trimmed.length()
  let mut exp_base = exp_value - frac_digits
  for {
    if end > 1 && trimmed.unsafe_get(end - 1).to_int().unsafe_to_char() == '0' {
      end -= 1
      exp_base += 1
    } else {
      break
    }
  }
  let digits = trimmed.view(start_offset=0, end_offset=end).to_string()
  let exp_final = exp_base + digits.length() - 1
  let sign = if negative { "-" } else { "" }
  let mantissa = if digits.length() == 1 {
    digits
  } else {
    digits.view(start_offset=0, end_offset=1).to_string() +
    "." +
    digits.view(start_offset=1, end_offset=digits.length()).to_string()
  }
  let exp_mark = if exp_final >= 0 { "+" } else { "-" }
  let exp_abs = if exp_final >= 0 { exp_final } else { -exp_final }
  sign + mantissa + "E" + exp_mark + exp_abs.to_string()
}

///|
fn ParseContext::lex_number_end(
  ctx : ParseContext,
  start : Int,
  end : Int,
) -> (Double, StringView?) {
  let s = ctx.input.view(start_offset=start, end_offset=end)
  if !s.contains(".") && !s.contains("e") && !s.contains("E") {
    let parsed_int = try? @strconv.parse_int64(s)
    match parsed_int {
      Ok(i) => {
        if s == "-0" {
          return (-0.0, Some(s))
        }
        let d = i.to_double()
        if i <= 9007199254740991 && i >= -9007199254740991 {
          return (d, None)
        }
        return (d, Some(s))
      }
      Err(_) => {
        let parsed_double = try? @strconv.parse_double(s)
        match parsed_double {
          Ok(d) =>
            if number_literal_needs_exponent_normalization(s) {
              (d, Some(number_literal_normalized_large_exponent_repr(s)))
            } else {
              (d, Some(s))
            }
          Err(_) =>
            if s is ['-', ..] {
              if number_literal_needs_exponent_normalization(s) {
                (
                  @double.neg_infinity,
                  Some(number_literal_normalized_large_exponent_repr(s)),
                )
              } else {
                (@double.neg_infinity, Some(s))
              }
            } else if number_literal_needs_exponent_normalization(s) {
              (
                @double.infinity,
                Some(number_literal_normalized_large_exponent_repr(s)),
              )
            } else {
              (@double.infinity, Some(s))
            }
        }
      }
    }
  } else {
    let parsed_double = try? @strconv.parse_double(s)
    match parsed_double {
      Ok(d) =>
        if number_literal_should_preserve_repr(s) {
          if number_literal_needs_exponent_normalization(s) {
            (d, Some(number_literal_normalized_large_exponent_repr(s)))
          } else {
            (d, Some(s))
          }
        } else {
          (d, None)
        }
      Err(_) =>
        if s is ['-', ..] {
          if number_literal_needs_exponent_normalization(s) {
            (
              @double.neg_infinity,
              Some(number_literal_normalized_large_exponent_repr(s)),
            )
          } else {
            (@double.neg_infinity, Some(s))
          }
        } else if number_literal_needs_exponent_normalization(s) {
          (
            @double.infinity,
            Some(number_literal_normalized_large_exponent_repr(s)),
          )
        } else {
          (@double.infinity, Some(s))
        }
    }
  }
}
