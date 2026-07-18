///|
#borrow(bytes)
extern "c" fn c_write_stderr(bytes : Bytes, len : Int) -> Int = "jqx_write_stderr"

///|
fn append_utf8_bytes(out : Array[Byte], code : Int) -> Unit {
  if code <= 0x7F {
    out.push(code.to_byte())
  } else if code <= 0x7FF {
    out.push((0xC0 | (code >> 6)).to_byte())
    out.push((0x80 | (code & 0x3F)).to_byte())
  } else if code <= 0xFFFF {
    out.push((0xE0 | (code >> 12)).to_byte())
    out.push((0x80 | ((code >> 6) & 0x3F)).to_byte())
    out.push((0x80 | (code & 0x3F)).to_byte())
  } else {
    out.push((0xF0 | (code >> 18)).to_byte())
    out.push((0x80 | ((code >> 12) & 0x3F)).to_byte())
    out.push((0x80 | ((code >> 6) & 0x3F)).to_byte())
    out.push((0x80 | (code & 0x3F)).to_byte())
  }
}

///|
fn write_stderr_line_internal(line : String) -> Unit {
  let byte_array = []
  for ch in line {
    append_utf8_bytes(byte_array, ch.to_int())
  }
  let bytes = Bytes::from_array(byte_array)
  ignore(c_write_stderr(bytes, bytes.length()))
}
