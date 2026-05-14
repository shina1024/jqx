///|
test "format output raw" {
  let v = @lib.Value::string("hi")
  @debug.assert_eq(format_output(true, v), "hi")
  @debug.assert_eq(format_output(false, v), "\"hi\"")
}
