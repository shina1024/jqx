///|
test "parse primitives" {
  assert_eq(try? parse("null"), Ok(Json::null()))
  assert_eq(try? parse("true"), Ok(Json::boolean(true)))
  assert_eq(try? parse("false"), Ok(Json::boolean(false)))
}

///|
test "parse numbers and arrays" {
  let json = try? parse("[1, -2, 3.5, 1e2]")
  assert_eq(
    json,
    Ok(
      Json::array([
        Json::number(1.0),
        Json::number(-2.0),
        Json::number(3.5),
        Json::number(100.0),
      ]),
    ),
  )
}

///|
test "parse large integer keeps repr" {
  let json = try? parse("9007199254740993")
  assert_eq(json, Ok(Json::number(9007199254740992.0, repr="9007199254740993")))
}

///|
test "parse object" {
  let json = try? parse("{\"a\":1,\"b\":[true,false]}")
  assert_eq(
    json,
    Ok(
      Json::object({
        "a": Json::number(1.0),
        "b": Json::array([Json::boolean(true), Json::boolean(false)]),
      }),
    ),
  )
}

///|
test "parse string escapes" {
  let json = try? parse("\"\\n\\t\\\"\"")
  assert_eq(json, Ok(Json::string("\n\t\"")))
}

///|
test "parse whitespace" {
  let json = try? parse(" \n\t[1, 2]\r ")
  assert_eq(json, Ok(Json::array([Json::number(1.0), Json::number(2.0)])))
}

///|
test "parse errors" {
  guard (try? parse("")) is Err(InvalidEof) else {
    fail("expected InvalidEof for empty input")
  }
  guard (try? parse("]")) is Err(InvalidChar(_, _)) else {
    fail("expected InvalidChar for unexpected token")
  }
  guard (try? parse("{\"a\":1")) is Err(InvalidEof) else {
    fail("expected InvalidEof for missing closing brace")
  }
}
