///|
priv struct DecimalParts {
  negative : Bool
  significant : String
  exponent : Int64
}

///|
fn decimal_ascii_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn decimal_trim_leading_zeros(s : String) -> String {
  let mut i = 0
  while i < s.length() && s.unsafe_get(i).to_int().unsafe_to_char() == '0' {
    i += 1
  }
  if i >= s.length() {
    "0"
  } else {
    s.view(start_offset=i, end_offset=s.length()).to_owned()
  }
}

///|
fn decimal_split_exponent(raw : String) -> (String, Int64)? {
  let mut exp_index = -1
  for i in 0..<raw.length() {
    let c = raw.unsafe_get(i).to_int().unsafe_to_char()
    if c == 'e' || c == 'E' {
      exp_index = i
      break
    }
  }
  if exp_index < 0 {
    Some((raw, 0))
  } else {
    let mantissa = raw.view(start_offset=0, end_offset=exp_index).to_owned()
    let exp_part = raw
      .view(start_offset=exp_index + 1, end_offset=raw.length())
      .to_owned()
    let exp = try @string.parse_int64(exp_part) catch {
      _ => return None
    } noraise {
      v => v
    }
    Some((mantissa, exp))
  }
}

///|
fn decimal_parse_mantissa(mantissa : String) -> (Bool, String, Int)? {
  if mantissa.length() == 0 {
    return None
  }
  let mut negative = false
  let mut pos = 0
  let first = mantissa.unsafe_get(0).to_int().unsafe_to_char()
  if first == '-' {
    negative = true
    pos = 1
  } else if first == '+' {
    pos = 1
  }
  if pos >= mantissa.length() {
    return None
  }
  let buf = StringBuilder()
  let mut seen_digit = false
  let mut seen_dot = false
  let mut frac_len = 0
  for i in pos..<mantissa.length() {
    let c = mantissa.unsafe_get(i).to_int().unsafe_to_char()
    if c == '.' {
      if seen_dot {
        return None
      }
      seen_dot = true
    } else if decimal_ascii_digit(c) {
      seen_digit = true
      buf.write_char(c)
      if seen_dot {
        frac_len += 1
      }
    } else {
      return None
    }
  }
  if !seen_digit {
    return None
  }
  Some((negative, buf.to_string(), frac_len))
}

///|
fn decimal_parts_from_repr(raw : String) -> DecimalParts? {
  match decimal_split_exponent(raw) {
    None => None
    Some((mantissa, exp)) =>
      match decimal_parse_mantissa(mantissa) {
        None => None
        Some((negative, digits_raw, frac_len)) => {
          let significant = decimal_trim_leading_zeros(digits_raw)
          let is_zero = significant == "0"
          Some({
            negative: negative && !is_zero,
            significant,
            exponent: exp - Int64::from_int(frac_len),
          })
        }
      }
  }
}

///|
fn decimal_compare_parts(a : DecimalParts, b : DecimalParts) -> Int {
  if a.significant == "0" && b.significant == "0" {
    return 0
  }
  if a.negative && !b.negative {
    return -1
  }
  if !a.negative && b.negative {
    return 1
  }
  let sign = if a.negative { -1 } else { 1 }
  let a_adjusted = a.exponent + Int64::from_int(a.significant.length())
  let b_adjusted = b.exponent + Int64::from_int(b.significant.length())
  if a_adjusted < b_adjusted {
    return -sign
  }
  if a_adjusted > b_adjusted {
    return sign
  }
  let min_exp = if a.exponent < b.exponent { a.exponent } else { b.exponent }
  let a_pad = (a.exponent - min_exp).to_int()
  let b_pad = (b.exponent - min_exp).to_int()
  let sa = StringBuilder()
  sa.write_string(a.significant)
  for _ in 0..<a_pad {
    sa.write_char('0')
  }
  let sb = StringBuilder()
  sb.write_string(b.significant)
  for _ in 0..<b_pad {
    sb.write_char('0')
  }
  sign * sa.to_string().compare(sb.to_string())
}

///|
fn decimal_compare_repr(a : String, b : String) -> Int? {
  match (decimal_parts_from_repr(a), decimal_parts_from_repr(b)) {
    (Some(x), Some(y)) => Some(decimal_compare_parts(x, y))
    _ => None
  }
}

///|
fn decimal_normalize_plain(
  sign : String,
  digits_raw : String,
  scale64 : Int64,
) -> String {
  let digits = decimal_trim_leading_zeros(digits_raw)
  if digits == "0" {
    if scale64 <= 0L {
      return sign + "0"
    }
    if scale64 > 10000L {
      return sign + "0"
    }
    let b = StringBuilder()
    b.write_string(sign)
    b.write_string("0.")
    for _ in 0..<scale64.to_int() {
      b.write_char('0')
    }
    return b.to_string()
  }
  if scale64 == 0L {
    return sign + digits
  }
  if scale64 < 0L {
    let exponent = Int64::from_int(digits.length()) - scale64 - 1L
    return decimal_normalize_scientific(sign, digits, exponent)
  }
  if scale64 > 10000L {
    let exponent = Int64::from_int(digits.length()) - scale64 - 1L
    return decimal_normalize_scientific(sign, digits, exponent)
  }
  let scale = scale64.to_int()
  let b = StringBuilder()
  b.write_string(sign)
  if digits.length() > scale {
    b.write_string(
      digits.view(start_offset=0, end_offset=digits.length() - scale).to_owned(),
    )
    b.write_char('.')
    b.write_string(
      digits
      .view(start_offset=digits.length() - scale, end_offset=digits.length())
      .to_owned(),
    )
  } else {
    b.write_string("0.")
    for _ in 0..<(scale - digits.length()) {
      b.write_char('0')
    }
    b.write_string(digits)
  }
  b.to_string()
}

///|
fn decimal_normalize_scientific(
  sign : String,
  significant : String,
  exponent : Int64,
) -> String {
  let b = StringBuilder()
  b.write_string(sign)
  b.write_char(significant.unsafe_get(0).to_int().unsafe_to_char())
  if significant.length() > 1 {
    b.write_char('.')
    b.write_string(
      significant
      .view(start_offset=1, end_offset=significant.length())
      .to_owned(),
    )
  }
  if exponent >= 0L {
    b.write_string("E+")
  } else {
    b.write_char('E')
  }
  b.write_string(exponent.to_string())
  b.to_string()
}

///|
fn decimal_canonical_repr(raw : String) -> String? {
  match decimal_split_exponent(raw) {
    None => None
    Some((mantissa, exp)) =>
      match decimal_parse_mantissa(mantissa) {
        None => None
        Some((negative, digits_raw, frac_len)) => {
          let sign = if negative { "-" } else { "" }
          let scale = Int64::from_int(frac_len) - exp
          if scale >= 0L {
            Some(decimal_normalize_plain(sign, digits_raw, scale))
          } else {
            let mut leading = 0
            while leading < digits_raw.length() &&
                  digits_raw.unsafe_get(leading).to_int().unsafe_to_char() ==
                  '0' {
              leading += 1
            }
            if leading >= digits_raw.length() {
              Some("0")
            } else {
              let significant = digits_raw
                .view(start_offset=leading, end_offset=digits_raw.length())
                .to_owned()
              let adjusted_exponent = Int64::from_int(significant.length()) -
                Int64::from_int(frac_len) +
                exp -
                1L
              Some(
                decimal_normalize_scientific(
                  sign, significant, adjusted_exponent,
                ),
              )
            }
          }
        }
      }
  }
}

///|
fn decimal_negated_repr(raw : String) -> String? {
  match decimal_parts_from_repr(raw) {
    None => None
    Some(d) =>
      if d.significant == "0" {
        if raw.has_prefix("-") {
          decimal_canonical_repr(
            raw.view(start_offset=1, end_offset=raw.length()).to_owned(),
          )
        } else {
          decimal_canonical_repr(raw)
        }
      } else if raw.has_prefix("-") {
        decimal_canonical_repr(
          raw.view(start_offset=1, end_offset=raw.length()).to_owned(),
        )
      } else {
        decimal_canonical_repr("-" + raw)
      }
  }
}

///|
fn decimal_abs_repr(raw : String) -> String? {
  if raw.has_prefix("-") {
    let rest = raw.view(start_offset=1, end_offset=raw.length()).to_owned()
    match decimal_parts_from_repr(raw) {
      Some(parts) =>
        if parts.significant == "0" {
          match decimal_canonical_repr(rest) {
            Some(canonical) => Some("-" + canonical)
            None => None
          }
        } else {
          decimal_canonical_repr(rest)
        }
      None => None
    }
  } else {
    decimal_canonical_repr(raw)
  }
}
