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
  guard (try? execute(parse_filter("contains(2)"), array_input)) is Err(err) &&
    err.to_string() ==
    "array ([1,2,3]) and number (2) cannot have their containment checked" else {
    fail("expected jq-compatible contains type error for array/number")
  }
  guard (try? execute(parse_filter("contains(false)"), must_parse("true")))
    is Err(err) &&
    err.to_string() ==
    "boolean (true) and boolean (false) cannot have their containment checked" else {
    fail("expected jq-compatible contains type error for boolean mismatch")
  }
  let s = must_parse("\"hello\"")
  guard (try? execute(parse_filter("startswith(1)"), s)) is Err(err) &&
    err.to_string() == "startswith() requires string inputs" else {
    fail("expected startswith type error")
  }
  guard (try? execute(parse_filter("endswith(1)"), s)) is Err(err) &&
    err.to_string() == "endswith() requires string inputs" else {
    fail("expected endswith type error")
  }
  let n = must_parse("1")
  guard (try? execute(parse_filter("startswith(\"1\")"), n)) is Err(err) &&
    err.to_string() == "startswith() requires string inputs" else {
    fail("expected startswith type error for non-string input")
  }
}

///|
test "eval inside jq semantics" {
  assert_eq(must_eval(parse_filter("inside(1)"), must_parse("1")), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("inside(2)"), must_parse("1")), [
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("inside([0,1,2,3])"), must_parse("[1,2]")), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("inside([0,1,2,3])"), must_parse("[1,4]")), [
    Json::boolean(false),
  ])
  assert_eq(
    must_eval(
      parse_filter("inside({\"a\":1,\"b\":2})"),
      must_parse("{\"a\":1}"),
    ),
    [Json::boolean(true)],
  )
  assert_eq(
    must_eval(
      parse_filter("inside({\"a\":1,\"b\":2})"),
      must_parse("{\"a\":2}"),
    ),
    [Json::boolean(false)],
  )
  assert_eq(
    must_eval(parse_filter("inside(\"hello\")"), must_parse("\"ell\"")),
    [Json::boolean(true)],
  )
  assert_eq(must_eval(parse_filter("inside((1,2))"), must_parse("1")), [
    Json::boolean(true),
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("inside(empty)"), must_parse("1")), [])
}

///|
test "eval inside type errors" {
  guard (try? execute(parse_filter("inside(false)"), must_parse("true")))
    is Err(err) &&
    err.to_string() ==
    "boolean (false) and boolean (true) cannot have their containment checked" else {
    fail("expected inside boolean mismatch error")
  }
  guard (try? execute(parse_filter("inside(1)"), must_parse("[1]"))) is Err(err) &&
    err.to_string() ==
    "number (1) and array ([1]) cannot have their containment checked" else {
    fail("expected inside number/array mismatch error")
  }
  guard (try? execute(parse_filter("inside([1])"), must_parse("1"))) is Err(err) &&
    err.to_string() ==
    "array ([1]) and number (1) cannot have their containment checked" else {
    fail("expected inside array/number mismatch error")
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
  guard (try? execute(parse_filter("has(0)"), obj)) is Err(err) &&
    err.to_string() == "Cannot check whether object has a number key" else {
    fail("expected object has(number) type error")
  }
  let arr = must_parse("[1,2]")
  guard (try? execute(parse_filter("has(\"0\")"), arr)) is Err(err) &&
    err.to_string() == "Cannot check whether array has a string key" else {
    fail("expected array has(string) type error")
  }
  let s = must_parse("\"abc\"")
  guard (try? execute(parse_filter("has(0)"), s)) is Err(err) &&
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
  guard (try? execute(parse_filter("\"a\" | in(1)"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "Cannot check whether number has a string key" else {
    fail("expected in(number, string) type error")
  }
  guard (try? execute(parse_filter("1 | in({\"a\":1})"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "Cannot check whether object has a number key" else {
    fail("expected in(object, number) type error")
  }
  guard (try? execute(parse_filter("\"a\" | in([1,2])"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "Cannot check whether array has a string key" else {
    fail("expected in(array, string) type error")
  }
}

///|
test "eval iter non-array errors" {
  let j = must_parse("1")
  let f = parse_filter(".[]")
  guard (try? execute(f, j)) is Err(_) else {
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
  guard (try? execute(parse_filter(".[1:2]"), num)) is Err(err) &&
    err.to_string() == "Cannot index number with object" else {
    fail("expected type error for number slice")
  }
  assert_eq(must_eval(parse_filter(".[1:2]?"), num), [])
}

///|
test "eval dynamic slice compatibility" {
  assert_eq(
    must_eval(parse_filter(".[:rindex(\"x\")]"), must_parse("\"正xyz\"")),
    [Json::string("正")],
  )
  assert_eq(
    must_eval(
      parse_filter("map([1,2][0:.])"),
      must_parse("[-1, 1, 2, 3, 1000000000000000000]"),
    ),
    [
      Json::array([
        Json::array([Json::number(1.0)]),
        Json::array([Json::number(1.0)]),
        Json::array([Json::number(1.0), Json::number(2.0)]),
        Json::array([Json::number(1.0), Json::number(2.0)]),
        Json::array([Json::number(1.0), Json::number(2.0)]),
      ]),
    ],
  )
  assert_eq(
    must_eval(parse_filter("[range(3)] | .[nan:1]"), must_parse("null")),
    [Json::array([Json::number(0.0)])],
  )
  assert_eq(
    must_eval(parse_filter("[range(3)] | .[1:nan]"), must_parse("null")),
    [Json::array([Json::number(1.0), Json::number(2.0)])],
  )
  guard (try? execute(
      parse_filter("[range(3)] | .[\"x\":1]"),
      must_parse("null"),
    ))
    is Err(err) &&
    err.to_string() == "Array/string slice indices must be integers" else {
    fail("expected dynamic slice endpoint type error")
  }
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
