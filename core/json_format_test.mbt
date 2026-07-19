///|
// Source under test: core/json_format.mbt

///|
test "pretty json formatting matches jq layout" {
  let value = Value::object_from_entries([
    (
      "foo",
      Value::array([
        Value::number(1.0),
        Value::object_from_entries([("bar", Value::number(2.0))]),
      ]),
    ),
  ])
  @debug.assert_eq(
    value.to_json_string_pretty(),
    "{\n  \"foo\": [\n    1,\n    {\n      \"bar\": 2\n    }\n  ]\n}",
  )
  @debug.assert_eq(Value::array([]).to_json_string_pretty(), "[]")
  @debug.assert_eq(Value::object(Map([])).to_json_string_pretty(), "{}")
}

///|
test "json formatting handles jq maximum depth without host stack overflow" {
  let mut value = Value::null()
  for _ in 0..<10001 {
    value = Value::array([value])
  }
  let rendered = value.to_json_string()
  guard rendered.contains("<skipped: too deep>") else {
    fail("expected jq maximum-depth sentinel")
  }
}
