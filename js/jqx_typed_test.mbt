///|
test "typed identity query" {
  let q : Query[@core.Json, @core.Json] = identity()
  let out = runQuery(q, "{\"a\":1}")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["{\"a\":1}"])
}

///|
test "typed field query" {
  let out = runQuery(field("foo"), "{\"foo\":2}")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["2"])
}

///|
test "typed pipe query" {
  let out = runQuery(pipe(field("foo"), field("bar")), "{\"foo\":{\"bar\":3}}")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["3"])
}

///|
test "typed map query" {
  let out = runQuery(map(field("x")), "[{\"x\":1},{\"x\":2}]")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["[1,2]"])
}

///|
test "typed evalQuery" {
  let input = parseJson("{\"foo\":7}")
  let out = evalQuery(field("foo"), input)
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values.length(), 1)
  assert_eq(values[0].to_json_string(), "7")
}
