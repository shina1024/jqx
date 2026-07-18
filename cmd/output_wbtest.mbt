///|
// Source under test: cmd/output.mbt

///|
test "format output raw" {
  let v = @lib.Value::string("hi")
  @debug.assert_eq(format_output(true, false, v), "hi")
  @debug.assert_eq(format_output(false, false, v), "\"hi\"")
}
