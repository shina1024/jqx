///|
fn write_output(
  raw : Bool,
  compact : Bool,
  v : @lib.Value,
  write : (String) -> Unit,
) -> Unit {
  if raw && v is String(s) {
    write(s)
  } else {
    v.write_json_chunks(!compact, write)
  }
}
