///|
fn utf8_c_string_bytes(s : String) -> Bytes {
  let utf8 = utf8_bytes_of_string(s)
  let out = []
  for byte in utf8 {
    out.push(byte.to_byte())
  }
  out.push(0)
  Bytes::from_array(out)
}

///|
fn bytes_prefix_to_int_array(bytes : Bytes, len : Int) -> Array[Int] {
  let out = []
  for i in 0..<len {
    out.push(bytes[i].to_int())
  }
  out
}

///|
#borrow(format_ptr, out_ptr)
extern "c" fn c_strftime_with_epoch(
  epoch_seconds : Int64,
  format_ptr : Bytes,
  out_ptr : Bytes,
  out_len : Int,
  use_localtime : Int,
) -> Int = "jqx_strftime_with_epoch"

///|
fn format_datetime_with_c_strftime(
  pattern : String,
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Double,
  use_localtime : Bool,
) -> String? {
  let whole_seconds = datetime_components_to_epoch_seconds(
      year, month, day, hour, minute, second,
    )
    .floor()
    .to_int64()

  let format_bytes = utf8_c_string_bytes(pattern)
  let out_buf = Bytes::new(4096)
  let written = c_strftime_with_epoch(
    whole_seconds,
    format_bytes,
    out_buf,
    out_buf.length(),
    if use_localtime {
      1
    } else {
      0
    },
  )
  if written <= 0 || written > out_buf.length() {
    return None
  }
  Some(utf8_decode_bytes_lossy(bytes_prefix_to_int_array(out_buf, written)))
}
