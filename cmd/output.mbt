///|
fn format_output(raw : Bool, compact : Bool, v : @lib.Value) -> String {
  if raw && v is String(s) {
    s
  } else if compact {
    v.to_json_string()
  } else {
    v.to_json_string_pretty()
  }
}
