///|
fn format_output(raw : Bool, v : @lib.Value) -> String {
  if raw && v is String(s) {
    s
  } else {
    v.to_json_string()
  }
}
