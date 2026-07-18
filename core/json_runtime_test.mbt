///|
// Source under test: core/json_runtime.mbt

///|
fn nested_json_array_text(depth : Int, leaf : String) -> String {
  let buf = StringBuilder()
  for _ in 0..<depth {
    buf.write_char('[')
  }
  buf.write_string(leaf)
  for _ in 0..<depth {
    buf.write_char(']')
  }
  buf.to_string()
}

///|
test "core run helpers centralize value and text lanes" {
  let compiled = compile(".foo") catch {
    err => fail("compile failed: " + err.to_string())
  }
  let compiled_values = run_compiled_values(compiled, "{\"foo\": 4}") catch {
    err => fail("run_compiled_values failed: " + err.to_string())
  }
  @debug.assert_eq(compiled_values, [Value::number(4.0)])

  let values = run_values(".foo", "{\"foo\": 9}") catch {
    err => fail("run_values failed: " + err.to_string())
  }
  @debug.assert_eq(values, [Value::number(9.0)])

  let text = run_compiled_json_text(compiled, "{\"foo\": 9007199254740993}") catch {
    err => fail("run_compiled_json_text failed: " + err.to_string())
  }
  @debug.assert_eq(text, ["9007199254740993"])
}

///|
test "run_json_text follows jq 1.8.2 print depth beyond old limit" {
  let beyond_old_limit = nested_json_array_text(257, "0")
  let within_limit = run_json_text(".", beyond_old_limit) catch {
    err =>
      fail("run_json_text failed beyond old depth limit: " + err.to_string())
  }
  @debug.assert_eq(within_limit, [beyond_old_limit])
}
