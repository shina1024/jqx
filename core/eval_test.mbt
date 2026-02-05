///|
fn must_parse(input : String) -> Json raise Failure {
  parse(input) catch {
    err => fail("parse failed: " + err.to_string())
  }
}

///|
fn must_eval(f : Filter, j : Json) -> Array[Json] raise Failure {
  eval(f, j) catch {
    err => fail("eval failed: " + err.to_string())
  }
}

///|
test "eval identity" {
  let j = must_parse("{\"a\":1}")
  let f = parse_filter(".")
  let out = must_eval(f, j)
  assert_eq(out, [j])
}

///|
test "eval field and missing field" {
  let j = must_parse("{\"a\":1}")
  let f1 = parse_filter(".a")
  let f2 = parse_filter(".b")
  assert_eq(must_eval(f1, j), [Json::number(1.0)])
  assert_eq(must_eval(f2, j), [Json::null()])
}

///|
test "eval index and iter" {
  let j = must_parse("[1,2,3]")
  let f1 = parse_filter(".[1]")
  let f2 = parse_filter(".[]")
  assert_eq(must_eval(f1, j), [Json::number(2.0)])
  assert_eq(must_eval(f2, j), [
    Json::number(1.0),
    Json::number(2.0),
    Json::number(3.0),
  ])
}

///|
test "eval pipe and comma" {
  let j = must_parse("{\"a\":{\"b\":2},\"c\":3}")
  let f = parse_filter(".a | .b, .c")
  assert_eq(must_eval(f, j), [Json::number(2.0), Json::number(3.0)])
}

///|
test "eval literal" {
  let j = must_parse("null")
  let f = parse_filter("\"hi\"")
  assert_eq(must_eval(f, j), [Json::string("hi")])
}

///|
test "eval array and object literals" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  let f1 = parse_filter("[.a, .b]")
  let f2 = parse_filter("{\"x\": .a, y: .b}")
  assert_eq(must_eval(f1, j), [
    Json::array([Json::number(1.0), Json::number(2.0)]),
  ])
  assert_eq(must_eval(f2, j), [
    Json::object({ "x": Json::number(1.0), "y": Json::number(2.0) }),
  ])
}

///|
test "eval builtins" {
  let j1 = must_parse("[1,2,3]")
  let j2 = must_parse("{\"a\":1,\"b\":2}")
  let j3 = must_parse("\"hi\"")
  assert_eq(must_eval(parse_filter("length"), j1), [Json::number(3.0)])
  assert_eq(must_eval(parse_filter("length"), j2), [Json::number(2.0)])
  assert_eq(must_eval(parse_filter("length"), j3), [Json::number(2.0)])
  assert_eq(must_eval(parse_filter("type"), j2), [Json::string("object")])
  assert_eq(must_eval(parse_filter("keys"), j2), [
    Json::array([Json::string("a"), Json::string("b")]),
  ])
}

///|
test "eval select" {
  let j = must_parse("{\"a\":1,\"b\":null}")
  let f1 = parse_filter("select(.a)")
  let f2 = parse_filter("select(.b)")
  assert_eq(must_eval(f1, j), [j])
  assert_eq(must_eval(f2, j), [])
}

///|
test "eval compare" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  let f1 = parse_filter(".a == 1")
  let f2 = parse_filter(".a != .b")
  assert_eq(must_eval(f1, j), [Json::boolean(true)])
  assert_eq(must_eval(f2, j), [Json::boolean(true)])
}

///|
test "eval compare order and logical" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  assert_eq(must_eval(parse_filter(".a < .b"), j), [Json::boolean(true)])
  assert_eq(must_eval(parse_filter(".a >= .b"), j), [Json::boolean(false)])
  assert_eq(must_eval(parse_filter(".a and .b"), j), [Json::boolean(true)])
  assert_eq(must_eval(parse_filter("not .b"), j), [Json::boolean(false)])
  assert_eq(must_eval(parse_filter(".a or .b"), j), [Json::boolean(true)])
}

///|
test "eval arithmetic" {
  let j = must_parse("{\"a\":1,\"b\":2,\"c\":3}")
  assert_eq(must_eval(parse_filter(".a + .b"), j), [Json::number(3.0)])
  assert_eq(must_eval(parse_filter(".c - .a"), j), [Json::number(2.0)])
  assert_eq(must_eval(parse_filter(".a * .b"), j), [Json::number(2.0)])
  assert_eq(must_eval(parse_filter(".c / .a"), j), [Json::number(3.0)])
}

///|
test "eval add arrays and objects" {
  let j = must_parse("{\"a\":[1],\"b\":[2],\"x\":{\"k\":1},\"y\":{\"k\":2}}")
  assert_eq(must_eval(parse_filter(".a + .b"), j), [
    Json::array([Json::number(1.0), Json::number(2.0)]),
  ])
  assert_eq(must_eval(parse_filter(".x + .y"), j), [
    Json::object({ "k": Json::number(2.0) }),
  ])
}

///|
test "eval map" {
  let j = must_parse("[1,2,3]")
  assert_eq(must_eval(parse_filter("map(. + 1)"), j), [
    Json::array([Json::number(2.0), Json::number(3.0), Json::number(4.0)]),
  ])
}

///|
test "eval if-then-else" {
  let j = must_parse("{\"a\":true,\"b\":1,\"c\":2}")
  assert_eq(must_eval(parse_filter("if .a then .b else .c end"), j), [
    Json::number(1.0),
  ])
  let j2 = must_parse("{\"a\":null,\"b\":1,\"c\":2}")
  assert_eq(must_eval(parse_filter("if .a then .b else .c end"), j2), [
    Json::number(2.0),
  ])
}

///|
test "eval fallback and empty" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  assert_eq(must_eval(parse_filter(".a // .b"), j), [Json::number(1.0)])
  assert_eq(must_eval(parse_filter("empty // .b"), j), [Json::number(2.0)])
  assert_eq(must_eval(parse_filter("empty"), j), [])
}

///|
test "eval string contains/starts/ends" {
  let j = must_parse("\"hello\"")
  assert_eq(must_eval(parse_filter("contains(\"ell\")"), j), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("startswith(\"he\")"), j), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("endswith(\"lo\")"), j), [
    Json::boolean(true),
  ])
}

///|
test "eval array contains" {
  let j = must_parse("[1,2,3]")
  assert_eq(must_eval(parse_filter("contains(2)"), j), [Json::boolean(true)])
  assert_eq(must_eval(parse_filter("contains(9)"), j), [Json::boolean(false)])
}

///|
test "eval iter non-array errors" {
  let j = must_parse("1")
  let f = parse_filter(".[]")
  guard (try? eval(f, j)) is Err(_) else {
    fail("expected error for iter over non-array/object")
  }
}
