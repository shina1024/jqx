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
test "eval string index jq compatibility" {
  let s = must_parse("\"abc\"")
  guard (try? eval(parse_filter(".[0]"), s)) is Err(err) &&
    err.to_string() == "Cannot index string with number" else {
    fail("expected string index type error")
  }
  guard (try? eval(parse_filter(".[-1]"), s)) is Err(err) &&
    err.to_string() == "Cannot index string with number" else {
    fail("expected string negative index type error")
  }
  assert_eq(must_eval(parse_filter(".[0]?"), s), [])
  assert_eq(must_eval(parse_filter(".[-1]?"), s), [])
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
test "eval first/last/nth compatibility" {
  let arr = must_parse("[1,2,3]")
  assert_eq(must_eval(parse_filter("first"), arr), [Json::number(1.0)])
  assert_eq(must_eval(parse_filter("last"), arr), [Json::number(3.0)])
  assert_eq(must_eval(parse_filter("nth(0)"), arr), [Json::number(1.0)])
  assert_eq(must_eval(parse_filter("nth(-1)"), arr), [Json::number(3.0)])
  assert_eq(must_eval(parse_filter("nth(9)"), arr), [Json::null()])
  assert_eq(must_eval(parse_filter("nth(1.9)"), arr), [Json::number(2.0)])
  assert_eq(must_eval(parse_filter("nth((0,-1,9))"), arr), [
    Json::number(1.0),
    Json::number(3.0),
    Json::null(),
  ])
  let empty_arr = must_parse("[]")
  assert_eq(must_eval(parse_filter("first"), empty_arr), [Json::null()])
  assert_eq(must_eval(parse_filter("last"), empty_arr), [Json::null()])
  assert_eq(must_eval(parse_filter("nth(0)"), empty_arr), [Json::null()])
  let null_json = must_parse("null")
  assert_eq(must_eval(parse_filter("first"), null_json), [Json::null()])
  assert_eq(must_eval(parse_filter("last"), null_json), [Json::null()])
  assert_eq(must_eval(parse_filter("nth(0)"), null_json), [Json::null()])
  assert_eq(must_eval(parse_filter("nth(\"a\")"), null_json), [Json::null()])
  let scalar = must_parse("1")
  assert_eq(must_eval(parse_filter("first(empty)"), scalar), [])
  assert_eq(must_eval(parse_filter("last(empty)"), scalar), [])
  assert_eq(must_eval(parse_filter("nth(empty)"), scalar), [])
  assert_eq(must_eval(parse_filter("first((1,2,3))"), scalar), [
    Json::number(1.0),
  ])
  assert_eq(must_eval(parse_filter("last((1,2,3))"), scalar), [
    Json::number(3.0),
  ])
}

///|
test "eval first/last/nth errors" {
  guard (try? eval(parse_filter("first"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot index number with number" else {
    fail("expected first number index error")
  }
  guard (try? eval(parse_filter("last"), must_parse("{}"))) is Err(err) &&
    err.to_string() == "Cannot index object with number" else {
    fail("expected last object index error")
  }
  guard (try? eval(parse_filter("nth(\"a\")"), must_parse("[1,2,3]")))
    is Err(err) &&
    err.to_string() == "Cannot index array with string \"a\"" else {
    fail("expected nth array string-key error")
  }
  guard (try? eval(parse_filter("nth(true)"), must_parse("null"))) is Err(err) &&
    err.to_string() == "Cannot index null with boolean" else {
    fail("expected nth null boolean-key error")
  }
}

///|
test "eval flatten compatibility" {
  let nested = must_parse("[1,[2],[[3,[4]]],5]")
  assert_eq(must_eval(parse_filter("flatten"), nested), [
    Json::array([
      Json::number(1.0),
      Json::number(2.0),
      Json::number(3.0),
      Json::number(4.0),
      Json::number(5.0),
    ]),
  ])
  assert_eq(must_eval(parse_filter("flatten(1)"), nested), [
    Json::array([
      Json::number(1.0),
      Json::number(2.0),
      Json::array([Json::number(3.0), Json::array([Json::number(4.0)])]),
      Json::number(5.0),
    ]),
  ])
  assert_eq(must_eval(parse_filter("flatten(2)"), nested), [
    Json::array([
      Json::number(1.0),
      Json::number(2.0),
      Json::number(3.0),
      Json::array([Json::number(4.0)]),
      Json::number(5.0),
    ]),
  ])
  assert_eq(must_eval(parse_filter("flatten(0)"), nested), [nested])
  assert_eq(must_eval(parse_filter("flatten(0.1)"), nested), [
    Json::array([
      Json::number(1.0),
      Json::number(2.0),
      Json::number(3.0),
      Json::number(4.0),
      Json::number(5.0),
    ]),
  ])
  assert_eq(must_eval(parse_filter("flatten((0,1))"), must_parse("[1,[2]]")), [
    Json::array([Json::number(1.0), Json::array([Json::number(2.0)])]),
    Json::array([Json::number(1.0), Json::number(2.0)]),
  ])
  assert_eq(must_eval(parse_filter("flatten(empty)"), nested), [])
}

///|
test "eval flatten errors" {
  guard (try? eval(parse_filter("flatten"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected flatten non-array iterate error")
  }
  guard (try? eval(parse_filter("flatten"), must_parse("null"))) is Err(err) &&
    err.to_string() == "Cannot iterate over null (null)" else {
    fail("expected flatten null iterate error")
  }
  guard (try? eval(parse_filter("flatten(-1)"), must_parse("[1,[2]]")))
    is Err(err) &&
    err.to_string() == "flatten depth must not be negative" else {
    fail("expected flatten negative depth error")
  }
  guard (try? eval(parse_filter("flatten(null)"), must_parse("[1,[2]]")))
    is Err(err) &&
    err.to_string() == "flatten depth must not be negative" else {
    fail("expected flatten null depth error")
  }
  guard (try? eval(parse_filter("flatten(true)"), must_parse("[1,[2]]")))
    is Err(err) &&
    err.to_string() == "flatten depth must not be negative" else {
    fail("expected flatten bool depth error")
  }
  guard (try? eval(parse_filter("flatten(\"x\")"), must_parse("[1,[2]]")))
    is Err(err) &&
    err.to_string() == "string (\"x\") and number (1) cannot be subtracted" else {
    fail("expected flatten string depth error")
  }
}

///|
test "eval transpose compatibility" {
  assert_eq(must_eval(parse_filter("transpose"), must_parse("[[1,2],[3,4]]")), [
    Json::array([
      Json::array([Json::number(1.0), Json::number(3.0)]),
      Json::array([Json::number(2.0), Json::number(4.0)]),
    ]),
  ])
  assert_eq(must_eval(parse_filter("transpose"), must_parse("[[1],[2,3]]")), [
    Json::array([
      Json::array([Json::number(1.0), Json::number(2.0)]),
      Json::array([Json::null(), Json::number(3.0)]),
    ]),
  ])
  assert_eq(must_eval(parse_filter("transpose"), must_parse("[]")), [
    Json::array([]),
  ])
  assert_eq(must_eval(parse_filter("transpose"), must_parse("[[],[]]")), [
    Json::array([]),
  ])
  assert_eq(must_eval(parse_filter("transpose"), must_parse("[[1],[]]")), [
    Json::array([Json::array([Json::number(1.0), Json::null()])]),
  ])
  assert_eq(must_eval(parse_filter("transpose"), must_parse("[{}]")), [
    Json::array([]),
  ])
  assert_eq(must_eval(parse_filter("transpose"), must_parse("[[1],null]")), [
    Json::array([Json::array([Json::number(1.0), Json::null()])]),
  ])
  assert_eq(
    must_eval(parse_filter("transpose"), must_parse("[[1,null],[2]]")),
    [
      Json::array([
        Json::array([Json::number(1.0), Json::number(2.0)]),
        Json::array([Json::null(), Json::null()]),
      ]),
    ],
  )
}

///|
test "eval transpose errors" {
  guard (try? eval(parse_filter("transpose"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected transpose non-array iterate error")
  }
  guard (try? eval(parse_filter("transpose"), must_parse("null"))) is Err(err) &&
    err.to_string() == "Cannot iterate over null (null)" else {
    fail("expected transpose null iterate error")
  }
  guard (try? eval(parse_filter("transpose"), must_parse("[1]"))) is Err(err) &&
    err.to_string() == "Cannot index number with number" else {
    fail("expected transpose number index error")
  }
  guard (try? eval(parse_filter("transpose"), must_parse("[[1],{}]")))
    is Err(err) &&
    err.to_string() == "Cannot index object with number" else {
    fail("expected transpose object index error")
  }
  guard (try? eval(parse_filter("transpose"), must_parse("[[1],\"x\"]")))
    is Err(err) &&
    err.to_string() == "Cannot index string with number" else {
    fail("expected transpose string index error")
  }
  guard (try? eval(parse_filter("transpose"), must_parse("[true]"))) is Err(err) &&
    err.to_string() == "boolean (true) has no length" else {
    fail("expected transpose boolean length error")
  }
}

///|
test "eval to_entries/from_entries/with_entries compatibility" {
  assert_eq(must_eval(parse_filter("to_entries"), must_parse("[10,20]")), [
    Json::array([
      Json::object({ "key": Json::number(0.0), "value": Json::number(10.0) }),
      Json::object({ "key": Json::number(1.0), "value": Json::number(20.0) }),
    ]),
  ])
  assert_eq(
    must_eval(
      parse_filter("from_entries"),
      must_parse(
        "[{\"key\":\"a\",\"value\":1},{\"Key\":\"b\",\"Value\":2},{\"name\":\"c\",\"value\":3},{\"Name\":\"d\",\"Value\":4}]",
      ),
    ),
    [
      Json::object({
        "a": Json::number(1.0),
        "b": Json::number(2.0),
        "c": Json::number(3.0),
        "d": Json::number(4.0),
      }),
    ],
  )
  assert_eq(
    must_eval(parse_filter("from_entries"), must_parse("[{\"key\":\"a\"}]")),
    [Json::object({ "a": Json::null() })],
  )
  assert_eq(
    must_eval(
      parse_filter("with_entries({key: (.key + \"_x\"), value: (.value + 10)})"),
      must_parse("{\"a\":1}"),
    ),
    [Json::object({ "a_x": Json::number(11.0) })],
  )
  assert_eq(
    must_eval(parse_filter("with_entries(empty)"), must_parse("{\"a\":1}")),
    [Json::object(Map::new())],
  )
}

///|
test "eval to_entries/from_entries/with_entries errors" {
  guard (try? eval(parse_filter("to_entries"), must_parse("1"))) is Err(err) &&
    err.to_string() == "number (1) has no keys" else {
    fail("expected to_entries no-keys error")
  }
  guard (try? eval(parse_filter("from_entries"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected from_entries iterate error")
  }
  guard (try? eval(parse_filter("from_entries"), must_parse("[1]"))) is Err(err) &&
    err.to_string() == "Cannot index number with string \"key\"" else {
    fail("expected from_entries entry index error")
  }
  guard (try? eval(parse_filter("from_entries"), must_parse("[{\"value\":1}]")))
    is Err(err) &&
    err.to_string() == "Cannot use null (null) as object key" else {
    fail("expected from_entries null key error")
  }
  guard (try? eval(
      parse_filter("from_entries"),
      must_parse("[{\"key\":1,\"value\":2}]"),
    ))
    is Err(err) &&
    err.to_string() == "Cannot use number (1) as object key" else {
    fail("expected from_entries number key error")
  }
  guard (try? eval(parse_filter("with_entries(.)"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "number (1) has no keys" else {
    fail("expected with_entries no-keys error")
  }
  guard (try? eval(parse_filter("with_entries(.)"), must_parse("[10,20]")))
    is Err(err) &&
    err.to_string() == "Cannot use number (0) as object key" else {
    fail("expected with_entries array key type error")
  }
}

///|
test "eval keys compatibility errors and keys_unsorted" {
  let arr = must_parse("[10,20]")
  assert_eq(must_eval(parse_filter("keys_unsorted"), arr), [
    Json::array([Json::number(0.0), Json::number(1.0)]),
  ])
  let obj = must_parse("{\"b\":2,\"a\":1}")
  let unsorted = must_eval(parse_filter("keys_unsorted"), obj)
  guard unsorted.length() == 1 else {
    fail("expected one output from keys_unsorted")
  }
  guard unsorted[0] is Array(keys_arr) else {
    fail("expected array result from keys_unsorted")
  }
  assert_eq(keys_arr.length(), 2)
  let mut saw_a = false
  let mut saw_b = false
  for k in keys_arr {
    if k == Json::string("a") {
      saw_a = true
    } else if k == Json::string("b") {
      saw_b = true
    } else {
      fail("unexpected key from keys_unsorted")
    }
  }
  guard saw_a && saw_b else { fail("keys_unsorted missing keys") }
  guard (try? eval(parse_filter("keys"), must_parse("1"))) is Err(err) &&
    err.to_string() == "number (1) has no keys" else {
    fail("expected jq-compatible keys error")
  }
  guard (try? eval(parse_filter("keys_unsorted"), must_parse("1"))) is Err(err) &&
    err.to_string() == "number (1) has no keys" else {
    fail("expected jq-compatible keys_unsorted error")
  }
}

///|
test "eval tostring/tonumber compatibility" {
  assert_eq(must_eval(parse_filter("tostring"), must_parse("1")), [
    Json::string("1"),
  ])
  assert_eq(must_eval(parse_filter("tostring"), must_parse("\"x\"")), [
    Json::string("x"),
  ])
  assert_eq(must_eval(parse_filter("tostring"), must_parse("null")), [
    Json::string("null"),
  ])
  assert_eq(must_eval(parse_filter("tostring"), must_parse("[1,2]")), [
    Json::string("[1,2]"),
  ])
  assert_eq(must_eval(parse_filter("tonumber"), must_parse("\"1\"")), [
    Json::number(1.0),
  ])
  assert_eq(must_eval(parse_filter("tonumber"), must_parse("\"01\"")), [
    Json::number(1.0),
  ])
  assert_eq(must_eval(parse_filter("tonumber"), must_parse("\"1.25\"")), [
    Json::number(1.25),
  ])
  assert_eq(must_eval(parse_filter("tonumber"), must_parse("1")), [
    Json::number(1.0),
  ])
  assert_eq(must_eval(parse_filter("tonumber"), must_parse("\"nan\"")), [
    Json::null(),
  ])
}

///|
test "eval tonumber errors" {
  guard (try? eval(parse_filter("tonumber"), must_parse("\"abc\""))) is Err(err) &&
    err.to_string() == "string (\"abc\") cannot be parsed as a number" else {
    fail("expected tonumber string parse error")
  }
  guard (try? eval(parse_filter("tonumber"), must_parse("null"))) is Err(err) &&
    err.to_string() == "null (null) cannot be parsed as a number" else {
    fail("expected tonumber null parse error")
  }
  guard (try? eval(parse_filter("tonumber"), must_parse("true"))) is Err(err) &&
    err.to_string() == "boolean (true) cannot be parsed as a number" else {
    fail("expected tonumber boolean parse error")
  }
}

///|
test "eval reverse compatibility" {
  assert_eq(must_eval(parse_filter("reverse"), must_parse("[1,2,3]")), [
    Json::array([Json::number(3.0), Json::number(2.0), Json::number(1.0)]),
  ])
  assert_eq(must_eval(parse_filter("reverse"), must_parse("[]")), [
    Json::array([]),
  ])
  assert_eq(must_eval(parse_filter("reverse"), must_parse("null")), [
    Json::array([]),
  ])
  assert_eq(must_eval(parse_filter("reverse"), must_parse("{}")), [
    Json::array([]),
  ])
  assert_eq(must_eval(parse_filter("reverse"), must_parse("\"\"")), [
    Json::array([]),
  ])
  assert_eq(must_eval(parse_filter("reverse"), must_parse("0")), [
    Json::array([]),
  ])
}

///|
test "eval reverse errors" {
  guard (try? eval(parse_filter("reverse"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot index number with number" else {
    fail("expected reverse number index error")
  }
  guard (try? eval(parse_filter("reverse"), must_parse("\"abc\""))) is Err(err) &&
    err.to_string() == "Cannot index string with number" else {
    fail("expected reverse string index error")
  }
  guard (try? eval(parse_filter("reverse"), must_parse("{\"a\":1}")))
    is Err(err) &&
    err.to_string() == "Cannot index object with number" else {
    fail("expected reverse object index error")
  }
  guard (try? eval(parse_filter("reverse"), must_parse("false"))) is Err(err) &&
    err.to_string() == "boolean (false) has no length" else {
    fail("expected reverse boolean length error")
  }
}

///|
test "eval join compatibility" {
  assert_eq(
    must_eval(parse_filter("join(\",\")"), must_parse("[\"a\",1,true,null]")),
    [Json::string("a,1,true,")],
  )
  assert_eq(must_eval(parse_filter("join(\",\")"), must_parse("[]")), [
    Json::string(""),
  ])
  assert_eq(must_eval(parse_filter("join(\",\")"), must_parse("[1,2]")), [
    Json::string("1,2"),
  ])
  assert_eq(must_eval(parse_filter("join(1)"), must_parse("[\"a\"]")), [
    Json::string("a"),
  ])
  assert_eq(
    must_eval(parse_filter("join((\",\", \":\"))"), must_parse("[\"a\",\"b\"]")),
    [Json::string("a,b"), Json::string("a:b")],
  )
  assert_eq(must_eval(parse_filter("join(empty)"), must_parse("[\"a\"]")), [])
}

///|
test "eval join errors" {
  guard (try? eval(parse_filter("join(\",\")"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected join iterate error")
  }
  guard (try? eval(parse_filter("join(1)"), must_parse("[\"a\",\"b\"]")))
    is Err(err) &&
    err.to_string() == "string (\"a\") and number (1) cannot be added" else {
    fail("expected join separator type error")
  }
  guard (try? eval(parse_filter("join(\",\")"), must_parse("[{\"x\":1}]")))
    is Err(err) &&
    err.to_string() == "string (\"\") and object ({\"x\":1}) cannot be added" else {
    fail("expected join object element type error")
  }
}

///|
test "eval split compatibility" {
  assert_eq(must_eval(parse_filter("split(\",\")"), must_parse("\"a,b,c\"")), [
    Json::array([Json::string("a"), Json::string("b"), Json::string("c")]),
  ])
  assert_eq(must_eval(parse_filter("split(\"\")"), must_parse("\"abc\"")), [
    Json::array([Json::string("a"), Json::string("b"), Json::string("c")]),
  ])
  assert_eq(must_eval(parse_filter("split(\"\")"), must_parse("\"\"")), [
    Json::array([]),
  ])
  assert_eq(must_eval(parse_filter("split(\",\")"), must_parse("\"\"")), [
    Json::array([]),
  ])
  assert_eq(
    must_eval(parse_filter("split((\",\", \"\"))"), must_parse("\"abc\"")),
    [
      Json::array([Json::string("abc")]),
      Json::array([Json::string("a"), Json::string("b"), Json::string("c")]),
    ],
  )
  assert_eq(must_eval(parse_filter("split(\"a\")"), must_parse("\"aa\"")), [
    Json::array([Json::string(""), Json::string(""), Json::string("")]),
  ])
  assert_eq(must_eval(parse_filter("split(empty)"), must_parse("\"a\"")), [])
}

///|
test "eval split errors" {
  guard (try? eval(parse_filter("split(\",\")"), must_parse("1"))) is Err(err) &&
    err.to_string() == "split input and separator must be strings" else {
    fail("expected split input type error")
  }
  guard (try? eval(parse_filter("split(1)"), must_parse("\"a\""))) is Err(err) &&
    err.to_string() == "split input and separator must be strings" else {
    fail("expected split separator type error")
  }
}

///|
test "eval explode/implode compatibility" {
  assert_eq(must_eval(parse_filter("explode"), must_parse("\"abc\"")), [
    Json::array([Json::number(97.0), Json::number(98.0), Json::number(99.0)]),
  ])
  assert_eq(must_eval(parse_filter("explode"), must_parse("\"あ\"")), [
    Json::array([Json::number(12354.0)]),
  ])
  assert_eq(must_eval(parse_filter("implode"), must_parse("[97,98,99]")), [
    Json::string("abc"),
  ])
  assert_eq(must_eval(parse_filter("implode"), must_parse("[12354]")), [
    Json::string("あ"),
  ])
  assert_eq(must_eval(parse_filter("implode"), must_parse("[]")), [
    Json::string(""),
  ])
  assert_eq(must_eval(parse_filter("implode"), must_parse("[-1]")), [
    Json::string("\u{fffd}"),
  ])
  assert_eq(must_eval(parse_filter("implode"), must_parse("[97.9]")), [
    Json::string("a"),
  ])
}

///|
test "eval explode/implode errors" {
  guard (try? eval(parse_filter("explode"), must_parse("1"))) is Err(err) &&
    err.to_string() == "explode input must be a string" else {
    fail("expected explode input type error")
  }
  guard (try? eval(parse_filter("implode"), must_parse("1"))) is Err(err) &&
    err.to_string() == "implode input must be an array" else {
    fail("expected implode input type error")
  }
  guard (try? eval(parse_filter("implode"), must_parse("[\"a\"]"))) is Err(err) &&
    err.to_string() ==
    "string (\"a\") can't be imploded, unicode codepoint needs to be numeric" else {
    fail("expected implode element type error")
  }
}

///|
test "eval index/rindex/indices compatibility" {
  assert_eq(must_eval(parse_filter("index(\"l\")"), must_parse("\"hello\"")), [
    Json::number(2.0),
  ])
  assert_eq(must_eval(parse_filter("rindex(\"l\")"), must_parse("\"hello\"")), [
    Json::number(3.0),
  ])
  assert_eq(
    must_eval(parse_filter("indices(\"l\")"), must_parse("\"hello\"")),
    [Json::array([Json::number(2.0), Json::number(3.0)])],
  )
  assert_eq(must_eval(parse_filter("index(\"z\")"), must_parse("\"hello\"")), [
    Json::null(),
  ])
  assert_eq(
    must_eval(parse_filter("indices(\"z\")"), must_parse("\"hello\"")),
    [Json::array([])],
  )
  assert_eq(must_eval(parse_filter("indices(\"aa\")"), must_parse("\"aaa\"")), [
    Json::array([Json::number(0.0), Json::number(1.0)]),
  ])
  assert_eq(
    must_eval(parse_filter("index((\"l\",\"e\"))"), must_parse("\"hello\"")),
    [Json::number(2.0), Json::number(1.0)],
  )
  assert_eq(must_eval(parse_filter("index(empty)"), must_parse("\"hello\"")), [])
  let arr = must_parse("[1,2,1,3]")
  assert_eq(must_eval(parse_filter("index(1)"), arr), [Json::number(0.0)])
  assert_eq(must_eval(parse_filter("rindex(1)"), arr), [Json::number(2.0)])
  assert_eq(must_eval(parse_filter("indices(1)"), arr), [
    Json::array([Json::number(0.0), Json::number(2.0)]),
  ])
  assert_eq(must_eval(parse_filter("index([1,3])"), arr), [Json::number(2.0)])
  assert_eq(must_eval(parse_filter("indices([1,3])"), arr), [
    Json::array([Json::number(2.0)]),
  ])
  assert_eq(must_eval(parse_filter("index(\"1\")"), must_parse("[1,2]")), [
    Json::null(),
  ])
  assert_eq(must_eval(parse_filter("indices([])"), must_parse("[1,2,3]")), [
    Json::array([]),
  ])
}

///|
test "eval index/rindex/indices errors" {
  guard (try? eval(parse_filter("index(1)"), must_parse("\"hello\"")))
    is Err(err) &&
    err.to_string() == "Cannot index string with number" else {
    fail("expected string index(number) type error")
  }
  guard (try? eval(parse_filter("index(true)"), must_parse("\"hello\"")))
    is Err(err) &&
    err.to_string() == "Cannot index string with boolean" else {
    fail("expected string index(boolean) type error")
  }
  guard (try? eval(parse_filter("index(\"a\")"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot index number with string \"a\"" else {
    fail("expected number index(string) type error")
  }
}

///|
test "eval any/all compatibility" {
  assert_eq(must_eval(parse_filter("any"), must_parse("[true,false]")), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("all"), must_parse("[true,false]")), [
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("any"), must_parse("[]")), [
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("all"), must_parse("[]")), [
    Json::boolean(true),
  ])
  assert_eq(
    must_eval(parse_filter("any"), must_parse("{\"a\":false,\"b\":true}")),
    [Json::boolean(true)],
  )
  assert_eq(
    must_eval(parse_filter("all"), must_parse("{\"a\":false,\"b\":true}")),
    [Json::boolean(false)],
  )
  assert_eq(must_eval(parse_filter("any"), must_parse("{}")), [
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("all"), must_parse("{}")), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("any(. > 2)"), must_parse("[1,2,3]")), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("all(. > 0)"), must_parse("[1,2,3]")), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("all(. > 2)"), must_parse("[1,2,3]")), [
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("any(empty)"), must_parse("[1,2,3]")), [
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("all(empty)"), must_parse("[1,2,3]")), [
    Json::boolean(true),
  ])
  assert_eq(
    must_eval(parse_filter("any((false,true))"), must_parse("[1,2,3]")),
    [Json::boolean(true)],
  )
  assert_eq(
    must_eval(parse_filter("all((true,false))"), must_parse("[1,2,3]")),
    [Json::boolean(false)],
  )
  assert_eq(
    must_eval(parse_filter("any(. > 0)"), must_parse("{\"a\":1,\"b\":0}")),
    [Json::boolean(true)],
  )
  assert_eq(
    must_eval(parse_filter("all(. > 0)"), must_parse("{\"a\":1,\"b\":0}")),
    [Json::boolean(false)],
  )
}

///|
test "eval any/all errors" {
  guard (try? eval(parse_filter("any"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected any number iterate error")
  }
  guard (try? eval(parse_filter("all"), must_parse("null"))) is Err(err) &&
    err.to_string() == "Cannot iterate over null (null)" else {
    fail("expected all null iterate error")
  }
  guard (try? eval(parse_filter("any"), must_parse("\"ab\""))) is Err(err) &&
    err.to_string() == "Cannot iterate over string (\"ab\")" else {
    fail("expected any string iterate error")
  }
  guard (try? eval(parse_filter("any(.)"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected any(cond) number iterate error")
  }
  guard (try? eval(parse_filter("all(.)"), must_parse("null"))) is Err(err) &&
    err.to_string() == "Cannot iterate over null (null)" else {
    fail("expected all(cond) null iterate error")
  }
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
test "eval add builtin compatibility" {
  assert_eq(must_eval(parse_filter("add"), must_parse("[1,2,3]")), [
    Json::number(6.0),
  ])
  assert_eq(must_eval(parse_filter("add"), must_parse("[]")), [Json::null()])
  assert_eq(must_eval(parse_filter("add"), must_parse("{}")), [Json::null()])
  assert_eq(must_eval(parse_filter("add"), must_parse("{\"a\":1,\"b\":2}")), [
    Json::number(3.0),
  ])
  assert_eq(must_eval(parse_filter("add"), must_parse("[\"a\",\"b\"]")), [
    Json::string("ab"),
  ])
  assert_eq(must_eval(parse_filter("add"), must_parse("[[1],[2]]")), [
    Json::array([Json::number(1.0), Json::number(2.0)]),
  ])
  assert_eq(
    must_eval(parse_filter("add"), must_parse("[{\"a\":1},{\"b\":2}]")),
    [Json::object({ "a": Json::number(1.0), "b": Json::number(2.0) })],
  )
  assert_eq(must_eval(parse_filter("add"), must_parse("[null,1]")), [
    Json::number(1.0),
  ])
  assert_eq(must_eval(parse_filter("add"), must_parse("[1,null]")), [
    Json::number(1.0),
  ])
  assert_eq(must_eval(parse_filter("add"), must_parse("[null,null]")), [
    Json::null(),
  ])
}

///|
test "eval add builtin errors" {
  guard (try? eval(parse_filter("add"), must_parse("null"))) is Err(err) &&
    err.to_string() == "Cannot iterate over null (null)" else {
    fail("expected add null iterate error")
  }
  guard (try? eval(parse_filter("add"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected add number iterate error")
  }
  guard (try? eval(parse_filter("add"), must_parse("[true,false]"))) is Err(err) &&
    err.to_string() == "boolean (true) and boolean (false) cannot be added" else {
    fail("expected add type mismatch error")
  }
}

///|
test "eval sort compatibility" {
  assert_eq(must_eval(parse_filter("sort"), must_parse("[3,1,2]")), [
    Json::array([Json::number(1.0), Json::number(2.0), Json::number(3.0)]),
  ])
  assert_eq(
    must_eval(
      parse_filter("sort"),
      must_parse("[{},[],\"a\",0,true,false,null]"),
    ),
    [
      Json::array([
        Json::null(),
        Json::boolean(false),
        Json::boolean(true),
        Json::number(0.0),
        Json::string("a"),
        Json::array([]),
        Json::object(Map::new()),
      ]),
    ],
  )
  assert_eq(
    must_eval(parse_filter("sort"), must_parse("[[1,2],[1,1],[1],[]]")),
    [
      Json::array([
        Json::array([]),
        Json::array([Json::number(1.0)]),
        Json::array([Json::number(1.0), Json::number(1.0)]),
        Json::array([Json::number(1.0), Json::number(2.0)]),
      ]),
    ],
  )
  assert_eq(
    must_eval(parse_filter("sort"), must_parse("[{\"a\":2},{\"a\":1}]")),
    [
      Json::array([
        Json::object({ "a": Json::number(1.0) }),
        Json::object({ "a": Json::number(2.0) }),
      ]),
    ],
  )
}

///|
test "eval sort errors" {
  guard (try? eval(parse_filter("sort"), must_parse("1"))) is Err(err) &&
    err.to_string() == "number (1) cannot be sorted, as it is not an array" else {
    fail("expected sort non-array type error")
  }
  guard (try? eval(parse_filter("sort"), must_parse("null"))) is Err(err) &&
    err.to_string() == "null (null) cannot be sorted, as it is not an array" else {
    fail("expected sort null type error")
  }
}

///|
test "eval sort_by compatibility" {
  assert_eq(
    must_eval(parse_filter("sort_by(.a)"), must_parse("[{\"a\":2},{\"a\":1}]")),
    [
      Json::array([
        Json::object({ "a": Json::number(1.0) }),
        Json::object({ "a": Json::number(2.0) }),
      ]),
    ],
  )
  assert_eq(must_eval(parse_filter("sort_by(.)"), must_parse("[3,1,2]")), [
    Json::array([Json::number(1.0), Json::number(2.0), Json::number(3.0)]),
  ])
  assert_eq(
    must_eval(
      parse_filter("sort_by(empty)"),
      must_parse("[{\"a\":2},{\"a\":1}]"),
    ),
    [
      Json::array([
        Json::object({ "a": Json::number(2.0) }),
        Json::object({ "a": Json::number(1.0) }),
      ]),
    ],
  )
}

///|
test "eval sort_by errors" {
  guard (try? eval(parse_filter("sort_by(.)"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected sort_by non-array error")
  }
}

///|
test "eval group_by compatibility" {
  assert_eq(
    must_eval(
      parse_filter("group_by(.a)"),
      must_parse("[{\"a\":2},{\"a\":1},{\"a\":2}]"),
    ),
    [
      Json::array([
        Json::array([Json::object({ "a": Json::number(1.0) })]),
        Json::array([
          Json::object({ "a": Json::number(2.0) }),
          Json::object({ "a": Json::number(2.0) }),
        ]),
      ]),
    ],
  )
  assert_eq(must_eval(parse_filter("group_by(.)"), must_parse("[3,1,2,1]")), [
    Json::array([
      Json::array([Json::number(1.0), Json::number(1.0)]),
      Json::array([Json::number(2.0)]),
      Json::array([Json::number(3.0)]),
    ]),
  ])
  assert_eq(must_eval(parse_filter("group_by(.)"), must_parse("[]")), [
    Json::array([]),
  ])
  assert_eq(
    must_eval(
      parse_filter("group_by(empty)"),
      must_parse("[{\"a\":2},{\"a\":1}]"),
    ),
    [
      Json::array([
        Json::array([
          Json::object({ "a": Json::number(2.0) }),
          Json::object({ "a": Json::number(1.0) }),
        ]),
      ]),
    ],
  )
}

///|
test "eval group_by errors" {
  guard (try? eval(parse_filter("group_by(.)"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected group_by non-array error")
  }
}

///|
test "eval min/max compatibility" {
  assert_eq(must_eval(parse_filter("min"), must_parse("[3,1,2]")), [
    Json::number(1.0),
  ])
  assert_eq(must_eval(parse_filter("max"), must_parse("[3,1,2]")), [
    Json::number(3.0),
  ])
  assert_eq(must_eval(parse_filter("min"), must_parse("[]")), [Json::null()])
  assert_eq(must_eval(parse_filter("max"), must_parse("[]")), [Json::null()])
  assert_eq(
    must_eval(parse_filter("min"), must_parse("[{\"a\":2},{\"a\":1}]")),
    [Json::object({ "a": Json::number(1.0) })],
  )
  assert_eq(
    must_eval(parse_filter("max"), must_parse("[{\"a\":2},{\"a\":1}]")),
    [Json::object({ "a": Json::number(2.0) })],
  )
}

///|
test "eval min/max errors" {
  guard (try? eval(parse_filter("min"), must_parse("1"))) is Err(err) &&
    err.to_string() == "number (1) and number (1) cannot be iterated over" else {
    fail("expected min non-array iterate error")
  }
  guard (try? eval(parse_filter("max"), must_parse("null"))) is Err(err) &&
    err.to_string() == "null (null) and null (null) cannot be iterated over" else {
    fail("expected max null iterate error")
  }
}

///|
test "eval min_by/max_by compatibility" {
  assert_eq(
    must_eval(parse_filter("min_by(.a)"), must_parse("[{\"a\":2},{\"a\":1}]")),
    [Json::object({ "a": Json::number(1.0) })],
  )
  assert_eq(
    must_eval(parse_filter("max_by(.a)"), must_parse("[{\"a\":2},{\"a\":1}]")),
    [Json::object({ "a": Json::number(2.0) })],
  )
  assert_eq(must_eval(parse_filter("min_by(.)"), must_parse("[3,1,2]")), [
    Json::number(1.0),
  ])
  assert_eq(must_eval(parse_filter("max_by(.)"), must_parse("[3,1,2]")), [
    Json::number(3.0),
  ])
  assert_eq(must_eval(parse_filter("min_by(.)"), must_parse("[]")), [
    Json::null(),
  ])
  assert_eq(must_eval(parse_filter("max_by(.)"), must_parse("[]")), [
    Json::null(),
  ])
  assert_eq(
    must_eval(
      parse_filter("min_by(empty)"),
      must_parse("[{\"a\":2},{\"a\":1}]"),
    ),
    [Json::object({ "a": Json::number(2.0) })],
  )
  assert_eq(
    must_eval(
      parse_filter("max_by(empty)"),
      must_parse("[{\"a\":2},{\"a\":1}]"),
    ),
    [Json::object({ "a": Json::number(1.0) })],
  )
  assert_eq(
    must_eval(
      parse_filter("max_by(.k)"),
      must_parse("[{\"k\":1,\"id\":\"a\"},{\"k\":1,\"id\":\"b\"}]"),
    ),
    [Json::object({ "k": Json::number(1.0), "id": Json::string("b") })],
  )
}

///|
test "eval min_by/max_by errors" {
  guard (try? eval(parse_filter("min_by(.)"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected min_by non-array error")
  }
  guard (try? eval(parse_filter("max_by(.)"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected max_by non-array error")
  }
}

///|
test "eval unique compatibility" {
  assert_eq(must_eval(parse_filter("unique"), must_parse("[1,2,1,3]")), [
    Json::array([Json::number(1.0), Json::number(2.0), Json::number(3.0)]),
  ])
  assert_eq(must_eval(parse_filter("unique"), must_parse("[]")), [
    Json::array([]),
  ])
  assert_eq(
    must_eval(
      parse_filter("unique"),
      must_parse("[{\"a\":2},{\"a\":1},{\"a\":2}]"),
    ),
    [
      Json::array([
        Json::object({ "a": Json::number(1.0) }),
        Json::object({ "a": Json::number(2.0) }),
      ]),
    ],
  )
}

///|
test "eval unique errors" {
  guard (try? eval(parse_filter("unique"), must_parse("1"))) is Err(err) &&
    err.to_string() == "number (1) cannot be sorted, as it is not an array" else {
    fail("expected unique non-array type error")
  }
  guard (try? eval(parse_filter("unique"), must_parse("null"))) is Err(err) &&
    err.to_string() == "null (null) cannot be sorted, as it is not an array" else {
    fail("expected unique null type error")
  }
}

///|
test "eval unique_by compatibility" {
  assert_eq(
    must_eval(
      parse_filter("unique_by(.a)"),
      must_parse(
        "[{\"a\":2,\"b\":\"x\"},{\"a\":1,\"b\":\"x\"},{\"a\":2,\"b\":\"y\"}]",
      ),
    ),
    [
      Json::array([
        Json::object({ "a": Json::number(1.0), "b": Json::string("x") }),
        Json::object({ "a": Json::number(2.0), "b": Json::string("x") }),
      ]),
    ],
  )
  assert_eq(must_eval(parse_filter("unique_by(.)"), must_parse("[]")), [
    Json::array([]),
  ])
  assert_eq(
    must_eval(
      parse_filter("unique_by(empty)"),
      must_parse("[{\"a\":2},{\"a\":1}]"),
    ),
    [Json::array([Json::object({ "a": Json::number(2.0) })])],
  )
  assert_eq(
    must_eval(
      parse_filter("unique_by((.a,.b))"),
      must_parse("[{\"a\":2},{\"a\":1}]"),
    ),
    [
      Json::array([
        Json::object({ "a": Json::number(1.0) }),
        Json::object({ "a": Json::number(2.0) }),
      ]),
    ],
  )
}

///|
test "eval unique_by errors" {
  guard (try? eval(parse_filter("unique_by(.)"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected unique_by non-array error")
  }
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
test "eval trimstr compatibility" {
  let j = must_parse("\"foobar\"")
  assert_eq(must_eval(parse_filter("ltrimstr(\"foo\")"), j), [
    Json::string("bar"),
  ])
  assert_eq(must_eval(parse_filter("ltrimstr(\"bar\")"), j), [
    Json::string("foobar"),
  ])
  assert_eq(must_eval(parse_filter("rtrimstr(\"bar\")"), j), [
    Json::string("foo"),
  ])
  assert_eq(must_eval(parse_filter("rtrimstr(\"foo\")"), j), [
    Json::string("foobar"),
  ])
  assert_eq(must_eval(parse_filter("ltrimstr((\"foo\",\"bar\"))"), j), [
    Json::string("bar"),
    Json::string("foobar"),
  ])
  assert_eq(must_eval(parse_filter("ltrimstr(empty)"), j), [])
}

///|
test "eval trimstr errors" {
  guard (try? eval(parse_filter("ltrimstr(\"1\")"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "startswith() requires string inputs" else {
    fail("expected ltrimstr input type error")
  }
  guard (try? eval(parse_filter("ltrimstr(1)"), must_parse("\"x\"")))
    is Err(err) &&
    err.to_string() == "startswith() requires string inputs" else {
    fail("expected ltrimstr separator type error")
  }
  guard (try? eval(parse_filter("rtrimstr(1)"), must_parse("\"x\"")))
    is Err(err) &&
    err.to_string() == "startswith() requires string inputs" else {
    fail("expected rtrimstr separator type error")
  }
}

///|
test "eval ascii case compatibility" {
  assert_eq(
    must_eval(parse_filter("ascii_downcase"), must_parse("\"AbC_é\"")),
    [Json::string("abc_é")],
  )
  assert_eq(must_eval(parse_filter("ascii_upcase"), must_parse("\"AbC_é\"")), [
    Json::string("ABC_é"),
  ])
}

///|
test "eval ascii case errors" {
  guard (try? eval(parse_filter("ascii_upcase"), must_parse("1"))) is Err(err) &&
    err.to_string() == "explode input must be a string" else {
    fail("expected ascii_upcase type error")
  }
  guard (try? eval(parse_filter("ascii_downcase"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "explode input must be a string" else {
    fail("expected ascii_downcase type error")
  }
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
  guard (try? eval(parse_filter("inside(false)"), must_parse("true")))
    is Err(err) &&
    err.to_string() ==
    "boolean (false) and boolean (true) cannot have their containment checked" else {
    fail("expected inside boolean mismatch error")
  }
  guard (try? eval(parse_filter("inside(1)"), must_parse("[1]"))) is Err(err) &&
    err.to_string() ==
    "number (1) and array ([1]) cannot have their containment checked" else {
    fail("expected inside number/array mismatch error")
  }
  guard (try? eval(parse_filter("inside([1])"), must_parse("1"))) is Err(err) &&
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
