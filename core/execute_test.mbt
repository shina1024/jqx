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
  assert_eq(must_execute(f1, j), [Value::number(1.0)])
  assert_eq(must_execute(f2, j), [Value::null()])
  assert_eq(must_execute(f3, j), [Value::number(1.0)])
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
  assert_eq(must_execute(parse_filter(".foo"), null_json), [Value::null()])
  assert_eq(must_execute(parse_filter(".foo?"), null_json), [Value::null()])
  assert_eq(must_execute(parse_filter(".[0]"), null_json), [Value::null()])
  assert_eq(must_execute(parse_filter(".[0]?"), null_json), [Value::null()])
}

///|
test "execute index and iter" {
  let j = must_parse("[1,2,3]")
  let f1 = parse_filter(".[1]")
  let f2 = parse_filter(".[]")
  let f3 = parse_filter(".[1,2]")
  assert_eq(must_execute(f1, j), [Value::number(2.0)])
  assert_eq(must_execute(f2, j), [
    Value::number(1.0),
    Value::number(2.0),
    Value::number(3.0),
  ])
  assert_eq(must_execute(f3, j), [Value::number(2.0), Value::number(3.0)])
  assert_eq(
    must_execute(parse_filter("[range(10)] | .[1.2:3.5]"), must_parse("null")),
    [Value::array([Value::number(1.0), Value::number(2.0), Value::number(3.0)])],
  )
  assert_eq(
    must_execute(parse_filter("[range(10)] | .[1.5:3.5]"), must_parse("null")),
    [Value::array([Value::number(1.0), Value::number(2.0), Value::number(3.0)])],
  )
  assert_eq(
    must_execute(parse_filter("[range(10)] | .[1.7:3.5]"), must_parse("null")),
    [Value::array([Value::number(1.0), Value::number(2.0), Value::number(3.0)])],
  )
}

///|
test "execute chained index without extra dot" {
  let j = must_parse("{\"a\":[10,20,30]}")
  assert_eq(must_execute(parse_filter(".a[1]"), j), [Value::number(20.0)])
  assert_eq(must_execute(parse_filter(".a[1:3]"), j), [
    Value::array([Value::number(20.0), Value::number(30.0)]),
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
    Value::number(1.0),
    Value::number(2.0),
    Value::number(3.0),
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
  assert_eq(must_execute(f, j), [Value::number(2.0), Value::null()])
  assert_eq(
    must_execute(parse_filter("{x:(1,2)},{x:3} | .x"), must_parse("null")),
    [Value::number(1.0), Value::number(2.0), Value::number(3.0)],
  )
}

///|
test "execute update assignment precedence" {
  let j1 = must_parse("{\"a\":0}")
  assert_eq(must_execute(parse_filter(".a = 1 | .a"), j1), [Value::number(1.0)])

  let j2 = must_parse("{\"a\":0}")
  assert_eq(must_execute(parse_filter(".a = 1 // 2 | .a"), j2), [
    Value::number(1.0),
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
      Value::object({
        "x": Value::string("abc"),
        "y": Value::array([
          Value::number(1.0),
          Value::number(2.0),
          Value::number(3.0),
        ]),
      }),
    ],
  )
}

///|
test "execute literal" {
  let j = must_parse("null")
  let f = parse_filter("\"hi\"")
  assert_eq(must_execute(f, j), [Value::string("hi")])
}

///|
test "execute array and object literals" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  let f1 = parse_filter("[.a, .b]")
  let f2 = parse_filter("{\"x\": .a, y: .b}")
  let f3 = parse_filter("{a, \"b\"}")
  let f4 = parse_filter("1 as $x | \"dyn\" as $k | { $x, $k: .b, a }")
  assert_eq(must_execute(f1, j), [
    Value::array([Value::number(1.0), Value::number(2.0)]),
  ])
  assert_eq(must_execute(f2, j), [
    Value::object({ "x": Value::number(1.0), "y": Value::number(2.0) }),
  ])
  assert_eq(must_execute(f3, j), [
    Value::object({ "a": Value::number(1.0), "b": Value::number(2.0) }),
  ])
  assert_eq(must_execute(f4, j), [
    Value::object({
      "x": Value::number(1.0),
      "dyn": Value::number(2.0),
      "a": Value::number(1.0),
    }),
  ])
}

///|
test "execute builtins" {
  let j1 = must_parse("[1,2,3]")
  let j2 = must_parse("{\"a\":1,\"b\":2}")
  let j3 = must_parse("\"hi\"")
  assert_eq(must_execute(parse_filter("length"), j1), [Value::number(3.0)])
  assert_eq(must_execute(parse_filter("length"), j2), [Value::number(2.0)])
  assert_eq(must_execute(parse_filter("length"), j3), [Value::number(2.0)])
  assert_eq(must_execute(parse_filter("type"), j2), [Value::string("object")])
  assert_eq(must_execute(parse_filter("keys"), j2), [
    Value::array([Value::string("a"), Value::string("b")]),
  ])
}

///|
test "execute def no-arg minimal" {
  let j = must_parse("1")
  assert_eq(must_execute(parse_filter("def inc: . + 1; . | inc"), j), [
    Value::number(2.0),
  ])
  assert_eq(
    must_execute(
      parse_filter("def inc: . + 1; def twice: inc | inc; . | twice"),
      j,
    ),
    [Value::number(3.0)],
  )
  assert_eq(must_execute(parse_filter("def length: 42; . | length"), j), [
    Value::number(42.0),
  ])
  let obj = must_parse("{\"a\":1,\"b\":2}")
  assert_eq(
    must_execute(parse_filter("def add(a;b): a + b; add(.a; .b)"), obj),
    [Value::number(3.0)],
  )
  let arr = must_parse("[1,2]")
  assert_eq(
    must_execute(parse_filter("def addvalue(f): . + [f]; addvalue(.[0])"), arr),
    [Value::array([Value::number(1.0), Value::number(2.0), Value::number(1.0)])],
  )
  assert_eq(must_execute(parse_filter("def plus($x): . + $x; plus(2)"), j), [
    Value::number(3.0),
  ])
  assert_eq(
    must_execute(
      parse_filter("def f: . + 1; def g: def g: . + 100; f | g | f; (f | g), g"),
      must_parse("3"),
    ),
    [Value::number(106.0), Value::number(105.0)],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "def f: .+1; def g: f; def f: .+100; def f(a):a+.+11; [(g|f(20)), f]",
      ),
      must_parse("1"),
    ),
    [Value::array([Value::number(33.0), Value::number(101.0)])],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "[[20,10][1,0] as $x | def f: (100,200) as $y | def g: [$x + $y, .]; . + $x | g; f[0] | [f][0][1] | f]",
      ),
      must_parse("999999999"),
    ),
    [
      Value::array([
        Value::array([Value::number(110.0), Value::number(130.0)]),
        Value::array([Value::number(210.0), Value::number(130.0)]),
        Value::array([Value::number(110.0), Value::number(230.0)]),
        Value::array([Value::number(210.0), Value::number(230.0)]),
        Value::array([Value::number(120.0), Value::number(160.0)]),
        Value::array([Value::number(220.0), Value::number(160.0)]),
        Value::array([Value::number(120.0), Value::number(260.0)]),
        Value::array([Value::number(220.0), Value::number(260.0)]),
      ]),
    ],
  )
}

///|
test "execute def edge semantics compatibility" {
  assert_eq(
    must_execute(
      parse_filter("10 as $x | def f: $x; 20 as $x | f"),
      must_parse("null"),
    ),
    [Value::number(10.0)],
  )
  guard (try? execute(
      parse_filter("def f: g; def g: . + 1; f"),
      must_parse("1"),
    ))
    is Err(EvalError::UnknownFunction(name)) &&
    name == "g" else {
    fail("expected forward def reference to fail")
  }
  guard (try? execute(
      parse_filter("def f(x): g(x); def g(y): y + 1; f(1)"),
      must_parse("null"),
    ))
    is Err(EvalError::UnknownFunction(name)) &&
    name == "g" else {
    fail("expected forward def reference with arity to fail")
  }
  guard (try? execute(
      parse_filter(
        "def even: if . == 0 then true else .-1|odd end; def odd: if . == 0 then false else .-1|even end; 4|even",
      ),
      must_parse("null"),
    ))
    is Err(EvalError::UnknownFunction(name)) &&
    name == "odd" else {
    fail("expected mutual recursion without prior definition to fail")
  }
}

///|
test "execute import/include missing module compatibility" {
  clear_module_sources()
  guard (try? execute(
      parse_filter("import \"a\" as foo; foo::a"),
      must_parse("null"),
    ))
    is Err(err) &&
    err.to_string() == "module not found: a" else {
    fail("expected missing module error for import")
  }
  guard (try? execute(
      parse_filter("include \"shadow1\"; include \"shadow2\"; e"),
      must_parse("null"),
    ))
    is Err(err) &&
    err.to_string() == "module not found: shadow2" else {
    fail("expected missing module error for include")
  }
  clear_module_sources()
}

///|
test "execute import/include module source compatibility" {
  clear_module_sources()
  register_module_source("math", "def inc: . + 1; def twice: inc | inc;")
  register_module_source(
    "util", "import \"math\" as m; def add3: m::inc | m::inc | m::inc;",
  )
  assert_eq(
    must_execute(
      parse_filter("import \"math\" as m; . | m::twice"),
      must_parse("1"),
    ),
    [Value::number(3.0)],
  )
  assert_eq(
    must_execute(parse_filter("include \"math\"; . | twice"), must_parse("1")),
    [Value::number(3.0)],
  )
  assert_eq(
    must_execute(
      parse_filter("import \"util\" as u; . | u::add3"),
      must_parse("1"),
    ),
    [Value::number(4.0)],
  )
  clear_module_sources()
}

///|
test "execute first/last/nth compatibility" {
  let arr = must_parse("[1,2,3]")
  assert_eq(must_execute(parse_filter("first"), arr), [Value::number(1.0)])
  assert_eq(must_execute(parse_filter("last"), arr), [Value::number(3.0)])
  assert_eq(must_execute(parse_filter("nth(0)"), arr), [Value::number(1.0)])
  assert_eq(must_execute(parse_filter("nth(-1)"), arr), [Value::number(3.0)])
  assert_eq(must_execute(parse_filter("nth(9)"), arr), [Value::null()])
  assert_eq(must_execute(parse_filter("nth(1.9)"), arr), [Value::number(2.0)])
  assert_eq(must_execute(parse_filter("nth((0,-1,9))"), arr), [
    Value::number(1.0),
    Value::number(3.0),
    Value::null(),
  ])
  let empty_arr = must_parse("[]")
  assert_eq(must_execute(parse_filter("first"), empty_arr), [Value::null()])
  assert_eq(must_execute(parse_filter("last"), empty_arr), [Value::null()])
  assert_eq(must_execute(parse_filter("nth(0)"), empty_arr), [Value::null()])
  let null_json = must_parse("null")
  assert_eq(must_execute(parse_filter("first"), null_json), [Value::null()])
  assert_eq(must_execute(parse_filter("last"), null_json), [Value::null()])
  assert_eq(must_execute(parse_filter("nth(0)"), null_json), [Value::null()])
  assert_eq(must_execute(parse_filter("nth(\"a\")"), null_json), [Value::null()])
  let scalar = must_parse("1")
  assert_eq(must_execute(parse_filter("first(empty)"), scalar), [])
  assert_eq(must_execute(parse_filter("last(empty)"), scalar), [])
  assert_eq(must_execute(parse_filter("nth(empty)"), scalar), [])
  assert_eq(must_execute(parse_filter("first((1,2,3))"), scalar), [
    Value::number(1.0),
  ])
  assert_eq(must_execute(parse_filter("last((1,2,3))"), scalar), [
    Value::number(3.0),
  ])
  let null_json2 = must_parse("null")
  assert_eq(
    must_execute(parse_filter("nth(1; 0,1,error(\"foo\"))"), null_json2),
    [Value::number(1.0)],
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
    Value::array([
      Value::number(1.0),
      Value::number(2.0),
      Value::number(3.0),
      Value::number(4.0),
      Value::number(5.0),
    ]),
  ])
  assert_eq(must_execute(parse_filter("flatten(1)"), nested), [
    Value::array([
      Value::number(1.0),
      Value::number(2.0),
      Value::array([Value::number(3.0), Value::array([Value::number(4.0)])]),
      Value::number(5.0),
    ]),
  ])
  assert_eq(must_execute(parse_filter("flatten(2)"), nested), [
    Value::array([
      Value::number(1.0),
      Value::number(2.0),
      Value::number(3.0),
      Value::array([Value::number(4.0)]),
      Value::number(5.0),
    ]),
  ])
  assert_eq(must_execute(parse_filter("flatten(0)"), nested), [nested])
  assert_eq(must_execute(parse_filter("flatten(0.1)"), nested), [
    Value::array([
      Value::number(1.0),
      Value::number(2.0),
      Value::number(3.0),
      Value::number(4.0),
      Value::number(5.0),
    ]),
  ])
  assert_eq(
    must_execute(parse_filter("flatten((0,1))"), must_parse("[1,[2]]")),
    [
      Value::array([Value::number(1.0), Value::array([Value::number(2.0)])]),
      Value::array([Value::number(1.0), Value::number(2.0)]),
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
      Value::array([
        Value::array([Value::number(1.0), Value::number(3.0)]),
        Value::array([Value::number(2.0), Value::number(4.0)]),
      ]),
    ],
  )
  assert_eq(
    must_execute(parse_filter("transpose"), must_parse("[[1],[2,3]]")),
    [
      Value::array([
        Value::array([Value::number(1.0), Value::number(2.0)]),
        Value::array([Value::null(), Value::number(3.0)]),
      ]),
    ],
  )
  assert_eq(must_execute(parse_filter("transpose"), must_parse("[]")), [
    Value::array([]),
  ])
  assert_eq(must_execute(parse_filter("transpose"), must_parse("[[],[]]")), [
    Value::array([]),
  ])
  assert_eq(must_execute(parse_filter("transpose"), must_parse("[[1],[]]")), [
    Value::array([Value::array([Value::number(1.0), Value::null()])]),
  ])
  assert_eq(must_execute(parse_filter("transpose"), must_parse("[{}]")), [
    Value::array([]),
  ])
  assert_eq(must_execute(parse_filter("transpose"), must_parse("[[1],null]")), [
    Value::array([Value::array([Value::number(1.0), Value::null()])]),
  ])
  assert_eq(
    must_execute(parse_filter("transpose"), must_parse("[[1,null],[2]]")),
    [
      Value::array([
        Value::array([Value::number(1.0), Value::number(2.0)]),
        Value::array([Value::null(), Value::null()]),
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
    Value::array([
      Value::object({ "key": Value::number(0.0), "value": Value::number(10.0) }),
      Value::object({ "key": Value::number(1.0), "value": Value::number(20.0) }),
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
      Value::object({
        "a": Value::number(1.0),
        "b": Value::number(2.0),
        "c": Value::number(3.0),
        "d": Value::number(4.0),
      }),
    ],
  )
  assert_eq(
    must_execute(parse_filter("from_entries"), must_parse("[{\"key\":\"a\"}]")),
    [Value::object({ "a": Value::null() })],
  )
  assert_eq(
    must_execute(
      parse_filter("with_entries({key: (.key + \"_x\"), value: (.value + 10)})"),
      must_parse("{\"a\":1}"),
    ),
    [Value::object({ "a_x": Value::number(11.0) })],
  )
  assert_eq(
    must_execute(parse_filter("with_entries(empty)"), must_parse("{\"a\":1}")),
    [Value::object(Map::new())],
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
    Value::array([Value::number(0.0), Value::number(1.0)]),
  ])
  let obj = must_parse("{\"b\":2,\"a\":1}")
  assert_eq(must_execute(parse_filter("keys_unsorted"), obj), [
    Value::array([Value::string("b"), Value::string("a")]),
  ])
  assert_eq(must_execute(parse_filter(".[]"), obj), [
    Value::number(2.0),
    Value::number(1.0),
  ])
  assert_eq(must_execute(parse_filter("tojson"), obj), [
    Value::string("{\"b\":2,\"a\":1}"),
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
    Value::string("1"),
  ])
  assert_eq(must_execute(parse_filter("tostring"), must_parse("\"x\"")), [
    Value::string("x"),
  ])
  assert_eq(must_execute(parse_filter("tostring"), must_parse("null")), [
    Value::string("null"),
  ])
  assert_eq(must_execute(parse_filter("tostring"), must_parse("[1,2]")), [
    Value::string("[1,2]"),
  ])
  assert_eq(must_execute(parse_filter("tonumber"), must_parse("\"1\"")), [
    Value::number(1.0),
  ])
  assert_eq(must_execute(parse_filter("tonumber"), must_parse("\"01\"")), [
    Value::number(1.0),
  ])
  assert_eq(must_execute(parse_filter("tonumber"), must_parse("\"1.25\"")), [
    Value::number(1.25),
  ])
  assert_eq(
    must_execute(parse_filter("tonumber"), must_parse("\"123\\u0000456\"")),
    [Value::number(123.0)],
  )
  assert_eq(must_execute(parse_filter("tonumber"), must_parse("1")), [
    Value::number(1.0),
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
    Value::string("1"),
  ])
  assert_eq(must_execute(parse_filter("tojson"), must_parse("\"x\"")), [
    Value::string("\"x\""),
  ])
  assert_eq(must_execute(parse_filter("tojson"), must_parse("[1,2]")), [
    Value::string("[1,2]"),
  ])
  assert_eq(must_execute(parse_filter("tojson"), must_parse("{\"a\":1}")), [
    Value::string("{\"a\":1}"),
  ])
  assert_eq(must_execute(parse_filter("tojson"), must_parse("null")), [
    Value::string("null"),
  ])
  assert_eq(must_execute(parse_filter("tojson"), must_parse("true")), [
    Value::string("true"),
  ])
  assert_eq(
    must_execute(
      parse_filter("tojson"),
      must_parse("0.12345678901234567890123456789"),
    ),
    [Value::string("0.12345678901234568")],
  )
  assert_eq(must_execute(parse_filter("tojson"), must_parse("1E-999999999")), [
    Value::string("0"),
  ])
  assert_eq(must_execute(parse_filter("fromjson"), must_parse("\"1\"")), [
    Value::number(1.0),
  ])
  assert_eq(must_execute(parse_filter("fromjson"), must_parse("\"[1,2]\"")), [
    Value::array([Value::number(1.0), Value::number(2.0)]),
  ])
  assert_eq(
    must_execute(parse_filter("fromjson"), must_parse("\"{\\\"a\\\":1}\"")),
    [Value::object({ "a": Value::number(1.0) })],
  )
  assert_eq(must_execute(parse_filter("fromjson"), must_parse("\"null\"")), [
    Value::null(),
  ])
  assert_eq(must_execute(parse_filter("fromjson"), must_parse("\" true \"")), [
    Value::boolean(true),
  ])
  assert_eq(
    must_execute(parse_filter("fromjson | isnan"), must_parse("\"nan\"")),
    [Value::boolean(true)],
  )
  assert_eq(
    must_execute(parse_filter("fromjson | isinfinite"), must_parse("\"INF\"")),
    [Value::boolean(true)],
  )
  assert_eq(
    must_execute(parse_filter("fromjson | isinfinite"), must_parse("\"-inf\"")),
    [Value::boolean(true)],
  )
}

///|
test "execute format filter compatibility" {
  assert_eq(
    must_execute(
      parse_filter(
        "@text,@json,([1,.]|@csv,@tsv),@html,(@uri|.,@urid),@sh,(@base64|.,@base64d)",
      ),
      must_parse("\"!()<>&'\\\"\\t\""),
    ),
    [
      Value::string("!()<>&'\"\t"),
      Value::string("\"!()<>&'\\\"\\t\""),
      Value::string("1,\"!()<>&'\"\"\t\""),
      Value::string("1\t!()<>&'\"\\t"),
      Value::string("!()&lt;&gt;&amp;&apos;&quot;\t"),
      Value::string("%21%28%29%3C%3E%26%27%22%09"),
      Value::string("!()<>&'\"\t"),
      Value::string("'!()<>&'\\''\"\t'"),
      Value::string("ISgpPD4mJyIJ"),
      Value::string("!()<>&'\"\t"),
    ],
  )
  assert_eq(
    must_execute(parse_filter("(@uri|@urid)"), must_parse("\"<>&'\\\"\\t\"")),
    [Value::string("<>&'\"\t")],
  )
  assert_eq(
    must_execute(parse_filter("@urid"), must_parse("\"a\\u0000b\\u0000c\"")),
    [Value::string("a")],
  )
  assert_eq(
    must_execute(parse_filter("@urid"), must_parse("\"Knäckebröd\"")),
    [Value::string("Kn\u{fffd}\u{fffd}ckebr\u{fffd}\u{fffd}d")],
  )
  assert_eq(
    must_execute(
      parse_filter("@urid | tojson"),
      must_parse(
        "\"%2C-.%2F09%3A%3B%3C%3D%3E%3F%40AZ%5B%5C%5D%5E_%60az%7B%7C%7D~%7F\"",
      ),
    ),
    [Value::string("\",-./09:;<=>?@AZ[\\\\]^_`az{|}~\\u007f\"")],
  )
  assert_eq(
    must_execute(
      parse_filter("(@base64|@base64d)"),
      must_parse("\"<>&'\\\"\\t\""),
    ),
    [Value::string("<>&'\"\t")],
  )
  assert_eq(
    must_execute(
      parse_filter("@html \"<b>\\(.)</b>\""),
      must_parse("\"<script>hax</script>\""),
    ),
    [Value::string("<b>&lt;script&gt;hax&lt;/script&gt;</b>")],
  )
  assert_eq(
    must_execute(
      parse_filter("@sh \"echo \\(.)\""),
      must_parse("\"O'Hara's Ale\""),
    ),
    [Value::string("echo 'O'\\''Hara'\\''s Ale'")],
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
  assert_eq(must_execute(parse_filter("@base64d"), must_parse("\"=\"")), [
    Value::string(""),
  ])
  assert_eq(must_execute(parse_filter("@base64d"), must_parse("\"====\"")), [
    Value::string(""),
  ])
  guard (try? execute(parse_filter("@base64d"), must_parse("\"A==\"")))
    is Err(err) &&
    err.to_string() == "string (\"A==\") trailing base64 byte found" else {
    fail("expected @base64d trailing byte error for lax padding")
  }
  guard (try? execute(parse_filter("@urid"), must_parse("\"%FX%9F%98%8E\"")))
    is Err(err) &&
    err.to_string() == "string (\"%FX%9F%98%8E\") is not a valid uri encoding" else {
    fail("expected @urid invalid encoding error")
  }
}

///|
test "execute io-control minimal compatibility" {
  assert_eq(must_execute(parse_filter("debug"), must_parse("1")), [
    Value::number(1.0),
    Value::array([Value::string("DEBUG:"), Value::number(1.0)]),
  ])
  assert_eq(
    must_execute(parse_filter("try input catch ."), must_parse("null")),
    [Value::string("break")],
  )
  guard (try? execute(parse_filter("input"), must_parse("null"))) is Err(err) &&
    err.to_string() == "break" else {
    fail("expected input EOF break error")
  }
}

///|
test "execute recursion builtins minimal compatibility" {
  assert_eq(
    must_execute(parse_filter("[while(.<100; .*2)]"), must_parse("1")),
    [
      Value::array([
        Value::number(1.0),
        Value::number(2.0),
        Value::number(4.0),
        Value::number(8.0),
        Value::number(16.0),
        Value::number(32.0),
        Value::number(64.0),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("[.,1]|until(.[0] < 1; [.[0] - 1, .[1] * .[0]])|.[1]"),
      must_parse("4"),
    ),
    [Value::number(24.0)],
  )
  assert_eq(
    must_execute(
      parse_filter("recurse(.foo[])"),
      must_parse("{\"foo\":[{\"foo\": []}, {\"foo\":[{\"foo\":[]}]}]}"),
    ),
    [
      must_parse("{\"foo\":[{\"foo\":[]},{\"foo\":[{\"foo\":[]}]}]}"),
      must_parse("{\"foo\":[]}"),
      must_parse("{\"foo\":[{\"foo\":[]}]}"),
      must_parse("{\"foo\":[]}"),
    ],
  )
  assert_eq(
    must_execute(parse_filter("recurse"), must_parse("{\"a\":0,\"b\":[1]}")),
    [
      must_parse("{\"a\":0,\"b\":[1]}"),
      Value::number(0.0),
      Value::array([Value::number(1.0)]),
      Value::number(1.0),
    ],
  )
  assert_eq(
    must_execute(parse_filter("recurse(. * .; . < 20)"), must_parse("2")),
    [Value::number(2.0), Value::number(4.0), Value::number(16.0)],
  )
  assert_eq(must_execute(parse_filter("walk(.)"), must_parse("{\"x\":0}")), [
    must_parse("{\"x\":0}"),
  ])
  assert_eq(must_execute(parse_filter("walk(1)"), must_parse("{\"x\":0}")), [
    Value::number(1.0),
  ])
  assert_eq(
    must_execute(parse_filter("[walk(.,1)]"), must_parse("{\"x\":0}")),
    [Value::array([must_parse("{\"x\":0}"), Value::number(1.0)])],
  )
  assert_eq(
    must_execute(
      parse_filter("walk(select(IN({}, []) | not))"),
      must_parse("{\"a\":1,\"b\":[]}"),
    ),
    [must_parse("{\"a\":1}")],
  )
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
    Value::array([Value::number(3.0), Value::number(2.0), Value::number(1.0)]),
  ])
  assert_eq(must_execute(parse_filter("reverse"), must_parse("[]")), [
    Value::array([]),
  ])
  assert_eq(must_execute(parse_filter("reverse"), must_parse("null")), [
    Value::array([]),
  ])
  assert_eq(must_execute(parse_filter("reverse"), must_parse("{}")), [
    Value::array([]),
  ])
  assert_eq(must_execute(parse_filter("reverse"), must_parse("\"\"")), [
    Value::array([]),
  ])
  assert_eq(must_execute(parse_filter("reverse"), must_parse("0")), [
    Value::array([]),
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
    [Value::string("a,1,true,")],
  )
  assert_eq(must_execute(parse_filter("join(\",\")"), must_parse("[]")), [
    Value::string(""),
  ])
  assert_eq(must_execute(parse_filter("join(\",\")"), must_parse("[1,2]")), [
    Value::string("1,2"),
  ])
  assert_eq(must_execute(parse_filter("join(1)"), must_parse("[\"a\"]")), [
    Value::string("a"),
  ])
  assert_eq(
    must_execute(
      parse_filter("join((\",\", \":\"))"),
      must_parse("[\"a\",\"b\"]"),
    ),
    [Value::string("a,b"), Value::string("a:b")],
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
    [Value::array([Value::string("a"), Value::string("b"), Value::string("c")])],
  )
  assert_eq(must_execute(parse_filter("split(\"\")"), must_parse("\"abc\"")), [
    Value::array([Value::string("a"), Value::string("b"), Value::string("c")]),
  ])
  assert_eq(must_execute(parse_filter("split(\"\")"), must_parse("\"\"")), [
    Value::array([]),
  ])
  assert_eq(must_execute(parse_filter("split(\",\")"), must_parse("\"\"")), [
    Value::array([]),
  ])
  assert_eq(
    must_execute(parse_filter("split((\",\", \"\"))"), must_parse("\"abc\"")),
    [
      Value::array([Value::string("abc")]),
      Value::array([Value::string("a"), Value::string("b"), Value::string("c")]),
    ],
  )
  assert_eq(must_execute(parse_filter("split(\"a\")"), must_parse("\"aa\"")), [
    Value::array([Value::string(""), Value::string(""), Value::string("")]),
  ])
  assert_eq(must_execute(parse_filter("split(empty)"), must_parse("\"a\"")), [])
  assert_eq(
    must_execute(
      parse_filter("split(\", *\"; null)"),
      must_parse("\"ab,cd, ef\""),
    ),
    [
      Value::array([
        Value::string("ab"),
        Value::string("cd"),
        Value::string("ef"),
      ]),
    ],
  )
  assert_eq(
    must_execute(parse_filter("[splits(\"\")]"), must_parse("\"ab\"")),
    [
      Value::array([
        Value::string(""),
        Value::string("a"),
        Value::string("b"),
        Value::string(""),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("[splits(\"a+\"; \"i\")]"),
      must_parse("\"abAABBabA\""),
    ),
    [
      Value::array([
        Value::string(""),
        Value::string("b"),
        Value::string("BB"),
        Value::string("b"),
        Value::string(""),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("[splits(\",? *\"; \"n\")]"),
      must_parse("\"ab,cd ef,  gh\""),
    ),
    [
      Value::array([
        Value::string("ab"),
        Value::string("cd"),
        Value::string("ef"),
        Value::string("gh"),
      ]),
    ],
  )
}

///|
test "execute test regex compatibility" {
  assert_eq(must_execute(parse_filter("test(\"a\")"), must_parse("\"abc\"")), [
    Value::boolean(true),
  ])
  assert_eq(must_execute(parse_filter("test(\"A\")"), must_parse("\"abc\"")), [
    Value::boolean(false),
  ])
  assert_eq(
    must_execute(parse_filter("test(\"A\"; \"i\")"), must_parse("\"abc\"")),
    [Value::boolean(true)],
  )
  assert_eq(
    must_execute(parse_filter("test(\"a+\"; null)"), must_parse("\"aaab\"")),
    [Value::boolean(true)],
  )
  assert_eq(must_execute(parse_filter("test(empty)"), must_parse("\"abc\"")), [])
  assert_eq(
    must_execute(parse_filter("test(\"\"; \"n\")"), must_parse("\"abc\"")),
    [Value::boolean(false)],
  )
}

///|
test "execute scan regex compatibility" {
  assert_eq(
    must_execute(parse_filter("[scan(\"a+\")]"), must_parse("\"baaaac\"")),
    [Value::array([Value::string("aaaa")])],
  )
  assert_eq(
    must_execute(
      parse_filter("[scan(\"A+\"; \"i\")]"),
      must_parse("\"baAaAc\""),
    ),
    [Value::array([Value::string("aAaA")])],
  )
  assert_eq(must_execute(parse_filter("[scan(\"\")]"), must_parse("\"ab\"")), [
    Value::array([Value::string(""), Value::string(""), Value::string("")]),
  ])
  assert_eq(
    must_execute(parse_filter("[scan(\"\"; \"n\")]"), must_parse("\"ab\"")),
    [Value::array([])],
  )
  assert_eq(must_execute(parse_filter("[scan(empty)]"), must_parse("\"ab\"")), [
    Value::array([]),
  ])
}

///|
test "execute match regex compatibility" {
  assert_eq(
    must_execute(parse_filter("match(\"a+\")"), must_parse("\"baaaac\"")),
    [
      must_parse(
        "{\"offset\":1,\"length\":4,\"string\":\"aaaa\",\"captures\":[]}",
      ),
    ],
  )
  assert_eq(
    must_execute(parse_filter("match(\"A+\"; \"i\")"), must_parse("\"baAaAc\"")),
    [
      must_parse(
        "{\"offset\":1,\"length\":4,\"string\":\"aAaA\",\"captures\":[]}",
      ),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("match(\".+?\\\\b\")"),
      must_parse("\"a\\u0304 two-codepoint grapheme\""),
    ),
    [
      must_parse(
        "{\"offset\":0,\"length\":2,\"string\":\"a\\u0304\",\"captures\":[]}",
      ),
    ],
  )
  assert_eq(must_execute(parse_filter("match(\"\")"), must_parse("\"ab\"")), [
    must_parse("{\"offset\":0,\"length\":0,\"string\":\"\",\"captures\":[]}"),
  ])
  assert_eq(
    must_execute(parse_filter("match(\"\"; \"n\")"), must_parse("\"ab\"")),
    [],
  )
  assert_eq(
    must_execute(parse_filter("[match(\"a\"; \"g\")]"), must_parse("\"abac\"")),
    [
      must_parse(
        "[{\"offset\":0,\"length\":1,\"string\":\"a\",\"captures\":[]},{\"offset\":2,\"length\":1,\"string\":\"a\",\"captures\":[]}]",
      ),
    ],
  )
  assert_eq(
    must_execute(parse_filter("[match(empty)]"), must_parse("\"ab\"")),
    [Value::array([])],
  )
}

///|
test "execute regex alternation sequence merge compatibility" {
  assert_eq(
    must_execute(parse_filter("match(\"a|ab\")"), must_parse("\"ab\"")),
    [must_parse("{\"offset\":0,\"length\":1,\"string\":\"a\",\"captures\":[]}")],
  )
  assert_eq(
    must_execute(parse_filter("match(\"ab|[ac]|ac\")"), must_parse("\"ac\"")),
    [must_parse("{\"offset\":0,\"length\":1,\"string\":\"a\",\"captures\":[]}")],
  )
  assert_eq(
    must_execute(parse_filter("match(\"ab|ac\")"), must_parse("\"ac\"")),
    [
      must_parse(
        "{\"offset\":0,\"length\":2,\"string\":\"ac\",\"captures\":[]}",
      ),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("match(\"あい|あう\")"),
      must_parse("\"あう\""),
    ),
    [
      must_parse(
        "{\"offset\":0,\"length\":2,\"string\":\"あう\",\"captures\":[]}",
      ),
    ],
  )
}

///|
test "execute capture regex compatibility" {
  assert_eq(
    must_execute(parse_filter("capture(\"a+\")"), must_parse("\"baaaac\"")),
    [Value::object(Map::new())],
  )
  assert_eq(
    must_execute(
      parse_filter("capture(\"A+\"; \"i\")"),
      must_parse("\"baAaAc\""),
    ),
    [Value::object(Map::new())],
  )
  assert_eq(
    must_execute(parse_filter("capture(\"a+\")"), must_parse("\"xyz\"")),
    [],
  )
  assert_eq(must_execute(parse_filter("capture(\"\")"), must_parse("\"ab\"")), [
    Value::object(Map::new()),
  ])
  assert_eq(
    must_execute(parse_filter("capture(\"\"; \"n\")"), must_parse("\"ab\"")),
    [],
  )
  assert_eq(
    must_execute(parse_filter("[capture(empty)]"), must_parse("\"ab\"")),
    [Value::array([])],
  )
}

///|
test "execute sub/gsub regex compatibility" {
  assert_eq(
    must_execute(parse_filter("sub(\"a\"; \"X\")"), must_parse("\"abac\"")),
    [Value::string("Xbac")],
  )
  assert_eq(
    must_execute(
      parse_filter("sub(\"a\"; \"X\"; \"g\")"),
      must_parse("\"abac\""),
    ),
    [Value::string("XbXc")],
  )
  assert_eq(
    must_execute(
      parse_filter("sub(\"A\"; \"X\"; \"i\")"),
      must_parse("\"abAc\""),
    ),
    [Value::string("XbAc")],
  )
  assert_eq(
    must_execute(parse_filter("sub(\"\"; \"X\")"), must_parse("\"ab\"")),
    [Value::string("Xab")],
  )
  assert_eq(
    must_execute(parse_filter("sub(\"z\"; \"X\")"), must_parse("\"ab\"")),
    [Value::string("ab")],
  )
  assert_eq(
    must_execute(parse_filter("sub(\"^_+\"; \"\")"), must_parse("\"_ab\"")),
    [Value::string("ab")],
  )
  assert_eq(
    must_execute(parse_filter("sub(\"_+$\"; \"\")"), must_parse("\"ab__\"")),
    [Value::string("ab")],
  )
  assert_eq(
    must_execute(parse_filter("gsub(\"a\"; \"X\")"), must_parse("\"abac\"")),
    [Value::string("XbXc")],
  )
  assert_eq(
    must_execute(
      parse_filter("gsub(\"a\"; \"X\"; null)"),
      must_parse("\"abac\""),
    ),
    [Value::string("XbXc")],
  )
  assert_eq(
    must_execute(
      parse_filter("gsub(\"A\"; \"X\"; \"i\")"),
      must_parse("\"abAc\""),
    ),
    [Value::string("XbXc")],
  )
  assert_eq(
    must_execute(parse_filter("gsub(\"\"; \"X\")"), must_parse("\"ab\"")),
    [Value::string("XaXbX")],
  )
  assert_eq(
    must_execute(parse_filter("gsub(\"$\"; \"a\"; \"g\")"), must_parse("\"a\"")),
    [Value::string("aa")],
  )
  assert_eq(
    must_execute(parse_filter("gsub(\"(?=u)\"; \"u\")"), must_parse("\"qux\"")),
    [Value::string("quux")],
  )
  assert_eq(
    must_execute(parse_filter("gsub(\"\"; \"X\"; \"n\")"), must_parse("\"ab\"")),
    [Value::string("ab")],
  )
  assert_eq(
    must_execute(parse_filter("[gsub(empty; \"X\")]"), must_parse("\"ab\"")),
    [Value::array([])],
  )
}

///|
test "execute regex named capture compatibility" {
  assert_eq(
    must_execute(
      parse_filter("capture(\"(?<a>[a-z]+)-(?<n>[0-9]+)\")"),
      must_parse("\"xyzzy-14\""),
    ),
    [must_parse("{\"a\":\"xyzzy\",\"n\":\"14\"}")],
  )
  assert_eq(
    must_execute(parse_filter("capture(\"(?<x>a)?b?\")"), must_parse("\"b\"")),
    [must_parse("{\"x\":null}")],
  )
  assert_eq(
    must_execute(parse_filter("match(\"(?<x>a)?b?\")"), must_parse("\"b\"")),
    [
      must_parse(
        "{\"offset\":0,\"length\":1,\"string\":\"b\",\"captures\":[{\"offset\":-1,\"string\":null,\"length\":0,\"name\":\"x\"}]}",
      ),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("match(\"(?<a>[a-z]+)-(?<n>[0-9]+)\")"),
      must_parse("\"xyzzy-14\""),
    ),
    [
      must_parse(
        "{\"offset\":0,\"length\":8,\"string\":\"xyzzy-14\",\"captures\":[{\"offset\":0,\"length\":5,\"string\":\"xyzzy\",\"name\":\"a\"},{\"offset\":6,\"length\":2,\"string\":\"14\",\"name\":\"n\"}]}",
      ),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("[match([\"foo\", \"ig\"])]"),
      must_parse("\"foo bar FOO\""),
    ),
    [
      must_parse(
        "[{\"offset\":0,\"length\":3,\"string\":\"foo\",\"captures\":[]},{\"offset\":8,\"length\":3,\"string\":\"FOO\",\"captures\":[]}]",
      ),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("[scan(\"(a+)(b+)\")]"),
      must_parse("\"abaabbaaabbb\""),
    ),
    [must_parse("[[\"a\",\"b\"],[\"aa\",\"bb\"],[\"aaa\",\"bbb\"]]")],
  )
  assert_eq(
    must_execute(
      parse_filter("sub(\"^(?<head>.)\"; \"Head=\\(.head) Tail=\")"),
      must_parse("\"abcdef\""),
    ),
    [Value::string("Head=a Tail=bcdef")],
  )
  assert_eq(
    must_execute(
      parse_filter("gsub(\"(?<d>\\\\d)\"; \":\\(.d);\")"),
      must_parse("\"a1b2\""),
    ),
    [Value::string("a:1;b:2;")],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "[sub(\"(?<a>.)\"; \"\\(.a|ascii_upcase)\", \"\\(.a|ascii_downcase)\", \"c\")]",
      ),
      must_parse("\"aB\""),
    ),
    [must_parse("[\"AB\",\"aB\",\"cB\"]")],
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
  guard (try? execute(parse_filter("split(\"a\"; \"z\")"), must_parse("\"a\"")))
    is Err(err) &&
    err.to_string() == "zg is not a valid modifier string" else {
    fail("expected split invalid flags error")
  }
}

///|
test "execute test regex errors" {
  guard (try? execute(parse_filter("test(\"a\")"), must_parse("1"))) is Err(err) &&
    err.to_string() == "number (1) cannot be matched, as it is not a string" else {
    fail("expected test input type error")
  }
  guard (try? execute(parse_filter("test(1)"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "number not a string or array" else {
    fail("expected test pattern type error")
  }
  guard (try? execute(parse_filter("test(\"a\"; 1)"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "test flags must be a string or null" else {
    fail("expected test flags type error")
  }
  guard (try? execute(parse_filter("test(\"a\"; \"z\")"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "z is not a valid modifier string" else {
    fail("expected test invalid flags error")
  }
}

///|
test "execute scan regex errors" {
  guard (try? execute(parse_filter("scan(\"a\")"), must_parse("1"))) is Err(err) &&
    err.to_string() == "number (1) cannot be matched, as it is not a string" else {
    fail("expected scan input type error")
  }
  guard (try? execute(parse_filter("scan(1)"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "number not a string or array" else {
    fail("expected scan pattern type error")
  }
  guard (try? execute(parse_filter("scan(\"a\"; 1)"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "scan flags must be a string or null" else {
    fail("expected scan flags type error")
  }
  guard (try? execute(parse_filter("scan(\"a\"; \"z\")"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "z is not a valid modifier string" else {
    fail("expected scan invalid flags error")
  }
}

///|
test "execute match regex errors" {
  guard (try? execute(parse_filter("match(\"a\")"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "number (1) cannot be matched, as it is not a string" else {
    fail("expected match input type error")
  }
  guard (try? execute(parse_filter("match(1)"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "number not a string or array" else {
    fail("expected match pattern type error")
  }
  guard (try? execute(parse_filter("match(\"a\"; 1)"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "match flags must be a string or null" else {
    fail("expected match flags type error")
  }
  guard (try? execute(
      parse_filter("match(\"a\"; \"z\")"),
      must_parse("\"abc\""),
    ))
    is Err(err) &&
    err.to_string() == "z is not a valid modifier string" else {
    fail("expected match invalid flags error")
  }
}

///|
test "execute capture regex errors" {
  guard (try? execute(parse_filter("capture(\"a\")"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "number (1) cannot be matched, as it is not a string" else {
    fail("expected capture input type error")
  }
  guard (try? execute(parse_filter("capture(1)"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "number not a string or array" else {
    fail("expected capture pattern type error")
  }
  guard (try? execute(parse_filter("capture(\"a\"; 1)"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "capture flags must be a string or null" else {
    fail("expected capture flags type error")
  }
  guard (try? execute(
      parse_filter("capture(\"a\"; \"z\")"),
      must_parse("\"abc\""),
    ))
    is Err(err) &&
    err.to_string() == "z is not a valid modifier string" else {
    fail("expected capture invalid flags error")
  }
}

///|
test "execute sub/gsub regex errors" {
  guard (try? execute(parse_filter("sub(\"a\"; \"x\")"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "number (1) cannot be matched, as it is not a string" else {
    fail("expected sub input type error")
  }
  guard (try? execute(parse_filter("sub(1; \"x\")"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "number not a string or array" else {
    fail("expected sub pattern type error")
  }
  guard (try? execute(parse_filter("sub(\"a\"; 1)"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "sub replacement must be a string" else {
    fail("expected sub replacement type error")
  }
  guard (try? execute(
      parse_filter("sub(\"a\"; \"x\"; 1)"),
      must_parse("\"abc\""),
    ))
    is Err(err) &&
    err.to_string() == "sub flags must be a string or null" else {
    fail("expected sub flags type error")
  }
  guard (try? execute(
      parse_filter("sub(\"a\"; \"x\"; \"z\")"),
      must_parse("\"abc\""),
    ))
    is Err(err) &&
    err.to_string() == "z is not a valid modifier string" else {
    fail("expected sub invalid flags error")
  }
  guard (try? execute(parse_filter("gsub(\"a\"; \"x\")"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "number (1) cannot be matched, as it is not a string" else {
    fail("expected gsub input type error")
  }
  guard (try? execute(parse_filter("gsub(1; \"x\")"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "number not a string or array" else {
    fail("expected gsub pattern type error")
  }
  guard (try? execute(parse_filter("gsub(\"a\"; 1)"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "gsub replacement must be a string" else {
    fail("expected gsub replacement type error")
  }
  guard (try? execute(
      parse_filter("gsub(\"a\"; \"x\"; 1)"),
      must_parse("\"abc\""),
    ))
    is Err(err) &&
    err.to_string() == "gsub flags must be a string or null" else {
    fail("expected gsub flags type error")
  }
  guard (try? execute(
      parse_filter("gsub(\"a\"; \"x\"; \"z\")"),
      must_parse("\"abc\""),
    ))
    is Err(err) &&
    err.to_string() == "zg is not a valid modifier string" else {
    fail("expected gsub invalid flags error")
  }
}

///|
test "execute combinations/date/env/stream compatibility" {
  assert_eq(
    must_execute(parse_filter("combinations"), must_parse("[[1,2], [3,4]]")),
    [
      Value::array([Value::number(1.0), Value::number(3.0)]),
      Value::array([Value::number(1.0), Value::number(4.0)]),
      Value::array([Value::number(2.0), Value::number(3.0)]),
      Value::array([Value::number(2.0), Value::number(4.0)]),
    ],
  )
  assert_eq(
    must_execute(parse_filter("combinations(2)"), must_parse("[0,1]")),
    [
      Value::array([Value::number(0.0), Value::number(0.0)]),
      Value::array([Value::number(0.0), Value::number(1.0)]),
      Value::array([Value::number(1.0), Value::number(0.0)]),
      Value::array([Value::number(1.0), Value::number(1.0)]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("fromdate"),
      must_parse("\"2015-03-05T23:51:47Z\""),
    ),
    [Value::number(1425599507.0)],
  )
  assert_eq(must_execute(parse_filter("env.PAGER"), must_parse("null")), [
    Value::null(),
  ])
  assert_eq(
    must_execute(
      parse_filter("truncate_stream([[0],\"a\"],[[1,0],\"b\"],[[1,0]],[[1]])"),
      must_parse("1"),
    ),
    [
      Value::array([Value::array([Value::number(0.0)]), Value::string("b")]),
      Value::array([Value::array([Value::number(0.0)])]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "fromstream(1|truncate_stream([[0],\"a\"],[[1,0],\"b\"],[[1,0]],[[1]]))",
      ),
      must_parse("null"),
    ),
    [Value::array([Value::string("b")])],
  )
  assert_eq(
    must_execute(
      parse_filter(". as $dot|fromstream($dot|tostream)|.==$dot"),
      must_parse("[0,[1,{\"a\":1},{\"b\":2}]]"),
    ),
    [Value::boolean(true)],
  )
}

///|
test "execute time builtins minimal compatibility" {
  assert_eq(must_execute(parse_filter("gmtime"), must_parse("1425599507")), [
    Value::array([
      Value::number(2015.0),
      Value::number(2.0),
      Value::number(5.0),
      Value::number(23.0),
      Value::number(51.0),
      Value::number(47.0),
      Value::number(4.0),
      Value::number(63.0),
    ]),
  ])
  assert_eq(must_execute(parse_filter("mktime"), must_parse("[2024,8,21]")), [
    Value::number(1726876800.0),
  ])
  assert_eq(
    must_execute(
      parse_filter("strftime(\"%Y-%m-%dT%H:%M:%SZ\")"),
      must_parse("[2024,2,15]"),
    ),
    [Value::string("2024-03-15T00:00:00Z")],
  )
  let localized = must_execute(
    parse_filter("strftime(\"%A, %B %d, %Y\")"),
    must_parse("1435677542.822351"),
  )
  guard localized.length() == 1 else { fail("expected single strftime output") }
  match localized[0] {
    String(s) =>
      if !s.contains("30, 2015") {
        fail("strftime day/year formatting mismatch")
      }
    _ => fail("expected string output from strftime")
  }
  assert_eq(
    must_execute(
      parse_filter("strptime(\"%Y-%m-%dT%H:%M:%SZ\")"),
      must_parse("\"2015-03-05T23:51:47Z\""),
    ),
    [
      Value::array([
        Value::number(2015.0),
        Value::number(2.0),
        Value::number(5.0),
        Value::number(23.0),
        Value::number(51.0),
        Value::number(47.0),
        Value::number(4.0),
        Value::number(63.0),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("strptime(\"%Y-%m-%dT%H:%M:%SZ\")|mktime"),
      must_parse("\"2015-03-05T23:51:47Z\""),
    ),
    [Value::number(1425599507.0)],
  )
  assert_eq(
    must_execute(
      parse_filter("try strftime(\"%Y-%m-%dT%H:%M:%SZ\") catch ."),
      must_parse("[\"a\",1,2,3,4,5,6,7]"),
    ),
    [Value::string("strftime/1 requires parsed datetime inputs")],
  )
  assert_eq(
    must_execute(
      parse_filter("try strflocaltime(\"%Y-%m-%dT%H:%M:%SZ\") catch ."),
      must_parse("[\"a\",1,2,3,4,5,6,7]"),
    ),
    [Value::string("strflocaltime/1 requires parsed datetime inputs")],
  )
  assert_eq(
    must_execute(
      parse_filter("try mktime catch ."),
      must_parse("[\"a\",1,2,3,4,5,6,7]"),
    ),
    [Value::string("mktime requires parsed datetime inputs")],
  )
  assert_eq(
    must_execute(
      parse_filter("try [\"OK\", strftime([])] catch [\"KO\", .]"),
      must_parse("0"),
    ),
    [
      Value::array([
        Value::string("KO"),
        Value::string("strftime/1 requires a string format"),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("try [\"OK\", strflocaltime({})] catch [\"KO\", .]"),
      must_parse("0"),
    ),
    [
      Value::array([
        Value::string("KO"),
        Value::string("strflocaltime/1 requires a string format"),
      ]),
    ],
  )
  assert_eq(
    must_execute(parse_filter("strflocaltime(\"\" | ., @uri)"), must_parse("0")),
    [Value::string(""), Value::string("")],
  )
}

///|
test "execute explode/implode compatibility" {
  assert_eq(must_execute(parse_filter("explode"), must_parse("\"abc\"")), [
    Value::array([Value::number(97.0), Value::number(98.0), Value::number(99.0)]),
  ])
  assert_eq(must_execute(parse_filter("explode"), must_parse("\"あ\"")), [
    Value::array([Value::number(12354.0)]),
  ])
  assert_eq(must_execute(parse_filter("implode"), must_parse("[97,98,99]")), [
    Value::string("abc"),
  ])
  assert_eq(must_execute(parse_filter("implode"), must_parse("[12354]")), [
    Value::string("あ"),
  ])
  assert_eq(must_execute(parse_filter("implode"), must_parse("[]")), [
    Value::string(""),
  ])
  assert_eq(must_execute(parse_filter("implode"), must_parse("[-1]")), [
    Value::string("\u{fffd}"),
  ])
  assert_eq(must_execute(parse_filter("implode"), must_parse("[97.9]")), [
    Value::string("a"),
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
    [Value::number(2.0)],
  )
  assert_eq(
    must_execute(parse_filter("rindex(\"l\")"), must_parse("\"hello\"")),
    [Value::number(3.0)],
  )
  assert_eq(
    must_execute(parse_filter("indices(\"l\")"), must_parse("\"hello\"")),
    [Value::array([Value::number(2.0), Value::number(3.0)])],
  )
  assert_eq(
    must_execute(parse_filter("index(\"z\")"), must_parse("\"hello\"")),
    [Value::null()],
  )
  assert_eq(
    must_execute(parse_filter("indices(\"z\")"), must_parse("\"hello\"")),
    [Value::array([])],
  )
  assert_eq(
    must_execute(parse_filter("indices(\"aa\")"), must_parse("\"aaa\"")),
    [Value::array([Value::number(0.0), Value::number(1.0)])],
  )
  assert_eq(
    must_execute(parse_filter("indices(\"o\")"), must_parse("\"🇬🇧oo\"")),
    [Value::array([Value::number(2.0), Value::number(3.0)])],
  )
  assert_eq(
    must_execute(
      parse_filter("_strindices(\"aba\")"),
      must_parse("\"xababababax\""),
    ),
    [
      Value::array([
        Value::number(1.0),
        Value::number(3.0),
        Value::number(5.0),
        Value::number(7.0),
      ]),
    ],
  )
  assert_eq(
    must_execute(parse_filter("index((\"l\",\"e\"))"), must_parse("\"hello\"")),
    [Value::number(2.0), Value::number(1.0)],
  )
  assert_eq(
    must_execute(parse_filter("index(empty)"), must_parse("\"hello\"")),
    [],
  )
  let arr = must_parse("[1,2,1,3]")
  assert_eq(must_execute(parse_filter("index(1)"), arr), [Value::number(0.0)])
  assert_eq(must_execute(parse_filter("rindex(1)"), arr), [Value::number(2.0)])
  assert_eq(must_execute(parse_filter("indices(1)"), arr), [
    Value::array([Value::number(0.0), Value::number(2.0)]),
  ])
  assert_eq(must_execute(parse_filter("index([1,3])"), arr), [
    Value::number(2.0),
  ])
  assert_eq(must_execute(parse_filter("indices([1,3])"), arr), [
    Value::array([Value::number(2.0)]),
  ])
  assert_eq(must_execute(parse_filter("index(\"1\")"), must_parse("[1,2]")), [
    Value::null(),
  ])
  assert_eq(must_execute(parse_filter("indices([])"), must_parse("[1,2,3]")), [
    Value::array([]),
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
  guard (try? execute(parse_filter("_strindices(\"abc\")"), must_parse("123")))
    is Err(err) &&
    err.to_string() == "number (123) cannot be searched, as it is not a string" else {
    fail("expected _strindices input type error")
  }
  guard (try? execute(parse_filter("_strindices(123)"), must_parse("\"abc\"")))
    is Err(err) &&
    err.to_string() == "number (123) is not a string" else {
    fail("expected _strindices pattern type error")
  }
}

///|
test "execute bsearch compatibility" {
  assert_eq(must_execute(parse_filter("bsearch(1)"), must_parse("[1,3,5]")), [
    Value::number(0.0),
  ])
  assert_eq(must_execute(parse_filter("bsearch(2)"), must_parse("[1,3,5]")), [
    Value::number(-2.0),
  ])
  assert_eq(must_execute(parse_filter("bsearch(5)"), must_parse("[1,3,5]")), [
    Value::number(2.0),
  ])
  assert_eq(must_execute(parse_filter("bsearch(6)"), must_parse("[1,3,5]")), [
    Value::number(-4.0),
  ])
  assert_eq(must_execute(parse_filter("bsearch(0)"), must_parse("[1,3,5]")), [
    Value::number(-1.0),
  ])
  assert_eq(must_execute(parse_filter("bsearch(1)"), must_parse("[]")), [
    Value::number(-1.0),
  ])
  assert_eq(must_execute(parse_filter("bsearch(1)"), must_parse("[1,1,1]")), [
    Value::number(1.0),
  ])
  assert_eq(
    must_execute(parse_filter("bsearch((2,5))"), must_parse("[1,3,5]")),
    [Value::number(-2.0), Value::number(2.0)],
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
    [Value::number(4.0)],
  )
  assert_eq(must_execute(parse_filter("bsearch([2])"), must_parse("[1,3,5]")), [
    Value::number(-4.0),
  ])
}

///|
test "execute range/limit/skip/IN compatibility" {
  let null_json = must_parse("null")
  assert_eq(must_execute(parse_filter("[range(0;10)]"), null_json), [
    Value::array([
      Value::number(0.0),
      Value::number(1.0),
      Value::number(2.0),
      Value::number(3.0),
      Value::number(4.0),
      Value::number(5.0),
      Value::number(6.0),
      Value::number(7.0),
      Value::number(8.0),
      Value::number(9.0),
    ]),
  ])
  assert_eq(must_execute(parse_filter("[range(0;10;3)]"), null_json), [
    Value::array([
      Value::number(0.0),
      Value::number(3.0),
      Value::number(6.0),
      Value::number(9.0),
    ]),
  ])
  assert_eq(must_execute(parse_filter("[range(3,5)]"), null_json), [
    Value::array([
      Value::number(0.0),
      Value::number(1.0),
      Value::number(2.0),
      Value::number(0.0),
      Value::number(1.0),
      Value::number(2.0),
      Value::number(3.0),
      Value::number(4.0),
    ]),
  ])

  assert_eq(
    must_execute(
      parse_filter("[limit(3; .[])]"),
      must_parse("[11,22,33,44,55,66,77,88,99]"),
    ),
    [
      Value::array([
        Value::number(11.0),
        Value::number(22.0),
        Value::number(33.0),
      ]),
    ],
  )
  assert_eq(must_execute(parse_filter("[limit(0; error)]"), null_json), [
    Value::array([]),
  ])
  assert_eq(
    must_execute(parse_filter("[limit(1; 1,error(\"foo\"))]"), null_json),
    [Value::array([Value::number(1.0)])],
  )

  assert_eq(
    must_execute(
      parse_filter("[skip(3; .[])]"),
      must_parse("[1,2,3,4,5,6,7,8,9]"),
    ),
    [
      Value::array([
        Value::number(4.0),
        Value::number(5.0),
        Value::number(6.0),
        Value::number(7.0),
        Value::number(8.0),
        Value::number(9.0),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("[skip(0,2,3,4; .[])]"),
      must_parse("[1,2,3,4,5,6,7,8,9]"),
    ),
    [
      Value::array([
        Value::number(1.0),
        Value::number(2.0),
        Value::number(3.0),
        Value::number(4.0),
        Value::number(5.0),
        Value::number(6.0),
        Value::number(7.0),
        Value::number(8.0),
        Value::number(9.0),
        Value::number(3.0),
        Value::number(4.0),
        Value::number(5.0),
        Value::number(6.0),
        Value::number(7.0),
        Value::number(8.0),
        Value::number(9.0),
        Value::number(4.0),
        Value::number(5.0),
        Value::number(6.0),
        Value::number(7.0),
        Value::number(8.0),
        Value::number(9.0),
        Value::number(5.0),
        Value::number(6.0),
        Value::number(7.0),
        Value::number(8.0),
        Value::number(9.0),
      ]),
    ],
  )

  assert_eq(
    must_execute(parse_filter("range(5;10)|IN(range(10))"), null_json),
    [
      Value::boolean(true),
      Value::boolean(true),
      Value::boolean(true),
      Value::boolean(true),
      Value::boolean(true),
    ],
  )
  assert_eq(
    must_execute(parse_filter("IN(range(10;20); range(10))"), null_json),
    [Value::boolean(false)],
  )
  assert_eq(
    must_execute(parse_filter("IN(range(5;20); range(10))"), null_json),
    [Value::boolean(true)],
  )
  assert_eq(
    must_execute(
      parse_filter("INDEX(range(5)|[., \"foo\\(.)\"]; .[0])"),
      null_json,
    ),
    [
      Value::object({
        "0": Value::array([Value::number(0.0), Value::string("foo0")]),
        "1": Value::array([Value::number(1.0), Value::string("foo1")]),
        "2": Value::array([Value::number(2.0), Value::string("foo2")]),
        "3": Value::array([Value::number(3.0), Value::string("foo3")]),
        "4": Value::array([Value::number(4.0), Value::string("foo4")]),
      }),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "JOIN({\"0\":[0,\"abc\"],\"1\":[1,\"bcd\"],\"2\":[2,\"def\"],\"3\":[3,\"efg\"],\"4\":[4,\"fgh\"]}; .[0]|tostring)",
      ),
      must_parse("[[5,\"foo\"],[3,\"bar\"],[1,\"foobar\"]]"),
    ),
    [
      must_parse(
        "[[[5,\"foo\"],null],[[3,\"bar\"],[3,\"efg\"]],[[1,\"foobar\"],[1,\"bcd\"]]]",
      ),
    ],
  )
}

///|
test "execute label/break compatibility" {
  assert_eq(
    must_execute(
      parse_filter(
        "[(label $here | .[] | if .>1 then break $here else . end), \"hi!\"]",
      ),
      must_parse("[0,1,2]"),
    ),
    [must_parse("[0,1,\"hi!\"]")],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "[(label $here | .[] | if .>1 then break $here else . end), \"hi!\"]",
      ),
      must_parse("[0,2,1]"),
    ),
    [must_parse("[0,\"hi!\"]")],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "[label $out | foreach .[] as $item ([3, null]; if .[0] < 1 then break $out else [.[0] -1, $item] end; .[1])]",
      ),
      must_parse("[11,22,33,44,55,66,77,88,99]"),
    ),
    [must_parse("[11,22,33]")],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "[ label $if | range(10) | ., (select(. == 5) | break $if) ]",
      ),
      must_parse("null"),
    ),
    [must_parse("[0,1,2,3,4,5]")],
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
  assert_eq(must_execute(f1, j), [Value::boolean(true)])
  assert_eq(must_execute(f2, j), [Value::boolean(true)])
}

///|
test "execute compare stream cross product" {
  let j = must_parse("null")
  assert_eq(must_execute(parse_filter("(1,2) == (1,2)"), j), [
    Value::boolean(true),
    Value::boolean(false),
    Value::boolean(false),
    Value::boolean(true),
  ])
  assert_eq(must_execute(parse_filter("(empty) == 1"), j), [])
}

///|
test "execute compare order and logical" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  assert_eq(must_execute(parse_filter(".a < .b"), j), [Value::boolean(true)])
  assert_eq(must_execute(parse_filter(".a >= .b"), j), [Value::boolean(false)])
  assert_eq(must_execute(parse_filter("null >= 0"), j), [Value::boolean(false)])
  assert_eq(must_execute(parse_filter("null < false"), j), [
    Value::boolean(true),
  ])
  assert_eq(must_execute(parse_filter("true < 0"), j), [Value::boolean(true)])
  assert_eq(must_execute(parse_filter("\"a\" > 0"), j), [Value::boolean(true)])
  assert_eq(must_execute(parse_filter("select(. >= 0)"), must_parse("null")), [])
  assert_eq(must_execute(parse_filter(". > .00005"), must_parse("0.0001")), [
    Value::boolean(true),
  ])
  assert_eq(must_execute(parse_filter(". > .00005"), must_parse("0.0")), [
    Value::boolean(false),
  ])
  assert_eq(must_execute(parse_filter(".a and .b"), j), [Value::boolean(true)])
  assert_eq(must_execute(parse_filter("not .b"), j), [Value::boolean(false)])
  assert_eq(must_execute(parse_filter(".a or .b"), j), [Value::boolean(true)])
  let n = must_parse("null")
  assert_eq(must_execute(parse_filter("(true, false) or false"), n), [
    Value::boolean(true),
    Value::boolean(false),
  ])
  assert_eq(must_execute(parse_filter("(true, true) and (true, false)"), n), [
    Value::boolean(true),
    Value::boolean(false),
    Value::boolean(true),
    Value::boolean(false),
  ])
  assert_eq(must_execute(parse_filter("not (true,false)"), n), [
    Value::boolean(false),
    Value::boolean(true),
  ])
}

///|
test "execute arithmetic" {
  let j = must_parse("{\"a\":1,\"b\":2,\"c\":3}")
  assert_eq(must_execute(parse_filter(".a + .b"), j), [Value::number(3.0)])
  assert_eq(must_execute(parse_filter(".c - .a"), j), [Value::number(2.0)])
  assert_eq(must_execute(parse_filter(".a * .b"), j), [Value::number(2.0)])
  assert_eq(must_execute(parse_filter(".c / .a"), j), [Value::number(3.0)])
  assert_eq(must_execute(parse_filter("\"a,b,c\" / \",\""), j), [
    Value::array([Value::string("a"), Value::string("b"), Value::string("c")]),
  ])
  assert_eq(must_execute(parse_filter("\"a, b,c,d, e\" / \", \""), j), [
    Value::array([
      Value::string("a"),
      Value::string("b,c,d"),
      Value::string("e"),
    ]),
  ])
  assert_eq(must_execute(parse_filter("10 % 3"), j), [Value::number(1.0)])
  assert_eq(
    must_execute(parse_filter("[(infinite, -infinite) % (1, -1, infinite)]"), j),
    [
      Value::array([
        Value::number(0.0),
        Value::number(0.0),
        Value::number(0.0),
        Value::number(0.0),
        Value::number(0.0),
        Value::number(-1.0),
      ]),
    ],
  )
  assert_eq(must_execute(parse_filter("(1 / 1e-17) | tojson"), j), [
    Value::string("1e+17"),
  ])
  assert_eq(
    must_execute(
      parse_filter(
        "(9E999999999|tojson), (9999999999E999999990|tojson), (1E-999999999|tojson), (0.000000001E-999999990|tojson)",
      ),
      j,
    ),
    [
      Value::string("1.7976931348623157e+308"),
      Value::string("1.7976931348623157e+308"),
      Value::string("0"),
      Value::string("0"),
    ],
  )
  assert_eq(must_execute(parse_filter("-."), must_parse("3")), [
    Value::number(-3.0),
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
  assert_eq(must_execute(parse_filter("\"ab\" * 2"), j), [Value::string("abab")])
  assert_eq(must_execute(parse_filter("2 * \"ab\""), j), [Value::string("abab")])
  assert_eq(must_execute(parse_filter("\"ab\" * 2.9"), j), [
    Value::string("abab"),
  ])
  assert_eq(must_execute(parse_filter("\"ab\" * 0"), j), [Value::string("")])
  assert_eq(must_execute(parse_filter("\"ab\" * -1"), j), [Value::null()])
  assert_eq(
    must_execute(parse_filter("{\"a\":{\"x\":1}} * {\"a\":{\"y\":2}}"), j),
    [
      Value::object({
        "a": Value::object({ "x": Value::number(1.0), "y": Value::number(2.0) }),
      }),
    ],
  )
  assert_eq(must_execute(parse_filter("{\"a\":{\"x\":1}} * {\"a\":2}"), j), [
    Value::object({ "a": Value::number(2.0) }),
  ])
  assert_eq(must_execute(parse_filter("{\"a\":1} * {\"b\":2}"), j), [
    Value::object({ "a": Value::number(1.0), "b": Value::number(2.0) }),
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
    Value::array([Value::number(1.0), Value::number(3.0)]),
  ])
  assert_eq(must_execute(parse_filter("[1,{\"a\":1}] - [{\"a\":1}]"), j), [
    Value::array([Value::number(1.0)]),
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
test "execute arithmetic type errors include full json values" {
  let j = must_parse("null")
  guard (try? execute(parse_filter("[1,2,3] + {\"a\":[1,2,3]}"), j)) is Err(err) &&
    err.to_string() ==
    "array ([1,2,3]) and object ({\"a\":[1,2,3]}) cannot be added" else {
    fail("expected full-value add type error")
  }
  guard (try? execute(parse_filter("[1,2,3] / {\"a\":[1,2,3]}"), j)) is Err(err) &&
    err.to_string() ==
    "array ([1,2,3]) and object ({\"a\":[1,2,3]}) cannot be divided" else {
    fail("expected full-value divide type error")
  }
}

///|
test "execute arithmetic stream cross product" {
  let j = must_parse("null")
  assert_eq(must_execute(parse_filter("(1,2) + (10,20)"), j), [
    Value::number(11.0),
    Value::number(12.0),
    Value::number(21.0),
    Value::number(22.0),
  ])
  assert_eq(must_execute(parse_filter("(empty) + 1"), j), [])
}

///|
test "execute add arrays and objects" {
  let j = must_parse("{\"a\":[1],\"b\":[2],\"x\":{\"k\":1},\"y\":{\"k\":2}}")
  assert_eq(must_execute(parse_filter(".a + .b"), j), [
    Value::array([Value::number(1.0), Value::number(2.0)]),
  ])
  assert_eq(must_execute(parse_filter(".x + .y"), j), [
    Value::object({ "k": Value::number(2.0) }),
  ])
}

///|
test "execute add null identity compatibility" {
  let j = must_parse("null")
  assert_eq(must_execute(parse_filter("null + 1"), j), [Value::number(1.0)])
  assert_eq(must_execute(parse_filter("1 + null"), j), [Value::number(1.0)])
  assert_eq(must_execute(parse_filter("null + null"), j), [Value::null()])
  assert_eq(must_execute(parse_filter("true + null"), j), [Value::boolean(true)])
  assert_eq(must_execute(parse_filter("null + [1]"), j), [
    Value::array([Value::number(1.0)]),
  ])
  assert_eq(must_execute(parse_filter("{\"a\":1} + null"), j), [
    Value::object({ "a": Value::number(1.0) }),
  ])
}

///|
test "execute update assignment compatibility" {
  let obj = must_parse("{\"a\":1,\"b\":2}")
  assert_eq(must_execute(parse_filter(".a |= . + 1"), obj), [
    Value::object({ "a": Value::number(2.0), "b": Value::number(2.0) }),
  ])
  assert_eq(must_execute(parse_filter(".a += 4"), must_parse("{\"a\":1}")), [
    Value::object({ "a": Value::number(5.0) }),
  ])
  assert_eq(
    must_execute(parse_filter(".a //= 9"), must_parse("{\"a\":null}")),
    [Value::object({ "a": Value::number(9.0) })],
  )
  assert_eq(must_execute(parse_filter(".[1] *= 10"), must_parse("[1,2,3]")), [
    Value::array([Value::number(1.0), Value::number(20.0), Value::number(3.0)]),
  ])
  assert_eq(
    must_execute(parse_filter(".a.b |= . + 1"), must_parse("{\"a\":{\"b\":1}}")),
    [Value::object({ "a": Value::object({ "b": Value::number(2.0) }) })],
  )
  assert_eq(
    must_execute(parse_filter(".a.b //= 9"), must_parse("{\"a\":{}}")),
    [Value::object({ "a": Value::object({ "b": Value::number(9.0) }) })],
  )
  assert_eq(
    must_execute(parse_filter(".a |= select(. >= 0)"), must_parse("null")),
    [Value::null()],
  )
  assert_eq(
    must_execute(
      parse_filter(".a |= select(. >= 0)"),
      must_parse("{\"a\":null}"),
    ),
    [Value::object({})],
  )
  assert_eq(must_execute(parse_filter(".[2] += 5"), must_parse("[]")), [
    Value::array([Value::null(), Value::null(), Value::number(5.0)]),
  ])
  assert_eq(must_execute(parse_filter(".[-1] += 1"), must_parse("[1,2,3]")), [
    Value::array([Value::number(1.0), Value::number(2.0), Value::number(4.0)]),
  ])
  assert_eq(must_execute(parse_filter(".a = 9"), must_parse("{\"a\":1}")), [
    Value::object({ "a": Value::number(9.0) }),
  ])
  assert_eq(
    must_execute(parse_filter(".foo = .bar"), must_parse("{\"bar\":42}")),
    [Value::object({ "bar": Value::number(42.0), "foo": Value::number(42.0) })],
  )
  assert_eq(
    must_execute(
      parse_filter(".a = .b"),
      must_parse("{\"a\":{\"b\":10},\"b\":20}"),
    ),
    [Value::object({ "a": Value::number(20.0), "b": Value::number(20.0) })],
  )
  assert_eq(
    must_execute(parse_filter(".foo += .foo"), must_parse("{\"foo\":2}")),
    [Value::object({ "foo": Value::number(4.0) })],
  )
  assert_eq(
    must_execute(parse_filter("(.a,.b) = range(3)"), must_parse("null")),
    [
      Value::object({ "a": Value::number(0.0), "b": Value::number(0.0) }),
      Value::object({ "a": Value::number(1.0), "b": Value::number(1.0) }),
      Value::object({ "a": Value::number(2.0), "b": Value::number(2.0) }),
    ],
  )
  assert_eq(
    must_execute(parse_filter("(.a,.b) |= range(3)"), must_parse("null")),
    [Value::object({ "a": Value::number(0.0), "b": Value::number(0.0) })],
  )
  assert_eq(
    must_execute(parse_filter("(.a,.a) |= . + 1"), must_parse("{\"a\":0}")),
    [Value::object({ "a": Value::number(2.0) })],
  )
  assert_eq(
    must_execute(parse_filter("(.a,.b) += (1,2)"), must_parse("null")),
    [
      Value::object({ "a": Value::number(1.0), "b": Value::number(1.0) }),
      Value::object({ "a": Value::number(2.0), "b": Value::number(2.0) }),
    ],
  )
  assert_eq(must_execute(parse_filter(".[] += .[0]"), must_parse("[1,2]")), [
    Value::array([Value::number(2.0), Value::number(3.0)]),
  ])
  assert_eq(
    must_execute(
      parse_filter(
        "reduce range(65540;65536;-1) as $i ([]; .[$i] = $i)|.[65536:]",
      ),
      must_parse("null"),
    ),
    [
      Value::array([
        Value::null(),
        Value::number(65537.0),
        Value::number(65538.0),
        Value::number(65539.0),
        Value::number(65540.0),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("(.a as $x | .b) = \"b\""),
      must_parse("{\"a\":null,\"b\":null}"),
    ),
    [Value::object({ "a": Value::null(), "b": Value::string("b") })],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "bsearch(4) as $ix | if $ix < 0 then .[-(1+$ix)] = 4 else . end",
      ),
      must_parse("[1,2,3]"),
    ),
    [
      Value::array([
        Value::number(1.0),
        Value::number(2.0),
        Value::number(3.0),
        Value::number(4.0),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter(".[2:4] = ([], [\"a\",\"b\"], [\"a\",\"b\",\"c\"])"),
      must_parse("[0,1,2,3,4,5,6,7]"),
    ),
    [
      Value::array([
        Value::number(0.0),
        Value::number(1.0),
        Value::number(4.0),
        Value::number(5.0),
        Value::number(6.0),
        Value::number(7.0),
      ]),
      Value::array([
        Value::number(0.0),
        Value::number(1.0),
        Value::string("a"),
        Value::string("b"),
        Value::number(4.0),
        Value::number(5.0),
        Value::number(6.0),
        Value::number(7.0),
      ]),
      Value::array([
        Value::number(0.0),
        Value::number(1.0),
        Value::string("a"),
        Value::string("b"),
        Value::string("c"),
        Value::number(4.0),
        Value::number(5.0),
        Value::number(6.0),
        Value::number(7.0),
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
    [Value::string("Cannot update string slices")],
  )
  assert_eq(
    must_execute(
      parse_filter("try ([range(3)] | .[nan] = 9) catch ."),
      must_parse("null"),
    ),
    [Value::string("Cannot set array element at NaN index")],
  )
  assert_eq(
    must_execute(
      parse_filter("try ([range(10)] | .[1.5:3.5] = [\"xyz\"]) catch ."),
      must_parse("null"),
    ),
    [
      Value::array([
        Value::number(0.0),
        Value::string("xyz"),
        Value::number(4.0),
        Value::number(5.0),
        Value::number(6.0),
        Value::number(7.0),
        Value::number(8.0),
        Value::number(9.0),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("(.[] | select(. >= 2)) |= empty"),
      must_parse("[1,5,3,0,7]"),
    ),
    [Value::array([Value::number(1.0), Value::number(0.0)])],
  )
  assert_eq(
    must_execute(
      parse_filter(".[] |= select(. % 2 == 0)"),
      must_parse("[0,1,2,3,4,5]"),
    ),
    [Value::array([Value::number(0.0), Value::number(2.0), Value::number(4.0)])],
  )
  assert_eq(
    must_execute(
      parse_filter(".foo[1,4,2,3] |= empty"),
      must_parse("{\"foo\":[0,1,2,3,4,5]}"),
    ),
    [
      Value::object({
        "foo": Value::array([Value::number(0.0), Value::number(5.0)]),
      }),
    ],
  )
  assert_eq(
    must_execute(parse_filter(".[1:2] |= empty"), must_parse("[1,2,3]")),
    [Value::array([Value::number(1.0), Value::number(3.0)])],
  )
  assert_eq(
    must_execute(
      parse_filter(".[] |= try tonumber"),
      must_parse(
        "[\"1\", \"2a\", \"3\", \" 4\", \"5 \", \"6.7\", \".89\", \"-876\", \"+5.43\", 21]",
      ),
    ),
    [
      Value::array([
        Value::number(1.0),
        Value::number(3.0),
        Value::number(6.7),
        Value::number(0.89),
        Value::number(-876.0),
        Value::number(5.43),
        Value::number(21.0),
      ]),
    ],
  )
  assert_eq(must_execute(parse_filter(".a %= 4"), must_parse("{\"a\":9}")), [
    Value::object({ "a": Value::number(1.0) }),
  ])
}

///|
test "execute update assignment dynamic slice compatibility" {
  assert_eq(
    must_execute(
      parse_filter("1 as $s | 3 as $e | .[$s:$e] = [9]"),
      must_parse("[0,1,2,3,4]"),
    ),
    [
      Value::array([
        Value::number(0.0),
        Value::number(9.0),
        Value::number(3.0),
        Value::number(4.0),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("1 as $s | 4 as $e | .[$s:$e] |= map(.+10)"),
      must_parse("[0,1,2,3,4]"),
    ),
    [
      Value::array([
        Value::number(0.0),
        Value::number(11.0),
        Value::number(12.0),
        Value::number(13.0),
        Value::number(4.0),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("1 as $s | 4 as $e | .[$s:$e] |= empty"),
      must_parse("[0,1,2,3,4]"),
    ),
    [Value::array([Value::number(0.0), Value::number(4.0)])],
  )
  assert_eq(
    must_execute(
      parse_filter("1 as $s | 4 as $e | .a[$s:$e] += [9]"),
      must_parse("{\"a\":[0,1,2,3,4]}"),
    ),
    [
      Value::object({
        "a": Value::array([
          Value::number(0.0),
          Value::number(1.0),
          Value::number(2.0),
          Value::number(3.0),
          Value::number(9.0),
          Value::number(4.0),
        ]),
      }),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("(.[] | .[1:3]) |= map(.+100)"),
      must_parse("[[0,1,2,3],[4,5,6,7]]"),
    ),
    [
      Value::array([
        Value::array([
          Value::number(0.0),
          Value::number(101.0),
          Value::number(102.0),
          Value::number(3.0),
        ]),
        Value::array([
          Value::number(4.0),
          Value::number(105.0),
          Value::number(106.0),
          Value::number(7.0),
        ]),
      ]),
    ],
  )
  guard (try? execute(
      parse_filter("(.[] | .[1:3]) |= . + 100"),
      must_parse("[[0,1,2,3],[4,5,6,7]]"),
    ))
    is Err(err) &&
    err.to_string() == "array ([1,2]) and number (100) cannot be added" else {
    fail("expected jq-compatible dynamic slice update type error")
  }
}

///|
test "execute object literal stream product" {
  let j = must_parse("null")
  assert_eq(must_execute(parse_filter("{a:(1,2)}"), j), [
    Value::object({ "a": Value::number(1.0) }),
    Value::object({ "a": Value::number(2.0) }),
  ])
  assert_eq(must_execute(parse_filter("{a:(1,2), b:(3,4)}"), j), [
    Value::object({ "a": Value::number(1.0), "b": Value::number(3.0) }),
    Value::object({ "a": Value::number(1.0), "b": Value::number(4.0) }),
    Value::object({ "a": Value::number(2.0), "b": Value::number(3.0) }),
    Value::object({ "a": Value::number(2.0), "b": Value::number(4.0) }),
  ])
  assert_eq(must_execute(parse_filter("{a:(empty)}"), j), [])
}

///|
test "execute map" {
  let j = must_parse("[1,2,3]")
  assert_eq(must_execute(parse_filter("map(. + 1)"), j), [
    Value::array([Value::number(2.0), Value::number(3.0), Value::number(4.0)]),
  ])
}

///|
test "execute map object compatibility" {
  let j = must_parse("{\"a\":1}")
  assert_eq(must_execute(parse_filter("map(. + 1)"), j), [
    Value::array([Value::number(2.0)]),
  ])
  assert_eq(must_execute(parse_filter("map((., . + 1))"), j), [
    Value::array([Value::number(1.0), Value::number(2.0)]),
  ])
  assert_eq(must_execute(parse_filter("map(select(. > 1))"), j), [
    Value::array([]),
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
    Value::object({ "b": Value::number(2.0) }),
  ])
  assert_eq(must_execute(parse_filter("map_values((., . + 1))"), obj), [
    Value::object({ "a": Value::number(1.0), "b": Value::number(2.0) }),
  ])
  let arr = must_parse("[1,2,3]")
  assert_eq(must_execute(parse_filter("map_values(. + 1)"), arr), [
    Value::array([Value::number(2.0), Value::number(3.0), Value::number(4.0)]),
  ])
  assert_eq(must_execute(parse_filter("map_values(select(. > 1))"), arr), [
    Value::array([Value::number(2.0), Value::number(3.0)]),
  ])
  assert_eq(must_execute(parse_filter("map_values((., . + 1))"), arr), [
    Value::array([Value::number(1.0), Value::number(2.0), Value::number(3.0)]),
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
  assert_eq(must_execute(parse_filter(".a as $x | $x"), j), [Value::number(1.0)])
  assert_eq(must_execute(parse_filter(".a as $x | .b"), j), [Value::number(2.0)])
  assert_eq(must_execute(parse_filter(".a as $x | $x + 1"), j), [
    Value::number(2.0),
  ])
  assert_eq(
    must_execute(parse_filter(". as $x | $x[]"), must_parse("[1,2,3]")),
    [Value::number(1.0), Value::number(2.0), Value::number(3.0)],
  )
  assert_eq(
    must_execute(parse_filter("[-1 as $x | 1,$x]"), must_parse("null")),
    [Value::array([Value::number(1.0), Value::number(-1.0)])],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "[\"foo\",1] as $p | getpath($p), setpath($p; 20), delpaths([$p])",
      ),
      must_parse("{\"bar\":42, \"foo\":[\"a\", \"b\", \"c\", \"d\"]}"),
    ),
    [
      Value::string("b"),
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
      Value::array([Value::null(), Value::number(1.0)]),
      Value::array([Value::number(2.0), Value::number(1.0)]),
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
    [Value::number(1.0), Value::number(2.0)],
  )
  assert_eq(
    must_execute(
      parse_filter("[1, {c:3, d:4}] as [$a, {c:$b, b:$c}] | $a, $b, $c"),
      must_parse("null"),
    ),
    [Value::number(1.0), Value::number(3.0), Value::null()],
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
    [Value::number(3.0)],
  )
}

///|
test "execute special variables compatibility" {
  assert_eq(must_execute(parse_filter("$ENV.PAGER"), must_parse("null")), [
    Value::null(),
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
    [Value::number(4.0)],
  )
  assert_eq(
    must_execute(
      parse_filter("[1,2,3][] as $x | [4,5,6,7][$x]"),
      must_parse("null"),
    ),
    [Value::number(5.0), Value::number(6.0), Value::number(7.0)],
  )
  assert_eq(
    must_execute(parse_filter("[][.]"), must_parse("1000000000000000000")),
    [Value::null()],
  )
  assert_eq(
    must_execute(parse_filter("[range(5)] | .[1.1]"), must_parse("null")),
    [Value::number(1.0)],
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
    Value::string("hi"),
  ])
  assert_eq(must_execute(parse_filter("try (.a + 1) catch ."), j), [
    Value::string("string (\"hi\") and number (1) cannot be added"),
  ])
  assert_eq(
    must_execute(parse_filter("try error(\"boom\") catch (. + \"!\")"), j),
    [Value::string("boom!")],
  )
  assert_eq(
    must_execute(parse_filter("try 2 catch 3 + 4"), must_parse("null")),
    [Value::number(6.0)],
  )
  assert_eq(
    must_execute(parse_filter("1 + try 2 catch 3 + 4"), must_parse("null")),
    [Value::number(7.0)],
  )
  assert_eq(
    must_execute(
      parse_filter("1 + try error(0) catch 3 + 4"),
      must_parse("null"),
    ),
    [Value::number(8.0)],
  )
  assert_eq(
    must_execute(
      parse_filter("try (.[999999999] = 0) catch ."),
      must_parse("null"),
    ),
    [Value::string("Array index too large")],
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
    [Value::string("string (\"very-long-...) cannot be negated")],
  )
  assert_eq(
    must_execute(
      parse_filter("try (.-.) catch ."),
      must_parse("\"very-long-string\""),
    ),
    [
      Value::string(
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
    [Value::string("hi"), Value::string("caught ho")],
  )
  assert_eq(must_execute(parse_filter("[(.*2, error)?]"), must_parse("1")), [
    Value::array([Value::number(2.0)]),
  ])
  assert_eq(
    must_execute(parse_filter("[repeat(.*2, error)?]"), must_parse("1")),
    [Value::array([Value::number(2.0)])],
  )
}

///|
test "execute reduce/foreach" {
  let j = must_parse("[1,2,3]")
  assert_eq(must_execute(parse_filter("reduce .[] as $x (0; . + $x)"), j), [
    Value::number(6.0),
  ])
  assert_eq(must_execute(parse_filter("foreach .[] as $x (0; . + $x)"), j), [
    Value::number(1.0),
    Value::number(3.0),
    Value::number(6.0),
  ])
  assert_eq(must_execute(parse_filter("foreach .[] as $x (0; . + $x; .)"), j), [
    Value::number(1.0),
    Value::number(3.0),
    Value::number(6.0),
  ])
  assert_eq(
    must_execute(
      parse_filter("reduce .[] as [$i,$j] (0; . + $i * $j)"),
      must_parse("[[1,2],[3,4],[5,6]]"),
    ),
    [Value::number(44.0)],
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
    [
      Value::number(1.0),
      Value::number(3.0),
      Value::number(2.0),
      Value::number(4.0),
    ],
  )
}

///|
test "execute if-then-else" {
  let j = must_parse("{\"a\":true,\"b\":1,\"c\":2}")
  assert_eq(must_execute(parse_filter("if .a then .b else .c end"), j), [
    Value::number(1.0),
  ])
  let j2 = must_parse("{\"a\":null,\"b\":1,\"c\":2}")
  assert_eq(must_execute(parse_filter("if .a then .b else .c end"), j2), [
    Value::number(2.0),
  ])
  let j3 = must_parse("{\"a\":false,\"c\":true,\"d\":3,\"e\":4}")
  assert_eq(
    must_execute(parse_filter("if .a then .b elif .c then .d else .e end"), j3),
    [Value::number(3.0)],
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
    [Value::array([])],
  )
  assert_eq(
    must_execute(parse_filter("[if false then 3 end]"), must_parse("7")),
    [must_parse("[7]")],
  )
}

///|
test "execute fallback and empty" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  assert_eq(must_execute(parse_filter(".a // .b"), j), [Value::number(1.0)])
  assert_eq(must_execute(parse_filter("empty // .b"), j), [Value::number(2.0)])
  assert_eq(must_execute(parse_filter("empty"), j), [])
}

///|
test "execute fallback jq semantics with null/false and streams" {
  let j = must_parse("null")
  assert_eq(must_execute(parse_filter("null // 1"), j), [Value::number(1.0)])
  assert_eq(must_execute(parse_filter("false // 1"), j), [Value::number(1.0)])
  assert_eq(must_execute(parse_filter("true // 1"), j), [Value::boolean(true)])
  assert_eq(must_execute(parse_filter("[false,1] | .[] // 9"), j), [
    Value::number(1.0),
  ])
  assert_eq(must_execute(parse_filter("[null,false] | .[] // 9"), j), [
    Value::number(9.0),
  ])
  assert_eq(must_execute(parse_filter("(1,2) // 9"), j), [
    Value::number(1.0),
    Value::number(2.0),
  ])
}

///|
test "execute string contains/starts/ends" {
  let j = must_parse("\"hello\"")
  assert_eq(must_execute(parse_filter("contains(\"ell\")"), j), [
    Value::boolean(true),
  ])
  assert_eq(must_execute(parse_filter("contains((\"he\",\"zz\"))"), j), [
    Value::boolean(true),
    Value::boolean(false),
  ])
  assert_eq(must_execute(parse_filter("contains(empty)"), j), [])
  assert_eq(must_execute(parse_filter("startswith(\"he\")"), j), [
    Value::boolean(true),
  ])
  assert_eq(must_execute(parse_filter("startswith((\"h\",\"x\"))"), j), [
    Value::boolean(true),
    Value::boolean(false),
  ])
  assert_eq(must_execute(parse_filter("startswith(empty)"), j), [])
  assert_eq(must_execute(parse_filter("endswith(\"lo\")"), j), [
    Value::boolean(true),
  ])
  assert_eq(must_execute(parse_filter("endswith((\"o\",\"x\"))"), j), [
    Value::boolean(true),
    Value::boolean(false),
  ])
  assert_eq(must_execute(parse_filter("endswith(empty)"), j), [])
}

///|
test "execute trimstr compatibility" {
  let j = must_parse("\"foobar\"")
  assert_eq(must_execute(parse_filter("ltrimstr(\"foo\")"), j), [
    Value::string("bar"),
  ])
  assert_eq(must_execute(parse_filter("ltrimstr(\"bar\")"), j), [
    Value::string("foobar"),
  ])
  assert_eq(must_execute(parse_filter("rtrimstr(\"bar\")"), j), [
    Value::string("foo"),
  ])
  assert_eq(must_execute(parse_filter("rtrimstr(\"foo\")"), j), [
    Value::string("foobar"),
  ])
  assert_eq(must_execute(parse_filter("ltrimstr((\"foo\",\"bar\"))"), j), [
    Value::string("bar"),
    Value::string("foobar"),
  ])
  assert_eq(must_execute(parse_filter("ltrimstr(empty)"), j), [])
  assert_eq(must_execute(parse_filter("ltrimstr(\"\")"), j), [
    Value::string("foobar"),
  ])
  assert_eq(must_execute(parse_filter("rtrimstr(\"\")"), j), [Value::string("")])
  assert_eq(must_execute(parse_filter("trimstr(\"\")"), j), [Value::string("")])
}

///|
test "execute trim/ltrim/rtrim compatibility" {
  assert_eq(
    must_execute(parse_filter("trim, ltrim, rtrim"), must_parse("\" abc \"")),
    [Value::string("abc"), Value::string("abc "), Value::string(" abc")],
  )
  assert_eq(
    must_execute(
      parse_filter("[.[]|trimstr(\"foo\")]"),
      must_parse("[\"fo\",\"foo\",\"barfoo\",\"foobarfoo\",\"foob\"]"),
    ),
    [
      Value::array([
        Value::string("fo"),
        Value::string(""),
        Value::string("bar"),
        Value::string("bar"),
        Value::string("b"),
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
    [
      Value::array([Value::number(10.0), Value::number(1.1), Value::number(0.1)]),
    ],
  )
  assert_eq(
    must_execute(parse_filter("map(abs)|tojson"), must_parse("[-0,0,-10,-1.1]")),
    [Value::string("[-0,0,10,1.1]")],
  )
  assert_eq(
    must_execute(
      parse_filter("map(abs)|tojson"),
      must_parse("[0.1,1000000000000000002]"),
    ),
    [Value::string("[0.1,1000000000000000002]")],
  )
  assert_eq(must_execute(parse_filter("abs"), must_parse("\"abc\"")), [
    Value::string("abc"),
  ])
  assert_eq(must_execute(parse_filter("abs"), must_parse("[1,-2]")), [
    Value::array([Value::number(1.0), Value::number(-2.0)]),
  ])
  assert_eq(must_execute(parse_filter("abs"), must_parse("{\"a\":-1}")), [
    Value::object({ "a": Value::number(-1.0) }),
  ])
  assert_eq(must_execute(parse_filter("have_decnum"), must_parse("null")), [
    Value::boolean(false),
  ])
  assert_eq(
    must_execute(
      parse_filter("\"-1\"|IN(builtins[] / \"/\"|.[1])"),
      must_parse("null"),
    ),
    [Value::boolean(false)],
  )
  assert_eq(
    must_execute(
      parse_filter("all(builtins[] / \"/\"; .[1]|tonumber >= 0)"),
      must_parse("null"),
    ),
    [Value::boolean(true)],
  )
  assert_eq(must_execute(parse_filter("isempty(empty)"), must_parse("null")), [
    Value::boolean(true),
  ])
  assert_eq(must_execute(parse_filter("isempty(.[])"), must_parse("[]")), [
    Value::boolean(true),
  ])
  assert_eq(must_execute(parse_filter("isempty(.[])"), must_parse("[1,2,3]")), [
    Value::boolean(false),
  ])
  assert_eq(
    must_execute(parse_filter("isempty((1,error(\"x\")))"), must_parse("null")),
    [Value::boolean(false)],
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
      Value::array([
        Value::boolean(false),
        Value::boolean(true),
        Value::boolean(false),
        Value::boolean(true),
      ]),
    ],
  )
  assert_eq(
    must_execute(parse_filter("[.[]|floor]"), must_parse("[-1.1,1.1,1.9]")),
    [
      Value::array([Value::number(-2.0), Value::number(1.0), Value::number(1.0)]),
    ],
  )
  assert_eq(must_execute(parse_filter("[.[]|sqrt]"), must_parse("[4,9]")), [
    Value::array([Value::number(2.0), Value::number(3.0)]),
  ])
  assert_eq(must_execute(parse_filter("pow(2;10)"), must_parse("null")), [
    Value::number(1024.0),
  ])
  assert_eq(
    must_execute(parse_filter("pow(2;8)|log2|round"), must_parse("null")),
    [Value::number(8.0)],
  )
  assert_eq(
    must_execute(parse_filter("map(fabs)"), must_parse("[-0,0,-10,-1.1]")),
    [
      Value::array([
        Value::number(0.0),
        Value::number(0.0),
        Value::number(10.0),
        Value::number(1.1),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("atan * 4 * 1000000|floor / 1000000"),
      must_parse("1"),
    ),
    [Value::number(3.141592)],
  )
  assert_eq(
    must_execute(
      parse_filter("infinite | type, nan | type"),
      must_parse("null"),
    ),
    [Value::string("string"), Value::string("number")],
  )
  guard (try? execute(parse_filter("modulemeta"), must_parse("\"c\"")))
    is Err(err) &&
    err.to_string() == "module not found: c" else {
    fail("expected modulemeta missing-module error")
  }
  assert_eq(
    must_execute(parse_filter("builtins|length > 10"), must_parse("null")),
    [Value::boolean(true)],
  )
}

///|
test "execute numeric/meta builtins errors" {
  guard (try? execute(parse_filter("toboolean"), must_parse("\"tru\"")))
    is Err(err) &&
    err.to_string() == "string (\"tru\") cannot be parsed as a boolean" else {
    fail("expected toboolean parse error")
  }
  assert_eq(
    must_execute(
      parse_filter("\"true\\u0000x\", \"false\\u0000\" | toboolean"),
      must_parse("null"),
    ),
    [Value::boolean(true), Value::boolean(false)],
  )
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
    [Value::string("abc_é")],
  )
  assert_eq(
    must_execute(parse_filter("ascii_upcase"), must_parse("\"AbC_é\"")),
    [Value::string("ABC_é")],
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
    [Value::number(6.0)],
  )
  assert_eq(
    must_execute(parse_filter("utf8bytelength"), must_parse("\"\\u03bc\"")),
    [Value::number(2.0)],
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

///|
test "execute shared run lanes preserve ordering and repr-sensitive outputs" {
  assert_eq(
    must_run_json_text(
      ". + {\"a\":9,\"c\":3}, .foo", "{\"b\":1,\"a\":2,\"foo\":\"line\\nbreak\"}",
    ),
    ["{\"b\":1,\"a\":9,\"foo\":\"line\\nbreak\",\"c\":3}", "\"line\\nbreak\""],
  )

  let values = must_run_values(
    ". + {\"a\":9,\"c\":3}, .huge, .n", "{\"b\":1,\"a\":2,\"huge\":9007199254740993,\"n\":1e309}",
  )
  assert_eq(values.length(), 3)
  assert_eq(
    values[0].to_json_string(),
    "{\"b\":1,\"a\":9,\"huge\":9007199254740993,\"n\":1e309,\"c\":3}",
  )
  assert_eq(values[1].to_json_string(), "9007199254740993")
  assert_eq(values[2].to_json_string(), "1e309")
}
