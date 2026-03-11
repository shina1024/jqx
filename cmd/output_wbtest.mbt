///|
test "format output raw" {
  let v = @lib.Value::string("hi")
  assert_eq(format_output(true, v), "hi")
  assert_eq(format_output(false, v), "\"hi\"")
}
