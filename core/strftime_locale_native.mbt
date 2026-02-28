///|
#borrow(pattern)
extern "c" fn strftime_locale_size_ffi(
  pattern : Bytes,
  pattern_len : Int,
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
  day_of_week : Int,
  day_of_year : Int,
) -> Int = "jqx_strftime_size_ffi"

///|
#borrow(pattern, out)
extern "c" fn strftime_locale_into_ffi(
  pattern : Bytes,
  pattern_len : Int,
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
  day_of_week : Int,
  day_of_year : Int,
  out : Bytes,
  out_len : Int,
) -> Int = "jqx_strftime_into_ffi"

///|
fn strftime_locale_format(
  pattern : String,
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
  day_of_week : Int,
  day_of_year : Int,
) -> String? {
  let pattern_buf = @buffer.new(size_hint=pattern.length() * 4)
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
