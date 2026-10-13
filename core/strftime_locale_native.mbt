///|
#borrow(pattern)
extern "c" fn strftime_locale_size_ffi(
  pattern : Bytes,
  pattern_len : Int32,
  year : Int32,
  month : Int32,
  day : Int32,
  hour : Int32,
  minute : Int32,
  second : Int32,
  day_of_week : Int32,
  day_of_year : Int32,
) -> Int32 = "jqx_strftime_size_ffi"

///|
#borrow(pattern, out)
extern "c" fn strftime_locale_into_ffi(
  pattern : Bytes,
  pattern_len : Int32,
  year : Int32,
  month : Int32,
  day : Int32,
  hour : Int32,
  minute : Int32,
  second : Int32,
  day_of_week : Int32,
  day_of_year : Int32,
  out : Bytes,
  out_len : Int32,
) -> Int32 = "jqx_strftime_into_ffi"

///|
fn strftime_locale_format(
  pattern : String,
  year : Int32,
  month : Int32,
  day : Int32,
  hour : Int32,
  minute : Int32,
  second : Int32,
  day_of_week : Int32,
  day_of_year : Int32,
) -> String? {
  let pattern_buf = Buffer(size_hint=pattern.length() * 4)
  pattern_buf.write_string_utf8(pattern)
  let pattern_bytes = pattern_buf.to_bytes()
  let pattern_len = pattern_bytes.length()
  let size = strftime_locale_size_ffi(
    pattern_bytes, pattern_len, year, month, day, hour, minute, second, day_of_week,
    day_of_year,
  )
  if size < 0 {
    return None
  }
  let out = Bytes::new(size)
  let read_len = strftime_locale_into_ffi(
    pattern_bytes, pattern_len, year, month, day, hour, minute, second, day_of_week,
    day_of_year, out, size,
  )
  if read_len != size {
    return None
  }
  Some(module_source_decode_utf8(out))
}
