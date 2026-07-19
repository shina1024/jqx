///|
#borrow(bytes)
extern "c" fn c_write_stdout(bytes : Bytes, len : Int) -> Int = "jqx_write_stdout"

///|
fn write_stdout_chunk(chunk : String) -> Unit {
  let byte_array = []
  for ch in chunk {
    append_utf8_bytes(byte_array, ch.to_int())
  }
  let bytes = Bytes::from_array(byte_array)
  ignore(c_write_stdout(bytes, bytes.length()))
}
