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
test "typed executeQuery" {
  let input = parseJson("{\"foo\":7}")
  let out = executeQuery(field("foo"), input)
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values.length(), 1)
  assert_eq(values[0].to_json_string(), "7")
}

///|
test "typed comma query" {
  let out = runQuery(comma(field("a"), field("b")), "{\"a\":1,\"b\":2}")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["1", "2"])
}

///|
test "typed select + iter query" {
  let q = pipe(
    iter(),
    pipe(
      select(eq(field("kind"), literal(@core.Json::string("ok")))),
      field("v"),
    ),
  )
  let out = runQuery(q, "[{\"kind\":\"ok\",\"v\":1},{\"kind\":\"ng\",\"v\":2}]")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["1"])
}

///|
test "typed add query" {
  let q = add(field("x"), literal(@core.Json::number(1.0)))
  let out = runQuery(q, "{\"x\":41}")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["42"])
}

///|
test "typed fallback query" {
  let q = fallback(field("a"), field("b"))
  let out = runQuery(q, "{\"b\":2}")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["2"])
}

///|
test "typed try_catch query" {
  let q = try_catch(field("x"), literal(@core.Json::string("err")))
  let out = runQuery(q, "1")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["\"err\""])
}

///|
test "typed generic call query" {
  let q = call("contains", [literal(@core.Json::string("ab"))])
  let out = runQuery(q, "\"abc\"")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["true"])
}

///|
test "typed comparison + select query" {
  let q = pipe(iter(), select(gt(field("v"), literal(@core.Json::number(1.0)))))
  let out = runQuery(q, "[{\"v\":1},{\"v\":2},{\"v\":3}]")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["{\"v\":2}", "{\"v\":3}"])
}

///|
test "typed boolean combinator query" {
  let cond = and_(
    gt(field("v"), literal(@core.Json::number(1.0))),
    not_(eq(field("kind"), literal(@core.Json::string("skip")))),
  )
  let q = pipe(iter(), pipe(select(cond), field("v")))
  let out = runQuery(
    q, "[{\"kind\":\"ok\",\"v\":1},{\"kind\":\"ok\",\"v\":2},{\"kind\":\"skip\",\"v\":3}]",
  )
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["2"])
}

///|
test "typed if_else query" {
  let q = pipe(
    iter(),
    if_else(
      lt(field("v"), literal(@core.Json::number(2.0))),
      literal(@core.Json::string("small")),
      literal(@core.Json::string("large")),
    ),
  )
  let out = runQuery(q, "[{\"v\":1},{\"v\":3}]")
  guard out is Ok(values) else { fail("expected Ok") }
  assert_eq(values, ["\"small\"", "\"large\""])
}
