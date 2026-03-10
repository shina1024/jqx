///|
extern "c" fn c_windows_utf8_argc() -> Int = "jqx_windows_utf8_argc"

///|
extern "c" fn c_windows_utf8_arg_len(index : Int) -> Int = "jqx_windows_utf8_arg_len"

///|
#borrow(out_ptr)
extern "c" fn c_windows_utf8_arg_copy(
  index : Int,
  out_ptr : Bytes,
  out_len : Int,
) -> Int = "jqx_windows_utf8_arg_copy"

///|
fn utf8_decode_bytes_lossy_prefix(bytes : Bytes, len : Int) -> String {
  let ints = []
  for i in 0..<len {
    ints.push(bytes[i].to_int())
  }
  let buf = StringBuilder::new()
  let mut i = 0
  while i < ints.length() {
    match utf8_decode_next_strict(ints, i) {
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
fn read_cli_args_internal() -> Array[String] {
  let fallback = @env.args()
  let argc = c_windows_utf8_argc()
  if argc <= 0 {
    return fallback
  }
  let out = []
  for i in 0..<argc {
    let len = c_windows_utf8_arg_len(i)
    if len < 0 {
      return fallback
    }
    let buf = Bytes::new(len + 1)
    let copied = c_windows_utf8_arg_copy(i, buf, buf.length())
    if copied != len {
      return fallback
    }
    out.push(utf8_decode_bytes_lossy_prefix(buf, len))
  }
  if out.length() == 0 {
    fallback
  } else {
    out
  }
}
