///|
#borrow(path)
extern "c" fn module_source_file_size_ffi(path : Bytes, path_len : Int) -> Int = "jqx_read_file_size_ffi"

///|
#borrow(path, out)
extern "c" fn module_source_file_read_ffi(
  path : Bytes,
  path_len : Int,
  out : Bytes,
  out_len : Int,
) -> Int = "jqx_read_file_into_ffi"

///|
fn module_source_utf8_is_continuation_byte(b : Int) -> Bool {
  b >= 0x80 && b <= 0xBF
}

///|
fn module_source_utf8_decode_next_strict(bytes : Bytes, i : Int) -> (Int, Int)? {
  guard i < bytes.length() else { return None }
  let b0 = bytes[i].to_int()
  if b0 <= 0x7F {
    return Some((b0, 1))
  }
  if b0 < 0xC2 || b0 > 0xF4 {
    return None
  }
  if b0 <= 0xDF {
    guard i + 1 < bytes.length() else { return None }
    let b1 = bytes[i + 1].to_int()
    guard module_source_utf8_is_continuation_byte(b1) else { return None }
    let code = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
    return Some((code, 2))
  }
  if b0 <= 0xEF {
    guard i + 2 < bytes.length() else { return None }
    let b1 = bytes[i + 1].to_int()
    let b2 = bytes[i + 2].to_int()
    guard module_source_utf8_is_continuation_byte(b1) &&
      module_source_utf8_is_continuation_byte(b2) else {
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
  let b1 = bytes[i + 1].to_int()
  let b2 = bytes[i + 2].to_int()
  let b3 = bytes[i + 3].to_int()
  guard module_source_utf8_is_continuation_byte(b1) &&
    module_source_utf8_is_continuation_byte(b2) &&
    module_source_utf8_is_continuation_byte(b3) else {
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
fn module_source_decode_utf8(bytes : Bytes) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < bytes.length() {
    match module_source_utf8_decode_next_strict(bytes, i) {
      Some((code, width)) => {
        out.write_char(code.unsafe_to_char())
        i += width
      }
      None => {
        out.write_char('\u{fffd}')
        i += 1
      }
    }
  }
  out.to_string()
}

///|
fn module_source_read_file(path : String) -> String? {
  let path_buf = @buffer.new(size_hint=path.length() * 4)
  path_buf.write_string_utf8(path)
  let path_bytes = path_buf.to_bytes()
  let path_len = path_bytes.length()
  let size = module_source_file_size_ffi(path_bytes, path_len)
  if size < 0 {
    return None
  }
  let out = Bytes::new(size)
  let read_len = module_source_file_read_ffi(path_bytes, path_len, out, size)
  if read_len != size {
    return None
  }
  Some(module_source_decode_utf8(out))
}
