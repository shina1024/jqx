///|
test "js run_json_text success" {
  let out = run_json_text(".foo", "{\"foo\": 1}")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["1"])
}

///|
test "js run_json_text parse error" {
  let out = run_json_text(".foo", "{")
  guard out is Err(err) else { fail("expected Err") }
  assert_eq(err.code, "parse_invalid_eof")
}

///|
test "js parse_json + compile + execute" {
  let json = parse_json("{\"a\": 2}")
  let filter = compile(".a")
  let out = execute(filter, json)
  assert_eq(out.length(), 1)
  assert_eq(out[0].to_json_string(), "2")
  assert_eq(is_valid_json("{\"a\": 2}"), true)
  assert_eq(is_valid_json("{"), false)
}

///|
test "js parse_json preserves large integer repr in output" {
  let out = run_json_text(".", "9007199254740993")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["9007199254740993"])
}

///|
test "js try_parse_json returns Err on invalid input" {
  let out = try_parse_json("{")
  guard out is Err(err) else { fail("expected Err") }
  assert_eq(err.code, "parse_invalid_eof")
}

///|
test "js try_compile and try_execute" {
  let parsed_filter = try_compile(".x")
  guard parsed_filter is Ok(filter) else { fail("expected Ok filter") }
  let parsed_json = try_parse_json("{\"x\": 7}")
  guard parsed_json is Ok(input) else { fail("expected Ok json") }
  let out = try_execute(filter, input)
  guard out is Ok(values) else { fail("expected Ok execute") }
  assert_eq(values.length(), 1)
  assert_eq(values[0].to_json_string(), "7")
}

///|
test "js execute direct filter" {
  let filter = compile(".foo")
  let input = parse_json("{\"foo\": 5}")
  let out = execute(filter, input)
  assert_eq(out.length(), 1)
  assert_eq(out[0].to_json_string(), "5")
  let execute_out = try_execute(filter, input)
  guard execute_out is Ok(values) else { fail("expected Ok") }
  assert_eq(values.length(), 1)
  assert_eq(values[0].to_json_string(), "5")
}

///|
test "js run_json_text preserves large-number repr output" {
  let out = run_json_text(".", "1e309")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["1e309"])
}

///|
test "js run_json_text preserves escaped strings and object order" {
  let out = run_json_text(
    ". + {\"a\":9,\"c\":3}, .foo", "{\"b\":1,\"a\":2,\"foo\":\"line\\nbreak\"}",
  )
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, [
    "{\"b\":1,\"a\":9,\"foo\":\"line\\nbreak\",\"c\":3}", "\"line\\nbreak\"",
  ])
}

///|
test "js run_values convenience lane" {
  let out = run_values(".foo + 1", "{\"foo\": 41}")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values.length(), 1)
  assert_eq(values[0].to_json_string(), "42")
  let out2 = run_values(".foo", "{\"foo\": 9}")
  guard out2 is Ok(values2) else { fail("expected Ok") }
  assert_eq(values2.length(), 1)
  assert_eq(values2[0].to_json_string(), "9")
}

///|
test "js run_compiled_json_text and run_compiled_values" {
  let compiled = compile(".foo")
  let out = run_compiled_json_text(compiled, "{\"foo\": 3}")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["3"])
  let out_values = run_compiled_values(compiled, "{\"foo\": 4}")
  guard out_values is Ok(values2) else { fail("expected Ok") }
  assert_eq(values2.length(), 1)
  assert_eq(values2[0].to_json_string(), "4")
}

///|
test "js compiled lanes preserve ordering and repr-sensitive outputs" {
  let compiled = compile(". + {\"a\":9,\"c\":3}, .huge, .n")
  let text_out = run_compiled_json_text(
    compiled, "{\"b\":1,\"a\":2,\"huge\":9007199254740993,\"n\":1e309}",
  )
  guard text_out is Ok(text_values) else { fail("expected Ok") }
  assert_eq(text_values, [
    "{\"b\":1,\"a\":9,\"huge\":9007199254740993,\"n\":1e309,\"c\":3}", "9007199254740993",
    "1e309",
  ])

  let value_out = run_compiled_values(
    compiled, "{\"b\":1,\"a\":2,\"huge\":9007199254740993,\"n\":1e309}",
  )
  guard value_out is Ok(values) else { fail("expected Ok") }
  assert_eq(values.length(), 3)
  assert_eq(
    values[0].to_json_string(),
    "{\"b\":1,\"a\":9,\"huge\":9007199254740993,\"n\":1e309,\"c\":3}",
  )
  assert_eq(values[1].to_json_string(), "9007199254740993")
  assert_eq(values[2].to_json_string(), "1e309")
}

///|
test "js structured error with position" {
  let out = try_compile(".['x']")
  guard out is Err(err) else { fail("expected Err") }
  assert_eq(err.code, "filter_invalid_char")
  assert_eq(err.line, 1)
  assert_eq(err.column, 3)
  assert_eq(err.offset, 2)
}

///|
test "js structured runtime error" {
  let filter = compile(".foo + 1")
  let input = parse_json("{\"foo\":\"x\"}")
  let out = try_execute(filter, input)
  guard out is Err(err) else { fail("expected Err") }
  assert_eq(err.code, "eval_type_error")
  assert_eq(err.line, -1)
  assert_eq(err.column, -1)
  assert_eq(err.offset, -1)
}
