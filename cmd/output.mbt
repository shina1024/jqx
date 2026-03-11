///|
fn format_output(raw : Bool, v : @lib.Value) -> String {
  if raw && v is @lib.Value::String(s) {
    s
  } else {
    v.to_json_string()
  }
}
