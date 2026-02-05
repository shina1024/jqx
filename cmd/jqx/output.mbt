///|
pub fn format_output(raw : Bool, v : @lib.Json) -> String {
  if raw && v is @lib.Json::String(s) {
    s
  } else {
    v.to_json_string()
  }
}
