///|
test "js executeToJsonStrings success" {
  let out = executeToJsonStrings(".foo", "{\"foo\": 1}")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["1"])
}

///|
test "js executeToJsonStrings parse error" {
  let out = executeToJsonStrings(".foo", "{")
  guard out is Err(_) else { fail("expected Err") }
}

///|
test "js parseJson + compile + execute" {
  let json = parseJson("{\"a\": 2}")
  let filter = compile(".a")
  let out = execute(filter, json)
  assert_eq(out.length(), 1)
  assert_eq(out[0].to_json_string(), "2")
}

///|
test "js parseJson preserves large integer repr in output" {
  let out = executeToJsonStrings(".", "9007199254740993")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["9007199254740993"])
}

///|
test "js tryParseJson returns Err on invalid input" {
  let out = tryParseJson("{")
  guard out is Err(_) else { fail("expected Err") }
}

///|
test "js safeParseJson alias" {
  let out = safeParseJson("{")
  guard out is Err(_) else { fail("expected Err") }
}

///|
test "js tryCompile and tryExecute" {
  let parsed_filter = tryCompile(".x")
  guard parsed_filter is Ok(filter) else { fail("expected Ok filter") }
  let parsed_json = tryParseJson("{\"x\": 7}")
  guard parsed_json is Ok(input) else { fail("expected Ok json") }
  let out = tryExecute(filter, input)
  guard out is Ok(values) else { fail("expected Ok execute") }
  assert_eq(values.length(), 1)
  assert_eq(values[0].to_json_string(), "7")
}

///|
test "js run aliases executeToJsonStrings" {
  let out = run(".[]", "[1,2]")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["1", "2"])
}

///|
test "js execute and parseFilter alias" {
  let filter = compile(".foo")
  let input = parseJson("{\"foo\": 5}")
  let out = execute(filter, input)
  assert_eq(out.length(), 1)
  assert_eq(out[0].to_json_string(), "5")
  let safe_out = safeExecute(filter, input)
  guard safe_out is Ok(values) else { fail("expected Ok") }
  assert_eq(values.length(), 1)
  assert_eq(values[0].to_json_string(), "5")
  let filter_alias = parseFilter(".foo")
  let alias_out = execute(filter_alias, input)
  assert_eq(alias_out.length(), 1)
  assert_eq(alias_out[0].to_json_string(), "5")
}

///|
test "js runCompat preserves large-number repr output" {
  let out = runCompat(".", "1e309")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["1e309"])
}

///|
test "js runValues convenience lane" {
  let out = runValues(".foo + 1", "{\"foo\": 41}")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values.length(), 1)
  assert_eq(values[0].to_json_string(), "42")
  let safe_out = safeRunValues(".foo", "{\"foo\": 9}")
  guard safe_out is Ok(safe_values) else { fail("expected Ok") }
  assert_eq(safe_values.length(), 1)
  assert_eq(safe_values[0].to_json_string(), "9")
}
