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
test "eval field/index type errors and optional suppression" {
  let number_json = must_parse("1")
  let array_json = must_parse("[1,2]")
  let object_json = must_parse("{\"a\":1}")
  let null_json = must_parse("null")
  guard (try? eval(parse_filter(".foo"), number_json)) is Err(err) &&
    err.to_string() == "Cannot index number with string \"foo\"" else {
    fail("expected type error for number .foo")
  }
  guard (try? eval(parse_filter(".foo"), array_json)) is Err(err) &&
    err.to_string() == "Cannot index array with string \"foo\"" else {
    fail("expected type error for array .foo")
  }
  guard (try? eval(parse_filter(".[0]"), number_json)) is Err(err) &&
    err.to_string() == "Cannot index number with number" else {
    fail("expected type error for number .[0]")
  }
  guard (try? eval(parse_filter(".[0]"), object_json)) is Err(err) &&
    err.to_string() == "Cannot index object with number" else {
    fail("expected type error for object .[0]")
  }
  assert_eq(must_eval(parse_filter(".foo?"), number_json), [])
  assert_eq(must_eval(parse_filter(".foo?"), array_json), [])
  assert_eq(must_eval(parse_filter(".[0]?"), number_json), [])
  assert_eq(must_eval(parse_filter(".[0]?"), object_json), [])
  assert_eq(must_eval(parse_filter(".foo"), null_json), [Json::null()])
  assert_eq(must_eval(parse_filter(".foo?"), null_json), [Json::null()])
  assert_eq(must_eval(parse_filter(".[0]"), null_json), [Json::null()])
  assert_eq(must_eval(parse_filter(".[0]?"), null_json), [Json::null()])
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
test "eval optional access" {
  let j = must_parse("[1,2,3]")
  assert_eq(must_eval(parse_filter(".[]?"), j), [
    Json::number(1.0),
    Json::number(2.0),
    Json::number(3.0),
  ])
  let j2 = must_parse("1")
  assert_eq(must_eval(parse_filter(".[]?"), j2), [])
  assert_eq(must_eval(parse_filter(".foo?"), j2), [])
  assert_eq(must_eval(parse_filter(".[0]?"), j2), [])
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
test "eval compare stream cross product" {
  let j = must_parse("null")
  assert_eq(must_eval(parse_filter("(1,2) == (1,2)"), j), [
    Json::boolean(true),
    Json::boolean(false),
    Json::boolean(false),
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("(empty) == 1"), j), [])
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
test "eval arithmetic stream cross product" {
  let j = must_parse("null")
  assert_eq(must_eval(parse_filter("(1,2) + (10,20)"), j), [
    Json::number(11.0),
    Json::number(12.0),
    Json::number(21.0),
    Json::number(22.0),
  ])
  assert_eq(must_eval(parse_filter("(empty) + 1"), j), [])
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
test "eval object literal stream product" {
  let j = must_parse("null")
  assert_eq(must_eval(parse_filter("{a:(1,2)}"), j), [
    Json::object({ "a": Json::number(1.0) }),
    Json::object({ "a": Json::number(2.0) }),
  ])
  assert_eq(must_eval(parse_filter("{a:(1,2), b:(3,4)}"), j), [
    Json::object({ "a": Json::number(1.0), "b": Json::number(3.0) }),
    Json::object({ "a": Json::number(1.0), "b": Json::number(4.0) }),
    Json::object({ "a": Json::number(2.0), "b": Json::number(3.0) }),
    Json::object({ "a": Json::number(2.0), "b": Json::number(4.0) }),
  ])
  assert_eq(must_eval(parse_filter("{a:(empty)}"), j), [])
}

///|
test "eval map" {
  let j = must_parse("[1,2,3]")
  assert_eq(must_eval(parse_filter("map(. + 1)"), j), [
    Json::array([Json::number(2.0), Json::number(3.0), Json::number(4.0)]),
  ])
}

///|
test "eval as and variable" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  assert_eq(must_eval(parse_filter(".a as $x | $x"), j), [Json::number(1.0)])
  assert_eq(must_eval(parse_filter(".a as $x | .b"), j), [Json::number(2.0)])
  assert_eq(must_eval(parse_filter(".a as $x | $x + 1"), j), [Json::number(2.0)])
}

///|
test "eval try" {
  let j = must_parse("{\"a\":\"hi\"}")
  assert_eq(must_eval(parse_filter("(.a + 1)?"), j), [])
  assert_eq(must_eval(parse_filter("(.a | .b)?"), j), [])
}

///|
test "eval try/catch" {
  let j = must_parse("{\"a\":\"hi\",\"b\":1}")
  assert_eq(must_eval(parse_filter("try .a catch .b"), j), [Json::string("hi")])
  assert_eq(must_eval(parse_filter("try (.a + 1) catch .b"), j), [
    Json::number(1.0),
  ])
}

///|
test "eval reduce/foreach" {
  let j = must_parse("[1,2,3]")
  assert_eq(must_eval(parse_filter("reduce .[] as $x (0; . + $x)"), j), [
    Json::number(6.0),
  ])
  assert_eq(must_eval(parse_filter("foreach .[] as $x (0; . + $x; .)"), j), [
    Json::number(1.0),
    Json::number(3.0),
    Json::number(6.0),
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
test "eval fallback jq semantics with null/false and streams" {
  let j = must_parse("null")
  assert_eq(must_eval(parse_filter("null // 1"), j), [Json::number(1.0)])
  assert_eq(must_eval(parse_filter("false // 1"), j), [Json::number(1.0)])
  assert_eq(must_eval(parse_filter("true // 1"), j), [Json::boolean(true)])
  assert_eq(must_eval(parse_filter("[false,1] | .[] // 9"), j), [
    Json::number(1.0),
  ])
  assert_eq(must_eval(parse_filter("[null,false] | .[] // 9"), j), [
    Json::number(9.0),
  ])
  assert_eq(must_eval(parse_filter("(1,2) // 9"), j), [
    Json::number(1.0),
    Json::number(2.0),
  ])
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

///|
test "eval index negative" {
  let j = must_parse("[1,2]")
  assert_eq(must_eval(parse_filter(".[-1]"), j), [Json::number(2.0)])
  assert_eq(must_eval(parse_filter(".[-1]?"), j), [Json::number(2.0)])
  assert_eq(must_eval(parse_filter(".[-3]"), j), [Json::null()])
}

///|
test "eval slice compatibility" {
  let arr = must_parse("[1,2,3]")
  assert_eq(must_eval(parse_filter(".[1:2]"), arr), [
    Json::array([Json::number(2.0)]),
  ])
  assert_eq(must_eval(parse_filter(".[1:9]"), arr), [
    Json::array([Json::number(2.0), Json::number(3.0)]),
  ])
  assert_eq(must_eval(parse_filter(".[-2:]"), arr), [
    Json::array([Json::number(2.0), Json::number(3.0)]),
  ])
  assert_eq(must_eval(parse_filter(".[:2]"), arr), [
    Json::array([Json::number(1.0), Json::number(2.0)]),
  ])
  let s = must_parse("\"abcd\"")
  assert_eq(must_eval(parse_filter(".[1:3]"), s), [Json::string("bc")])
  assert_eq(must_eval(parse_filter(".[-2:]"), s), [Json::string("cd")])
  assert_eq(must_eval(parse_filter(".[:2]"), s), [Json::string("ab")])
  assert_eq(must_eval(parse_filter(".[2:2]"), s), [Json::string("")])
  let n = must_parse("null")
  assert_eq(must_eval(parse_filter(".[1:2]"), n), [Json::null()])
  assert_eq(must_eval(parse_filter(".[1:2]?"), n), [Json::null()])
  let num = must_parse("1")
  guard (try? eval(parse_filter(".[1:2]"), num)) is Err(err) &&
    err.to_string() == "Cannot index number with object" else {
    fail("expected type error for number slice")
  }
  assert_eq(must_eval(parse_filter(".[1:2]?"), num), [])
}

///|
test "eval length compatibility" {
  assert_eq(must_eval(parse_filter("length"), must_parse("null")), [
    Json::number(0.0),
  ])
  assert_eq(must_eval(parse_filter("length"), must_parse("-3")), [
    Json::number(3.0),
  ])
  assert_eq(must_eval(parse_filter("length"), must_parse("3.14")), [
    Json::number(3.14),
  ])
}

///|
test "eval keys array compatibility" {
  let j = must_parse("[10,20]")
  assert_eq(must_eval(parse_filter("keys"), j), [
    Json::array([Json::number(0.0), Json::number(1.0)]),
  ])
}
