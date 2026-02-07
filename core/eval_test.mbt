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
test "eval string index compatibility" {
  let s = must_parse("\"abc\"")
  assert_eq(must_eval(parse_filter(".[0]"), s), [Json::string("a")])
  assert_eq(must_eval(parse_filter(".[-1]"), s), [Json::string("c")])
  assert_eq(must_eval(parse_filter(".[3]"), s), [Json::null()])
  assert_eq(must_eval(parse_filter(".[0]?"), s), [Json::string("a")])
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
test "eval jq type-filter builtins" {
  assert_eq(must_eval(parse_filter("values"), must_parse("null")), [])
  assert_eq(must_eval(parse_filter("values"), must_parse("1")), [
    Json::number(1.0),
  ])
  assert_eq(must_eval(parse_filter("nulls"), must_parse("null")), [Json::null()])
  assert_eq(must_eval(parse_filter("nulls"), must_parse("1")), [])
  assert_eq(must_eval(parse_filter("booleans"), must_parse("true")), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("booleans"), must_parse("1")), [])
  assert_eq(must_eval(parse_filter("numbers"), must_parse("1")), [
    Json::number(1.0),
  ])
  assert_eq(must_eval(parse_filter("numbers"), must_parse("\"1\"")), [])
  assert_eq(must_eval(parse_filter("strings"), must_parse("\"x\"")), [
    Json::string("x"),
  ])
  assert_eq(must_eval(parse_filter("arrays"), must_parse("[]")), [
    Json::array([]),
  ])
  assert_eq(must_eval(parse_filter("objects"), must_parse("{}")), [
    Json::object(Map::new()),
  ])
  assert_eq(must_eval(parse_filter("iterables"), must_parse("{}")), [
    Json::object(Map::new()),
  ])
  assert_eq(must_eval(parse_filter("iterables"), must_parse("1")), [])
  assert_eq(must_eval(parse_filter("scalars"), must_parse("1")), [
    Json::number(1.0),
  ])
  assert_eq(must_eval(parse_filter("scalars"), must_parse("{}")), [])
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
test "eval select stream compatibility" {
  let j = must_parse("1")
  assert_eq(must_eval(parse_filter("select((false,true,true))"), j), [j, j])
  assert_eq(must_eval(parse_filter("select((false,false))"), j), [])
  assert_eq(must_eval(parse_filter("select(empty)"), j), [])
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
test "eval multiply compatibility" {
  let j = must_parse("null")
  assert_eq(must_eval(parse_filter("\"ab\" * 2"), j), [Json::string("abab")])
  assert_eq(must_eval(parse_filter("2 * \"ab\""), j), [Json::string("abab")])
  assert_eq(must_eval(parse_filter("\"ab\" * 2.9"), j), [Json::string("abab")])
  assert_eq(must_eval(parse_filter("\"ab\" * 0"), j), [Json::string("")])
  assert_eq(must_eval(parse_filter("\"ab\" * -1"), j), [Json::null()])
  assert_eq(
    must_eval(parse_filter("{\"a\":{\"x\":1}} * {\"a\":{\"y\":2}}"), j),
    [
      Json::object({
        "a": Json::object({ "x": Json::number(1.0), "y": Json::number(2.0) }),
      }),
    ],
  )
  assert_eq(must_eval(parse_filter("{\"a\":{\"x\":1}} * {\"a\":2}"), j), [
    Json::object({ "a": Json::number(2.0) }),
  ])
  assert_eq(must_eval(parse_filter("{\"a\":1} * {\"b\":2}"), j), [
    Json::object({ "a": Json::number(1.0), "b": Json::number(2.0) }),
  ])
}

///|
test "eval multiply repeat too long error" {
  let j = must_parse("null")
  guard (try? eval(parse_filter("\"x\" * 1000000000000"), j)) is Err(err) &&
    err.to_string() == "Repeat string result too long" else {
    fail("expected repeat-too-long error")
  }
}

///|
test "eval array subtraction compatibility" {
  let j = must_parse("null")
  assert_eq(must_eval(parse_filter("[1,2,2,3] - [2]"), j), [
    Json::array([Json::number(1.0), Json::number(3.0)]),
  ])
  assert_eq(must_eval(parse_filter("[1,{\"a\":1}] - [{\"a\":1}]"), j), [
    Json::array([Json::number(1.0)]),
  ])
}

///|
test "eval division by zero compatibility" {
  let j = must_parse("null")
  guard (try? eval(parse_filter("1 / 0"), j)) is Err(err) &&
    err.to_string() ==
    "number (1) and number (0) cannot be divided because the divisor is zero" else {
    fail("expected jq-compatible division by zero error")
  }
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
test "eval add null identity compatibility" {
  let j = must_parse("null")
  assert_eq(must_eval(parse_filter("null + 1"), j), [Json::number(1.0)])
  assert_eq(must_eval(parse_filter("1 + null"), j), [Json::number(1.0)])
  assert_eq(must_eval(parse_filter("null + null"), j), [Json::null()])
  assert_eq(must_eval(parse_filter("true + null"), j), [Json::boolean(true)])
  assert_eq(must_eval(parse_filter("null + [1]"), j), [
    Json::array([Json::number(1.0)]),
  ])
  assert_eq(must_eval(parse_filter("{\"a\":1} + null"), j), [
    Json::object({ "a": Json::number(1.0) }),
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
test "eval map object compatibility" {
  let j = must_parse("{\"a\":1}")
  assert_eq(must_eval(parse_filter("map(. + 1)"), j), [
    Json::array([Json::number(2.0)]),
  ])
  assert_eq(must_eval(parse_filter("map((., . + 1))"), j), [
    Json::array([Json::number(1.0), Json::number(2.0)]),
  ])
  assert_eq(must_eval(parse_filter("map(select(. > 1))"), j), [Json::array([])])
}

///|
test "eval map iter errors" {
  guard (try? eval(parse_filter("map(. + 1)"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected map number error")
  }
  guard (try? eval(parse_filter("map(. + 1)"), must_parse("null"))) is Err(err) &&
    err.to_string() == "Cannot iterate over null (null)" else {
    fail("expected map null error")
  }
}

///|
test "eval map_values jq semantics" {
  let obj = must_parse("{\"a\":1,\"b\":2}")
  assert_eq(must_eval(parse_filter("map_values(select(. > 1))"), obj), [
    Json::object({ "b": Json::number(2.0) }),
  ])
  assert_eq(must_eval(parse_filter("map_values((., . + 1))"), obj), [
    Json::object({ "a": Json::number(1.0), "b": Json::number(2.0) }),
  ])
  let arr = must_parse("[1,2,3]")
  assert_eq(must_eval(parse_filter("map_values(. + 1)"), arr), [
    Json::array([Json::number(2.0), Json::number(3.0), Json::number(4.0)]),
  ])
  assert_eq(must_eval(parse_filter("map_values(select(. > 1))"), arr), [
    Json::array([Json::number(2.0), Json::number(3.0)]),
  ])
  assert_eq(must_eval(parse_filter("map_values((., . + 1))"), arr), [
    Json::array([Json::number(1.0), Json::number(2.0), Json::number(3.0)]),
  ])
}

///|
test "eval map_values iter errors" {
  guard (try? eval(parse_filter("map_values(. + 1)"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected map_values number error")
  }
  guard (try? eval(parse_filter("map_values(. + 1)"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "Cannot iterate over null (null)" else {
    fail("expected map_values null error")
  }
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
  assert_eq(must_eval(parse_filter("contains((\"he\",\"zz\"))"), j), [
    Json::boolean(true),
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("contains(empty)"), j), [])
  assert_eq(must_eval(parse_filter("startswith(\"he\")"), j), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("startswith((\"h\",\"x\"))"), j), [
    Json::boolean(true),
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("startswith(empty)"), j), [])
  assert_eq(must_eval(parse_filter("endswith(\"lo\")"), j), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("endswith((\"o\",\"x\"))"), j), [
    Json::boolean(true),
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("endswith(empty)"), j), [])
}

///|
test "eval contains jq semantics" {
  let array_input = must_parse("[1,{\"x\":2},3]")
  assert_eq(must_eval(parse_filter("contains([1,3])"), array_input), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("contains([{\"x\":2}])"), array_input), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("contains([{\"x\":9}])"), array_input), [
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("contains(([],[3]))"), array_input), [
    Json::boolean(true),
    Json::boolean(true),
  ])
  let repeated_input = must_parse("[1]")
  assert_eq(must_eval(parse_filter("contains([1,1])"), repeated_input), [
    Json::boolean(true),
  ])
  let object_input = must_parse("{\"a\":1,\"b\":{\"c\":2,\"d\":3}}")
  assert_eq(
    must_eval(parse_filter("contains({\"b\":{\"c\":2}})"), object_input),
    [Json::boolean(true)],
  )
  assert_eq(
    must_eval(parse_filter("contains({\"b\":{\"c\":9}})"), object_input),
    [Json::boolean(false)],
  )
  assert_eq(must_eval(parse_filter("contains({\"z\":1})"), object_input), [
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("contains(1)"), must_parse("1")), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("contains(2)"), must_parse("1")), [
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("contains(true)"), must_parse("true")), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("contains(null)"), must_parse("null")), [
    Json::boolean(true),
  ])
}

///|
test "eval contains/startswith/endswith type errors" {
  let array_input = must_parse("[1,2,3]")
  guard (try? eval(parse_filter("contains(2)"), array_input)) is Err(err) &&
    err.to_string() ==
    "array ([1,2,3]) and number (2) cannot have their containment checked" else {
    fail("expected jq-compatible contains type error for array/number")
  }
  guard (try? eval(parse_filter("contains(false)"), must_parse("true")))
    is Err(err) &&
    err.to_string() ==
    "boolean (true) and boolean (false) cannot have their containment checked" else {
    fail("expected jq-compatible contains type error for boolean mismatch")
  }
  let s = must_parse("\"hello\"")
  guard (try? eval(parse_filter("startswith(1)"), s)) is Err(err) &&
    err.to_string() == "startswith() requires string inputs" else {
    fail("expected startswith type error")
  }
  guard (try? eval(parse_filter("endswith(1)"), s)) is Err(err) &&
    err.to_string() == "endswith() requires string inputs" else {
    fail("expected endswith type error")
  }
  let n = must_parse("1")
  guard (try? eval(parse_filter("startswith(\"1\")"), n)) is Err(err) &&
    err.to_string() == "startswith() requires string inputs" else {
    fail("expected startswith type error for non-string input")
  }
}

///|
test "eval has jq semantics" {
  let obj = must_parse("{\"a\":1}")
  assert_eq(must_eval(parse_filter("has(\"a\")"), obj), [Json::boolean(true)])
  assert_eq(must_eval(parse_filter("has(\"z\")"), obj), [Json::boolean(false)])
  assert_eq(must_eval(parse_filter("has((\"a\",\"z\"))"), obj), [
    Json::boolean(true),
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("has(empty)"), obj), [])
  let arr = must_parse("[1,2]")
  assert_eq(must_eval(parse_filter("has(0)"), arr), [Json::boolean(true)])
  assert_eq(must_eval(parse_filter("has(2)"), arr), [Json::boolean(false)])
  assert_eq(must_eval(parse_filter("has((-1,1.9,-0.9))"), arr), [
    Json::boolean(false),
    Json::boolean(true),
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("has(empty)"), arr), [])
  let n = must_parse("null")
  assert_eq(must_eval(parse_filter("has((0,\"a\",true))"), n), [
    Json::boolean(false),
    Json::boolean(false),
    Json::boolean(false),
  ])
}

///|
test "eval has type errors" {
  let obj = must_parse("{\"a\":1}")
  guard (try? eval(parse_filter("has(0)"), obj)) is Err(err) &&
    err.to_string() == "Cannot check whether object has a number key" else {
    fail("expected object has(number) type error")
  }
  let arr = must_parse("[1,2]")
  guard (try? eval(parse_filter("has(\"0\")"), arr)) is Err(err) &&
    err.to_string() == "Cannot check whether array has a string key" else {
    fail("expected array has(string) type error")
  }
  let s = must_parse("\"abc\"")
  guard (try? eval(parse_filter("has(0)"), s)) is Err(err) &&
    err.to_string() == "Cannot check whether string has a number key" else {
    fail("expected string has(number) type error")
  }
}

///|
test "eval in jq semantics" {
  assert_eq(
    must_eval(parse_filter("\"a\" | in({\"a\":1})"), must_parse("null")),
    [Json::boolean(true)],
  )
  assert_eq(must_eval(parse_filter("2 | in([10,20])"), must_parse("null")), [
    Json::boolean(false),
  ])
  assert_eq(
    must_eval(
      parse_filter("\"a\" | in(({\"a\":1},{\"b\":2}))"),
      must_parse("null"),
    ),
    [Json::boolean(true), Json::boolean(false)],
  )
  assert_eq(must_eval(parse_filter("0 | in(null)"), must_parse("null")), [
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("0 | in(empty)"), must_parse("null")), [])
}

///|
test "eval in type errors" {
  guard (try? eval(parse_filter("\"a\" | in(1)"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "Cannot check whether number has a string key" else {
    fail("expected in(number, string) type error")
  }
  guard (try? eval(parse_filter("1 | in({\"a\":1})"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "Cannot check whether object has a number key" else {
    fail("expected in(object, number) type error")
  }
  guard (try? eval(parse_filter("\"a\" | in([1,2])"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "Cannot check whether array has a string key" else {
    fail("expected in(array, string) type error")
  }
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
