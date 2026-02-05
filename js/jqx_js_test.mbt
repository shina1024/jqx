///|
test "js evalToJsonStrings" {
  let out = evalToJsonStrings(".foo", "{\"foo\": 1}")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["1"])
}
