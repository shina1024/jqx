///|
pub enum Json {
  JNull
  JTrue
  JFalse
  Number(Double, String?)
  String(String)
  Array(Array[Json])
  Object(Map[String, Json])
} derive(Eq)

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
  Object(o)
}

///|
pub struct Position {
  line : Int // 1-based
  column : Int // 0-based
} derive(Eq)

///|
pub suberror ParseError {
  InvalidChar(Position, Char)
  InvalidEof
  DepthLimitExceeded
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
      ..write_object(column)
    InvalidEof => logger.write_string("Unexpected end of file")
    DepthLimitExceeded =>
      logger.write_string(
        "Depth limit exceeded, please increase the max_nesting_depth parameter",
      )
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
      Show::output(o, logger)
      logger.write_string(")")
    }
  }
}

///|
/// Encode Json as a compact JSON string (jq-style output).
pub fn Json::to_json_string(self : Json) -> String {
  let buf = StringBuilder::new()
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

  fn write_value(j : Json) {
    match j {
      JNull => buf.write_string("null")
      JTrue => buf.write_string("true")
      JFalse => buf.write_string("false")
      Number(n, repr) =>
        match repr {
          Some(s) => buf.write_string(s)
          None => buf.write_string(n.to_string())
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
          write_value(v)
        }
        buf.write_char(']')
      }
      Object(o) => {
        buf.write_char('{')
        let mut first = true
        for kv in o.iter() {
          let k = kv.0
          let v = kv.1
          if first {
            first = false
          } else {
            buf.write_char(',')
          }
          write_escaped(k)
          buf.write_char(':')
          write_value(v)
        }
        buf.write_char('}')
      }
    }
  }

  write_value(self)
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
#label_migration(max_nesting_depth, fill=false)
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
  loop ctx.lex_property_name() {
    RBrace => {
      ctx.remaining_available_depth += 1
      Json::object(map)
    }
    String(name) => {
      ctx.lex_after_property_name()
      map[name] = ctx.parse_value()
      match ctx.lex_after_object_value() {
        Comma => continue ctx.lex_property_name2()
        RBrace => {
          ctx.remaining_available_depth += 1
          Json::object(map)
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
  let mut column = 0
  for i in 0..<offset {
    if input.unsafe_get(i) == '\n' {
      line += 1
      column = 0
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
    Some('n') => {
      ctx.expect_ascii_char('u')
      ctx.expect_ascii_char('l')
      ctx.expect_ascii_char('l')
      return Null
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
          return Number(n, repr.map(_.to_string()))
        }
        Some(c2) => {
          if c2 is ('1'..='9') {
            let (n, repr) = ctx.lex_decimal_integer(start=ctx.offset - 2)
            return Number(n, repr.map(_.to_string()))
          }
          ctx.invalid_char(shift=-1)
        }
        None => raise InvalidEof
      }
    Some('0') => {
      let (n, repr) = ctx.lex_zero(start=ctx.offset - 1)
      return Number(n, repr.map(_.to_string()))
    }
    Some('1'..='9') => {
      let (n, repr) = ctx.lex_decimal_integer(start=ctx.offset - 1)
      return Number(n, repr.map(_.to_string()))
    }
    Some('"') => {
      let s = ctx.lex_string()
      return String(s)
    }
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
        let d = i.to_double()
        if i <= 9007199254740991 && i >= -9007199254740991 {
          return (d, None)
        }
        return (d, Some(s))
      }
      Err(_) => {
        let parsed_double = try? @strconv.parse_double(s)
        match parsed_double {
          Ok(d) => (d, Some(s))
          Err(_) =>
            if s is ['-', ..] {
              (@double.neg_infinity, Some(s))
            } else {
              (@double.infinity, Some(s))
            }
        }
      }
    }
  } else {
    let parsed_double = try? @strconv.parse_double(s)
    match parsed_double {
      Ok(d) => (d, None)
      Err(_) =>
        if s is ['-', ..] {
          (@double.neg_infinity, Some(s))
        } else {
          (@double.infinity, Some(s))
        }
    }
  }
}
