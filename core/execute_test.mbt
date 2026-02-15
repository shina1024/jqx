///|
// Source under test: core/execute.mbt, core/json_ops.mbt, core/builtin_dispatch.mbt

///|
test "execute identity" {
  let j = must_parse("{\"a\":1}")
  let f = parse_filter(".")
  let out = must_execute(f, j)
  assert_eq(out, [j])
}

///|
test "execute field and missing field" {
  let j = must_parse("{\"a\":1}")
  let f1 = parse_filter(".a")
  let f2 = parse_filter(".b")
  let f3 = parse_filter(".\"a\"")
  assert_eq(must_execute(f1, j), [Json::number(1.0)])
  assert_eq(must_execute(f2, j), [Json::null()])
  assert_eq(must_execute(f3, j), [Json::number(1.0)])
}

///|
test "execute field/index type errors and optional suppression" {
  let number_json = must_parse("1")
  let array_json = must_parse("[1,2]")
  let object_json = must_parse("{\"a\":1}")
  let null_json = must_parse("null")
  guard (try? execute(parse_filter(".foo"), number_json)) is Err(err) &&
    err.to_string() == "Cannot index number with string \"foo\"" else {
    fail("expected type error for number .foo")
  }
  guard (try? execute(parse_filter(".foo"), array_json)) is Err(err) &&
    err.to_string() == "Cannot index array with string \"foo\"" else {
    fail("expected type error for array .foo")
  }
  guard (try? execute(parse_filter(".[0]"), number_json)) is Err(err) &&
    err.to_string() == "Cannot index number with number" else {
    fail("expected type error for number .[0]")
  }
  guard (try? execute(parse_filter(".[0]"), object_json)) is Err(err) &&
    err.to_string() == "Cannot index object with number" else {
    fail("expected type error for object .[0]")
  }
  assert_eq(must_execute(parse_filter(".foo?"), number_json), [])
  assert_eq(must_execute(parse_filter(".foo?"), array_json), [])
  assert_eq(must_execute(parse_filter(".[0]?"), number_json), [])
  assert_eq(must_execute(parse_filter(".[0]?"), object_json), [])
  assert_eq(must_execute(parse_filter(".foo"), null_json), [Json::null()])
  assert_eq(must_execute(parse_filter(".foo?"), null_json), [Json::null()])
  assert_eq(must_execute(parse_filter(".[0]"), null_json), [Json::null()])
  assert_eq(must_execute(parse_filter(".[0]?"), null_json), [Json::null()])
}

///|
test "execute index and iter" {
  let j = must_parse("[1,2,3]")
  let f1 = parse_filter(".[1]")
  let f2 = parse_filter(".[]")
  let f3 = parse_filter(".[1,2]")
  assert_eq(must_execute(f1, j), [Json::number(2.0)])
  assert_eq(must_execute(f2, j), [
    Json::number(1.0),
    Json::number(2.0),
    Json::number(3.0),
  ])
  assert_eq(must_execute(f3, j), [Json::number(2.0), Json::number(3.0)])
  assert_eq(
    must_execute(parse_filter("[range(10)] | .[1.2:3.5]"), must_parse("null")),
    [Json::array([Json::number(1.0), Json::number(2.0), Json::number(3.0)])],
  )
  assert_eq(
    must_execute(parse_filter("[range(10)] | .[1.5:3.5]"), must_parse("null")),
    [Json::array([Json::number(1.0), Json::number(2.0), Json::number(3.0)])],
  )
  assert_eq(
    must_execute(parse_filter("[range(10)] | .[1.7:3.5]"), must_parse("null")),
    [Json::array([Json::number(1.0), Json::number(2.0), Json::number(3.0)])],
  )
}

///|
test "execute chained index without extra dot" {
  let j = must_parse("{\"a\":[10,20,30]}")
  assert_eq(must_execute(parse_filter(".a[1]"), j), [Json::number(20.0)])
  assert_eq(must_execute(parse_filter(".a[1:3]"), j), [
    Json::array([Json::number(20.0), Json::number(30.0)]),
  ])
}

///|
test "execute string index jq compatibility" {
  let s = must_parse("\"abc\"")
  guard (try? execute(parse_filter(".[0]"), s)) is Err(err) &&
    err.to_string() == "Cannot index string with number" else {
    fail("expected string index type error")
  }
  guard (try? execute(parse_filter(".[-1]"), s)) is Err(err) &&
    err.to_string() == "Cannot index string with number" else {
    fail("expected string negative index type error")
  }
  assert_eq(must_execute(parse_filter(".[0]?"), s), [])
  assert_eq(must_execute(parse_filter(".[-1]?"), s), [])
}

///|
test "execute optional access" {
  let j = must_parse("[1,2,3]")
  assert_eq(must_execute(parse_filter(".[]?"), j), [
    Json::number(1.0),
    Json::number(2.0),
    Json::number(3.0),
  ])
  let j2 = must_parse("1")
  assert_eq(must_execute(parse_filter(".[]?"), j2), [])
  assert_eq(must_execute(parse_filter(".foo?"), j2), [])
  assert_eq(must_execute(parse_filter(".[0]?"), j2), [])
}

///|
test "execute pipe and comma" {
  let j = must_parse("{\"a\":{\"b\":2},\"c\":3}")
  let f = parse_filter(".a | .b, .c")
  assert_eq(must_execute(f, j), [Json::number(2.0), Json::null()])
  assert_eq(
    must_execute(parse_filter("{x:(1,2)},{x:3} | .x"), must_parse("null")),
    [Json::number(1.0), Json::number(2.0), Json::number(3.0)],
  )
}

///|
test "execute update assignment precedence" {
  let j1 = must_parse("{\"a\":0}")
  assert_eq(must_execute(parse_filter(".a = 1 | .a"), j1), [Json::number(1.0)])

  let j2 = must_parse("{\"a\":0}")
  assert_eq(must_execute(parse_filter(".a = 1 // 2 | .a"), j2), [
    Json::number(1.0),
  ])

  let j3 = must_parse(
    "[{\"x\":\"a\",\"y\":1},{\"x\":\"b\",\"y\":2},{\"x\":\"c\",\"y\":3}]",
  )
  assert_eq(
    must_execute(
      parse_filter("reduce .[] as {$x,$y} (null; .x += $x | .y += [$y])"),
      j3,
    ),
    [
      Json::object({
        "x": Json::string("abc"),
        "y": Json::array([
          Json::number(1.0),
          Json::number(2.0),
          Json::number(3.0),
        ]),
      }),
    ],
  )
}

///|
test "execute literal" {
  let j = must_parse("null")
  let f = parse_filter("\"hi\"")
  assert_eq(must_execute(f, j), [Json::string("hi")])
}

///|
test "execute array and object literals" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  let f1 = parse_filter("[.a, .b]")
  let f2 = parse_filter("{\"x\": .a, y: .b}")
  let f3 = parse_filter("{a, \"b\"}")
  let f4 = parse_filter("1 as $x | \"dyn\" as $k | { $x, $k: .b, a }")
  assert_eq(must_execute(f1, j), [
    Json::array([Json::number(1.0), Json::number(2.0)]),
  ])
  assert_eq(must_execute(f2, j), [
    Json::object({ "x": Json::number(1.0), "y": Json::number(2.0) }),
  ])
  assert_eq(must_execute(f3, j), [
    Json::object({ "a": Json::number(1.0), "b": Json::number(2.0) }),
  ])
  assert_eq(must_execute(f4, j), [
    Json::object({
      "x": Json::number(1.0),
      "dyn": Json::number(2.0),
      "a": Json::number(1.0),
    }),
  ])
}

///|
test "execute builtins" {
  let j1 = must_parse("[1,2,3]")
  let j2 = must_parse("{\"a\":1,\"b\":2}")
  let j3 = must_parse("\"hi\"")
  assert_eq(must_execute(parse_filter("length"), j1), [Json::number(3.0)])
  assert_eq(must_execute(parse_filter("length"), j2), [Json::number(2.0)])
  assert_eq(must_execute(parse_filter("length"), j3), [Json::number(2.0)])
  assert_eq(must_execute(parse_filter("type"), j2), [Json::string("object")])
  assert_eq(must_execute(parse_filter("keys"), j2), [
    Json::array([Json::string("a"), Json::string("b")]),
  ])
}

///|
test "execute def no-arg minimal" {
  let j = must_parse("1")
  assert_eq(must_execute(parse_filter("def inc: . + 1; . | inc"), j), [
    Json::number(2.0),
  ])
  assert_eq(
    must_execute(
      parse_filter("def inc: . + 1; def twice: inc | inc; . | twice"),
      j,
    ),
    [Json::number(3.0)],
  )
  assert_eq(must_execute(parse_filter("def length: 42; . | length"), j), [
    Json::number(42.0),
  ])
  let obj = must_parse("{\"a\":1,\"b\":2}")
  assert_eq(
    must_execute(parse_filter("def add(a;b): a + b; add(.a; .b)"), obj),
    [Json::number(3.0)],
  )
  let arr = must_parse("[1,2]")
  assert_eq(
    must_execute(parse_filter("def addvalue(f): . + [f]; addvalue(.[0])"), arr),
    [Json::array([Json::number(1.0), Json::number(2.0), Json::number(1.0)])],
  )
  assert_eq(must_execute(parse_filter("def plus($x): . + $x; plus(2)"), j), [
    Json::number(3.0),
  ])
  assert_eq(
    must_execute(
      parse_filter("def f: . + 1; def g: def g: . + 100; f | g | f; (f | g), g"),
      must_parse("3"),
    ),
    [Json::number(106.0), Json::number(105.0)],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "def f: .+1; def g: f; def f: .+100; def f(a):a+.+11; [(g|f(20)), f]",
      ),
      must_parse("1"),
    ),
    [Json::array([Json::number(33.0), Json::number(101.0)])],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "[[20,10][1,0] as $x | def f: (100,200) as $y | def g: [$x + $y, .]; . + $x | g; f[0] | [f][0][1] | f]",
      ),
      must_parse("999999999"),
    ),
    [
      Json::array([
        Json::array([Json::number(110.0), Json::number(130.0)]),
        Json::array([Json::number(210.0), Json::number(130.0)]),
        Json::array([Json::number(110.0), Json::number(230.0)]),
        Json::array([Json::number(210.0), Json::number(230.0)]),
        Json::array([Json::number(120.0), Json::number(160.0)]),
        Json::array([Json::number(220.0), Json::number(160.0)]),
        Json::array([Json::number(120.0), Json::number(260.0)]),
        Json::array([Json::number(220.0), Json::number(260.0)]),
      ]),
    ],
  )
}

///|
test "execute first/last/nth compatibility" {
  let arr = must_parse("[1,2,3]")
  assert_eq(must_execute(parse_filter("first"), arr), [Json::number(1.0)])
  assert_eq(must_execute(parse_filter("last"), arr), [Json::number(3.0)])
  assert_eq(must_execute(parse_filter("nth(0)"), arr), [Json::number(1.0)])
  assert_eq(must_execute(parse_filter("nth(-1)"), arr), [Json::number(3.0)])
  assert_eq(must_execute(parse_filter("nth(9)"), arr), [Json::null()])
  assert_eq(must_execute(parse_filter("nth(1.9)"), arr), [Json::number(2.0)])
  assert_eq(must_execute(parse_filter("nth((0,-1,9))"), arr), [
    Json::number(1.0),
    Json::number(3.0),
    Json::null(),
  ])
  let empty_arr = must_parse("[]")
  assert_eq(must_execute(parse_filter("first"), empty_arr), [Json::null()])
  assert_eq(must_execute(parse_filter("last"), empty_arr), [Json::null()])
  assert_eq(must_execute(parse_filter("nth(0)"), empty_arr), [Json::null()])
  let null_json = must_parse("null")
  assert_eq(must_execute(parse_filter("first"), null_json), [Json::null()])
  assert_eq(must_execute(parse_filter("last"), null_json), [Json::null()])
  assert_eq(must_execute(parse_filter("nth(0)"), null_json), [Json::null()])
  assert_eq(must_execute(parse_filter("nth(\"a\")"), null_json), [Json::null()])
  let scalar = must_parse("1")
  assert_eq(must_execute(parse_filter("first(empty)"), scalar), [])
  assert_eq(must_execute(parse_filter("last(empty)"), scalar), [])
  assert_eq(must_execute(parse_filter("nth(empty)"), scalar), [])
  assert_eq(must_execute(parse_filter("first((1,2,3))"), scalar), [
    Json::number(1.0),
  ])
  assert_eq(must_execute(parse_filter("last((1,2,3))"), scalar), [
    Json::number(3.0),
  ])
  let null_json2 = must_parse("null")
  assert_eq(
    must_execute(parse_filter("nth(1; 0,1,error(\"foo\"))"), null_json2),
    [Json::number(1.0)],
  )
  assert_eq(must_execute(parse_filter("nth(5; empty)"), null_json2), [])
}

///|
test "execute first/last/nth errors" {
  guard (try? execute(parse_filter("first"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot index number with number" else {
    fail("expected first number index error")
  }
  guard (try? execute(parse_filter("last"), must_parse("{}"))) is Err(err) &&
    err.to_string() == "Cannot index object with number" else {
    fail("expected last object index error")
  }
  guard (try? execute(parse_filter("nth(\"a\")"), must_parse("[1,2,3]")))
    is Err(err) &&
    err.to_string() == "Cannot index array with string \"a\"" else {
    fail("expected nth array string-key error")
  }
  guard (try? execute(parse_filter("nth(true)"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "Cannot index null with boolean" else {
    fail("expected nth null boolean-key error")
  }
}

///|
test "execute flatten compatibility" {
  let nested = must_parse("[1,[2],[[3,[4]]],5]")
  assert_eq(must_execute(parse_filter("flatten"), nested), [
    Json::array([
      Json::number(1.0),
      Json::number(2.0),
      Json::number(3.0),
      Json::number(4.0),
      Json::number(5.0),
    ]),
  ])
  assert_eq(must_execute(parse_filter("flatten(1)"), nested), [
    Json::array([
      Json::number(1.0),
      Json::number(2.0),
      Json::array([Json::number(3.0), Json::array([Json::number(4.0)])]),
      Json::number(5.0),
    ]),
  ])
  assert_eq(must_execute(parse_filter("flatten(2)"), nested), [
    Json::array([
      Json::number(1.0),
      Json::number(2.0),
      Json::number(3.0),
      Json::array([Json::number(4.0)]),
      Json::number(5.0),
    ]),
  ])
  assert_eq(must_execute(parse_filter("flatten(0)"), nested), [nested])
  assert_eq(must_execute(parse_filter("flatten(0.1)"), nested), [
    Json::array([
      Json::number(1.0),
      Json::number(2.0),
      Json::number(3.0),
      Json::number(4.0),
      Json::number(5.0),
    ]),
  ])
  assert_eq(
    must_execute(parse_filter("flatten((0,1))"), must_parse("[1,[2]]")),
    [
      Json::array([Json::number(1.0), Json::array([Json::number(2.0)])]),
      Json::array([Json::number(1.0), Json::number(2.0)]),
    ],
  )
  assert_eq(must_execute(parse_filter("flatten(empty)"), nested), [])
}

///|
test "execute flatten errors" {
  guard (try? execute(parse_filter("flatten"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected flatten non-array iterate error")
  }
  guard (try? execute(parse_filter("flatten"), must_parse("null"))) is Err(err) &&
    err.to_string() == "Cannot iterate over null (null)" else {
    fail("expected flatten null iterate error")
  }
  guard (try? execute(parse_filter("flatten(-1)"), must_parse("[1,[2]]")))
    is Err(err) &&
    err.to_string() == "flatten depth must not be negative" else {
    fail("expected flatten negative depth error")
  }
  guard (try? execute(parse_filter("flatten(null)"), must_parse("[1,[2]]")))
    is Err(err) &&
    err.to_string() == "flatten depth must not be negative" else {
    fail("expected flatten null depth error")
  }
  guard (try? execute(parse_filter("flatten(true)"), must_parse("[1,[2]]")))
    is Err(err) &&
    err.to_string() == "flatten depth must not be negative" else {
    fail("expected flatten bool depth error")
  }
  guard (try? execute(parse_filter("flatten(\"x\")"), must_parse("[1,[2]]")))
    is Err(err) &&
    err.to_string() == "string (\"x\") and number (1) cannot be subtracted" else {
    fail("expected flatten string depth error")
  }
}

///|
test "execute transpose compatibility" {
  assert_eq(
    must_execute(parse_filter("transpose"), must_parse("[[1,2],[3,4]]")),
    [
      Json::array([
        Json::array([Json::number(1.0), Json::number(3.0)]),
        Json::array([Json::number(2.0), Json::number(4.0)]),
      ]),
    ],
  )
  assert_eq(
    must_execute(parse_filter("transpose"), must_parse("[[1],[2,3]]")),
    [
      Json::array([
        Json::array([Json::number(1.0), Json::number(2.0)]),
        Json::array([Json::null(), Json::number(3.0)]),
      ]),
    ],
  )
  assert_eq(must_execute(parse_filter("transpose"), must_parse("[]")), [
    Json::array([]),
  ])
  assert_eq(must_execute(parse_filter("transpose"), must_parse("[[],[]]")), [
    Json::array([]),
  ])
  assert_eq(must_execute(parse_filter("transpose"), must_parse("[[1],[]]")), [
    Json::array([Json::array([Json::number(1.0), Json::null()])]),
  ])
  assert_eq(must_execute(parse_filter("transpose"), must_parse("[{}]")), [
    Json::array([]),
  ])
  assert_eq(must_execute(parse_filter("transpose"), must_parse("[[1],null]")), [
    Json::array([Json::array([Json::number(1.0), Json::null()])]),
  ])
  assert_eq(
    must_execute(parse_filter("transpose"), must_parse("[[1,null],[2]]")),
    [
      Json::array([
        Json::array([Json::number(1.0), Json::number(2.0)]),
        Json::array([Json::null(), Json::null()]),
      ]),
    ],
  )
}

///|
test "execute transpose errors" {
  guard (try? execute(parse_filter("transpose"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected transpose non-array iterate error")
  }
  guard (try? execute(parse_filter("transpose"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "Cannot iterate over null (null)" else {
    fail("expected transpose null iterate error")
  }
  guard (try? execute(parse_filter("transpose"), must_parse("[1]"))) is Err(err) &&
    err.to_string() == "Cannot index number with number" else {
    fail("expected transpose number index error")
  }
  guard (try? execute(parse_filter("transpose"), must_parse("[[1],{}]")))
    is Err(err) &&
    err.to_string() == "Cannot index object with number" else {
    fail("expected transpose object index error")
  }
  guard (try? execute(parse_filter("transpose"), must_parse("[[1],\"x\"]")))
    is Err(err) &&
    err.to_string() == "Cannot index string with number" else {
    fail("expected transpose string index error")
  }
  guard (try? execute(parse_filter("transpose"), must_parse("[true]")))
    is Err(err) &&
    err.to_string() == "boolean (true) has no length" else {
    fail("expected transpose boolean length error")
  }
}

///|
test "execute to_entries/from_entries/with_entries compatibility" {
  assert_eq(must_execute(parse_filter("to_entries"), must_parse("[10,20]")), [
    Json::array([
      Json::object({ "key": Json::number(0.0), "value": Json::number(10.0) }),
      Json::object({ "key": Json::number(1.0), "value": Json::number(20.0) }),
    ]),
  ])
  assert_eq(
    must_execute(
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
    must_execute(parse_filter("from_entries"), must_parse("[{\"key\":\"a\"}]")),
    [Json::object({ "a": Json::null() })],
  )
  assert_eq(
    must_execute(
      parse_filter("with_entries({key: (.key + \"_x\"), value: (.value + 10)})"),
      must_parse("{\"a\":1}"),
    ),
    [Json::object({ "a_x": Json::number(11.0) })],
  )
  assert_eq(
    must_execute(parse_filter("with_entries(empty)"), must_parse("{\"a\":1}")),
    [Json::object(Map::new())],
  )
}

///|
test "execute to_entries/from_entries/with_entries errors" {
  guard (try? execute(parse_filter("to_entries"), must_parse("1"))) is Err(err) &&
    err.to_string() == "number (1) has no keys" else {
    fail("expected to_entries no-keys error")
  }
  guard (try? execute(parse_filter("from_entries"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected from_entries iterate error")
  }
  guard (try? execute(parse_filter("from_entries"), must_parse("[1]")))
    is Err(err) &&
    err.to_string() == "Cannot index number with string \"key\"" else {
    fail("expected from_entries entry index error")
  }
  guard (try? execute(
      parse_filter("from_entries"),
      must_parse("[{\"value\":1}]"),
    ))
    is Err(err) &&
    err.to_string() == "Cannot use null (null) as object key" else {
    fail("expected from_entries null key error")
  }
  guard (try? execute(
      parse_filter("from_entries"),
      must_parse("[{\"key\":1,\"value\":2}]"),
    ))
    is Err(err) &&
    err.to_string() == "Cannot use number (1) as object key" else {
    fail("expected from_entries number key error")
  }
  guard (try? execute(parse_filter("with_entries(.)"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "number (1) has no keys" else {
    fail("expected with_entries no-keys error")
  }
  guard (try? execute(parse_filter("with_entries(.)"), must_parse("[10,20]")))
    is Err(err) &&
    err.to_string() == "Cannot use number (0) as object key" else {
    fail("expected with_entries array key type error")
  }
}

///|
test "execute keys compatibility errors and keys_unsorted" {
  let arr = must_parse("[10,20]")
  assert_eq(must_execute(parse_filter("keys_unsorted"), arr), [
    Json::array([Json::number(0.0), Json::number(1.0)]),
  ])
  let obj = must_parse("{\"b\":2,\"a\":1}")
  assert_eq(must_execute(parse_filter("keys_unsorted"), obj), [
    Json::array([Json::string("b"), Json::string("a")]),
  ])
  assert_eq(must_execute(parse_filter(".[]"), obj), [
    Json::number(2.0),
    Json::number(1.0),
  ])
  assert_eq(must_execute(parse_filter("tojson"), obj), [
    Json::string("{\"b\":2,\"a\":1}"),
  ])
  guard (try? execute(parse_filter("keys"), must_parse("1"))) is Err(err) &&
    err.to_string() == "number (1) has no keys" else {
    fail("expected jq-compatible keys error")
  }
  guard (try? execute(parse_filter("keys_unsorted"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "number (1) has no keys" else {
    fail("expected jq-compatible keys_unsorted error")
  }
}

///|
test "execute tostring/tonumber compatibility" {
  assert_eq(must_execute(parse_filter("tostring"), must_parse("1")), [
    Json::string("1"),
  ])
  assert_eq(must_execute(parse_filter("tostring"), must_parse("\"x\"")), [
    Json::string("x"),
  ])
  assert_eq(must_execute(parse_filter("tostring"), must_parse("null")), [
    Json::string("null"),
  ])
  assert_eq(must_execute(parse_filter("tostring"), must_parse("[1,2]")), [
    Json::string("[1,2]"),
  ])
  assert_eq(must_execute(parse_filter("tonumber"), must_parse("\"1\"")), [
    Json::number(1.0),
  ])
  assert_eq(must_execute(parse_filter("tonumber"), must_parse("\"01\"")), [
    Json::number(1.0),
  ])
  assert_eq(must_execute(parse_filter("tonumber"), must_parse("\"1.25\"")), [
    Json::number(1.25),
  ])
  assert_eq(must_execute(parse_filter("tonumber"), must_parse("1")), [
    Json::number(1.0),
  ])
  let nan_number = must_execute(parse_filter("tonumber"), must_parse("\"nan\""))
  assert_eq(nan_number.length(), 1)
  assert_eq(nan_number[0].to_json_string(), "null")
  let huge = must_execute(parse_filter("tonumber"), must_parse("\"1e309\""))
  assert_eq(huge.length(), 1)
  assert_eq(huge[0].to_json_string(), "1e309")
  let pos_inf = must_execute(
    parse_filter("tonumber"),
    must_parse("\"Infinity\""),
  )
  assert_eq(pos_inf.length(), 1)
  assert_eq(pos_inf[0].to_json_string(), "1.7976931348623157e+308")
  let neg_inf = must_execute(
    parse_filter("tonumber"),
    must_parse("\"-Infinity\""),
  )
  assert_eq(neg_inf.length(), 1)
  assert_eq(neg_inf[0].to_json_string(), "-1.7976931348623157e+308")
}

///|
test "execute tojson/fromjson compatibility" {
  assert_eq(must_execute(parse_filter("tojson"), must_parse("1")), [
    Json::string("1"),
  ])
  assert_eq(must_execute(parse_filter("tojson"), must_parse("\"x\"")), [
    Json::string("\"x\""),
  ])
  assert_eq(must_execute(parse_filter("tojson"), must_parse("[1,2]")), [
    Json::string("[1,2]"),
  ])
  assert_eq(must_execute(parse_filter("tojson"), must_parse("{\"a\":1}")), [
    Json::string("{\"a\":1}"),
  ])
  assert_eq(must_execute(parse_filter("tojson"), must_parse("null")), [
    Json::string("null"),
  ])
  assert_eq(must_execute(parse_filter("tojson"), must_parse("true")), [
    Json::string("true"),
  ])
  assert_eq(
    must_execute(
      parse_filter("tojson"),
      must_parse("0.12345678901234567890123456789"),
    ),
    [Json::string("0.12345678901234568")],
  )
  assert_eq(must_execute(parse_filter("tojson"), must_parse("1E-999999999")), [
    Json::string("0"),
  ])
  assert_eq(must_execute(parse_filter("fromjson"), must_parse("\"1\"")), [
    Json::number(1.0),
  ])
  assert_eq(must_execute(parse_filter("fromjson"), must_parse("\"[1,2]\"")), [
    Json::array([Json::number(1.0), Json::number(2.0)]),
  ])
  assert_eq(
    must_execute(parse_filter("fromjson"), must_parse("\"{\\\"a\\\":1}\"")),
    [Json::object({ "a": Json::number(1.0) })],
  )
  assert_eq(must_execute(parse_filter("fromjson"), must_parse("\"null\"")), [
    Json::null(),
  ])
  assert_eq(must_execute(parse_filter("fromjson"), must_parse("\" true \"")), [
    Json::boolean(true),
  ])
  assert_eq(
    must_execute(parse_filter("fromjson | isnan"), must_parse("\"nan\"")),
    [Json::boolean(true)],
  )
  assert_eq(
    must_execute(parse_filter("fromjson | isinfinite"), must_parse("\"INF\"")),
    [Json::boolean(true)],
  )
  assert_eq(
    must_execute(parse_filter("fromjson | isinfinite"), must_parse("\"-inf\"")),
    [Json::boolean(true)],
  )
}

///|
test "execute format filter compatibility" {
  assert_eq(
    must_execute(parse_filter("(@uri|@urid)"), must_parse("\"<>&'\\\"\\t\"")),
    [Json::string("<>&'\"\t")],
  )
  assert_eq(
    must_execute(
      parse_filter("(@base64|@base64d)"),
      must_parse("\"<>&'\\\"\\t\""),
    ),
    [Json::string("<>&'\"\t")],
  )
  guard (try? execute(
      parse_filter("@base64d"),
      must_parse("\"Not base64 data\""),
    ))
    is Err(err) &&
    err.to_string() == "string (\"Not base64...) is not valid base64 data" else {
    fail("expected @base64d invalid data error")
  }
  guard (try? execute(parse_filter("@base64d"), must_parse("\"QUJDa\"")))
    is Err(err) &&
    err.to_string() == "string (\"QUJDa\") trailing base64 byte found" else {
    fail("expected @base64d trailing byte error")
  }
  guard (try? execute(parse_filter("@urid"), must_parse("\"%FX%9F%98%8E\"")))
    is Err(err) &&
    err.to_string() == "string (\"%FX%9F%98%8E\") is not a valid uri encoding" else {
    fail("expected @urid invalid encoding error")
  }
}

///|
test "execute fromjson errors" {
  guard (try? execute(parse_filter("fromjson"), must_parse("1"))) is Err(err) &&
    err.to_string() == "number (1) only strings can be parsed" else {
    fail("expected fromjson number type error")
  }
  guard (try? execute(parse_filter("fromjson"), must_parse("null"))) is Err(err) &&
    err.to_string() == "null (null) only strings can be parsed" else {
    fail("expected fromjson null type error")
  }
  guard (try? execute(parse_filter("fromjson"), must_parse("{}"))) is Err(err) &&
    err.to_string() == "object ({}) only strings can be parsed" else {
    fail("expected fromjson object type error")
  }
  guard (try? execute(parse_filter("fromjson"), must_parse("\"x\"")))
    is Err(err) &&
    err.to_string().contains("while parsing 'x'") else {
    fail("expected fromjson invalid token parse context")
  }
  guard (try? execute(parse_filter("fromjson"), must_parse("\"\""))) is Err(err) &&
    err.to_string().contains("while parsing ''") else {
    fail("expected fromjson empty parse context")
  }
  guard (try? execute(parse_filter("fromjson"), must_parse("\"[1,2\"")))
    is Err(err) &&
    err.to_string().contains("while parsing '[1,2'") else {
    fail("expected fromjson unfinished array parse context")
  }
  guard (try? execute(parse_filter("fromjson"), must_parse("\"NaN10\"")))
    is Err(err) &&
    err.to_string() ==
    "Invalid numeric literal at EOF at line 1, column 5 (while parsing 'NaN10')" else {
    fail("expected fromjson invalid non-finite suffix parse context")
  }
}

///|
test "execute tonumber errors" {
  guard (try? execute(parse_filter("tonumber"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "string (\"abc\") cannot be parsed as a number" else {
    fail("expected tonumber string parse error")
  }
  guard (try? execute(parse_filter("tonumber"), must_parse("null"))) is Err(err) &&
    err.to_string() == "null (null) cannot be parsed as a number" else {
    fail("expected tonumber null parse error")
  }
  guard (try? execute(parse_filter("tonumber"), must_parse("true"))) is Err(err) &&
    err.to_string() == "boolean (true) cannot be parsed as a number" else {
    fail("expected tonumber boolean parse error")
  }
}

///|
test "execute reverse compatibility" {
  assert_eq(must_execute(parse_filter("reverse"), must_parse("[1,2,3]")), [
    Json::array([Json::number(3.0), Json::number(2.0), Json::number(1.0)]),
  ])
  assert_eq(must_execute(parse_filter("reverse"), must_parse("[]")), [
    Json::array([]),
  ])
  assert_eq(must_execute(parse_filter("reverse"), must_parse("null")), [
    Json::array([]),
  ])
  assert_eq(must_execute(parse_filter("reverse"), must_parse("{}")), [
    Json::array([]),
  ])
  assert_eq(must_execute(parse_filter("reverse"), must_parse("\"\"")), [
    Json::array([]),
  ])
  assert_eq(must_execute(parse_filter("reverse"), must_parse("0")), [
    Json::array([]),
  ])
}

///|
test "execute reverse errors" {
  guard (try? execute(parse_filter("reverse"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot index number with number" else {
    fail("expected reverse number index error")
  }
  guard (try? execute(parse_filter("reverse"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "Cannot index string with number" else {
    fail("expected reverse string index error")
  }
  guard (try? execute(parse_filter("reverse"), must_parse("{\"a\":1}")))
    is Err(err) &&
    err.to_string() == "Cannot index object with number" else {
    fail("expected reverse object index error")
  }
  guard (try? execute(parse_filter("reverse"), must_parse("false"))) is Err(err) &&
    err.to_string() == "boolean (false) has no length" else {
    fail("expected reverse boolean length error")
  }
}

///|
test "execute join compatibility" {
  assert_eq(
    must_execute(parse_filter("join(\",\")"), must_parse("[\"a\",1,true,null]")),
    [Json::string("a,1,true,")],
  )
  assert_eq(must_execute(parse_filter("join(\",\")"), must_parse("[]")), [
    Json::string(""),
  ])
  assert_eq(must_execute(parse_filter("join(\",\")"), must_parse("[1,2]")), [
    Json::string("1,2"),
  ])
  assert_eq(must_execute(parse_filter("join(1)"), must_parse("[\"a\"]")), [
    Json::string("a"),
  ])
  assert_eq(
    must_execute(
      parse_filter("join((\",\", \":\"))"),
      must_parse("[\"a\",\"b\"]"),
    ),
    [Json::string("a,b"), Json::string("a:b")],
  )
  assert_eq(must_execute(parse_filter("join(empty)"), must_parse("[\"a\"]")), [])
}

///|
test "execute join errors" {
  guard (try? execute(parse_filter("join(\",\")"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected join iterate error")
  }
  guard (try? execute(parse_filter("join(1)"), must_parse("[\"a\",\"b\"]")))
    is Err(err) &&
    err.to_string() == "string (\"a\") and number (1) cannot be added" else {
    fail("expected join separator type error")
  }
  guard (try? execute(parse_filter("join(\",\")"), must_parse("[{\"x\":1}]")))
    is Err(err) &&
    err.to_string() == "string (\"\") and object ({\"x\":1}) cannot be added" else {
    fail("expected join object element type error")
  }
  guard (try? execute(
      parse_filter("join(\",\")"),
      must_parse("[\"1\",\"2\",{\"a\":{\"b\":{\"c\":33}}}]"),
    ))
    is Err(err) &&
    err.to_string() ==
    "string (\"1,2,\") and object ({\"a\":{\"b\":{...) cannot be added" else {
    fail("expected join deep object preview error")
  }
}

///|
test "execute split compatibility" {
  assert_eq(
    must_execute(parse_filter("split(\",\")"), must_parse("\"a,b,c\"")),
    [Json::array([Json::string("a"), Json::string("b"), Json::string("c")])],
  )
  assert_eq(must_execute(parse_filter("split(\"\")"), must_parse("\"abc\"")), [
    Json::array([Json::string("a"), Json::string("b"), Json::string("c")]),
  ])
  assert_eq(must_execute(parse_filter("split(\"\")"), must_parse("\"\"")), [
    Json::array([]),
  ])
  assert_eq(must_execute(parse_filter("split(\",\")"), must_parse("\"\"")), [
    Json::array([]),
  ])
  assert_eq(
    must_execute(parse_filter("split((\",\", \"\"))"), must_parse("\"abc\"")),
    [
      Json::array([Json::string("abc")]),
      Json::array([Json::string("a"), Json::string("b"), Json::string("c")]),
    ],
  )
  assert_eq(must_execute(parse_filter("split(\"a\")"), must_parse("\"aa\"")), [
    Json::array([Json::string(""), Json::string(""), Json::string("")]),
  ])
  assert_eq(must_execute(parse_filter("split(empty)"), must_parse("\"a\"")), [])
  assert_eq(
    must_execute(
      parse_filter("split(\", *\"; null)"),
      must_parse("\"ab,cd, ef\""),
    ),
    [Json::array([Json::string("ab"), Json::string("cd"), Json::string("ef")])],
  )
  assert_eq(
    must_execute(parse_filter("[splits(\"\")]"), must_parse("\"ab\"")),
    [
      Json::array([
        Json::string(""),
        Json::string("a"),
        Json::string("b"),
        Json::string(""),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("[splits(\"a+\"; \"i\")]"),
      must_parse("\"abAABBabA\""),
    ),
    [
      Json::array([
        Json::string(""),
        Json::string("b"),
        Json::string("BB"),
        Json::string("b"),
        Json::string(""),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("[splits(\",? *\"; \"n\")]"),
      must_parse("\"ab,cd ef,  gh\""),
    ),
    [
      Json::array([
        Json::string("ab"),
        Json::string("cd"),
        Json::string("ef"),
        Json::string("gh"),
      ]),
    ],
  )
}

///|
test "execute split errors" {
  guard (try? execute(parse_filter("split(\",\")"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "split input and separator must be strings" else {
    fail("expected split input type error")
  }
  guard (try? execute(parse_filter("split(1)"), must_parse("\"a\"")))
    is Err(err) &&
    err.to_string() == "split input and separator must be strings" else {
    fail("expected split separator type error")
  }
  guard (try? execute(parse_filter("split(\",\"; 1)"), must_parse("\"a\"")))
    is Err(err) &&
    err.to_string() == "split flags must be a string or null" else {
    fail("expected split flags type error")
  }
  guard (try? execute(parse_filter("splits(1)"), must_parse("\"a\"")))
    is Err(err) &&
    err.to_string() == "splits input and separator must be strings" else {
    fail("expected splits separator type error")
  }
}

///|
test "execute combinations/date/env/stream compatibility" {
  assert_eq(
    must_execute(parse_filter("combinations"), must_parse("[[1,2], [3,4]]")),
    [
      Json::array([Json::number(1.0), Json::number(3.0)]),
      Json::array([Json::number(1.0), Json::number(4.0)]),
      Json::array([Json::number(2.0), Json::number(3.0)]),
      Json::array([Json::number(2.0), Json::number(4.0)]),
    ],
  )
  assert_eq(
    must_execute(parse_filter("combinations(2)"), must_parse("[0,1]")),
    [
      Json::array([Json::number(0.0), Json::number(0.0)]),
      Json::array([Json::number(0.0), Json::number(1.0)]),
      Json::array([Json::number(1.0), Json::number(0.0)]),
      Json::array([Json::number(1.0), Json::number(1.0)]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("fromdate"),
      must_parse("\"2015-03-05T23:51:47Z\""),
    ),
    [Json::number(1425599507.0)],
  )
  assert_eq(must_execute(parse_filter("env.PAGER"), must_parse("null")), [
    Json::null(),
  ])
  assert_eq(
    must_execute(
      parse_filter("truncate_stream([[0],\"a\"],[[1,0],\"b\"],[[1,0]],[[1]])"),
      must_parse("1"),
    ),
    [
      Json::array([Json::array([Json::number(0.0)]), Json::string("b")]),
      Json::array([Json::array([Json::number(0.0)])]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "fromstream(1|truncate_stream([[0],\"a\"],[[1,0],\"b\"],[[1,0]],[[1]]))",
      ),
      must_parse("null"),
    ),
    [Json::array([Json::string("b")])],
  )
  assert_eq(
    must_execute(
      parse_filter(". as $dot|fromstream($dot|tostream)|.==$dot"),
      must_parse("[0,[1,{\"a\":1},{\"b\":2}]]"),
    ),
    [Json::boolean(true)],
  )
}

///|
test "execute explode/implode compatibility" {
  assert_eq(must_execute(parse_filter("explode"), must_parse("\"abc\"")), [
    Json::array([Json::number(97.0), Json::number(98.0), Json::number(99.0)]),
  ])
  assert_eq(must_execute(parse_filter("explode"), must_parse("\"あ\"")), [
    Json::array([Json::number(12354.0)]),
  ])
  assert_eq(must_execute(parse_filter("implode"), must_parse("[97,98,99]")), [
    Json::string("abc"),
  ])
  assert_eq(must_execute(parse_filter("implode"), must_parse("[12354]")), [
    Json::string("あ"),
  ])
  assert_eq(must_execute(parse_filter("implode"), must_parse("[]")), [
    Json::string(""),
  ])
  assert_eq(must_execute(parse_filter("implode"), must_parse("[-1]")), [
    Json::string("\u{fffd}"),
  ])
  assert_eq(must_execute(parse_filter("implode"), must_parse("[97.9]")), [
    Json::string("a"),
  ])
}

///|
test "execute explode/implode errors" {
  guard (try? execute(parse_filter("explode"), must_parse("1"))) is Err(err) &&
    err.to_string() == "explode input must be a string" else {
    fail("expected explode input type error")
  }
  guard (try? execute(parse_filter("implode"), must_parse("1"))) is Err(err) &&
    err.to_string() == "implode input must be an array" else {
    fail("expected implode input type error")
  }
  guard (try? execute(parse_filter("implode"), must_parse("[\"a\"]")))
    is Err(err) &&
    err.to_string() ==
    "string (\"a\") can't be imploded, unicode codepoint needs to be numeric" else {
    fail("expected implode element type error")
  }
  guard (try? execute(parse_filter("[nan] | implode"), must_parse("null")))
    is Err(err) &&
    err.to_string() ==
    "number (null) can't be imploded, unicode codepoint needs to be numeric" else {
    fail("expected implode NaN type error")
  }
}

///|
test "execute index/rindex/indices compatibility" {
  assert_eq(
    must_execute(parse_filter("index(\"l\")"), must_parse("\"hello\"")),
    [Json::number(2.0)],
  )
  assert_eq(
    must_execute(parse_filter("rindex(\"l\")"), must_parse("\"hello\"")),
    [Json::number(3.0)],
  )
  assert_eq(
    must_execute(parse_filter("indices(\"l\")"), must_parse("\"hello\"")),
    [Json::array([Json::number(2.0), Json::number(3.0)])],
  )
  assert_eq(
    must_execute(parse_filter("index(\"z\")"), must_parse("\"hello\"")),
    [Json::null()],
  )
  assert_eq(
    must_execute(parse_filter("indices(\"z\")"), must_parse("\"hello\"")),
    [Json::array([])],
  )
  assert_eq(
    must_execute(parse_filter("indices(\"aa\")"), must_parse("\"aaa\"")),
    [Json::array([Json::number(0.0), Json::number(1.0)])],
  )
  assert_eq(
    must_execute(parse_filter("indices(\"o\")"), must_parse("\"🇬🇧oo\"")),
    [Json::array([Json::number(2.0), Json::number(3.0)])],
  )
  assert_eq(
    must_execute(parse_filter("index((\"l\",\"e\"))"), must_parse("\"hello\"")),
    [Json::number(2.0), Json::number(1.0)],
  )
  assert_eq(
    must_execute(parse_filter("index(empty)"), must_parse("\"hello\"")),
    [],
  )
  let arr = must_parse("[1,2,1,3]")
  assert_eq(must_execute(parse_filter("index(1)"), arr), [Json::number(0.0)])
  assert_eq(must_execute(parse_filter("rindex(1)"), arr), [Json::number(2.0)])
  assert_eq(must_execute(parse_filter("indices(1)"), arr), [
    Json::array([Json::number(0.0), Json::number(2.0)]),
  ])
  assert_eq(must_execute(parse_filter("index([1,3])"), arr), [Json::number(2.0)])
  assert_eq(must_execute(parse_filter("indices([1,3])"), arr), [
    Json::array([Json::number(2.0)]),
  ])
  assert_eq(must_execute(parse_filter("index(\"1\")"), must_parse("[1,2]")), [
    Json::null(),
  ])
  assert_eq(must_execute(parse_filter("indices([])"), must_parse("[1,2,3]")), [
    Json::array([]),
  ])
}

///|
test "execute index/rindex/indices errors" {
  guard (try? execute(parse_filter("index(1)"), must_parse("\"hello\"")))
    is Err(err) &&
    err.to_string() == "Cannot index string with number" else {
    fail("expected string index(number) type error")
  }
  guard (try? execute(parse_filter("index(true)"), must_parse("\"hello\"")))
    is Err(err) &&
    err.to_string() == "Cannot index string with boolean" else {
    fail("expected string index(boolean) type error")
  }
  guard (try? execute(parse_filter("index(\"a\")"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "Cannot index number with string \"a\"" else {
    fail("expected number index(string) type error")
  }
}

///|
test "execute bsearch compatibility" {
  assert_eq(must_execute(parse_filter("bsearch(1)"), must_parse("[1,3,5]")), [
    Json::number(0.0),
  ])
  assert_eq(must_execute(parse_filter("bsearch(2)"), must_parse("[1,3,5]")), [
    Json::number(-2.0),
  ])
  assert_eq(must_execute(parse_filter("bsearch(5)"), must_parse("[1,3,5]")), [
    Json::number(2.0),
  ])
  assert_eq(must_execute(parse_filter("bsearch(6)"), must_parse("[1,3,5]")), [
    Json::number(-4.0),
  ])
  assert_eq(must_execute(parse_filter("bsearch(0)"), must_parse("[1,3,5]")), [
    Json::number(-1.0),
  ])
  assert_eq(must_execute(parse_filter("bsearch(1)"), must_parse("[]")), [
    Json::number(-1.0),
  ])
  assert_eq(must_execute(parse_filter("bsearch(1)"), must_parse("[1,1,1]")), [
    Json::number(1.0),
  ])
  assert_eq(
    must_execute(parse_filter("bsearch((2,5))"), must_parse("[1,3,5]")),
    [Json::number(-2.0), Json::number(2.0)],
  )
  assert_eq(
    must_execute(parse_filter("bsearch(empty)"), must_parse("[1,3,5]")),
    [],
  )
  assert_eq(
    must_execute(
      parse_filter("bsearch(\"a\")"),
      must_parse("[null,false,true,1,\"a\",[],{}]"),
    ),
    [Json::number(4.0)],
  )
  assert_eq(must_execute(parse_filter("bsearch([2])"), must_parse("[1,3,5]")), [
    Json::number(-4.0),
  ])
}

///|
test "execute range/limit/skip/IN compatibility" {
  let null_json = must_parse("null")
  assert_eq(must_execute(parse_filter("[range(0;10)]"), null_json), [
    Json::array([
      Json::number(0.0),
      Json::number(1.0),
      Json::number(2.0),
      Json::number(3.0),
      Json::number(4.0),
      Json::number(5.0),
      Json::number(6.0),
      Json::number(7.0),
      Json::number(8.0),
      Json::number(9.0),
    ]),
  ])
  assert_eq(must_execute(parse_filter("[range(0;10;3)]"), null_json), [
    Json::array([
      Json::number(0.0),
      Json::number(3.0),
      Json::number(6.0),
      Json::number(9.0),
    ]),
  ])
  assert_eq(must_execute(parse_filter("[range(3,5)]"), null_json), [
    Json::array([
      Json::number(0.0),
      Json::number(1.0),
      Json::number(2.0),
      Json::number(0.0),
      Json::number(1.0),
      Json::number(2.0),
      Json::number(3.0),
      Json::number(4.0),
    ]),
  ])

  assert_eq(
    must_execute(
      parse_filter("[limit(3; .[])]"),
      must_parse("[11,22,33,44,55,66,77,88,99]"),
    ),
    [Json::array([Json::number(11.0), Json::number(22.0), Json::number(33.0)])],
  )
  assert_eq(must_execute(parse_filter("[limit(0; error)]"), null_json), [
    Json::array([]),
  ])
  assert_eq(
    must_execute(parse_filter("[limit(1; 1,error(\"foo\"))]"), null_json),
    [Json::array([Json::number(1.0)])],
  )

  assert_eq(
    must_execute(
      parse_filter("[skip(3; .[])]"),
      must_parse("[1,2,3,4,5,6,7,8,9]"),
    ),
    [
      Json::array([
        Json::number(4.0),
        Json::number(5.0),
        Json::number(6.0),
        Json::number(7.0),
        Json::number(8.0),
        Json::number(9.0),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("[skip(0,2,3,4; .[])]"),
      must_parse("[1,2,3,4,5,6,7,8,9]"),
    ),
    [
      Json::array([
        Json::number(1.0),
        Json::number(2.0),
        Json::number(3.0),
        Json::number(4.0),
        Json::number(5.0),
        Json::number(6.0),
        Json::number(7.0),
        Json::number(8.0),
        Json::number(9.0),
        Json::number(3.0),
        Json::number(4.0),
        Json::number(5.0),
        Json::number(6.0),
        Json::number(7.0),
        Json::number(8.0),
        Json::number(9.0),
        Json::number(4.0),
        Json::number(5.0),
        Json::number(6.0),
        Json::number(7.0),
        Json::number(8.0),
        Json::number(9.0),
        Json::number(5.0),
        Json::number(6.0),
        Json::number(7.0),
        Json::number(8.0),
        Json::number(9.0),
      ]),
    ],
  )

  assert_eq(
    must_execute(parse_filter("range(5;10)|IN(range(10))"), null_json),
    [
      Json::boolean(true),
      Json::boolean(true),
      Json::boolean(true),
      Json::boolean(true),
      Json::boolean(true),
    ],
  )
  assert_eq(
    must_execute(parse_filter("IN(range(10;20); range(10))"), null_json),
    [Json::boolean(false)],
  )
  assert_eq(
    must_execute(parse_filter("IN(range(5;20); range(10))"), null_json),
    [Json::boolean(true)],
  )
  assert_eq(
    must_execute(
      parse_filter("INDEX(range(5)|[., \"foo\\(.)\"]; .[0])"),
      null_json,
    ),
    [
      Json::object({
        "0": Json::array([Json::number(0.0), Json::string("foo0")]),
        "1": Json::array([Json::number(1.0), Json::string("foo1")]),
        "2": Json::array([Json::number(2.0), Json::string("foo2")]),
        "3": Json::array([Json::number(3.0), Json::string("foo3")]),
        "4": Json::array([Json::number(4.0), Json::string("foo4")]),
      }),
    ],
  )
}

///|
test "execute range/limit/skip/nth stream errors" {
  let null_json = must_parse("null")
  guard (try? execute(parse_filter("limit(-1; .[])"), must_parse("[1,2,3]")))
    is Err(err) &&
    err.to_string() == "limit doesn't support negative count" else {
    fail("expected limit negative count error")
  }
  guard (try? execute(parse_filter("skip(-1; .[])"), must_parse("[1,2,3]")))
    is Err(err) &&
    err.to_string() == "skip doesn't support negative count" else {
    fail("expected skip negative count error")
  }
  guard (try? execute(parse_filter("nth(-1; range(10))"), null_json))
    is Err(err) &&
    err.to_string() == "nth doesn't support negative indices" else {
    fail("expected nth negative index error")
  }
}

///|
test "execute bsearch errors" {
  guard (try? execute(parse_filter("bsearch(1)"), must_parse("1"))) is Err(err) &&
    err.to_string() == "number (1) cannot be searched from" else {
    fail("expected bsearch number input error")
  }
  guard (try? execute(parse_filter("bsearch(1)"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "null (null) cannot be searched from" else {
    fail("expected bsearch null input error")
  }
  guard (try? execute(parse_filter("bsearch(1)"), must_parse("\"a\"")))
    is Err(err) &&
    err.to_string() == "string (\"a\") cannot be searched from" else {
    fail("expected bsearch string input error")
  }
  guard (try? execute(parse_filter("bsearch(1)"), must_parse("{}"))) is Err(err) &&
    err.to_string() == "object ({}) cannot be searched from" else {
    fail("expected bsearch object input error")
  }
  guard (try? execute(parse_filter("bsearch(1)"), must_parse("true")))
    is Err(err) &&
    err.to_string() == "boolean (true) cannot be searched from" else {
    fail("expected bsearch boolean input error")
  }
  assert_eq(must_execute(parse_filter("bsearch(empty)"), must_parse("1")), [])
}

///|
test "execute select" {
  let j = must_parse("{\"a\":1,\"b\":null}")
  let f1 = parse_filter("select(.a)")
  let f2 = parse_filter("select(.b)")
  assert_eq(must_execute(f1, j), [j])
  assert_eq(must_execute(f2, j), [])
}

///|
test "execute select stream compatibility" {
  let j = must_parse("1")
  assert_eq(must_execute(parse_filter("select((false,true,true))"), j), [j, j])
  assert_eq(must_execute(parse_filter("select((false,false))"), j), [])
  assert_eq(must_execute(parse_filter("select(empty)"), j), [])
}

///|
test "execute compare" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  let f1 = parse_filter(".a == 1")
  let f2 = parse_filter(".a != .b")
  assert_eq(must_execute(f1, j), [Json::boolean(true)])
  assert_eq(must_execute(f2, j), [Json::boolean(true)])
}

///|
test "execute compare stream cross product" {
  let j = must_parse("null")
  assert_eq(must_execute(parse_filter("(1,2) == (1,2)"), j), [
    Json::boolean(true),
    Json::boolean(false),
    Json::boolean(false),
    Json::boolean(true),
  ])
  assert_eq(must_execute(parse_filter("(empty) == 1"), j), [])
}

///|
test "execute compare order and logical" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  assert_eq(must_execute(parse_filter(".a < .b"), j), [Json::boolean(true)])
  assert_eq(must_execute(parse_filter(".a >= .b"), j), [Json::boolean(false)])
  assert_eq(must_execute(parse_filter(". > .00005"), must_parse("0.0001")), [
    Json::boolean(true),
  ])
  assert_eq(must_execute(parse_filter(". > .00005"), must_parse("0.0")), [
    Json::boolean(false),
  ])
  assert_eq(must_execute(parse_filter(".a and .b"), j), [Json::boolean(true)])
  assert_eq(must_execute(parse_filter("not .b"), j), [Json::boolean(false)])
  assert_eq(must_execute(parse_filter(".a or .b"), j), [Json::boolean(true)])
  let n = must_parse("null")
  assert_eq(must_execute(parse_filter("(true, false) or false"), n), [
    Json::boolean(true),
    Json::boolean(false),
  ])
  assert_eq(must_execute(parse_filter("(true, true) and (true, false)"), n), [
    Json::boolean(true),
    Json::boolean(false),
    Json::boolean(true),
    Json::boolean(false),
  ])
  assert_eq(must_execute(parse_filter("not (true,false)"), n), [
    Json::boolean(false),
    Json::boolean(true),
  ])
}

///|
test "execute arithmetic" {
  let j = must_parse("{\"a\":1,\"b\":2,\"c\":3}")
  assert_eq(must_execute(parse_filter(".a + .b"), j), [Json::number(3.0)])
  assert_eq(must_execute(parse_filter(".c - .a"), j), [Json::number(2.0)])
  assert_eq(must_execute(parse_filter(".a * .b"), j), [Json::number(2.0)])
  assert_eq(must_execute(parse_filter(".c / .a"), j), [Json::number(3.0)])
  assert_eq(must_execute(parse_filter("\"a,b,c\" / \",\""), j), [
    Json::array([Json::string("a"), Json::string("b"), Json::string("c")]),
  ])
  assert_eq(must_execute(parse_filter("\"a, b,c,d, e\" / \", \""), j), [
    Json::array([Json::string("a"), Json::string("b,c,d"), Json::string("e")]),
  ])
  assert_eq(must_execute(parse_filter("10 % 3"), j), [Json::number(1.0)])
  assert_eq(
    must_execute(parse_filter("[(infinite, -infinite) % (1, -1, infinite)]"), j),
    [
      Json::array([
        Json::number(0.0),
        Json::number(0.0),
        Json::number(0.0),
        Json::number(0.0),
        Json::number(0.0),
        Json::number(-1.0),
      ]),
    ],
  )
  assert_eq(must_execute(parse_filter("(1 / 1e-17) | tojson"), j), [
    Json::string("1e+17"),
  ])
  assert_eq(
    must_execute(
      parse_filter(
        "(9E999999999|tojson), (9999999999E999999990|tojson), (1E-999999999|tojson), (0.000000001E-999999990|tojson)",
      ),
      j,
    ),
    [
      Json::string("1.7976931348623157e+308"),
      Json::string("1.7976931348623157e+308"),
      Json::string("0"),
      Json::string("0"),
    ],
  )
  assert_eq(must_execute(parse_filter("-."), must_parse("3")), [
    Json::number(-3.0),
  ])
  let inf_out = must_execute(parse_filter(". + 1"), must_parse("1e309"))
  assert_eq(inf_out.length(), 1)
  assert_eq(inf_out[0].to_json_string(), "1.7976931348623157e+308")
  let nan_out = must_execute(parse_filter(". - ."), must_parse("1e309"))
  assert_eq(nan_out.length(), 1)
  assert_eq(nan_out[0].to_json_string(), "null")
  let null_input = must_parse("null")
  let literal_inf_out = must_execute(parse_filter("1e309 + 1"), null_input)
  assert_eq(literal_inf_out.length(), 1)
  assert_eq(literal_inf_out[0].to_json_string(), "1.7976931348623157e+308")
  let literal_nan_out = must_execute(parse_filter("1e309 - 1e309"), null_input)
  assert_eq(literal_nan_out.length(), 1)
  assert_eq(literal_nan_out[0].to_json_string(), "null")
}

///|
test "execute multiply compatibility" {
  let j = must_parse("null")
  assert_eq(must_execute(parse_filter("\"ab\" * 2"), j), [Json::string("abab")])
  assert_eq(must_execute(parse_filter("2 * \"ab\""), j), [Json::string("abab")])
  assert_eq(must_execute(parse_filter("\"ab\" * 2.9"), j), [
    Json::string("abab"),
  ])
  assert_eq(must_execute(parse_filter("\"ab\" * 0"), j), [Json::string("")])
  assert_eq(must_execute(parse_filter("\"ab\" * -1"), j), [Json::null()])
  assert_eq(
    must_execute(parse_filter("{\"a\":{\"x\":1}} * {\"a\":{\"y\":2}}"), j),
    [
      Json::object({
        "a": Json::object({ "x": Json::number(1.0), "y": Json::number(2.0) }),
      }),
    ],
  )
  assert_eq(must_execute(parse_filter("{\"a\":{\"x\":1}} * {\"a\":2}"), j), [
    Json::object({ "a": Json::number(2.0) }),
  ])
  assert_eq(must_execute(parse_filter("{\"a\":1} * {\"b\":2}"), j), [
    Json::object({ "a": Json::number(1.0), "b": Json::number(2.0) }),
  ])
}

///|
test "execute multiply repeat too long error" {
  let j = must_parse("null")
  guard (try? execute(parse_filter("\"x\" * 1000000000000"), j)) is Err(err) &&
    err.to_string() == "Repeat string result too long" else {
    fail("expected repeat-too-long error")
  }
}

///|
test "execute array subtraction compatibility" {
  let j = must_parse("null")
  assert_eq(must_execute(parse_filter("[1,2,2,3] - [2]"), j), [
    Json::array([Json::number(1.0), Json::number(3.0)]),
  ])
  assert_eq(must_execute(parse_filter("[1,{\"a\":1}] - [{\"a\":1}]"), j), [
    Json::array([Json::number(1.0)]),
  ])
}

///|
test "execute division by zero compatibility" {
  let j = must_parse("null")
  guard (try? execute(parse_filter("1 / 0"), j)) is Err(err) &&
    err.to_string() ==
    "number (1) and number (0) cannot be divided because the divisor is zero" else {
    fail("expected jq-compatible division by zero error")
  }
  guard (try? execute(parse_filter("1 % 0"), j)) is Err(err) &&
    err.to_string() ==
    "number (1) and number (0) cannot be divided (remainder) because the divisor is zero" else {
    fail("expected jq-compatible modulo by zero error")
  }
}

///|
test "execute arithmetic stream cross product" {
  let j = must_parse("null")
  assert_eq(must_execute(parse_filter("(1,2) + (10,20)"), j), [
    Json::number(11.0),
    Json::number(12.0),
    Json::number(21.0),
    Json::number(22.0),
  ])
  assert_eq(must_execute(parse_filter("(empty) + 1"), j), [])
}

///|
test "execute add arrays and objects" {
  let j = must_parse("{\"a\":[1],\"b\":[2],\"x\":{\"k\":1},\"y\":{\"k\":2}}")
  assert_eq(must_execute(parse_filter(".a + .b"), j), [
    Json::array([Json::number(1.0), Json::number(2.0)]),
  ])
  assert_eq(must_execute(parse_filter(".x + .y"), j), [
    Json::object({ "k": Json::number(2.0) }),
  ])
}

///|
test "execute add null identity compatibility" {
  let j = must_parse("null")
  assert_eq(must_execute(parse_filter("null + 1"), j), [Json::number(1.0)])
  assert_eq(must_execute(parse_filter("1 + null"), j), [Json::number(1.0)])
  assert_eq(must_execute(parse_filter("null + null"), j), [Json::null()])
  assert_eq(must_execute(parse_filter("true + null"), j), [Json::boolean(true)])
  assert_eq(must_execute(parse_filter("null + [1]"), j), [
    Json::array([Json::number(1.0)]),
  ])
  assert_eq(must_execute(parse_filter("{\"a\":1} + null"), j), [
    Json::object({ "a": Json::number(1.0) }),
  ])
}

///|
test "execute update assignment compatibility" {
  let obj = must_parse("{\"a\":1,\"b\":2}")
  assert_eq(must_execute(parse_filter(".a |= . + 1"), obj), [
    Json::object({ "a": Json::number(2.0), "b": Json::number(2.0) }),
  ])
  assert_eq(must_execute(parse_filter(".a += 4"), must_parse("{\"a\":1}")), [
    Json::object({ "a": Json::number(5.0) }),
  ])
  assert_eq(
    must_execute(parse_filter(".a //= 9"), must_parse("{\"a\":null}")),
    [Json::object({ "a": Json::number(9.0) })],
  )
  assert_eq(must_execute(parse_filter(".[1] *= 10"), must_parse("[1,2,3]")), [
    Json::array([Json::number(1.0), Json::number(20.0), Json::number(3.0)]),
  ])
  assert_eq(
    must_execute(parse_filter(".a.b |= . + 1"), must_parse("{\"a\":{\"b\":1}}")),
    [Json::object({ "a": Json::object({ "b": Json::number(2.0) }) })],
  )
  assert_eq(
    must_execute(parse_filter(".a.b //= 9"), must_parse("{\"a\":{}}")),
    [Json::object({ "a": Json::object({ "b": Json::number(9.0) }) })],
  )
  assert_eq(must_execute(parse_filter(".[2] += 5"), must_parse("[]")), [
    Json::array([Json::null(), Json::null(), Json::number(5.0)]),
  ])
  assert_eq(must_execute(parse_filter(".[-1] += 1"), must_parse("[1,2,3]")), [
    Json::array([Json::number(1.0), Json::number(2.0), Json::number(4.0)]),
  ])
  assert_eq(must_execute(parse_filter(".a = 9"), must_parse("{\"a\":1}")), [
    Json::object({ "a": Json::number(9.0) }),
  ])
  assert_eq(
    must_execute(parse_filter(".foo = .bar"), must_parse("{\"bar\":42}")),
    [Json::object({ "bar": Json::number(42.0), "foo": Json::number(42.0) })],
  )
  assert_eq(
    must_execute(
      parse_filter(".a = .b"),
      must_parse("{\"a\":{\"b\":10},\"b\":20}"),
    ),
    [Json::object({ "a": Json::number(20.0), "b": Json::number(20.0) })],
  )
  assert_eq(
    must_execute(parse_filter(".foo += .foo"), must_parse("{\"foo\":2}")),
    [Json::object({ "foo": Json::number(4.0) })],
  )
  assert_eq(
    must_execute(parse_filter("(.a,.b) = range(3)"), must_parse("null")),
    [
      Json::object({ "a": Json::number(0.0), "b": Json::number(0.0) }),
      Json::object({ "a": Json::number(1.0), "b": Json::number(1.0) }),
      Json::object({ "a": Json::number(2.0), "b": Json::number(2.0) }),
    ],
  )
  assert_eq(
    must_execute(parse_filter("(.a,.b) |= range(3)"), must_parse("null")),
    [Json::object({ "a": Json::number(0.0), "b": Json::number(0.0) })],
  )
  assert_eq(
    must_execute(parse_filter("(.a,.b) += (1,2)"), must_parse("null")),
    [
      Json::object({ "a": Json::number(1.0), "b": Json::number(1.0) }),
      Json::object({ "a": Json::number(2.0), "b": Json::number(2.0) }),
    ],
  )
  assert_eq(must_execute(parse_filter(".[] += .[0]"), must_parse("[1,2]")), [
    Json::array([Json::number(2.0), Json::number(3.0)]),
  ])
  assert_eq(
    must_execute(
      parse_filter(
        "reduce range(65540;65536;-1) as $i ([]; .[$i] = $i)|.[65536:]",
      ),
      must_parse("null"),
    ),
    [
      Json::array([
        Json::null(),
        Json::number(65537.0),
        Json::number(65538.0),
        Json::number(65539.0),
        Json::number(65540.0),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("(.a as $x | .b) = \"b\""),
      must_parse("{\"a\":null,\"b\":null}"),
    ),
    [Json::object({ "a": Json::null(), "b": Json::string("b") })],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "bsearch(4) as $ix | if $ix < 0 then .[-(1+$ix)] = 4 else . end",
      ),
      must_parse("[1,2,3]"),
    ),
    [
      Json::array([
        Json::number(1.0),
        Json::number(2.0),
        Json::number(3.0),
        Json::number(4.0),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter(".[2:4] = ([], [\"a\",\"b\"], [\"a\",\"b\",\"c\"])"),
      must_parse("[0,1,2,3,4,5,6,7]"),
    ),
    [
      Json::array([
        Json::number(0.0),
        Json::number(1.0),
        Json::number(4.0),
        Json::number(5.0),
        Json::number(6.0),
        Json::number(7.0),
      ]),
      Json::array([
        Json::number(0.0),
        Json::number(1.0),
        Json::string("a"),
        Json::string("b"),
        Json::number(4.0),
        Json::number(5.0),
        Json::number(6.0),
        Json::number(7.0),
      ]),
      Json::array([
        Json::number(0.0),
        Json::number(1.0),
        Json::string("a"),
        Json::string("b"),
        Json::string("c"),
        Json::number(4.0),
        Json::number(5.0),
        Json::number(6.0),
        Json::number(7.0),
      ]),
    ],
  )
  guard (try? execute(parse_filter(".[1:3] = 9"), must_parse("[0,1,2,3]")))
    is Err(err) &&
    err.to_string() == "A slice of an array can only be assigned another array" else {
    fail("expected slice assignment array-only error")
  }
  assert_eq(
    must_execute(
      parse_filter("try (\"foobar\" | .[1.5:3.5] = \"xyz\") catch ."),
      must_parse("null"),
    ),
    [Json::string("Cannot update string slices")],
  )
  assert_eq(
    must_execute(
      parse_filter("try ([range(3)] | .[nan] = 9) catch ."),
      must_parse("null"),
    ),
    [Json::string("Cannot set array element at NaN index")],
  )
  assert_eq(
    must_execute(
      parse_filter("try ([range(10)] | .[1.5:3.5] = [\"xyz\"]) catch ."),
      must_parse("null"),
    ),
    [
      Json::array([
        Json::number(0.0),
        Json::string("xyz"),
        Json::number(4.0),
        Json::number(5.0),
        Json::number(6.0),
        Json::number(7.0),
        Json::number(8.0),
        Json::number(9.0),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("(.[] | select(. >= 2)) |= empty"),
      must_parse("[1,5,3,0,7]"),
    ),
    [Json::array([Json::number(1.0), Json::number(0.0)])],
  )
  assert_eq(
    must_execute(
      parse_filter(".[] |= select(. % 2 == 0)"),
      must_parse("[0,1,2,3,4,5]"),
    ),
    [Json::array([Json::number(0.0), Json::number(2.0), Json::number(4.0)])],
  )
  assert_eq(
    must_execute(
      parse_filter(".foo[1,4,2,3] |= empty"),
      must_parse("{\"foo\":[0,1,2,3,4,5]}"),
    ),
    [
      Json::object({
        "foo": Json::array([Json::number(0.0), Json::number(5.0)]),
      }),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter(".[] |= try tonumber"),
      must_parse(
        "[\"1\", \"2a\", \"3\", \" 4\", \"5 \", \"6.7\", \".89\", \"-876\", \"+5.43\", 21]",
      ),
    ),
    [
      Json::array([
        Json::number(1.0),
        Json::number(3.0),
        Json::number(6.7),
        Json::number(0.89),
        Json::number(-876.0),
        Json::number(5.43),
        Json::number(21.0),
      ]),
    ],
  )
  assert_eq(must_execute(parse_filter(".a %= 4"), must_parse("{\"a\":9}")), [
    Json::object({ "a": Json::number(1.0) }),
  ])
}

///|
test "execute object literal stream product" {
  let j = must_parse("null")
  assert_eq(must_execute(parse_filter("{a:(1,2)}"), j), [
    Json::object({ "a": Json::number(1.0) }),
    Json::object({ "a": Json::number(2.0) }),
  ])
  assert_eq(must_execute(parse_filter("{a:(1,2), b:(3,4)}"), j), [
    Json::object({ "a": Json::number(1.0), "b": Json::number(3.0) }),
    Json::object({ "a": Json::number(1.0), "b": Json::number(4.0) }),
    Json::object({ "a": Json::number(2.0), "b": Json::number(3.0) }),
    Json::object({ "a": Json::number(2.0), "b": Json::number(4.0) }),
  ])
  assert_eq(must_execute(parse_filter("{a:(empty)}"), j), [])
}

///|
test "execute map" {
  let j = must_parse("[1,2,3]")
  assert_eq(must_execute(parse_filter("map(. + 1)"), j), [
    Json::array([Json::number(2.0), Json::number(3.0), Json::number(4.0)]),
  ])
}

///|
test "execute map object compatibility" {
  let j = must_parse("{\"a\":1}")
  assert_eq(must_execute(parse_filter("map(. + 1)"), j), [
    Json::array([Json::number(2.0)]),
  ])
  assert_eq(must_execute(parse_filter("map((., . + 1))"), j), [
    Json::array([Json::number(1.0), Json::number(2.0)]),
  ])
  assert_eq(must_execute(parse_filter("map(select(. > 1))"), j), [
    Json::array([]),
  ])
}

///|
test "execute map iter errors" {
  guard (try? execute(parse_filter("map(. + 1)"), must_parse("1"))) is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected map number error")
  }
  guard (try? execute(parse_filter("map(. + 1)"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "Cannot iterate over null (null)" else {
    fail("expected map null error")
  }
}

///|
test "execute map_values jq semantics" {
  let obj = must_parse("{\"a\":1,\"b\":2}")
  assert_eq(must_execute(parse_filter("map_values(select(. > 1))"), obj), [
    Json::object({ "b": Json::number(2.0) }),
  ])
  assert_eq(must_execute(parse_filter("map_values((., . + 1))"), obj), [
    Json::object({ "a": Json::number(1.0), "b": Json::number(2.0) }),
  ])
  let arr = must_parse("[1,2,3]")
  assert_eq(must_execute(parse_filter("map_values(. + 1)"), arr), [
    Json::array([Json::number(2.0), Json::number(3.0), Json::number(4.0)]),
  ])
  assert_eq(must_execute(parse_filter("map_values(select(. > 1))"), arr), [
    Json::array([Json::number(2.0), Json::number(3.0)]),
  ])
  assert_eq(must_execute(parse_filter("map_values((., . + 1))"), arr), [
    Json::array([Json::number(1.0), Json::number(2.0), Json::number(3.0)]),
  ])
}

///|
test "execute map_values iter errors" {
  guard (try? execute(parse_filter("map_values(. + 1)"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "Cannot iterate over number (1)" else {
    fail("expected map_values number error")
  }
  guard (try? execute(parse_filter("map_values(. + 1)"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "Cannot iterate over null (null)" else {
    fail("expected map_values null error")
  }
}

///|
test "execute as and variable" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  assert_eq(must_execute(parse_filter(".a as $x | $x"), j), [Json::number(1.0)])
  assert_eq(must_execute(parse_filter(".a as $x | .b"), j), [Json::number(2.0)])
  assert_eq(must_execute(parse_filter(".a as $x | $x + 1"), j), [
    Json::number(2.0),
  ])
  assert_eq(
    must_execute(parse_filter(". as $x | $x[]"), must_parse("[1,2,3]")),
    [Json::number(1.0), Json::number(2.0), Json::number(3.0)],
  )
  assert_eq(
    must_execute(parse_filter("[-1 as $x | 1,$x]"), must_parse("null")),
    [Json::array([Json::number(1.0), Json::number(-1.0)])],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "[\"foo\",1] as $p | getpath($p), setpath($p; 20), delpaths([$p])",
      ),
      must_parse("{\"bar\":42, \"foo\":[\"a\", \"b\", \"c\", \"d\"]}"),
    ),
    [
      Json::string("b"),
      must_parse("{\"bar\":42,\"foo\":[\"a\",20,\"c\",\"d\"]}"),
      must_parse("{\"bar\":42,\"foo\":[\"a\",\"c\",\"d\"]}"),
    ],
  )
}

///|
test "execute as pattern bindings" {
  assert_eq(
    must_execute(
      parse_filter(".[] as [$a,$b] | [$b,$a]"),
      must_parse("[[1],[1,2,3]]"),
    ),
    [
      Json::array([Json::null(), Json::number(1.0)]),
      Json::array([Json::number(2.0), Json::number(1.0)]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter(". as {$a, $b:[$c,$d]} | [$a, $b, $c, $d]"),
      must_parse("{\"a\":1,\"b\":[2,{\"d\":3}]}"),
    ),
    [must_parse("[1,[2,{\"d\":3}],2,{\"d\":3}]")],
  )
  assert_eq(
    must_execute(
      parse_filter(".[] | . as {a:$a} ?// [$a] | $a"),
      must_parse("[{\"a\":1},[2]]"),
    ),
    [Json::number(1.0), Json::number(2.0)],
  )
  assert_eq(
    must_execute(
      parse_filter("[1, {c:3, d:4}] as [$a, {c:$b, b:$c}] | $a, $b, $c"),
      must_parse("null"),
    ),
    [Json::number(1.0), Json::number(3.0), Json::null()],
  )
  assert_eq(
    must_execute(
      parse_filter(
        ".[] as [$a] ?// [$b] | if $a != null then error(\"err: \\($a)\") else {$a,$b} end",
      ),
      must_parse("[[3]]"),
    ),
    [must_parse("{\"a\":null,\"b\":3}")],
  )
  assert_eq(
    must_execute(
      parse_filter(
        ".[] | . as {$a, b: [$c, {$d}]} ?// [$a, {$b}, $e] ?// $f | [$a, $b, $c, $d, $e, $f]",
      ),
      must_parse(
        "[{\"a\":1, \"b\":[2,{\"d\":3}]}, [4, {\"b\":5, \"c\":6}, 7, 8, 9], \"foo\"]",
      ),
    ),
    [
      must_parse("[1,null,2,3,null,null]"),
      must_parse("[4,5,null,null,7,null]"),
      must_parse("[null,null,null,null,null,\"foo\"]"),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter(". as {(\"e\"+\"x\"+\"p\"):$exp} | $exp"),
      must_parse("{\"exp\":3}"),
    ),
    [Json::number(3.0)],
  )
}

///|
test "execute special variables compatibility" {
  assert_eq(must_execute(parse_filter("$ENV.PAGER"), must_parse("null")), [
    Json::null(),
  ])
  assert_eq(
    must_execute(
      parse_filter("{ a, $__loc__, c }"),
      must_parse("{\"a\":[1,2,3],\"b\":\"foo\",\"c\":{\"hi\":\"hey\"}}"),
    ),
    [
      must_parse(
        "{\"a\":[1,2,3],\"__loc__\":{\"file\":\"<top-level>\",\"line\":1},\"c\":{\"hi\":\"hey\"}}",
      ),
    ],
  )
}

///|
test "execute dynamic bracket index" {
  assert_eq(
    must_execute(
      parse_filter(".foo[.baz]"),
      must_parse("{\"foo\":{\"bar\":4},\"baz\":\"bar\"}"),
    ),
    [Json::number(4.0)],
  )
  assert_eq(
    must_execute(
      parse_filter("[1,2,3][] as $x | [4,5,6,7][$x]"),
      must_parse("null"),
    ),
    [Json::number(5.0), Json::number(6.0), Json::number(7.0)],
  )
  assert_eq(
    must_execute(parse_filter("[][.]"), must_parse("1000000000000000000")),
    [Json::null()],
  )
  assert_eq(
    must_execute(parse_filter("[range(5)] | .[1.1]"), must_parse("null")),
    [Json::number(1.0)],
  )
}

///|
test "execute try" {
  let j = must_parse("{\"a\":\"hi\"}")
  assert_eq(must_execute(parse_filter("(.a + 1)?"), j), [])
  assert_eq(must_execute(parse_filter("(.a | .b)?"), j), [])
}

///|
test "execute try/catch" {
  let j = must_parse("{\"a\":\"hi\",\"b\":1}")
  assert_eq(must_execute(parse_filter("try .a catch .b"), j), [
    Json::string("hi"),
  ])
  assert_eq(must_execute(parse_filter("try (.a + 1) catch ."), j), [
    Json::string("string (\"hi\") and number (1) cannot be added"),
  ])
  assert_eq(
    must_execute(parse_filter("try error(\"boom\") catch (. + \"!\")"), j),
    [Json::string("boom!")],
  )
  assert_eq(
    must_execute(parse_filter("try 2 catch 3 + 4"), must_parse("null")),
    [Json::number(6.0)],
  )
  assert_eq(
    must_execute(parse_filter("1 + try 2 catch 3 + 4"), must_parse("null")),
    [Json::number(7.0)],
  )
  assert_eq(
    must_execute(
      parse_filter("1 + try error(0) catch 3 + 4"),
      must_parse("null"),
    ),
    [Json::number(8.0)],
  )
  assert_eq(
    must_execute(
      parse_filter("try (.[999999999] = 0) catch ."),
      must_parse("null"),
    ),
    [Json::string("Array index too large")],
  )
  guard (try? execute(parse_filter("try .a + 1"), j)) is Err(err) &&
    err.to_string() == "string (\"hi\") and number (1) cannot be added" else {
    fail("expected try precedence to match (try .a) + 1")
  }
  assert_eq(
    must_execute(
      parse_filter("try -. catch ."),
      must_parse("\"very-long-string\""),
    ),
    [Json::string("string (\"very-long-...) cannot be negated")],
  )
  assert_eq(
    must_execute(
      parse_filter("try (.-.) catch ."),
      must_parse("\"very-long-string\""),
    ),
    [
      Json::string(
        "string (\"very-long-...) and string (\"very-long-...) cannot be subtracted",
      ),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "try ([\"hi\",\"ho\"][] | if . == \"ho\" then error else . end) catch \"caught \\(.)\"",
      ),
      must_parse("null"),
    ),
    [Json::string("hi"), Json::string("caught ho")],
  )
  assert_eq(must_execute(parse_filter("[(.*2, error)?]"), must_parse("1")), [
    Json::array([Json::number(2.0)]),
  ])
  assert_eq(
    must_execute(parse_filter("[repeat(.*2, error)?]"), must_parse("1")),
    [Json::array([Json::number(2.0)])],
  )
}

///|
test "execute reduce/foreach" {
  let j = must_parse("[1,2,3]")
  assert_eq(must_execute(parse_filter("reduce .[] as $x (0; . + $x)"), j), [
    Json::number(6.0),
  ])
  assert_eq(must_execute(parse_filter("foreach .[] as $x (0; . + $x)"), j), [
    Json::number(1.0),
    Json::number(3.0),
    Json::number(6.0),
  ])
  assert_eq(must_execute(parse_filter("foreach .[] as $x (0; . + $x; .)"), j), [
    Json::number(1.0),
    Json::number(3.0),
    Json::number(6.0),
  ])
  assert_eq(
    must_execute(
      parse_filter("reduce .[] as [$i,$j] (0; . + $i * $j)"),
      must_parse("[[1,2],[3,4],[5,6]]"),
    ),
    [Json::number(44.0)],
  )
  assert_eq(
    must_execute(
      parse_filter("foreach .[] as [$i,$j] (0; . + $i * $j; [$i,$j,.])"),
      must_parse("[[1,2],[3,4]]"),
    ),
    [must_parse("[1,2,2]"), must_parse("[3,4,14]")],
  )
  assert_eq(
    must_execute(
      parse_filter("foreach .[] as $x (0, 1; . + $x)"),
      must_parse("[1,2]"),
    ),
    [Json::number(1.0), Json::number(3.0), Json::number(2.0), Json::number(4.0)],
  )
}

///|
test "execute if-then-else" {
  let j = must_parse("{\"a\":true,\"b\":1,\"c\":2}")
  assert_eq(must_execute(parse_filter("if .a then .b else .c end"), j), [
    Json::number(1.0),
  ])
  let j2 = must_parse("{\"a\":null,\"b\":1,\"c\":2}")
  assert_eq(must_execute(parse_filter("if .a then .b else .c end"), j2), [
    Json::number(2.0),
  ])
  let j3 = must_parse("{\"a\":false,\"c\":true,\"d\":3,\"e\":4}")
  assert_eq(
    must_execute(parse_filter("if .a then .b elif .c then .d else .e end"), j3),
    [Json::number(3.0)],
  )
  assert_eq(must_execute(parse_filter("if .a then .b end"), j2), [j2])
  assert_eq(
    must_execute(
      parse_filter("[if 1,null,2 then 3 else 4 end]"),
      must_parse("null"),
    ),
    [must_parse("[3,4,3]")],
  )
  assert_eq(
    must_execute(
      parse_filter("[if empty then 3 else 4 end]"),
      must_parse("null"),
    ),
    [Json::array([])],
  )
  assert_eq(
    must_execute(parse_filter("[if false then 3 end]"), must_parse("7")),
    [must_parse("[7]")],
  )
}

///|
test "execute fallback and empty" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  assert_eq(must_execute(parse_filter(".a // .b"), j), [Json::number(1.0)])
  assert_eq(must_execute(parse_filter("empty // .b"), j), [Json::number(2.0)])
  assert_eq(must_execute(parse_filter("empty"), j), [])
}

///|
test "execute fallback jq semantics with null/false and streams" {
  let j = must_parse("null")
  assert_eq(must_execute(parse_filter("null // 1"), j), [Json::number(1.0)])
  assert_eq(must_execute(parse_filter("false // 1"), j), [Json::number(1.0)])
  assert_eq(must_execute(parse_filter("true // 1"), j), [Json::boolean(true)])
  assert_eq(must_execute(parse_filter("[false,1] | .[] // 9"), j), [
    Json::number(1.0),
  ])
  assert_eq(must_execute(parse_filter("[null,false] | .[] // 9"), j), [
    Json::number(9.0),
  ])
  assert_eq(must_execute(parse_filter("(1,2) // 9"), j), [
    Json::number(1.0),
    Json::number(2.0),
  ])
}

///|
test "execute string contains/starts/ends" {
  let j = must_parse("\"hello\"")
  assert_eq(must_execute(parse_filter("contains(\"ell\")"), j), [
    Json::boolean(true),
  ])
  assert_eq(must_execute(parse_filter("contains((\"he\",\"zz\"))"), j), [
    Json::boolean(true),
    Json::boolean(false),
  ])
  assert_eq(must_execute(parse_filter("contains(empty)"), j), [])
  assert_eq(must_execute(parse_filter("startswith(\"he\")"), j), [
    Json::boolean(true),
  ])
  assert_eq(must_execute(parse_filter("startswith((\"h\",\"x\"))"), j), [
    Json::boolean(true),
    Json::boolean(false),
  ])
  assert_eq(must_execute(parse_filter("startswith(empty)"), j), [])
  assert_eq(must_execute(parse_filter("endswith(\"lo\")"), j), [
    Json::boolean(true),
  ])
  assert_eq(must_execute(parse_filter("endswith((\"o\",\"x\"))"), j), [
    Json::boolean(true),
    Json::boolean(false),
  ])
  assert_eq(must_execute(parse_filter("endswith(empty)"), j), [])
}

///|
test "execute trimstr compatibility" {
  let j = must_parse("\"foobar\"")
  assert_eq(must_execute(parse_filter("ltrimstr(\"foo\")"), j), [
    Json::string("bar"),
  ])
  assert_eq(must_execute(parse_filter("ltrimstr(\"bar\")"), j), [
    Json::string("foobar"),
  ])
  assert_eq(must_execute(parse_filter("rtrimstr(\"bar\")"), j), [
    Json::string("foo"),
  ])
  assert_eq(must_execute(parse_filter("rtrimstr(\"foo\")"), j), [
    Json::string("foobar"),
  ])
  assert_eq(must_execute(parse_filter("ltrimstr((\"foo\",\"bar\"))"), j), [
    Json::string("bar"),
    Json::string("foobar"),
  ])
  assert_eq(must_execute(parse_filter("ltrimstr(empty)"), j), [])
  assert_eq(must_execute(parse_filter("ltrimstr(\"\")"), j), [
    Json::string("foobar"),
  ])
  assert_eq(must_execute(parse_filter("rtrimstr(\"\")"), j), [Json::string("")])
  assert_eq(must_execute(parse_filter("trimstr(\"\")"), j), [Json::string("")])
}

///|
test "execute trim/ltrim/rtrim compatibility" {
  assert_eq(
    must_execute(parse_filter("trim, ltrim, rtrim"), must_parse("\" abc \"")),
    [Json::string("abc"), Json::string("abc "), Json::string(" abc")],
  )
  assert_eq(
    must_execute(
      parse_filter("[.[]|trimstr(\"foo\")]"),
      must_parse("[\"fo\",\"foo\",\"barfoo\",\"foobarfoo\",\"foob\"]"),
    ),
    [
      Json::array([
        Json::string("fo"),
        Json::string(""),
        Json::string("bar"),
        Json::string("bar"),
        Json::string("b"),
      ]),
    ],
  )
}

///|
test "execute trimstr errors" {
  guard (try? execute(parse_filter("ltrimstr(\"1\")"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "startswith() requires string inputs" else {
    fail("expected ltrimstr input type error")
  }
  guard (try? execute(parse_filter("ltrimstr(1)"), must_parse("\"x\"")))
    is Err(err) &&
    err.to_string() == "startswith() requires string inputs" else {
    fail("expected ltrimstr separator type error")
  }
  guard (try? execute(parse_filter("rtrimstr(1)"), must_parse("\"x\"")))
    is Err(err) &&
    err.to_string() == "endswith() requires string inputs" else {
    fail("expected rtrimstr separator type error")
  }
  guard (try? execute(parse_filter("trim"), must_parse("1"))) is Err(err) &&
    err.to_string() == "trim input must be a string" else {
    fail("expected trim input type error")
  }
  guard (try? execute(parse_filter("ltrim"), must_parse("1"))) is Err(err) &&
    err.to_string() == "trim input must be a string" else {
    fail("expected ltrim input type error")
  }
  guard (try? execute(parse_filter("rtrim"), must_parse("1"))) is Err(err) &&
    err.to_string() == "trim input must be a string" else {
    fail("expected rtrim input type error")
  }
  guard (try? execute(parse_filter("trimstr(\"1\")"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "startswith() requires string inputs" else {
    fail("expected trimstr input type error")
  }
  guard (try? execute(parse_filter("trimstr(1)"), must_parse("\"x\"")))
    is Err(err) &&
    err.to_string() == "startswith() requires string inputs" else {
    fail("expected trimstr separator type error")
  }
}

///|
test "execute abs/have_decnum/isempty compatibility" {
  assert_eq(
    must_execute(parse_filter("map(abs)"), must_parse("[-10,-1.1,-1e-1]")),
    [Json::array([Json::number(10.0), Json::number(1.1), Json::number(0.1)])],
  )
  assert_eq(
    must_execute(parse_filter("map(abs)|tojson"), must_parse("[-0,0,-10,-1.1]")),
    [Json::string("[-0,0,10,1.1]")],
  )
  assert_eq(
    must_execute(
      parse_filter("map(abs)|tojson"),
      must_parse("[0.1,1000000000000000002]"),
    ),
    [Json::string("[0.1,1000000000000000002]")],
  )
  assert_eq(must_execute(parse_filter("abs"), must_parse("\"abc\"")), [
    Json::string("abc"),
  ])
  assert_eq(must_execute(parse_filter("abs"), must_parse("[1,-2]")), [
    Json::array([Json::number(1.0), Json::number(-2.0)]),
  ])
  assert_eq(must_execute(parse_filter("abs"), must_parse("{\"a\":-1}")), [
    Json::object({ "a": Json::number(-1.0) }),
  ])
  assert_eq(must_execute(parse_filter("have_decnum"), must_parse("null")), [
    Json::boolean(false),
  ])
  assert_eq(
    must_execute(
      parse_filter("\"-1\"|IN(builtins[] / \"/\"|.[1])"),
      must_parse("null"),
    ),
    [Json::boolean(false)],
  )
  assert_eq(
    must_execute(
      parse_filter("all(builtins[] / \"/\"; .[1]|tonumber >= 0)"),
      must_parse("null"),
    ),
    [Json::boolean(true)],
  )
  assert_eq(must_execute(parse_filter("isempty(empty)"), must_parse("null")), [
    Json::boolean(true),
  ])
  assert_eq(must_execute(parse_filter("isempty(.[])"), must_parse("[]")), [
    Json::boolean(true),
  ])
  assert_eq(must_execute(parse_filter("isempty(.[])"), must_parse("[1,2,3]")), [
    Json::boolean(false),
  ])
  assert_eq(
    must_execute(parse_filter("isempty((1,error(\"x\")))"), must_parse("null")),
    [Json::boolean(false)],
  )
}

///|
test "execute numeric/meta builtins compatibility" {
  assert_eq(
    must_execute(
      parse_filter("map(toboolean)"),
      must_parse("[\"false\",\"true\",false,true]"),
    ),
    [
      Json::array([
        Json::boolean(false),
        Json::boolean(true),
        Json::boolean(false),
        Json::boolean(true),
      ]),
    ],
  )
  assert_eq(
    must_execute(parse_filter("[.[]|floor]"), must_parse("[-1.1,1.1,1.9]")),
    [Json::array([Json::number(-2.0), Json::number(1.0), Json::number(1.0)])],
  )
  assert_eq(must_execute(parse_filter("[.[]|sqrt]"), must_parse("[4,9]")), [
    Json::array([Json::number(2.0), Json::number(3.0)]),
  ])
  assert_eq(must_execute(parse_filter("pow(2;10)"), must_parse("null")), [
    Json::number(1024.0),
  ])
  assert_eq(
    must_execute(parse_filter("pow(2;8)|log2|round"), must_parse("null")),
    [Json::number(8.0)],
  )
  assert_eq(
    must_execute(parse_filter("map(fabs)"), must_parse("[-0,0,-10,-1.1]")),
    [
      Json::array([
        Json::number(0.0),
        Json::number(0.0),
        Json::number(10.0),
        Json::number(1.1),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("atan * 4 * 1000000|floor / 1000000"),
      must_parse("1"),
    ),
    [Json::number(3.141592)],
  )
  assert_eq(
    must_execute(
      parse_filter("infinite | type, nan | type"),
      must_parse("null"),
    ),
    [Json::string("string"), Json::string("number")],
  )
  guard (try? execute(parse_filter("modulemeta"), must_parse("\"c\"")))
    is Err(err) &&
    err.to_string() == "module not found: c" else {
    fail("expected modulemeta missing-module error")
  }
  assert_eq(
    must_execute(parse_filter("builtins|length > 10"), must_parse("null")),
    [Json::boolean(true)],
  )
}

///|
test "execute numeric/meta builtins errors" {
  guard (try? execute(parse_filter("toboolean"), must_parse("\"tru\"")))
    is Err(err) &&
    err.to_string() == "string (\"tru\") cannot be parsed as a boolean" else {
    fail("expected toboolean parse error")
  }
  guard (try? execute(parse_filter("sqrt"), must_parse("\"x\""))) is Err(err) &&
    err.to_string() == "string (\"x\") only numbers have sqrt" else {
    fail("expected sqrt type error")
  }
  guard (try? execute(parse_filter("floor"), must_parse("true"))) is Err(err) &&
    err.to_string() == "boolean (true) only numbers have floor" else {
    fail("expected floor type error")
  }
  guard (try? execute(parse_filter("pow(\"x\";2)"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "pow() requires numeric arguments" else {
    fail("expected pow type error")
  }
  guard (try? execute(parse_filter("log2"), must_parse("\"x\""))) is Err(err) &&
    err.to_string() == "string (\"x\") only numbers have log2" else {
    fail("expected log2 type error")
  }
}

///|
test "execute abs/fabs/isempty errors" {
  guard (try? execute(parse_filter("abs"), must_parse("null"))) is Err(err) &&
    err.to_string() == "null (null) cannot be negated" else {
    fail("expected abs null type error")
  }
  guard (try? execute(parse_filter("abs"), must_parse("true"))) is Err(err) &&
    err.to_string() == "boolean (true) cannot be negated" else {
    fail("expected abs boolean type error")
  }
  guard (try? execute(parse_filter("fabs"), must_parse("\"x\""))) is Err(err) &&
    err.to_string() == "string (\"x\") cannot be negated" else {
    fail("expected fabs string type error")
  }
  guard (try? execute(parse_filter("isempty(.[0])"), must_parse("{\"a\":1}")))
    is Err(err) &&
    err.to_string() == "Cannot index object with number" else {
    fail("expected isempty to propagate pre-first error")
  }
}

///|
test "execute ascii case compatibility" {
  assert_eq(
    must_execute(parse_filter("ascii_downcase"), must_parse("\"AbC_é\"")),
    [Json::string("abc_é")],
  )
  assert_eq(
    must_execute(parse_filter("ascii_upcase"), must_parse("\"AbC_é\"")),
    [Json::string("ABC_é")],
  )
}

///|
test "execute ascii case errors" {
  guard (try? execute(parse_filter("ascii_upcase"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "ascii_upcase input must be a string" else {
    fail("expected ascii_upcase type error")
  }
  guard (try? execute(parse_filter("ascii_downcase"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "ascii_downcase input must be a string" else {
    fail("expected ascii_downcase type error")
  }
}

///|
test "execute utf8bytelength compatibility" {
  assert_eq(
    must_execute(parse_filter("utf8bytelength"), must_parse("\"asdf\\u03bc\"")),
    [Json::number(6.0)],
  )
  assert_eq(
    must_execute(parse_filter("utf8bytelength"), must_parse("\"\\u03bc\"")),
    [Json::number(2.0)],
  )
}

///|
test "execute utf8bytelength errors" {
  guard (try? execute(parse_filter("utf8bytelength"), must_parse("[]")))
    is Err(err) &&
    err.to_string() == "array ([]) only strings have UTF-8 byte length" else {
    fail("expected utf8bytelength array type error")
  }
  guard (try? execute(parse_filter("utf8bytelength"), must_parse("{}")))
    is Err(err) &&
    err.to_string() == "object ({}) only strings have UTF-8 byte length" else {
    fail("expected utf8bytelength object type error")
  }
  guard (try? execute(parse_filter("utf8bytelength"), must_parse("55")))
    is Err(err) &&
    err.to_string() == "number (55) only strings have UTF-8 byte length" else {
    fail("expected utf8bytelength number type error")
  }
}
