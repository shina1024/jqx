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
