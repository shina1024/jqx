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
pub fn parse_json(
  input : StringView,
  max_nesting_depth? : Int = 10000,
) -> Json raise ParseError {
  Value::to_json(parse(input, max_nesting_depth~))
}

///|
pub fn parse(
  input : StringView,
  max_nesting_depth? : Int = 10000,
) -> Value raise ParseError {
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
fn ParseContext::parse_value(ctx : ParseContext) -> Value raise ParseError {
  let tok = ctx.lex_value(allow_rbracket=false)
  ctx.parse_value2(tok)
}

///|
fn ParseContext::parse_value2(
  ctx : ParseContext,
  tok : Token,
) -> Value raise ParseError {
  match tok {
    Null => Value::null()
    True => Value::boolean(true)
    False => Value::boolean(false)
    Number(n, repr) => Value::number(n, repr?)
    String(s) => Value::string(s)
    LBrace => ctx.parse_object()
    LBracket => ctx.parse_array()
    RBracket | RBrace | Comma => abort("unreachable")
  }
}

///|
fn ParseContext::parse_object(ctx : ParseContext) -> Value raise ParseError {
  if ctx.remaining_available_depth <= 0 {
    raise DepthLimitExceeded
  }
  ctx.remaining_available_depth -= 1
  let map = Map([])
  let key_order = []
  for token = ctx.lex_property_name() {
    match token {
      RBrace => {
        ctx.remaining_available_depth += 1
        break Value::object_with_order(map, key_order)
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
            break Value::object_with_order(map, key_order)
          }
          _ => abort("unreachable")
        }
      }
      _ => abort("unreachable")
    }
  }
}

///|
fn ParseContext::parse_array(ctx : ParseContext) -> Value raise ParseError {
  if ctx.remaining_available_depth <= 0 {
    raise DepthLimitExceeded
  }
  ctx.remaining_available_depth -= 1
  let vec = []
  for token = ctx.lex_value(allow_rbracket=true) {
    match token {
      RBracket => {
        ctx.remaining_available_depth += 1
        break Value::array(vec)
      }
      tok => {
        vec.push(ctx.parse_value2(tok))
        let tok2 = ctx.lex_after_array_value()
        match tok2 {
          Comma => continue ctx.lex_value(allow_rbracket=false)
          RBracket => {
            ctx.remaining_available_depth += 1
            break Value::array(vec)
          }
          _ => abort("unreachable")
        }
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
  return { line, column }
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
  let buf = StringBuilder()
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
  while ctx.offset < ctx.end_offset {
    match ctx.peek_char() {
      Some(c) if is_ascii_alpha(c) || c is ('0'..='9') =>
        ignore(ctx.read_char())
      Some(_) => {
        ended_at_separator = true
        break
      }
      None => break
    }
  }
  let token = ctx.input
    .view(start_offset=start, end_offset=ctx.offset)
    .to_owned()
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
  lexmatch rest with longest {
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
          ctx.expect_ascii_char(b'u')
          ctx.expect_ascii_char(b'l')
          ctx.expect_ascii_char(b'l')
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
      ctx.expect_ascii_char(b'r')
      ctx.expect_ascii_char(b'u')
      ctx.expect_ascii_char(b'e')
      return True
    }
    Some('f') => {
      ctx.expect_ascii_char(b'a')
      ctx.expect_ascii_char(b'l')
      ctx.expect_ascii_char(b's')
      ctx.expect_ascii_char(b'e')
      return False
    }
    Some('-') =>
      match ctx.read_char() {
        Some('0') => {
          let (n, repr) = ctx.lex_zero(start=ctx.offset - 2)
          return Number(n, repr.map(s => s.to_owned()))
        }
        Some(c2) => {
          if c2 is ('1'..='9') {
            let (n, repr) = ctx.lex_decimal_integer(start=ctx.offset - 2)
            return Number(n, repr.map(s => s.to_owned()))
          } else if c2 is ('i' | 'I' | 'n' | 'N') {
            return ctx.lex_nonfinite_number(start=ctx.offset - 2)
          }
          ctx.invalid_char(shift=-1)
        }
        None => raise InvalidEof
      }
    Some('0') => {
      let (n, repr) = ctx.lex_zero(start=ctx.offset - 1)
      return Number(n, repr.map(s => s.to_owned()))
    }
    Some('1'..='9') => {
      let (n, repr) = ctx.lex_decimal_integer(start=ctx.offset - 1)
      return Number(n, repr.map(s => s.to_owned()))
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
  let buf = StringBuilder()
  let mut start = ctx.offset
  fn flush(end : Int) {
    if start > 0 && end > start {
      buf.write_view(ctx.input.view(start_offset=start, end_offset=end))
    }
  }

  let mut closed = false
  while !closed {
    match ctx.read_char() {
      Some('"') => {
        flush(ctx.offset - 1)
        closed = true
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
  while !has_closing_quote && ctx.offset < ctx.end_offset {
    match ctx.read_char() {
      Some('\'') => has_closing_quote = true
      Some(_) => ()
      None => ()
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
  let mut digits_read = 0
  while digits_read < n {
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
    digits_read += 1
  }
  r
}

///|
fn ParseContext::lex_decimal_integer(
  ctx : ParseContext,
  start~ : Int,
) -> (Double, StringView?) raise ParseError {
  while ctx.offset < ctx.end_offset {
    match ctx.peek_char() {
      Some('.') => {
        ignore(ctx.read_char())
        return ctx.lex_decimal_point(start~)
      }
      Some('e' | 'E') => {
        ignore(ctx.read_char())
        return ctx.lex_decimal_exponent(start~)
      }
      Some(c) =>
        if c >= '0' && c <= '9' {
          ignore(ctx.read_char())
        } else {
          return ctx.lex_number_end(start, ctx.offset)
        }
      None => break
    }
  }
  ctx.lex_number_end(start, ctx.offset)
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
  while ctx.offset < ctx.end_offset {
    match ctx.peek_char() {
      Some('e' | 'E') => {
        ignore(ctx.read_char())
        return ctx.lex_decimal_exponent(start~)
      }
      Some(c) =>
        if c >= '0' && c <= '9' {
          ignore(ctx.read_char())
        } else {
          return ctx.lex_number_end(start, ctx.offset)
        }
      None => break
    }
  }
  ctx.lex_number_end(start, ctx.offset)
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
  while ctx.offset < ctx.end_offset {
    match ctx.peek_char() {
      Some(c) =>
        if c >= '0' && c <= '9' {
          ignore(ctx.read_char())
        } else {
          return ctx.lex_number_end(start, ctx.offset)
        }
      None => break
    }
  }
  ctx.lex_number_end(start, ctx.offset)
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
  while left_start < dot &&
        token.unsafe_get(left_start).to_int().unsafe_to_char() == '0' {
    left_start += 1
  }
  let left_digits = if dot > left_start { dot - left_start } else { 0 }
  let mut right_start = end
  if dot < end {
    right_start = dot + 1
  }
  let mut right_end = end
  while right_end > right_start &&
        token.unsafe_get(right_end - 1).to_int().unsafe_to_char() == '0' {
    right_end -= 1
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
    None => return token.to_owned()
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
      return token.to_owned()
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
  let digits_raw_buf = StringBuilder()
  let mut frac_digits = 0
  let mut saw_dot = false
  for i in mant_start..<exp_index {
    let ch = token.unsafe_get(i).to_int().unsafe_to_char()
    if ch == '.' {
      if saw_dot {
        return token.to_owned()
      }
      saw_dot = true
    } else if is_ascii_digit(ch) {
      digits_raw_buf.write_char(ch)
      if saw_dot {
        frac_digits += 1
      }
    } else {
      return token.to_owned()
    }
  }
  let digits_raw = digits_raw_buf.to_string()
  if digits_raw.length() == 0 {
    return token.to_owned()
  }
  let mut lead = 0
  while lead < digits_raw.length() &&
        digits_raw.unsafe_get(lead).to_int().unsafe_to_char() == '0' {
    lead += 1
  }
  if lead >= digits_raw.length() {
    return "0E+0"
  }
  let trimmed = digits_raw
    .view(start_offset=lead, end_offset=digits_raw.length())
    .to_owned()
  let mut end = trimmed.length()
  let mut exp_base = exp_value - frac_digits
  while end > 1 && trimmed.unsafe_get(end - 1).to_int().unsafe_to_char() == '0' {
    end -= 1
    exp_base += 1
  }
  let digits = trimmed.view(start_offset=0, end_offset=end).to_owned()
  let exp_final = exp_base + digits.length() - 1
  let sign = if negative { "-" } else { "" }
  let mantissa = if digits.length() == 1 {
    digits
  } else {
    digits.view(start_offset=0, end_offset=1).to_owned() +
    "." +
    digits.view(start_offset=1, end_offset=digits.length()).to_owned()
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
    try @string.parse_int64(s) catch {
      _ =>
        try @string.parse_double(s) catch {
          _ =>
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
        } noraise {
          d =>
            if number_literal_needs_exponent_normalization(s) {
              (d, Some(number_literal_normalized_large_exponent_repr(s)))
            } else {
              (d, Some(s))
            }
        }
    } noraise {
      i => {
        if s == "-0" {
          return (-0.0, Some(s))
        }
        let d = i.to_double()
        if i <= 9007199254740991 && i >= -9007199254740991 {
          return (d, None)
        }
        return (d, Some(s))
      }
    }
  } else {
    try @string.parse_double(s) catch {
      _ =>
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
    } noraise {
      d =>
        if number_literal_should_preserve_repr(s) {
          if number_literal_needs_exponent_normalization(s) {
            (d, Some(number_literal_normalized_large_exponent_repr(s)))
          } else {
            (d, Some(s))
          }
        } else {
          (d, None)
        }
    }
  }
}
