///|
fn read_stdin_all_internal() -> String {
  let bytes = []
  loop getchar() {
    -1 => break
    c => {
      bytes.push(c)
      continue getchar()
    }
  }
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
extern "c" fn getchar() -> Int = "getchar"

///|
fn utf8_is_continuation_byte(b : Int) -> Bool {
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
    guard utf8_is_continuation_byte(b1) else { return None }
    let code = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
    return Some((code, 2))
  }
  if b0 <= 0xEF {
    guard i + 2 < bytes.length() else { return None }
    let b1 = bytes[i + 1]
    let b2 = bytes[i + 2]
    guard utf8_is_continuation_byte(b1) && utf8_is_continuation_byte(b2) else {
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
  guard utf8_is_continuation_byte(b1) &&
    utf8_is_continuation_byte(b2) &&
    utf8_is_continuation_byte(b3) else {
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
