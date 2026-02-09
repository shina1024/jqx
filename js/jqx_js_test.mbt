///|
test "js evalToJsonStrings success" {
  let out = evalToJsonStrings(".foo", "{\"foo\": 1}")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["1"])
}

///|
test "js evalToJsonStrings parse error" {
  let out = evalToJsonStrings(".foo", "{")
  guard out is Err(_) else { fail("expected Err") }
}

///|
test "js parseJson + parseFilter + eval" {
  let json = parseJson("{\"a\": 2}")
  let filter = parseFilter(".a")
  let out = eval(filter, json)
  assert_eq(out.length(), 1)
  assert_eq(out[0].to_json_string(), "2")
}

///|
test "js parseJson preserves large integer repr in output" {
  let out = evalToJsonStrings(".", "9007199254740993")
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
test "js tryParseFilter and tryEval" {
  let parsed_filter = tryParseFilter(".x")
  guard parsed_filter is Ok(filter) else { fail("expected Ok filter") }
  let parsed_json = tryParseJson("{\"x\": 7}")
  guard parsed_json is Ok(input) else { fail("expected Ok json") }
  let out = tryEval(filter, input)
  guard out is Ok(values) else { fail("expected Ok eval") }
  assert_eq(values.length(), 1)
  assert_eq(values[0].to_json_string(), "7")
}

///|
test "js run aliases evalToJsonStrings" {
  let out = run(".[]", "[1,2]")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["1", "2"])
}

///|
test "js execute and safeExecute aliases" {
  let filter = parseFilter(".foo")
  let input = parseJson("{\"foo\": 5}")
  let out = execute(filter, input)
  assert_eq(out.length(), 1)
  assert_eq(out[0].to_json_string(), "5")
  let safe_out = safeExecute(filter, input)
  guard safe_out is Ok(values) else { fail("expected Ok") }
  assert_eq(values.length(), 1)
  assert_eq(values[0].to_json_string(), "5")
}
