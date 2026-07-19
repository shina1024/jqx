///|
// Source under test: core/execute.mbt, core/json_ops.mbt, core/builtin_dispatch.mbt

///|
test "execute identity" {
  let j = must_parse("{\"a\":1}")
  let f = compile(".")
  let out = must_execute(f, j)
  @debug.assert_eq(out, [j])
}

///|
test "execute field and missing field" {
  let j = must_parse("{\"a\":1}")
  let f1 = compile(".a")
  let f2 = compile(".b")
  let f3 = compile(".\"a\"")
  @debug.assert_eq(must_execute(f1, j), [Value::number(1.0)])
  @debug.assert_eq(must_execute(f2, j), [Value::null()])
  @debug.assert_eq(must_execute(f3, j), [Value::number(1.0)])
}

///|
test "execute field/index type errors and optional suppression" {
  let number_json = must_parse("1")
  let array_json = must_parse("[1,2]")
  let object_json = must_parse("{\"a\":1}")
  let null_json = must_parse("null")
  guard (try execute(compile(".foo"), number_json) catch {
    err => err.to_string() == "Cannot index number with string (\"foo\")"
  } noraise {
    _ => false
  }) else {
    fail("expected type error for number .foo")
  }
  guard (try execute(compile(".foo"), array_json) catch {
    err => err.to_string() == "Cannot index array with string (\"foo\")"
  } noraise {
    _ => false
  }) else {
    fail("expected type error for array .foo")
  }
  guard (try execute(compile(".[0]"), number_json) catch {
    err => err.to_string() == "Cannot index number with number (0)"
  } noraise {
    _ => false
  }) else {
    fail("expected type error for number .[0]")
  }
  guard (try execute(compile(".[0]"), object_json) catch {
    err => err.to_string() == "Cannot index object with number (0)"
  } noraise {
    _ => false
  }) else {
    fail("expected type error for object .[0]")
  }
  @debug.assert_eq(must_execute(compile(".foo?"), number_json), [])
  @debug.assert_eq(must_execute(compile(".foo?"), array_json), [])
  @debug.assert_eq(must_execute(compile(".[0]?"), number_json), [])
  @debug.assert_eq(must_execute(compile(".[0]?"), object_json), [])
  @debug.assert_eq(must_execute(compile(".foo"), null_json), [Value::null()])
  @debug.assert_eq(must_execute(compile(".foo?"), null_json), [Value::null()])
  @debug.assert_eq(must_execute(compile(".[0]"), null_json), [Value::null()])
  @debug.assert_eq(must_execute(compile(".[0]?"), null_json), [Value::null()])
}

///|
test "execute index and iter" {
  let j = must_parse("[1,2,3]")
  let f1 = compile(".[1]")
  let f2 = compile(".[]")
  let f3 = compile(".[1,2]")
  @debug.assert_eq(must_execute(f1, j), [Value::number(2.0)])
  @debug.assert_eq(must_execute(f2, j), [
    Value::number(1.0),
    Value::number(2.0),
    Value::number(3.0),
  ])
  @debug.assert_eq(must_execute(f3, j), [Value::number(2.0), Value::number(3.0)])
  @debug.assert_eq(
    must_execute(compile("[range(10)] | .[1.2:3.5]"), must_parse("null")),
    [Value::array([Value::number(1.0), Value::number(2.0), Value::number(3.0)])],
  )
  @debug.assert_eq(
    must_execute(compile("[range(10)] | .[1.5:3.5]"), must_parse("null")),
    [Value::array([Value::number(1.0), Value::number(2.0), Value::number(3.0)])],
  )
  @debug.assert_eq(
    must_execute(compile("[range(10)] | .[1.7:3.5]"), must_parse("null")),
    [Value::array([Value::number(1.0), Value::number(2.0), Value::number(3.0)])],
  )
}

///|
test "execute chained index without extra dot" {
  let j = must_parse("{\"a\":[10,20,30]}")
  @debug.assert_eq(must_execute(compile(".a[1]"), j), [Value::number(20.0)])
  @debug.assert_eq(must_execute(compile(".a[1:3]"), j), [
    Value::array([Value::number(20.0), Value::number(30.0)]),
  ])
}

///|
test "execute string index jq compatibility" {
  let s = must_parse("\"abc\"")
  guard (try execute(compile(".[0]"), s) catch {
    err => err.to_string() == "Cannot index string with number (0)"
  } noraise {
    _ => false
  }) else {
    fail("expected string index type error")
  }
  guard (try execute(compile(".[-1]"), s) catch {
    err => err.to_string() == "Cannot index string with number (-1)"
  } noraise {
    _ => false
  }) else {
    fail("expected string negative index type error")
  }
  @debug.assert_eq(must_execute(compile(".[0]?"), s), [])
  @debug.assert_eq(must_execute(compile(".[-1]?"), s), [])
}

///|
test "execute optional access" {
  let j = must_parse("[1,2,3]")
  @debug.assert_eq(must_execute(compile(".[]?"), j), [
    Value::number(1.0),
    Value::number(2.0),
    Value::number(3.0),
  ])
  let j2 = must_parse("1")
  @debug.assert_eq(must_execute(compile(".[]?"), j2), [])
  @debug.assert_eq(must_execute(compile(".foo?"), j2), [])
  @debug.assert_eq(must_execute(compile(".[0]?"), j2), [])
}

///|
test "execute pipe and comma" {
  let j = must_parse("{\"a\":{\"b\":2},\"c\":3}")
  let f = compile(".a | .b, .c")
  @debug.assert_eq(must_execute(f, j), [Value::number(2.0), Value::null()])
  @debug.assert_eq(
    must_execute(compile("{x:(1,2)},{x:3} | .x"), must_parse("null")),
    [Value::number(1.0), Value::number(2.0), Value::number(3.0)],
  )
}

///|
test "execute update assignment precedence" {
  let j1 = must_parse("{\"a\":0}")
  @debug.assert_eq(must_execute(compile(".a = 1 | .a"), j1), [
    Value::number(1.0),
  ])

  let j2 = must_parse("{\"a\":0}")
  @debug.assert_eq(must_execute(compile(".a = 1 // 2 | .a"), j2), [
    Value::number(1.0),
  ])

  let j3 = must_parse(
    "[{\"x\":\"a\",\"y\":1},{\"x\":\"b\",\"y\":2},{\"x\":\"c\",\"y\":3}]",
  )
  @debug.assert_eq(
    must_execute(
      compile("reduce .[] as {$x,$y} (null; .x += $x | .y += [$y])"),
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
  let f = compile("\"hi\"")
  @debug.assert_eq(must_execute(f, j), [Value::string("hi")])
}

///|
test "execute array and object literals" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  let f1 = compile("[.a, .b]")
  let f2 = compile("{\"x\": .a, y: .b}")
  let f3 = compile("{a, \"b\"}")
  let f4 = compile("1 as $x | \"dyn\" as $k | { $x, $k: .b, a }")
  @debug.assert_eq(must_execute(f1, j), [
    Value::array([Value::number(1.0), Value::number(2.0)]),
  ])
  @debug.assert_eq(must_execute(f2, j), [
    Value::object({ "x": Value::number(1.0), "y": Value::number(2.0) }),
  ])
  @debug.assert_eq(must_execute(f3, j), [
    Value::object({ "a": Value::number(1.0), "b": Value::number(2.0) }),
  ])
  @debug.assert_eq(must_execute(f4, j), [
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
  @debug.assert_eq(must_execute(compile("length"), j1), [Value::number(3.0)])
  @debug.assert_eq(must_execute(compile("length"), j2), [Value::number(2.0)])
  @debug.assert_eq(must_execute(compile("length"), j3), [Value::number(2.0)])
  @debug.assert_eq(must_execute(compile("type"), j2), [Value::string("object")])
  @debug.assert_eq(must_execute(compile("keys"), j2), [
    Value::array([Value::string("a"), Value::string("b")]),
  ])
}

///|
test "execute def no-arg minimal" {
  let j = must_parse("1")
  @debug.assert_eq(must_execute(compile("def inc: . + 1; . | inc"), j), [
    Value::number(2.0),
  ])
  @debug.assert_eq(
    must_execute(compile("def inc: . + 1; def twice: inc | inc; . | twice"), j),
    [Value::number(3.0)],
  )
  @debug.assert_eq(must_execute(compile("def length: 42; . | length"), j), [
    Value::number(42.0),
  ])
  let obj = must_parse("{\"a\":1,\"b\":2}")
  @debug.assert_eq(
    must_execute(compile("def add(a;b): a + b; add(.a; .b)"), obj),
    [Value::number(3.0)],
  )
  let arr = must_parse("[1,2]")
  @debug.assert_eq(
    must_execute(compile("def addvalue(f): . + [f]; addvalue(.[0])"), arr),
    [Value::array([Value::number(1.0), Value::number(2.0), Value::number(1.0)])],
  )
  @debug.assert_eq(must_execute(compile("def plus($x): . + $x; plus(2)"), j), [
    Value::number(3.0),
  ])
  @debug.assert_eq(
    must_execute(
      compile("def f: . + 1; def g: def g: . + 100; f | g | f; (f | g), g"),
      must_parse("3"),
    ),
    [Value::number(106.0), Value::number(105.0)],
  )
  @debug.assert_eq(
    must_execute(
      compile(
        "def f: .+1; def g: f; def f: .+100; def f(a):a+.+11; [(g|f(20)), f]",
      ),
      must_parse("1"),
    ),
    [Value::array([Value::number(33.0), Value::number(101.0)])],
  )
  @debug.assert_eq(
    must_execute(
      compile(
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
  @debug.assert_eq(
    must_execute(
      compile("10 as $x | def f: $x; 20 as $x | f"),
      must_parse("null"),
    ),
    [Value::number(10.0)],
  )
  guard (try compile("def f: g; def g: . + 1; f") catch {
    Diagnostics(_) => true
    _ => false
  } noraise {
    _ => false
  }) else {
    fail("expected forward def reference to fail at compile time")
  }
  guard (try compile("def f(x): g(x); def g(y): y + 1; f(1)") catch {
    Diagnostics(_) => true
    _ => false
  } noraise {
    _ => false
  }) else {
    fail("expected forward def reference with arity to fail at compile time")
  }
  guard (try
    compile(
      "def even: if . == 0 then true else .-1|odd end; def odd: if . == 0 then false else .-1|even end; 4|even",
    )
  catch {
    Diagnostics(_) => true
    _ => false
  } noraise {
    _ => false
  }) else {
    fail(
      "expected mutual recursion without prior definition to fail at compile time",
    )
  }
}

///|
test "execute import/include missing module compatibility" {
  clear_module_sources()
  guard (try
    execute(compile("import \"a\" as foo; foo::a"), must_parse("null"))
  catch {
    err => err.to_string() == "module not found: a"
  } noraise {
    _ => false
  }) else {
    fail("expected missing module error for import")
  }
  guard (try
    execute(
      compile("include \"shadow1\"; include \"shadow2\"; e"),
      must_parse("null"),
    )
  catch {
    err => err.to_string() == "module not found: shadow2"
  } noraise {
    _ => false
  }) else {
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
  @debug.assert_eq(
    must_execute(compile("import \"math\" as m; . | m::twice"), must_parse("1")),
    [Value::number(3.0)],
  )
  @debug.assert_eq(
    must_execute(compile("include \"math\"; . | twice"), must_parse("1")),
    [Value::number(3.0)],
  )
  @debug.assert_eq(
    must_execute(compile("import \"util\" as u; . | u::add3"), must_parse("1")),
    [Value::number(4.0)],
  )
  clear_module_sources()
}

///|
test "execute first/last/nth compatibility" {
  let arr = must_parse("[1,2,3]")
  @debug.assert_eq(must_execute(compile("first"), arr), [Value::number(1.0)])
  @debug.assert_eq(must_execute(compile("last"), arr), [Value::number(3.0)])
  @debug.assert_eq(must_execute(compile("nth(0)"), arr), [Value::number(1.0)])
  @debug.assert_eq(must_execute(compile("nth(-1)"), arr), [Value::number(3.0)])
  @debug.assert_eq(must_execute(compile("nth(9)"), arr), [Value::null()])
  @debug.assert_eq(must_execute(compile("nth(1.9)"), arr), [Value::number(2.0)])
  @debug.assert_eq(must_execute(compile("nth((0,-1,9))"), arr), [
    Value::number(1.0),
    Value::number(3.0),
    Value::null(),
  ])
  let empty_arr = must_parse("[]")
  @debug.assert_eq(must_execute(compile("first"), empty_arr), [Value::null()])
  @debug.assert_eq(must_execute(compile("last"), empty_arr), [Value::null()])
  @debug.assert_eq(must_execute(compile("nth(0)"), empty_arr), [Value::null()])
  let null_json = must_parse("null")
  @debug.assert_eq(must_execute(compile("first"), null_json), [Value::null()])
  @debug.assert_eq(must_execute(compile("last"), null_json), [Value::null()])
  @debug.assert_eq(must_execute(compile("nth(0)"), null_json), [Value::null()])
  @debug.assert_eq(must_execute(compile("nth(\"a\")"), null_json), [
    Value::null(),
  ])
  let scalar = must_parse("1")
  @debug.assert_eq(must_execute(compile("first(empty)"), scalar), [])
  @debug.assert_eq(must_execute(compile("last(empty)"), scalar), [])
  @debug.assert_eq(must_execute(compile("nth(empty)"), scalar), [])
  @debug.assert_eq(must_execute(compile("first((1,2,3))"), scalar), [
    Value::number(1.0),
  ])
  @debug.assert_eq(must_execute(compile("last((1,2,3))"), scalar), [
    Value::number(3.0),
  ])
  let null_json2 = must_parse("null")
  @debug.assert_eq(
    must_execute(compile("nth(1; 0,1,error(\"foo\"))"), null_json2),
    [Value::number(1.0)],
  )
  @debug.assert_eq(must_execute(compile("nth(5; empty)"), null_json2), [])
}

///|
test "execute first/last/nth errors" {
  guard (try execute(compile("first"), must_parse("1")) catch {
    err => err.to_string() == "Cannot index number with number (0)"
  } noraise {
    _ => false
  }) else {
    fail("expected first number index error")
  }
  guard (try execute(compile("last"), must_parse("{}")) catch {
    err => err.to_string() == "Cannot index object with number (-1)"
  } noraise {
    _ => false
  }) else {
    fail("expected last object index error")
  }
  guard (try execute(compile("nth(\"a\")"), must_parse("[1,2,3]")) catch {
    err => err.to_string() == "Cannot index array with string (\"a\")"
  } noraise {
    _ => false
  }) else {
    fail("expected nth array string-key error")
  }
  guard (try execute(compile("nth(true)"), must_parse("null")) catch {
    err => err.to_string() == "Cannot index null with boolean"
  } noraise {
    _ => false
  }) else {
    fail("expected nth null boolean-key error")
  }
}

///|
test "execute flatten compatibility" {
  let nested = must_parse("[1,[2],[[3,[4]]],5]")
  @debug.assert_eq(must_execute(compile("flatten"), nested), [
    Value::array([
      Value::number(1.0),
      Value::number(2.0),
      Value::number(3.0),
      Value::number(4.0),
      Value::number(5.0),
    ]),
  ])
  @debug.assert_eq(must_execute(compile("flatten(1)"), nested), [
    Value::array([
      Value::number(1.0),
      Value::number(2.0),
      Value::array([Value::number(3.0), Value::array([Value::number(4.0)])]),
      Value::number(5.0),
    ]),
  ])
  @debug.assert_eq(must_execute(compile("flatten(2)"), nested), [
    Value::array([
      Value::number(1.0),
      Value::number(2.0),
      Value::number(3.0),
      Value::array([Value::number(4.0)]),
      Value::number(5.0),
    ]),
  ])
  @debug.assert_eq(must_execute(compile("flatten(0)"), nested), [nested])
  @debug.assert_eq(must_execute(compile("flatten(0.1)"), nested), [
    Value::array([
      Value::number(1.0),
      Value::number(2.0),
      Value::number(3.0),
      Value::number(4.0),
      Value::number(5.0),
    ]),
  ])
  @debug.assert_eq(
    must_execute(compile("flatten((0,1))"), must_parse("[1,[2]]")),
    [
      Value::array([Value::number(1.0), Value::array([Value::number(2.0)])]),
      Value::array([Value::number(1.0), Value::number(2.0)]),
    ],
  )
  @debug.assert_eq(must_execute(compile("flatten(empty)"), nested), [])
}

///|
test "execute flatten handles deeply nested arrays" {
  let mut deep = Value::number(0.0)
  for _ in 0..<10000 {
    deep = Value::array([deep])
  }
  let expected = [Value::array([Value::number(0.0)])]
  @debug.assert_eq(must_execute(compile("flatten"), deep), expected)
  @debug.assert_eq(must_execute(compile("flatten(10000)"), deep), expected)
}

///|
test "execute flatten errors" {
  guard (try execute(compile("flatten"), must_parse("1")) catch {
    err => err.to_string() == "Cannot iterate over number (1)"
  } noraise {
    _ => false
  }) else {
    fail("expected flatten non-array iterate error")
  }
  guard (try execute(compile("flatten"), must_parse("null")) catch {
    err => err.to_string() == "Cannot iterate over null (null)"
  } noraise {
    _ => false
  }) else {
    fail("expected flatten null iterate error")
  }
  guard (try execute(compile("flatten(-1)"), must_parse("[1,[2]]")) catch {
    err => err.to_string() == "flatten depth must not be negative"
  } noraise {
    _ => false
  }) else {
    fail("expected flatten negative depth error")
  }
  guard (try execute(compile("flatten(null)"), must_parse("[1,[2]]")) catch {
    err => err.to_string() == "flatten depth must not be negative"
  } noraise {
    _ => false
  }) else {
    fail("expected flatten null depth error")
  }
  guard (try execute(compile("flatten(true)"), must_parse("[1,[2]]")) catch {
    err => err.to_string() == "flatten depth must not be negative"
  } noraise {
    _ => false
  }) else {
    fail("expected flatten bool depth error")
  }
  guard (try execute(compile("flatten(\"x\")"), must_parse("[1,[2]]")) catch {
    err =>
      err.to_string() == "string (\"x\") and number (1) cannot be subtracted"
  } noraise {
    _ => false
  }) else {
    fail("expected flatten string depth error")
  }
}

///|
test "execute transpose compatibility" {
  @debug.assert_eq(
    must_execute(compile("transpose"), must_parse("[[1,2],[3,4]]")),
    [
      Value::array([
        Value::array([Value::number(1.0), Value::number(3.0)]),
        Value::array([Value::number(2.0), Value::number(4.0)]),
      ]),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("transpose"), must_parse("[[1],[2,3]]")),
    [
      Value::array([
        Value::array([Value::number(1.0), Value::number(2.0)]),
        Value::array([Value::null(), Value::number(3.0)]),
      ]),
    ],
  )
  @debug.assert_eq(must_execute(compile("transpose"), must_parse("[]")), [
    Value::array([]),
  ])
  @debug.assert_eq(must_execute(compile("transpose"), must_parse("[[],[]]")), [
    Value::array([]),
  ])
  @debug.assert_eq(must_execute(compile("transpose"), must_parse("[[1],[]]")), [
    Value::array([Value::array([Value::number(1.0), Value::null()])]),
  ])
  @debug.assert_eq(must_execute(compile("transpose"), must_parse("[{}]")), [
    Value::array([]),
  ])
  @debug.assert_eq(
    must_execute(compile("transpose"), must_parse("[[1],null]")),
    [Value::array([Value::array([Value::number(1.0), Value::null()])])],
  )
  @debug.assert_eq(
    must_execute(compile("transpose"), must_parse("[[1,null],[2]]")),
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
  guard (try execute(compile("transpose"), must_parse("1")) catch {
    err => err.to_string() == "Cannot iterate over number (1)"
  } noraise {
    _ => false
  }) else {
    fail("expected transpose non-array iterate error")
  }
  guard (try execute(compile("transpose"), must_parse("null")) catch {
    err => err.to_string() == "Cannot iterate over null (null)"
  } noraise {
    _ => false
  }) else {
    fail("expected transpose null iterate error")
  }
  guard (try execute(compile("transpose"), must_parse("[1]")) catch {
    err => err.to_string() == "Cannot index number with number (0)"
  } noraise {
    _ => false
  }) else {
    fail("expected transpose number index error")
  }
  guard (try execute(compile("transpose"), must_parse("[[1],{}]")) catch {
    err => err.to_string() == "Cannot index object with number (0)"
  } noraise {
    _ => false
  }) else {
    fail("expected transpose object index error")
  }
  guard (try execute(compile("transpose"), must_parse("[[1],\"x\"]")) catch {
    err => err.to_string() == "Cannot index string with number (0)"
  } noraise {
    _ => false
  }) else {
    fail("expected transpose string index error")
  }
  guard (try execute(compile("transpose"), must_parse("[true]")) catch {
    err => err.to_string() == "boolean (true) has no length"
  } noraise {
    _ => false
  }) else {
    fail("expected transpose boolean length error")
  }
}

///|
test "execute to_entries/from_entries/with_entries compatibility" {
  @debug.assert_eq(must_execute(compile("to_entries"), must_parse("[10,20]")), [
    Value::array([
      Value::object({ "key": Value::number(0.0), "value": Value::number(10.0) }),
      Value::object({ "key": Value::number(1.0), "value": Value::number(20.0) }),
    ]),
  ])
  @debug.assert_eq(
    must_execute(
      compile("from_entries"),
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
  @debug.assert_eq(
    must_execute(compile("from_entries"), must_parse("[{\"key\":\"a\"}]")),
    [Value::object({ "a": Value::null() })],
  )
  @debug.assert_eq(
    must_execute(
      compile("with_entries({key: (.key + \"_x\"), value: (.value + 10)})"),
      must_parse("{\"a\":1}"),
    ),
    [Value::object({ "a_x": Value::number(11.0) })],
  )
  @debug.assert_eq(
    must_execute(compile("with_entries(empty)"), must_parse("{\"a\":1}")),
    [Value::object(Map([]))],
  )
}

///|
test "execute to_entries/from_entries/with_entries errors" {
  guard (try execute(compile("to_entries"), must_parse("1")) catch {
    err => err.to_string() == "number (1) has no keys"
  } noraise {
    _ => false
  }) else {
    fail("expected to_entries no-keys error")
  }
  guard (try execute(compile("from_entries"), must_parse("1")) catch {
    err => err.to_string() == "Cannot iterate over number (1)"
  } noraise {
    _ => false
  }) else {
    fail("expected from_entries iterate error")
  }
  guard (try execute(compile("from_entries"), must_parse("[1]")) catch {
    err => err.to_string() == "Cannot index number with string (\"key\")"
  } noraise {
    _ => false
  }) else {
    fail("expected from_entries entry index error")
  }
  guard (try
    execute(compile("from_entries"), must_parse("[{\"value\":1}]"))
  catch {
    err => err.to_string() == "Cannot use null (null) as object key"
  } noraise {
    _ => false
  }) else {
    fail("expected from_entries null key error")
  }
  guard (try
    execute(compile("from_entries"), must_parse("[{\"key\":1,\"value\":2}]"))
  catch {
    err => err.to_string() == "Cannot use number (1) as object key"
  } noraise {
    _ => false
  }) else {
    fail("expected from_entries number key error")
  }
  guard (try execute(compile("with_entries(.)"), must_parse("1")) catch {
    err => err.to_string() == "number (1) has no keys"
  } noraise {
    _ => false
  }) else {
    fail("expected with_entries no-keys error")
  }
  guard (try execute(compile("with_entries(.)"), must_parse("[10,20]")) catch {
    err => err.to_string() == "Cannot use number (0) as object key"
  } noraise {
    _ => false
  }) else {
    fail("expected with_entries array key type error")
  }
}

///|
test "execute keys compatibility errors and keys_unsorted" {
  let arr = must_parse("[10,20]")
  @debug.assert_eq(must_execute(compile("keys_unsorted"), arr), [
    Value::array([Value::number(0.0), Value::number(1.0)]),
  ])
  let obj = must_parse("{\"b\":2,\"a\":1}")
  @debug.assert_eq(must_execute(compile("keys_unsorted"), obj), [
    Value::array([Value::string("b"), Value::string("a")]),
  ])
  @debug.assert_eq(must_execute(compile(".[]"), obj), [
    Value::number(2.0),
    Value::number(1.0),
  ])
  @debug.assert_eq(must_execute(compile("tojson"), obj), [
    Value::string("{\"b\":2,\"a\":1}"),
  ])
  guard (try execute(compile("keys"), must_parse("1")) catch {
    err => err.to_string() == "number (1) has no keys"
  } noraise {
    _ => false
  }) else {
    fail("expected jq-compatible keys error")
  }
  guard (try execute(compile("keys_unsorted"), must_parse("1")) catch {
    err => err.to_string() == "number (1) has no keys"
  } noraise {
    _ => false
  }) else {
    fail("expected jq-compatible keys_unsorted error")
  }
}

///|
test "execute tostring/tonumber compatibility" {
  @debug.assert_eq(must_execute(compile("tostring"), must_parse("1")), [
    Value::string("1"),
  ])
  @debug.assert_eq(must_execute(compile("tostring"), must_parse("\"x\"")), [
    Value::string("x"),
  ])
  @debug.assert_eq(must_execute(compile("tostring"), must_parse("null")), [
    Value::string("null"),
  ])
  @debug.assert_eq(must_execute(compile("tostring"), must_parse("[1,2]")), [
    Value::string("[1,2]"),
  ])
  @debug.assert_eq(must_execute(compile("tonumber"), must_parse("\"1\"")), [
    Value::number(1.0),
  ])
  @debug.assert_eq(must_execute(compile("tonumber"), must_parse("\"01\"")), [
    Value::number(1.0),
  ])
  @debug.assert_eq(must_execute(compile("tonumber"), must_parse("\"1.25\"")), [
    Value::number(1.25),
  ])
  guard (try
    execute(compile("tonumber"), must_parse("\"123\\u0000456\""))
  catch {
    err =>
      err.to_string() ==
      "string (\"123\\u0000456\") cannot be parsed as a number"
  } noraise {
    _ => false
  }) else {
    fail("expected tonumber to reject strings with embedded NUL and suffix")
  }
  @debug.assert_eq(must_execute(compile("tonumber"), must_parse("1")), [
    Value::number(1.0),
  ])
  let nan_number = must_execute(compile("tonumber"), must_parse("\"nan\""))
  @debug.assert_eq(nan_number.length(), 1)
  @debug.assert_eq(nan_number[0].to_json_string(), "null")
  let huge = must_execute(compile("tonumber"), must_parse("\"1e309\""))
  @debug.assert_eq(huge.length(), 1)
  @debug.assert_eq(huge[0].to_json_string(), "1E+309")
  let pos_inf = must_execute(compile("tonumber"), must_parse("\"Infinity\""))
  @debug.assert_eq(pos_inf.length(), 1)
  @debug.assert_eq(pos_inf[0].to_json_string(), "1.7976931348623157e+308")
  let neg_inf = must_execute(compile("tonumber"), must_parse("\"-Infinity\""))
  @debug.assert_eq(neg_inf.length(), 1)
  @debug.assert_eq(neg_inf[0].to_json_string(), "-1.7976931348623157e+308")
}

///|
test "execute tojson/fromjson compatibility" {
  @debug.assert_eq(must_execute(compile("tojson"), must_parse("1")), [
    Value::string("1"),
  ])
  @debug.assert_eq(must_execute(compile("tojson"), must_parse("\"x\"")), [
    Value::string("\"x\""),
  ])
  @debug.assert_eq(must_execute(compile("tojson"), must_parse("[1,2]")), [
    Value::string("[1,2]"),
  ])
  @debug.assert_eq(must_execute(compile("tojson"), must_parse("{\"a\":1}")), [
    Value::string("{\"a\":1}"),
  ])
  @debug.assert_eq(must_execute(compile("tojson"), must_parse("null")), [
    Value::string("null"),
  ])
  @debug.assert_eq(must_execute(compile("tojson"), must_parse("true")), [
    Value::string("true"),
  ])
  @debug.assert_eq(
    must_execute(
      compile("tojson"),
      must_parse("0.12345678901234567890123456789"),
    ),
    [Value::string("0.12345678901234567890123456789")],
  )
  @debug.assert_eq(
    must_execute(compile("tojson"), must_parse("1E-999999999")),
    [Value::string("1E-999999999")],
  )
  @debug.assert_eq(must_execute(compile("fromjson"), must_parse("\"1\"")), [
    Value::number(1.0),
  ])
  @debug.assert_eq(must_execute(compile("fromjson"), must_parse("\"[1,2]\"")), [
    Value::array([Value::number(1.0), Value::number(2.0)]),
  ])
  @debug.assert_eq(
    must_execute(compile("fromjson"), must_parse("\"{\\\"a\\\":1}\"")),
    [Value::object({ "a": Value::number(1.0) })],
  )
  @debug.assert_eq(must_execute(compile("fromjson"), must_parse("\"null\"")), [
    Value::null(),
  ])
  @debug.assert_eq(
    must_execute(compile("fromjson"), must_parse("\" true \"")),
    [Value::boolean(true)],
  )
  @debug.assert_eq(
    must_execute(compile("fromjson | isnan"), must_parse("\"nan\"")),
    [Value::boolean(true)],
  )
  @debug.assert_eq(
    must_execute(compile("fromjson | isinfinite"), must_parse("\"INF\"")),
    [Value::boolean(true)],
  )
  @debug.assert_eq(
    must_execute(compile("fromjson | isinfinite"), must_parse("\"-inf\"")),
    [Value::boolean(true)],
  )
}

///|
test "execute format filter compatibility" {
  @debug.assert_eq(
    must_execute(
      compile(
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
  @debug.assert_eq(
    must_execute(compile("(@uri|@urid)"), must_parse("\"<>&'\\\"\\t\"")),
    [Value::string("<>&'\"\t")],
  )
  @debug.assert_eq(
    must_execute(compile("@urid"), must_parse("\"a\\u0000b\\u0000c\"")),
    [Value::string("a\u{00}b\u{00}c")],
  )
  @debug.assert_eq(
    must_execute(compile("@urid"), must_parse("\"Knäckebröd\"")),
    [Value::string("Knäckebröd")],
  )
  @debug.assert_eq(
    must_execute(
      compile("@urid | tojson"),
      must_parse(
        "\"%2C-.%2F09%3A%3B%3C%3D%3E%3F%40AZ%5B%5C%5D%5E_%60az%7B%7C%7D~%7F\"",
      ),
    ),
    [Value::string("\",-./09:;<=>?@AZ[\\\\]^_`az{|}~\\u007f\"")],
  )
  @debug.assert_eq(
    must_execute(compile("(@base64|@base64d)"), must_parse("\"<>&'\\\"\\t\"")),
    [Value::string("<>&'\"\t")],
  )
  @debug.assert_eq(
    must_execute(
      compile("@html \"<b>\\(.)</b>\""),
      must_parse("\"<script>hax</script>\""),
    ),
    [Value::string("<b>&lt;script&gt;hax&lt;/script&gt;</b>")],
  )
  @debug.assert_eq(
    must_execute(compile("@sh \"echo \\(.)\""), must_parse("\"O'Hara's Ale\"")),
    [Value::string("echo 'O'\\''Hara'\\''s Ale'")],
  )
  guard (try
    execute(compile("@base64d"), must_parse("\"Not base64 data\""))
  catch {
    err =>
      err.to_string() == "string (\"Not base64 data\") is not valid base64 data"
  } noraise {
    _ => false
  }) else {
    fail("expected @base64d invalid data error")
  }
  guard (try execute(compile("@base64d"), must_parse("\"QUJDa\"")) catch {
    err => err.to_string() == "string (\"QUJDa\") trailing base64 byte found"
  } noraise {
    _ => false
  }) else {
    fail("expected @base64d trailing byte error")
  }
  @debug.assert_eq(must_execute(compile("@base64d"), must_parse("\"=\"")), [
    Value::string(""),
  ])
  @debug.assert_eq(must_execute(compile("@base64d"), must_parse("\"====\"")), [
    Value::string(""),
  ])
  guard (try execute(compile("@base64d"), must_parse("\"A==\"")) catch {
    err => err.to_string() == "string (\"A==\") trailing base64 byte found"
  } noraise {
    _ => false
  }) else {
    fail("expected @base64d trailing byte error for lax padding")
  }
  guard (try execute(compile("@urid"), must_parse("\"%FX%9F%98%8E\"")) catch {
    err =>
      err.to_string() == "string (\"%FX%9F%98%8E\") is not a valid uri encoding"
  } noraise {
    _ => false
  }) else {
    fail("expected @urid invalid encoding error")
  }
}

///|
test "execute io-control minimal compatibility" {
  @debug.assert_eq(must_execute(compile("debug"), must_parse("1")), [
    Value::number(1.0),
    Value::array([Value::string("DEBUG:"), Value::number(1.0)]),
  ])
  @debug.assert_eq(
    must_execute(compile("try input catch ."), must_parse("null")),
    [Value::string("break")],
  )
  guard (try execute(compile("input"), must_parse("null")) catch {
    err => err.to_string() == "break"
  } noraise {
    _ => false
  }) else {
    fail("expected input EOF break error")
  }
}

///|
test "execute recursion builtins minimal compatibility" {
  @debug.assert_eq(
    must_execute(compile("[while(.<100; .*2)]"), must_parse("1")),
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
  @debug.assert_eq(
    must_execute(
      compile("[.,1]|until(.[0] < 1; [.[0] - 1, .[1] * .[0]])|.[1]"),
      must_parse("4"),
    ),
    [Value::number(24.0)],
  )
  @debug.assert_eq(
    must_execute(
      compile("recurse(.foo[])"),
      must_parse("{\"foo\":[{\"foo\": []}, {\"foo\":[{\"foo\":[]}]}]}"),
    ),
    [
      must_parse("{\"foo\":[{\"foo\":[]},{\"foo\":[{\"foo\":[]}]}]}"),
      must_parse("{\"foo\":[]}"),
      must_parse("{\"foo\":[{\"foo\":[]}]}"),
      must_parse("{\"foo\":[]}"),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("recurse"), must_parse("{\"a\":0,\"b\":[1]}")),
    [
      must_parse("{\"a\":0,\"b\":[1]}"),
      Value::number(0.0),
      Value::array([Value::number(1.0)]),
      Value::number(1.0),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("recurse(. * .; . < 20)"), must_parse("2")),
    [Value::number(2.0), Value::number(4.0), Value::number(16.0)],
  )
  @debug.assert_eq(must_execute(compile("walk(.)"), must_parse("{\"x\":0}")), [
    must_parse("{\"x\":0}"),
  ])
  @debug.assert_eq(must_execute(compile("walk(1)"), must_parse("{\"x\":0}")), [
    Value::number(1.0),
  ])
  @debug.assert_eq(
    must_execute(compile("[walk(.,1)]"), must_parse("{\"x\":0}")),
    [Value::array([must_parse("{\"x\":0}"), Value::number(1.0)])],
  )
  @debug.assert_eq(
    must_execute(
      compile("walk(select(IN({}, []) | not))"),
      must_parse("{\"a\":1,\"b\":[]}"),
    ),
    [must_parse("{\"a\":1}")],
  )
}

///|
test "execute fromjson errors" {
  guard (try execute(compile("fromjson"), must_parse("1")) catch {
    err => err.to_string() == "number (1) only strings can be parsed"
  } noraise {
    _ => false
  }) else {
    fail("expected fromjson number type error")
  }
  guard (try execute(compile("fromjson"), must_parse("null")) catch {
    err => err.to_string() == "null (null) only strings can be parsed"
  } noraise {
    _ => false
  }) else {
    fail("expected fromjson null type error")
  }
  guard (try execute(compile("fromjson"), must_parse("{}")) catch {
    err => err.to_string() == "object ({}) only strings can be parsed"
  } noraise {
    _ => false
  }) else {
    fail("expected fromjson object type error")
  }
  guard (try execute(compile("fromjson"), must_parse("\"x\"")) catch {
    err => err.to_string().contains("while parsing 'x'")
  } noraise {
    _ => false
  }) else {
    fail("expected fromjson invalid token parse context")
  }
  guard (try execute(compile("fromjson"), must_parse("\"\"")) catch {
    err => err.to_string().contains("while parsing ''")
  } noraise {
    _ => false
  }) else {
    fail("expected fromjson empty parse context")
  }
  guard (try execute(compile("fromjson"), must_parse("\"[1,2\"")) catch {
    err => err.to_string().contains("while parsing '[1,2'")
  } noraise {
    _ => false
  }) else {
    fail("expected fromjson unfinished array parse context")
  }
  guard (try execute(compile("fromjson"), must_parse("\"NaN10\"")) catch {
    err =>
      err.to_string() ==
      "Invalid numeric literal at EOF at line 1, column 5 (while parsing 'NaN10')"
  } noraise {
    _ => false
  }) else {
    fail("expected fromjson invalid non-finite suffix parse context")
  }
}

///|
test "execute tonumber errors" {
  guard (try execute(compile("tonumber"), must_parse("\"abc\"")) catch {
    err => err.to_string() == "string (\"abc\") cannot be parsed as a number"
  } noraise {
    _ => false
  }) else {
    fail("expected tonumber string parse error")
  }
  guard (try execute(compile("tonumber"), must_parse("null")) catch {
    err => err.to_string() == "null (null) cannot be parsed as a number"
  } noraise {
    _ => false
  }) else {
    fail("expected tonumber null parse error")
  }
  guard (try execute(compile("tonumber"), must_parse("true")) catch {
    err => err.to_string() == "boolean (true) cannot be parsed as a number"
  } noraise {
    _ => false
  }) else {
    fail("expected tonumber boolean parse error")
  }
}

///|
test "execute reverse compatibility" {
  @debug.assert_eq(must_execute(compile("reverse"), must_parse("[1,2,3]")), [
    Value::array([Value::number(3.0), Value::number(2.0), Value::number(1.0)]),
  ])
  @debug.assert_eq(must_execute(compile("reverse"), must_parse("[]")), [
    Value::array([]),
  ])
  @debug.assert_eq(must_execute(compile("reverse"), must_parse("null")), [
    Value::array([]),
  ])
  @debug.assert_eq(must_execute(compile("reverse"), must_parse("{}")), [
    Value::array([]),
  ])
  @debug.assert_eq(must_execute(compile("reverse"), must_parse("\"\"")), [
    Value::array([]),
  ])
  @debug.assert_eq(must_execute(compile("reverse"), must_parse("0")), [
    Value::array([]),
  ])
}

///|
test "execute reverse errors" {
  guard (try execute(compile("reverse"), must_parse("1")) catch {
    err => err.to_string() == "Cannot index number with number (0)"
  } noraise {
    _ => false
  }) else {
    fail("expected reverse number index error")
  }
  guard (try execute(compile("reverse"), must_parse("\"abc\"")) catch {
    err => err.to_string() == "Cannot index string with number (2)"
  } noraise {
    _ => false
  }) else {
    fail("expected reverse string index error")
  }
  guard (try execute(compile("reverse"), must_parse("{\"a\":1}")) catch {
    err => err.to_string() == "Cannot index object with number (0)"
  } noraise {
    _ => false
  }) else {
    fail("expected reverse object index error")
  }
  guard (try execute(compile("reverse"), must_parse("false")) catch {
    err => err.to_string() == "boolean (false) has no length"
  } noraise {
    _ => false
  }) else {
    fail("expected reverse boolean length error")
  }
}

///|
test "execute join compatibility" {
  @debug.assert_eq(
    must_execute(compile("join(\",\")"), must_parse("[\"a\",1,true,null]")),
    [Value::string("a,1,true,")],
  )
  @debug.assert_eq(must_execute(compile("join(\",\")"), must_parse("[]")), [
    Value::string(""),
  ])
  @debug.assert_eq(must_execute(compile("join(\",\")"), must_parse("[1,2]")), [
    Value::string("1,2"),
  ])
  @debug.assert_eq(must_execute(compile("join(1)"), must_parse("[\"a\"]")), [
    Value::string("a"),
  ])
  @debug.assert_eq(
    must_execute(compile("join((\",\", \":\"))"), must_parse("[\"a\",\"b\"]")),
    [Value::string("a,b"), Value::string("a:b")],
  )
  @debug.assert_eq(
    must_execute(compile("join(empty)"), must_parse("[\"a\"]")),
    [],
  )
}

///|
test "execute join errors" {
  guard (try execute(compile("join(\",\")"), must_parse("1")) catch {
    err => err.to_string() == "Cannot iterate over number (1)"
  } noraise {
    _ => false
  }) else {
    fail("expected join iterate error")
  }
  guard (try execute(compile("join(1)"), must_parse("[\"a\",\"b\"]")) catch {
    err => err.to_string() == "string (\"a\") and number (1) cannot be added"
  } noraise {
    _ => false
  }) else {
    fail("expected join separator type error")
  }
  guard (try execute(compile("join(\",\")"), must_parse("[{\"x\":1}]")) catch {
    err =>
      err.to_string() == "string (\"\") and object ({\"x\":1}) cannot be added"
  } noraise {
    _ => false
  }) else {
    fail("expected join object element type error")
  }
  guard (try
    execute(
      compile("join(\",\")"),
      must_parse("[\"1\",\"2\",{\"a\":{\"b\":{\"c\":33}}}]"),
    )
  catch {
    err =>
      err.to_string() ==
      "string (\"1,2,\") and object ({\"a\":{\"b\":{\"c\":33}}}) cannot be added"
  } noraise {
    _ => false
  }) else {
    fail("expected join deep object preview error")
  }
}

///|
test "execute split compatibility" {
  @debug.assert_eq(
    must_execute(compile("split(\",\")"), must_parse("\"a,b,c\"")),
    [Value::array([Value::string("a"), Value::string("b"), Value::string("c")])],
  )
  @debug.assert_eq(
    must_execute(compile("split(\"\")"), must_parse("\"abc\"")),
    [Value::array([Value::string("a"), Value::string("b"), Value::string("c")])],
  )
  @debug.assert_eq(must_execute(compile("split(\"\")"), must_parse("\"\"")), [
    Value::array([]),
  ])
  @debug.assert_eq(must_execute(compile("split(\",\")"), must_parse("\"\"")), [
    Value::array([]),
  ])
  @debug.assert_eq(
    must_execute(compile("split((\",\", \"\"))"), must_parse("\"abc\"")),
    [
      Value::array([Value::string("abc")]),
      Value::array([Value::string("a"), Value::string("b"), Value::string("c")]),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("split(\"a\")"), must_parse("\"aa\"")),
    [Value::array([Value::string(""), Value::string(""), Value::string("")])],
  )
  @debug.assert_eq(must_execute(compile("split(empty)"), must_parse("\"a\"")), [])
  @debug.assert_eq(
    must_execute(compile("split(\", *\"; null)"), must_parse("\"ab,cd, ef\"")),
    [
      Value::array([
        Value::string("ab"),
        Value::string("cd"),
        Value::string("ef"),
      ]),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("[splits(\"\")]"), must_parse("\"ab\"")),
    [
      Value::array([
        Value::string(""),
        Value::string("a"),
        Value::string("b"),
        Value::string(""),
      ]),
    ],
  )
  @debug.assert_eq(
    must_execute(
      compile("[splits(\"a+\"; \"i\")]"),
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
  @debug.assert_eq(
    must_execute(
      compile("[splits(\",? *\"; \"n\")]"),
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
  @debug.assert_eq(
    must_execute(compile("test(\"a\")"), must_parse("\"abc\"")),
    [Value::boolean(true)],
  )
  @debug.assert_eq(
    must_execute(compile("test(\"A\")"), must_parse("\"abc\"")),
    [Value::boolean(false)],
  )
  @debug.assert_eq(
    must_execute(compile("test(\"A\"; \"i\")"), must_parse("\"abc\"")),
    [Value::boolean(true)],
  )
  @debug.assert_eq(
    must_execute(compile("test(\"a+\"; null)"), must_parse("\"aaab\"")),
    [Value::boolean(true)],
  )
  @debug.assert_eq(
    must_execute(compile("test(empty)"), must_parse("\"abc\"")),
    [],
  )
  @debug.assert_eq(
    must_execute(compile("test(\"\"; \"n\")"), must_parse("\"abc\"")),
    [Value::boolean(false)],
  )
}

///|
test "execute scan regex compatibility" {
  @debug.assert_eq(
    must_execute(compile("[scan(\"a+\")]"), must_parse("\"baaaac\"")),
    [Value::array([Value::string("aaaa")])],
  )
  @debug.assert_eq(
    must_execute(compile("[scan(\"A+\"; \"i\")]"), must_parse("\"baAaAc\"")),
    [Value::array([Value::string("aAaA")])],
  )
  @debug.assert_eq(
    must_execute(compile("[scan(\"\")]"), must_parse("\"ab\"")),
    [Value::array([Value::string(""), Value::string(""), Value::string("")])],
  )
  @debug.assert_eq(
    must_execute(compile("[scan(\"\"; \"n\")]"), must_parse("\"ab\"")),
    [Value::array([])],
  )
  @debug.assert_eq(
    must_execute(compile("[scan(empty)]"), must_parse("\"ab\"")),
    [Value::array([])],
  )
}

///|
test "execute match regex compatibility" {
  @debug.assert_eq(
    must_execute(compile("match(\"a+\")"), must_parse("\"baaaac\"")),
    [
      must_parse(
        "{\"offset\":1,\"length\":4,\"string\":\"aaaa\",\"captures\":[]}",
      ),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("match(\"A+\"; \"i\")"), must_parse("\"baAaAc\"")),
    [
      must_parse(
        "{\"offset\":1,\"length\":4,\"string\":\"aAaA\",\"captures\":[]}",
      ),
    ],
  )
  @debug.assert_eq(
    must_execute(
      compile("match(\".+?\\\\b\")"),
      must_parse("\"a\\u0304 two-codepoint grapheme\""),
    ),
    [
      must_parse(
        "{\"offset\":0,\"length\":2,\"string\":\"a\\u0304\",\"captures\":[]}",
      ),
    ],
  )
  @debug.assert_eq(must_execute(compile("match(\"\")"), must_parse("\"ab\"")), [
    must_parse("{\"offset\":0,\"length\":0,\"string\":\"\",\"captures\":[]}"),
  ])
  @debug.assert_eq(
    must_execute(compile("match(\"\"; \"n\")"), must_parse("\"ab\"")),
    [],
  )
  @debug.assert_eq(
    must_execute(compile("[match(\"a\"; \"g\")]"), must_parse("\"abac\"")),
    [
      must_parse(
        "[{\"offset\":0,\"length\":1,\"string\":\"a\",\"captures\":[]},{\"offset\":2,\"length\":1,\"string\":\"a\",\"captures\":[]}]",
      ),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("[match(empty)]"), must_parse("\"ab\"")),
    [Value::array([])],
  )
}

///|
test "execute regex alternation sequence merge compatibility" {
  @debug.assert_eq(
    must_execute(compile("match(\"a|ab\")"), must_parse("\"ab\"")),
    [must_parse("{\"offset\":0,\"length\":1,\"string\":\"a\",\"captures\":[]}")],
  )
  @debug.assert_eq(
    must_execute(compile("match(\"ab|[ac]|ac\")"), must_parse("\"ac\"")),
    [must_parse("{\"offset\":0,\"length\":1,\"string\":\"a\",\"captures\":[]}")],
  )
  @debug.assert_eq(
    must_execute(compile("match(\"ab|ac\")"), must_parse("\"ac\"")),
    [
      must_parse(
        "{\"offset\":0,\"length\":2,\"string\":\"ac\",\"captures\":[]}",
      ),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("match(\"あい|あう\")"), must_parse("\"あう\"")),
    [
      must_parse(
        "{\"offset\":0,\"length\":2,\"string\":\"あう\",\"captures\":[]}",
      ),
    ],
  )
}

///|
test "execute capture regex compatibility" {
  @debug.assert_eq(
    must_execute(compile("capture(\"a+\")"), must_parse("\"baaaac\"")),
    [Value::object(Map([]))],
  )
  @debug.assert_eq(
    must_execute(compile("capture(\"A+\"; \"i\")"), must_parse("\"baAaAc\"")),
    [Value::object(Map([]))],
  )
  @debug.assert_eq(
    must_execute(compile("capture(\"a+\")"), must_parse("\"xyz\"")),
    [],
  )
  @debug.assert_eq(
    must_execute(compile("capture(\"\")"), must_parse("\"ab\"")),
    [Value::object(Map([]))],
  )
  @debug.assert_eq(
    must_execute(compile("capture(\"\"; \"n\")"), must_parse("\"ab\"")),
    [],
  )
  @debug.assert_eq(
    must_execute(compile("[capture(empty)]"), must_parse("\"ab\"")),
    [Value::array([])],
  )
}

///|
test "execute sub/gsub regex compatibility" {
  @debug.assert_eq(
    must_execute(compile("sub(\"a\"; \"X\")"), must_parse("\"abac\"")),
    [Value::string("Xbac")],
  )
  @debug.assert_eq(
    must_execute(compile("sub(\"a\"; \"X\"; \"g\")"), must_parse("\"abac\"")),
    [Value::string("XbXc")],
  )
  @debug.assert_eq(
    must_execute(compile("sub(\"A\"; \"X\"; \"i\")"), must_parse("\"abAc\"")),
    [Value::string("XbAc")],
  )
  @debug.assert_eq(
    must_execute(compile("sub(\"\"; \"X\")"), must_parse("\"ab\"")),
    [Value::string("Xab")],
  )
  @debug.assert_eq(
    must_execute(compile("sub(\"z\"; \"X\")"), must_parse("\"ab\"")),
    [Value::string("ab")],
  )
  @debug.assert_eq(
    must_execute(compile("sub(\"^_+\"; \"\")"), must_parse("\"_ab\"")),
    [Value::string("ab")],
  )
  @debug.assert_eq(
    must_execute(compile("sub(\"_+$\"; \"\")"), must_parse("\"ab__\"")),
    [Value::string("ab")],
  )
  @debug.assert_eq(
    must_execute(compile("gsub(\"a\"; \"X\")"), must_parse("\"abac\"")),
    [Value::string("XbXc")],
  )
  @debug.assert_eq(
    must_execute(compile("gsub(\"a\"; \"X\"; null)"), must_parse("\"abac\"")),
    [Value::string("XbXc")],
  )
  @debug.assert_eq(
    must_execute(compile("gsub(\"A\"; \"X\"; \"i\")"), must_parse("\"abAc\"")),
    [Value::string("XbXc")],
  )
  @debug.assert_eq(
    must_execute(compile("gsub(\"\"; \"X\")"), must_parse("\"ab\"")),
    [Value::string("XaXbX")],
  )
  @debug.assert_eq(
    must_execute(compile("gsub(\"$\"; \"a\"; \"g\")"), must_parse("\"a\"")),
    [Value::string("aa")],
  )
  @debug.assert_eq(
    must_execute(compile("gsub(\"(?=u)\"; \"u\")"), must_parse("\"qux\"")),
    [Value::string("quux")],
  )
  @debug.assert_eq(
    must_execute(compile("gsub(\"\"; \"X\"; \"n\")"), must_parse("\"ab\"")),
    [Value::string("ab")],
  )
  @debug.assert_eq(
    must_execute(compile("[gsub(empty; \"X\")]"), must_parse("\"ab\"")),
    [Value::array([])],
  )
}

///|
test "execute regex named capture compatibility" {
  @debug.assert_eq(
    must_execute(
      compile("capture(\"(?<a>[a-z]+)-(?<n>[0-9]+)\")"),
      must_parse("\"xyzzy-14\""),
    ),
    [must_parse("{\"a\":\"xyzzy\",\"n\":\"14\"}")],
  )
  @debug.assert_eq(
    must_execute(compile("capture(\"(?<x>a)?b?\")"), must_parse("\"b\"")),
    [must_parse("{\"x\":null}")],
  )
  @debug.assert_eq(
    must_execute(compile("match(\"(?<x>a)?b?\")"), must_parse("\"b\"")),
    [
      must_parse(
        "{\"offset\":0,\"length\":1,\"string\":\"b\",\"captures\":[{\"offset\":-1,\"string\":null,\"length\":0,\"name\":\"x\"}]}",
      ),
    ],
  )
  @debug.assert_eq(
    must_execute(
      compile("match(\"(?<a>[a-z]+)-(?<n>[0-9]+)\")"),
      must_parse("\"xyzzy-14\""),
    ),
    [
      must_parse(
        "{\"offset\":0,\"length\":8,\"string\":\"xyzzy-14\",\"captures\":[{\"offset\":0,\"length\":5,\"string\":\"xyzzy\",\"name\":\"a\"},{\"offset\":6,\"length\":2,\"string\":\"14\",\"name\":\"n\"}]}",
      ),
    ],
  )
  @debug.assert_eq(
    must_execute(
      compile("[match([\"foo\", \"ig\"])]"),
      must_parse("\"foo bar FOO\""),
    ),
    [
      must_parse(
        "[{\"offset\":0,\"length\":3,\"string\":\"foo\",\"captures\":[]},{\"offset\":8,\"length\":3,\"string\":\"FOO\",\"captures\":[]}]",
      ),
    ],
  )
  @debug.assert_eq(
    must_execute(
      compile("[scan(\"(a+)(b+)\")]"),
      must_parse("\"abaabbaaabbb\""),
    ),
    [must_parse("[[\"a\",\"b\"],[\"aa\",\"bb\"],[\"aaa\",\"bbb\"]]")],
  )
  @debug.assert_eq(
    must_execute(
      compile("sub(\"^(?<head>.)\"; \"Head=\\(.head) Tail=\")"),
      must_parse("\"abcdef\""),
    ),
    [Value::string("Head=a Tail=bcdef")],
  )
  @debug.assert_eq(
    must_execute(
      compile("gsub(\"(?<d>\\\\d)\"; \":\\(.d);\")"),
      must_parse("\"a1b2\""),
    ),
    [Value::string("a:1;b:2;")],
  )
  @debug.assert_eq(
    must_execute(
      compile(
        "[sub(\"(?<a>.)\"; \"\\(.a|ascii_upcase)\", \"\\(.a|ascii_downcase)\", \"c\")]",
      ),
      must_parse("\"aB\""),
    ),
    [must_parse("[\"AB\",\"aB\",\"cB\"]")],
  )
}

///|
test "execute split errors" {
  guard (try execute(compile("split(\",\")"), must_parse("1")) catch {
    err => err.to_string() == "split input and separator must be strings"
  } noraise {
    _ => false
  }) else {
    fail("expected split input type error")
  }
  guard (try execute(compile("split(1)"), must_parse("\"a\"")) catch {
    err => err.to_string() == "split input and separator must be strings"
  } noraise {
    _ => false
  }) else {
    fail("expected split separator type error")
  }
  guard (try execute(compile("split(\",\"; 1)"), must_parse("\"a\"")) catch {
    err => err.to_string() == "split flags must be a string or null"
  } noraise {
    _ => false
  }) else {
    fail("expected split flags type error")
  }
  guard (try execute(compile("splits(1)"), must_parse("\"a\"")) catch {
    err => err.to_string() == "splits input and separator must be strings"
  } noraise {
    _ => false
  }) else {
    fail("expected splits separator type error")
  }
  guard (try
    execute(compile("split(\"a\"; \"z\")"), must_parse("\"a\""))
  catch {
    err => err.to_string() == "zg is not a valid modifier string"
  } noraise {
    _ => false
  }) else {
    fail("expected split invalid flags error")
  }
}

///|
test "execute test regex errors" {
  guard (try execute(compile("test(\"a\")"), must_parse("1")) catch {
    err =>
      err.to_string() == "number (1) cannot be matched, as it is not a string"
  } noraise {
    _ => false
  }) else {
    fail("expected test input type error")
  }
  guard (try execute(compile("test(1)"), must_parse("\"abc\"")) catch {
    err => err.to_string() == "number not a string or array"
  } noraise {
    _ => false
  }) else {
    fail("expected test pattern type error")
  }
  guard (try execute(compile("test(\"a\"; 1)"), must_parse("\"abc\"")) catch {
    err => err.to_string() == "test flags must be a string or null"
  } noraise {
    _ => false
  }) else {
    fail("expected test flags type error")
  }
  guard (try
    execute(compile("test(\"a\"; \"z\")"), must_parse("\"abc\""))
  catch {
    err => err.to_string() == "z is not a valid modifier string"
  } noraise {
    _ => false
  }) else {
    fail("expected test invalid flags error")
  }
}

///|
test "execute scan regex errors" {
  guard (try execute(compile("scan(\"a\")"), must_parse("1")) catch {
    err =>
      err.to_string() == "number (1) cannot be matched, as it is not a string"
  } noraise {
    _ => false
  }) else {
    fail("expected scan input type error")
  }
  guard (try execute(compile("scan(1)"), must_parse("\"abc\"")) catch {
    err => err.to_string() == "number not a string or array"
  } noraise {
    _ => false
  }) else {
    fail("expected scan pattern type error")
  }
  guard (try execute(compile("scan(\"a\"; 1)"), must_parse("\"abc\"")) catch {
    err => err.to_string() == "scan flags must be a string or null"
  } noraise {
    _ => false
  }) else {
    fail("expected scan flags type error")
  }
  guard (try
    execute(compile("scan(\"a\"; \"z\")"), must_parse("\"abc\""))
  catch {
    err => err.to_string() == "z is not a valid modifier string"
  } noraise {
    _ => false
  }) else {
    fail("expected scan invalid flags error")
  }
}

///|
test "execute match regex errors" {
  guard (try execute(compile("match(\"a\")"), must_parse("1")) catch {
    err =>
      err.to_string() == "number (1) cannot be matched, as it is not a string"
  } noraise {
    _ => false
  }) else {
    fail("expected match input type error")
  }
  guard (try execute(compile("match(1)"), must_parse("\"abc\"")) catch {
    err => err.to_string() == "number not a string or array"
  } noraise {
    _ => false
  }) else {
    fail("expected match pattern type error")
  }
  guard (try execute(compile("match(\"a\"; 1)"), must_parse("\"abc\"")) catch {
    err => err.to_string() == "match flags must be a string or null"
  } noraise {
    _ => false
  }) else {
    fail("expected match flags type error")
  }
  guard (try
    execute(compile("match(\"a\"; \"z\")"), must_parse("\"abc\""))
  catch {
    err => err.to_string() == "z is not a valid modifier string"
  } noraise {
    _ => false
  }) else {
    fail("expected match invalid flags error")
  }
}

///|
test "execute capture regex errors" {
  guard (try execute(compile("capture(\"a\")"), must_parse("1")) catch {
    err =>
      err.to_string() == "number (1) cannot be matched, as it is not a string"
  } noraise {
    _ => false
  }) else {
    fail("expected capture input type error")
  }
  guard (try execute(compile("capture(1)"), must_parse("\"abc\"")) catch {
    err => err.to_string() == "number not a string or array"
  } noraise {
    _ => false
  }) else {
    fail("expected capture pattern type error")
  }
  guard (try
    execute(compile("capture(\"a\"; 1)"), must_parse("\"abc\""))
  catch {
    err => err.to_string() == "capture flags must be a string or null"
  } noraise {
    _ => false
  }) else {
    fail("expected capture flags type error")
  }
  guard (try
    execute(compile("capture(\"a\"; \"z\")"), must_parse("\"abc\""))
  catch {
    err => err.to_string() == "z is not a valid modifier string"
  } noraise {
    _ => false
  }) else {
    fail("expected capture invalid flags error")
  }
}

///|
test "execute sub/gsub regex errors" {
  guard (try execute(compile("sub(\"a\"; \"x\")"), must_parse("1")) catch {
    err =>
      err.to_string() == "number (1) cannot be matched, as it is not a string"
  } noraise {
    _ => false
  }) else {
    fail("expected sub input type error")
  }
  guard (try execute(compile("sub(1; \"x\")"), must_parse("\"abc\"")) catch {
    err => err.to_string() == "number not a string or array"
  } noraise {
    _ => false
  }) else {
    fail("expected sub pattern type error")
  }
  guard (try execute(compile("sub(\"a\"; 1)"), must_parse("\"abc\"")) catch {
    err => err.to_string() == "sub replacement must be a string"
  } noraise {
    _ => false
  }) else {
    fail("expected sub replacement type error")
  }
  guard (try
    execute(compile("sub(\"a\"; \"x\"; 1)"), must_parse("\"abc\""))
  catch {
    err => err.to_string() == "sub flags must be a string or null"
  } noraise {
    _ => false
  }) else {
    fail("expected sub flags type error")
  }
  guard (try
    execute(compile("sub(\"a\"; \"x\"; \"z\")"), must_parse("\"abc\""))
  catch {
    err => err.to_string() == "z is not a valid modifier string"
  } noraise {
    _ => false
  }) else {
    fail("expected sub invalid flags error")
  }
  guard (try execute(compile("gsub(\"a\"; \"x\")"), must_parse("1")) catch {
    err =>
      err.to_string() == "number (1) cannot be matched, as it is not a string"
  } noraise {
    _ => false
  }) else {
    fail("expected gsub input type error")
  }
  guard (try execute(compile("gsub(1; \"x\")"), must_parse("\"abc\"")) catch {
    err => err.to_string() == "number not a string or array"
  } noraise {
    _ => false
  }) else {
    fail("expected gsub pattern type error")
  }
  guard (try execute(compile("gsub(\"a\"; 1)"), must_parse("\"abc\"")) catch {
    err => err.to_string() == "gsub replacement must be a string"
  } noraise {
    _ => false
  }) else {
    fail("expected gsub replacement type error")
  }
  guard (try
    execute(compile("gsub(\"a\"; \"x\"; 1)"), must_parse("\"abc\""))
  catch {
    err => err.to_string() == "gsub flags must be a string or null"
  } noraise {
    _ => false
  }) else {
    fail("expected gsub flags type error")
  }
  guard (try
    execute(compile("gsub(\"a\"; \"x\"; \"z\")"), must_parse("\"abc\""))
  catch {
    err => err.to_string() == "zg is not a valid modifier string"
  } noraise {
    _ => false
  }) else {
    fail("expected gsub invalid flags error")
  }
}

///|
test "execute combinations/date/env/stream compatibility" {
  @debug.assert_eq(
    must_execute(compile("combinations"), must_parse("[[1,2], [3,4]]")),
    [
      Value::array([Value::number(1.0), Value::number(3.0)]),
      Value::array([Value::number(1.0), Value::number(4.0)]),
      Value::array([Value::number(2.0), Value::number(3.0)]),
      Value::array([Value::number(2.0), Value::number(4.0)]),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("combinations(2)"), must_parse("[0,1]")),
    [
      Value::array([Value::number(0.0), Value::number(0.0)]),
      Value::array([Value::number(0.0), Value::number(1.0)]),
      Value::array([Value::number(1.0), Value::number(0.0)]),
      Value::array([Value::number(1.0), Value::number(1.0)]),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("fromdate"), must_parse("\"2015-03-05T23:51:47Z\"")),
    [Value::number(1425599507.0)],
  )
  @debug.assert_eq(must_execute(compile("env.PAGER"), must_parse("null")), [
    Value::null(),
  ])
  @debug.assert_eq(
    must_execute(
      compile("truncate_stream([[0],\"a\"],[[1,0],\"b\"],[[1,0]],[[1]])"),
      must_parse("1"),
    ),
    [
      Value::array([Value::array([Value::number(0.0)]), Value::string("b")]),
      Value::array([Value::array([Value::number(0.0)])]),
    ],
  )
  @debug.assert_eq(
    must_execute(
      compile(
        "fromstream(1|truncate_stream([[0],\"a\"],[[1,0],\"b\"],[[1,0]],[[1]]))",
      ),
      must_parse("null"),
    ),
    [Value::array([Value::string("b")])],
  )
  @debug.assert_eq(
    must_execute(
      compile(". as $dot|fromstream($dot|tostream)|.==$dot"),
      must_parse("[0,[1,{\"a\":1},{\"b\":2}]]"),
    ),
    [Value::boolean(true)],
  )
}

///|
test "execute time builtins minimal compatibility" {
  @debug.assert_eq(must_execute(compile("gmtime"), must_parse("1425599507")), [
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
  @debug.assert_eq(must_execute(compile("mktime"), must_parse("[2024,8,21]")), [
    Value::number(1726876800.0),
  ])
  @debug.assert_eq(
    must_execute(
      compile("strftime(\"%Y-%m-%dT%H:%M:%SZ\")"),
      must_parse("[2024,2,15]"),
    ),
    [Value::string("2024-03-15T00:00:00Z")],
  )
  let localized = must_execute(
    compile("strftime(\"%A, %B %d, %Y\")"),
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
  @debug.assert_eq(
    must_execute(
      compile("strptime(\"%Y-%m-%dT%H:%M:%SZ\")"),
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
  @debug.assert_eq(
    must_execute(
      compile("strptime(\"%Y-%m-%dT%H:%M:%SZ\")|mktime"),
      must_parse("\"2015-03-05T23:51:47Z\""),
    ),
    [Value::number(1425599507.0)],
  )
  @debug.assert_eq(
    must_execute(
      compile("try strftime(\"%Y-%m-%dT%H:%M:%SZ\") catch ."),
      must_parse("[\"a\",1,2,3,4,5,6,7]"),
    ),
    [Value::string("strftime/1 requires parsed datetime inputs")],
  )
  @debug.assert_eq(
    must_execute(
      compile("try strflocaltime(\"%Y-%m-%dT%H:%M:%SZ\") catch ."),
      must_parse("[\"a\",1,2,3,4,5,6,7]"),
    ),
    [Value::string("strflocaltime/1 requires parsed datetime inputs")],
  )
  @debug.assert_eq(
    must_execute(
      compile("try mktime catch ."),
      must_parse("[\"a\",1,2,3,4,5,6,7]"),
    ),
    [Value::string("mktime requires parsed datetime inputs")],
  )
  @debug.assert_eq(
    must_execute(
      compile("try [\"OK\", strftime([])] catch [\"KO\", .]"),
      must_parse("0"),
    ),
    [
      Value::array([
        Value::string("KO"),
        Value::string("strftime/1 requires a string format"),
      ]),
    ],
  )
  @debug.assert_eq(
    must_execute(
      compile("try [\"OK\", strflocaltime({})] catch [\"KO\", .]"),
      must_parse("0"),
    ),
    [
      Value::array([
        Value::string("KO"),
        Value::string("strflocaltime/1 requires a string format"),
      ]),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("strflocaltime(\"\" | ., @uri)"), must_parse("0")),
    [Value::string(""), Value::string("")],
  )
}

///|
test "execute explode/implode compatibility" {
  @debug.assert_eq(must_execute(compile("explode"), must_parse("\"abc\"")), [
    Value::array([Value::number(97.0), Value::number(98.0), Value::number(99.0)]),
  ])
  @debug.assert_eq(must_execute(compile("explode"), must_parse("\"あ\"")), [
    Value::array([Value::number(12354.0)]),
  ])
  @debug.assert_eq(must_execute(compile("implode"), must_parse("[97,98,99]")), [
    Value::string("abc"),
  ])
  @debug.assert_eq(must_execute(compile("implode"), must_parse("[12354]")), [
    Value::string("あ"),
  ])
  @debug.assert_eq(must_execute(compile("implode"), must_parse("[]")), [
    Value::string(""),
  ])
  @debug.assert_eq(must_execute(compile("implode"), must_parse("[-1]")), [
    Value::string("\u{fffd}"),
  ])
  @debug.assert_eq(must_execute(compile("implode"), must_parse("[97.9]")), [
    Value::string("a"),
  ])
}

///|
test "execute explode/implode errors" {
  guard (try execute(compile("explode"), must_parse("1")) catch {
    err => err.to_string() == "explode input must be a string"
  } noraise {
    _ => false
  }) else {
    fail("expected explode input type error")
  }
  guard (try execute(compile("implode"), must_parse("1")) catch {
    err => err.to_string() == "implode input must be an array"
  } noraise {
    _ => false
  }) else {
    fail("expected implode input type error")
  }
  guard (try execute(compile("implode"), must_parse("[\"a\"]")) catch {
    err =>
      err.to_string() ==
      "string (\"a\") can't be imploded, unicode codepoint needs to be numeric"
  } noraise {
    _ => false
  }) else {
    fail("expected implode element type error")
  }
  guard (try execute(compile("[nan] | implode"), must_parse("null")) catch {
    err =>
      err.to_string() ==
      "number (null) can't be imploded, unicode codepoint needs to be numeric"
  } noraise {
    _ => false
  }) else {
    fail("expected implode NaN type error")
  }
}

///|
test "execute index/rindex/indices compatibility" {
  @debug.assert_eq(
    must_execute(compile("index(\"l\")"), must_parse("\"hello\"")),
    [Value::number(2.0)],
  )
  @debug.assert_eq(
    must_execute(compile("rindex(\"l\")"), must_parse("\"hello\"")),
    [Value::number(3.0)],
  )
  @debug.assert_eq(
    must_execute(compile("indices(\"l\")"), must_parse("\"hello\"")),
    [Value::array([Value::number(2.0), Value::number(3.0)])],
  )
  @debug.assert_eq(
    must_execute(compile("index(\"z\")"), must_parse("\"hello\"")),
    [Value::null()],
  )
  @debug.assert_eq(
    must_execute(compile("indices(\"z\")"), must_parse("\"hello\"")),
    [Value::array([])],
  )
  @debug.assert_eq(
    must_execute(compile("indices(\"aa\")"), must_parse("\"aaa\"")),
    [Value::array([Value::number(0.0), Value::number(1.0)])],
  )
  @debug.assert_eq(
    must_execute(compile("indices(\"o\")"), must_parse("\"🇬🇧oo\"")),
    [Value::array([Value::number(2.0), Value::number(3.0)])],
  )
  @debug.assert_eq(
    must_execute(compile("_strindices(\"aba\")"), must_parse("\"xababababax\"")),
    [
      Value::array([
        Value::number(1.0),
        Value::number(3.0),
        Value::number(5.0),
        Value::number(7.0),
      ]),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("index((\"l\",\"e\"))"), must_parse("\"hello\"")),
    [Value::number(2.0), Value::number(1.0)],
  )
  @debug.assert_eq(
    must_execute(compile("index(empty)"), must_parse("\"hello\"")),
    [],
  )
  let arr = must_parse("[1,2,1,3]")
  @debug.assert_eq(must_execute(compile("index(1)"), arr), [Value::number(0.0)])
  @debug.assert_eq(must_execute(compile("rindex(1)"), arr), [Value::number(2.0)])
  @debug.assert_eq(must_execute(compile("indices(1)"), arr), [
    Value::array([Value::number(0.0), Value::number(2.0)]),
  ])
  @debug.assert_eq(must_execute(compile("index([1,3])"), arr), [
    Value::number(2.0),
  ])
  @debug.assert_eq(must_execute(compile("indices([1,3])"), arr), [
    Value::array([Value::number(2.0)]),
  ])
  @debug.assert_eq(must_execute(compile("index(\"1\")"), must_parse("[1,2]")), [
    Value::null(),
  ])
  @debug.assert_eq(
    must_execute(compile("indices([])"), must_parse("[1,2,3]")),
    [Value::array([])],
  )
}

///|
test "execute array index handles deeply nested values" {
  let mut deep = Value::null()
  for _ in 0..<20000 {
    deep = Value::array([deep])
  }
  @debug.assert_eq(must_execute(compile("index(.)"), Value::array([deep])), [
    Value::number(0.0),
  ])
}

///|
test "execute array index guards separately constructed deep values" {
  let filter = compile(
    "(reduce range(10001) as $_ ([]; [.])) as $x | " +
    "(reduce range(10001) as $_ ([]; [.])) as $y | [$x] | index([$y])",
  )
  guard (try execute(filter, Value::null()) catch {
    err => err.to_string() == "Equality check too deep"
  } noraise {
    _ => false
  }) else {
    fail("expected checked array search depth error")
  }
}

///|
test "execute equality short-circuits before deep tails" {
  let setup = "(reduce range(10001) as $_ (0; [.])) as $x | " +
    "(reduce range(10001) as $_ (0; [.])) as $y | "
  for
    expression in [
      "[0,$x] == [1,$y]", "{\"a\":0,\"b\":$x} == {\"a\":1,\"b\":$y}",
    ] {
    @debug.assert_eq(must_execute(compile(setup + expression), Value::null()), [
      Value::boolean(false),
    ])
  }
}

///|
test "execute index/rindex/indices errors" {
  guard (try execute(compile("index(1)"), must_parse("\"hello\"")) catch {
    err => err.to_string() == "Cannot index string with number (1)"
  } noraise {
    _ => false
  }) else {
    fail("expected string index(number) type error")
  }
  guard (try execute(compile("index(true)"), must_parse("\"hello\"")) catch {
    err => err.to_string() == "Cannot index string with boolean"
  } noraise {
    _ => false
  }) else {
    fail("expected string index(boolean) type error")
  }
  guard (try execute(compile("index(\"a\")"), must_parse("1")) catch {
    err => err.to_string() == "Cannot index number with string (\"a\")"
  } noraise {
    _ => false
  }) else {
    fail("expected number index(string) type error")
  }
  guard (try execute(compile("_strindices(\"abc\")"), must_parse("123")) catch {
    err =>
      err.to_string() ==
      "number (123) cannot be searched, as it is not a string"
  } noraise {
    _ => false
  }) else {
    fail("expected _strindices input type error")
  }
  guard (try execute(compile("_strindices(123)"), must_parse("\"abc\"")) catch {
    err => err.to_string() == "number (123) is not a string"
  } noraise {
    _ => false
  }) else {
    fail("expected _strindices pattern type error")
  }
}

///|
test "execute bsearch compatibility" {
  @debug.assert_eq(must_execute(compile("bsearch(1)"), must_parse("[1,3,5]")), [
    Value::number(0.0),
  ])
  @debug.assert_eq(must_execute(compile("bsearch(2)"), must_parse("[1,3,5]")), [
    Value::number(-2.0),
  ])
  @debug.assert_eq(must_execute(compile("bsearch(5)"), must_parse("[1,3,5]")), [
    Value::number(2.0),
  ])
  @debug.assert_eq(must_execute(compile("bsearch(6)"), must_parse("[1,3,5]")), [
    Value::number(-4.0),
  ])
  @debug.assert_eq(must_execute(compile("bsearch(0)"), must_parse("[1,3,5]")), [
    Value::number(-1.0),
  ])
  @debug.assert_eq(must_execute(compile("bsearch(1)"), must_parse("[]")), [
    Value::number(-1.0),
  ])
  @debug.assert_eq(must_execute(compile("bsearch(1)"), must_parse("[1,1,1]")), [
    Value::number(1.0),
  ])
  @debug.assert_eq(
    must_execute(compile("bsearch((2,5))"), must_parse("[1,3,5]")),
    [Value::number(-2.0), Value::number(2.0)],
  )
  @debug.assert_eq(
    must_execute(compile("bsearch(empty)"), must_parse("[1,3,5]")),
    [],
  )
  @debug.assert_eq(
    must_execute(
      compile("bsearch(\"a\")"),
      must_parse("[null,false,true,1,\"a\",[],{}]"),
    ),
    [Value::number(4.0)],
  )
  @debug.assert_eq(
    must_execute(compile("bsearch([2])"), must_parse("[1,3,5]")),
    [Value::number(-4.0)],
  )
}

///|
test "execute range/limit/skip/IN compatibility" {
  let null_json = must_parse("null")
  @debug.assert_eq(must_execute(compile("[range(0;10)]"), null_json), [
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
  @debug.assert_eq(must_execute(compile("[range(0;10;3)]"), null_json), [
    Value::array([
      Value::number(0.0),
      Value::number(3.0),
      Value::number(6.0),
      Value::number(9.0),
    ]),
  ])
  @debug.assert_eq(must_execute(compile("[range(3,5)]"), null_json), [
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

  @debug.assert_eq(
    must_execute(
      compile("[limit(3; .[])]"),
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
  @debug.assert_eq(must_execute(compile("[limit(0; error)]"), null_json), [
    Value::array([]),
  ])
  @debug.assert_eq(
    must_execute(compile("[limit(1; 1,error(\"foo\"))]"), null_json),
    [Value::array([Value::number(1.0)])],
  )

  @debug.assert_eq(
    must_execute(compile("[skip(3; .[])]"), must_parse("[1,2,3,4,5,6,7,8,9]")),
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
  @debug.assert_eq(
    must_execute(
      compile("[skip(0,2,3,4; .[])]"),
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

  @debug.assert_eq(
    must_execute(compile("range(5;10)|IN(range(10))"), null_json),
    [
      Value::boolean(true),
      Value::boolean(true),
      Value::boolean(true),
      Value::boolean(true),
      Value::boolean(true),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("IN(range(10;20); range(10))"), null_json),
    [Value::boolean(false)],
  )
  @debug.assert_eq(
    must_execute(compile("IN(range(5;20); range(10))"), null_json),
    [Value::boolean(true)],
  )
  @debug.assert_eq(
    must_execute(compile("INDEX(range(5)|[., \"foo\\(.)\"]; .[0])"), null_json),
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
  @debug.assert_eq(
    must_execute(
      compile(
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
  @debug.assert_eq(
    must_execute(
      compile(
        "[(label $here | .[] | if .>1 then break $here else . end), \"hi!\"]",
      ),
      must_parse("[0,1,2]"),
    ),
    [must_parse("[0,1,\"hi!\"]")],
  )
  @debug.assert_eq(
    must_execute(
      compile(
        "[(label $here | .[] | if .>1 then break $here else . end), \"hi!\"]",
      ),
      must_parse("[0,2,1]"),
    ),
    [must_parse("[0,\"hi!\"]")],
  )
  @debug.assert_eq(
    must_execute(
      compile(
        "[label $out | foreach .[] as $item ([3, null]; if .[0] < 1 then break $out else [.[0] -1, $item] end; .[1])]",
      ),
      must_parse("[11,22,33,44,55,66,77,88,99]"),
    ),
    [must_parse("[11,22,33]")],
  )
  @debug.assert_eq(
    must_execute(
      compile("[ label $if | range(10) | ., (select(. == 5) | break $if) ]"),
      must_parse("null"),
    ),
    [must_parse("[0,1,2,3,4,5]")],
  )
}

///|
test "execute range/limit/skip/nth stream errors" {
  let null_json = must_parse("null")
  guard (try execute(compile("limit(-1; .[])"), must_parse("[1,2,3]")) catch {
    err => err.to_string() == "limit doesn't support negative count"
  } noraise {
    _ => false
  }) else {
    fail("expected limit negative count error")
  }
  guard (try execute(compile("skip(-1; .[])"), must_parse("[1,2,3]")) catch {
    err => err.to_string() == "skip doesn't support negative count"
  } noraise {
    _ => false
  }) else {
    fail("expected skip negative count error")
  }
  guard (try execute(compile("nth(-1; range(10))"), null_json) catch {
    err => err.to_string() == "nth doesn't support negative indices"
  } noraise {
    _ => false
  }) else {
    fail("expected nth negative index error")
  }
}

///|
test "execute bsearch errors" {
  guard (try execute(compile("bsearch(1)"), must_parse("1")) catch {
    err => err.to_string() == "number (1) cannot be searched from"
  } noraise {
    _ => false
  }) else {
    fail("expected bsearch number input error")
  }
  guard (try execute(compile("bsearch(1)"), must_parse("null")) catch {
    err => err.to_string() == "null (null) cannot be searched from"
  } noraise {
    _ => false
  }) else {
    fail("expected bsearch null input error")
  }
  guard (try execute(compile("bsearch(1)"), must_parse("\"a\"")) catch {
    err => err.to_string() == "string (\"a\") cannot be searched from"
  } noraise {
    _ => false
  }) else {
    fail("expected bsearch string input error")
  }
  guard (try execute(compile("bsearch(1)"), must_parse("{}")) catch {
    err => err.to_string() == "object ({}) cannot be searched from"
  } noraise {
    _ => false
  }) else {
    fail("expected bsearch object input error")
  }
  guard (try execute(compile("bsearch(1)"), must_parse("true")) catch {
    err => err.to_string() == "boolean (true) cannot be searched from"
  } noraise {
    _ => false
  }) else {
    fail("expected bsearch boolean input error")
  }
  @debug.assert_eq(must_execute(compile("bsearch(empty)"), must_parse("1")), [])
}

///|
test "execute select" {
  let j = must_parse("{\"a\":1,\"b\":null}")
  let f1 = compile("select(.a)")
  let f2 = compile("select(.b)")
  @debug.assert_eq(must_execute(f1, j), [j])
  @debug.assert_eq(must_execute(f2, j), [])
}

///|
test "execute select stream compatibility" {
  let j = must_parse("1")
  @debug.assert_eq(must_execute(compile("select((false,true,true))"), j), [j, j])
  @debug.assert_eq(must_execute(compile("select((false,false))"), j), [])
  @debug.assert_eq(must_execute(compile("select(empty)"), j), [])
}

///|
test "execute compare" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  let f1 = compile(".a == 1")
  let f2 = compile(".a != .b")
  @debug.assert_eq(must_execute(f1, j), [Value::boolean(true)])
  @debug.assert_eq(must_execute(f2, j), [Value::boolean(true)])
}

///|
test "execute compare stream cross product" {
  let j = must_parse("null")
  @debug.assert_eq(must_execute(compile("(1,2) == (1,2)"), j), [
    Value::boolean(true),
    Value::boolean(false),
    Value::boolean(false),
    Value::boolean(true),
  ])
  @debug.assert_eq(must_execute(compile("(empty) == 1"), j), [])
}

///|
test "execute compare order and logical" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  @debug.assert_eq(must_execute(compile(".a < .b"), j), [Value::boolean(true)])
  @debug.assert_eq(must_execute(compile(".a >= .b"), j), [Value::boolean(false)])
  @debug.assert_eq(must_execute(compile("null >= 0"), j), [
    Value::boolean(false),
  ])
  @debug.assert_eq(must_execute(compile("null < false"), j), [
    Value::boolean(true),
  ])
  @debug.assert_eq(must_execute(compile("true < 0"), j), [Value::boolean(true)])
  @debug.assert_eq(must_execute(compile("\"a\" > 0"), j), [Value::boolean(true)])
  @debug.assert_eq(
    must_execute(compile("select(. >= 0)"), must_parse("null")),
    [],
  )
  @debug.assert_eq(must_execute(compile(". > .00005"), must_parse("0.0001")), [
    Value::boolean(true),
  ])
  @debug.assert_eq(must_execute(compile(". > .00005"), must_parse("0.0")), [
    Value::boolean(false),
  ])
  @debug.assert_eq(must_execute(compile(".a and .b"), j), [Value::boolean(true)])
  @debug.assert_eq(must_execute(compile("not .b"), j), [Value::boolean(false)])
  @debug.assert_eq(must_execute(compile(".a or .b"), j), [Value::boolean(true)])
  let n = must_parse("null")
  @debug.assert_eq(must_execute(compile("(true, false) or false"), n), [
    Value::boolean(true),
    Value::boolean(false),
  ])
  @debug.assert_eq(must_execute(compile("(true, true) and (true, false)"), n), [
    Value::boolean(true),
    Value::boolean(false),
    Value::boolean(true),
    Value::boolean(false),
  ])
  @debug.assert_eq(must_execute(compile("not (true,false)"), n), [
    Value::boolean(false),
    Value::boolean(true),
  ])
}

///|
test "execute arithmetic" {
  let j = must_parse("{\"a\":1,\"b\":2,\"c\":3}")
  @debug.assert_eq(must_execute(compile(".a + .b"), j), [Value::number(3.0)])
  @debug.assert_eq(must_execute(compile(".c - .a"), j), [Value::number(2.0)])
  @debug.assert_eq(must_execute(compile(".a * .b"), j), [Value::number(2.0)])
  @debug.assert_eq(must_execute(compile(".c / .a"), j), [Value::number(3.0)])
  @debug.assert_eq(must_execute(compile("\"a,b,c\" / \",\""), j), [
    Value::array([Value::string("a"), Value::string("b"), Value::string("c")]),
  ])
  @debug.assert_eq(must_execute(compile("\"a, b,c,d, e\" / \", \""), j), [
    Value::array([
      Value::string("a"),
      Value::string("b,c,d"),
      Value::string("e"),
    ]),
  ])
  @debug.assert_eq(must_execute(compile("10 % 3"), j), [Value::number(1.0)])
  @debug.assert_eq(
    must_execute(compile("[(infinite, -infinite) % (1, -1, infinite)]"), j),
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
  @debug.assert_eq(must_execute(compile("(1 / 1e-17) | tojson"), j), [
    Value::string("1e+17"),
  ])
  @debug.assert_eq(
    must_execute(
      compile(
        "(9E999999999|tojson), (9999999999E999999990|tojson), (1E-999999999|tojson), (0.000000001E-999999990|tojson)",
      ),
      j,
    ),
    [
      Value::string("9E+999999999"),
      Value::string("9.999999999E+999999999"),
      Value::string("1E-999999999"),
      Value::string("1E-999999999"),
    ],
  )
  @debug.assert_eq(must_execute(compile("-."), must_parse("3")), [
    Value::number(-3.0),
  ])
  let inf_out = must_execute(compile(". + 1"), must_parse("1e309"))
  @debug.assert_eq(inf_out.length(), 1)
  @debug.assert_eq(inf_out[0].to_json_string(), "1.7976931348623157e+308")
  let nan_out = must_execute(compile(". - ."), must_parse("1e309"))
  @debug.assert_eq(nan_out.length(), 1)
  @debug.assert_eq(nan_out[0].to_json_string(), "null")
  let null_input = must_parse("null")
  let literal_inf_out = must_execute(compile("1e309 + 1"), null_input)
  @debug.assert_eq(literal_inf_out.length(), 1)
  @debug.assert_eq(
    literal_inf_out[0].to_json_string(),
    "1.7976931348623157e+308",
  )
  let literal_nan_out = must_execute(compile("1e309 - 1e309"), null_input)
  @debug.assert_eq(literal_nan_out.length(), 1)
  @debug.assert_eq(literal_nan_out[0].to_json_string(), "null")
}

///|
test "execute multiply compatibility" {
  let j = must_parse("null")
  @debug.assert_eq(must_execute(compile("\"ab\" * 2"), j), [
    Value::string("abab"),
  ])
  @debug.assert_eq(must_execute(compile("2 * \"ab\""), j), [
    Value::string("abab"),
  ])
  @debug.assert_eq(must_execute(compile("\"ab\" * 2.9"), j), [
    Value::string("abab"),
  ])
  @debug.assert_eq(must_execute(compile("\"ab\" * 0"), j), [Value::string("")])
  @debug.assert_eq(must_execute(compile("\"ab\" * -1"), j), [Value::null()])
  @debug.assert_eq(
    must_execute(compile("{\"a\":{\"x\":1}} * {\"a\":{\"y\":2}}"), j),
    [
      Value::object({
        "a": Value::object({ "x": Value::number(1.0), "y": Value::number(2.0) }),
      }),
    ],
  )
  @debug.assert_eq(must_execute(compile("{\"a\":{\"x\":1}} * {\"a\":2}"), j), [
    Value::object({ "a": Value::number(2.0) }),
  ])
  @debug.assert_eq(must_execute(compile("{\"a\":1} * {\"b\":2}"), j), [
    Value::object({ "a": Value::number(1.0), "b": Value::number(2.0) }),
  ])
}

///|
test "execute multiply repeat too long error" {
  let j = must_parse("null")
  guard (try execute(compile("\"x\" * 1000000000000"), j) catch {
    err => err.to_string() == "Repeat string result too long"
  } noraise {
    _ => false
  }) else {
    fail("expected repeat-too-long error")
  }
}

///|
test "execute array subtraction compatibility" {
  let j = must_parse("null")
  @debug.assert_eq(must_execute(compile("[1,2,2,3] - [2]"), j), [
    Value::array([Value::number(1.0), Value::number(3.0)]),
  ])
  @debug.assert_eq(must_execute(compile("[1,{\"a\":1}] - [{\"a\":1}]"), j), [
    Value::array([Value::number(1.0)]),
  ])
}

///|
test "execute division by zero compatibility" {
  let j = must_parse("null")
  guard (try execute(compile("1 / 0"), j) catch {
    err =>
      err.to_string() ==
      "number (1) and number (0) cannot be divided because the divisor is zero"
  } noraise {
    _ => false
  }) else {
    fail("expected jq-compatible division by zero error")
  }
  guard (try execute(compile("1 % 0"), j) catch {
    err =>
      err.to_string() ==
      "number (1) and number (0) cannot be divided (remainder) because the divisor is zero"
  } noraise {
    _ => false
  }) else {
    fail("expected jq-compatible modulo by zero error")
  }
}

///|
test "execute arithmetic type errors include full json values" {
  let j = must_parse("null")
  guard (try execute(compile("[1,2,3] + {\"a\":[1,2,3]}"), j) catch {
    err =>
      err.to_string() ==
      "array ([1,2,3]) and object ({\"a\":[1,2,3]}) cannot be added"
  } noraise {
    _ => false
  }) else {
    fail("expected full-value add type error")
  }
  guard (try execute(compile("[1,2,3] / {\"a\":[1,2,3]}"), j) catch {
    err =>
      err.to_string() ==
      "array ([1,2,3]) and object ({\"a\":[1,2,3]}) cannot be divided"
  } noraise {
    _ => false
  }) else {
    fail("expected full-value divide type error")
  }
}

///|
test "execute arithmetic stream cross product" {
  let j = must_parse("null")
  @debug.assert_eq(must_execute(compile("(1,2) + (10,20)"), j), [
    Value::number(11.0),
    Value::number(12.0),
    Value::number(21.0),
    Value::number(22.0),
  ])
  @debug.assert_eq(must_execute(compile("(empty) + 1"), j), [])
}

///|
test "execute add arrays and objects" {
  let j = must_parse("{\"a\":[1],\"b\":[2],\"x\":{\"k\":1},\"y\":{\"k\":2}}")
  @debug.assert_eq(must_execute(compile(".a + .b"), j), [
    Value::array([Value::number(1.0), Value::number(2.0)]),
  ])
  @debug.assert_eq(must_execute(compile(".x + .y"), j), [
    Value::object({ "k": Value::number(2.0) }),
  ])
}

///|
test "execute add null identity compatibility" {
  let j = must_parse("null")
  @debug.assert_eq(must_execute(compile("null + 1"), j), [Value::number(1.0)])
  @debug.assert_eq(must_execute(compile("1 + null"), j), [Value::number(1.0)])
  @debug.assert_eq(must_execute(compile("null + null"), j), [Value::null()])
  @debug.assert_eq(must_execute(compile("true + null"), j), [
    Value::boolean(true),
  ])
  @debug.assert_eq(must_execute(compile("null + [1]"), j), [
    Value::array([Value::number(1.0)]),
  ])
  @debug.assert_eq(must_execute(compile("{\"a\":1} + null"), j), [
    Value::object({ "a": Value::number(1.0) }),
  ])
}

///|
test "execute update assignment compatibility" {
  let obj = must_parse("{\"a\":1,\"b\":2}")
  @debug.assert_eq(must_execute(compile(".a |= . + 1"), obj), [
    Value::object({ "a": Value::number(2.0), "b": Value::number(2.0) }),
  ])
  @debug.assert_eq(must_execute(compile(".a += 4"), must_parse("{\"a\":1}")), [
    Value::object({ "a": Value::number(5.0) }),
  ])
  @debug.assert_eq(
    must_execute(compile(".a //= 9"), must_parse("{\"a\":null}")),
    [Value::object({ "a": Value::number(9.0) })],
  )
  @debug.assert_eq(must_execute(compile(".[1] *= 10"), must_parse("[1,2,3]")), [
    Value::array([Value::number(1.0), Value::number(20.0), Value::number(3.0)]),
  ])
  @debug.assert_eq(
    must_execute(compile(".a.b |= . + 1"), must_parse("{\"a\":{\"b\":1}}")),
    [Value::object({ "a": Value::object({ "b": Value::number(2.0) }) })],
  )
  @debug.assert_eq(
    must_execute(compile(".a.b //= 9"), must_parse("{\"a\":{}}")),
    [Value::object({ "a": Value::object({ "b": Value::number(9.0) }) })],
  )
  @debug.assert_eq(
    must_execute(compile(".a |= select(. >= 0)"), must_parse("null")),
    [Value::null()],
  )
  @debug.assert_eq(
    must_execute(compile(".a |= select(. >= 0)"), must_parse("{\"a\":null}")),
    [Value::object(Map([]))],
  )
  @debug.assert_eq(must_execute(compile(".[2] += 5"), must_parse("[]")), [
    Value::array([Value::null(), Value::null(), Value::number(5.0)]),
  ])
  @debug.assert_eq(must_execute(compile(".[-1] += 1"), must_parse("[1,2,3]")), [
    Value::array([Value::number(1.0), Value::number(2.0), Value::number(4.0)]),
  ])
  @debug.assert_eq(must_execute(compile(".a = 9"), must_parse("{\"a\":1}")), [
    Value::object({ "a": Value::number(9.0) }),
  ])
  @debug.assert_eq(
    must_execute(compile(".foo = .bar"), must_parse("{\"bar\":42}")),
    [Value::object({ "bar": Value::number(42.0), "foo": Value::number(42.0) })],
  )
  @debug.assert_eq(
    must_execute(compile(".a = .b"), must_parse("{\"a\":{\"b\":10},\"b\":20}")),
    [Value::object({ "a": Value::number(20.0), "b": Value::number(20.0) })],
  )
  @debug.assert_eq(
    must_execute(compile(".foo += .foo"), must_parse("{\"foo\":2}")),
    [Value::object({ "foo": Value::number(4.0) })],
  )
  @debug.assert_eq(
    must_execute(compile("(.a,.b) = range(3)"), must_parse("null")),
    [
      Value::object({ "a": Value::number(0.0), "b": Value::number(0.0) }),
      Value::object({ "a": Value::number(1.0), "b": Value::number(1.0) }),
      Value::object({ "a": Value::number(2.0), "b": Value::number(2.0) }),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("(.a,.b) |= range(3)"), must_parse("null")),
    [Value::object({ "a": Value::number(0.0), "b": Value::number(0.0) })],
  )
  @debug.assert_eq(
    must_execute(compile("(.a,.a) |= . + 1"), must_parse("{\"a\":0}")),
    [Value::object({ "a": Value::number(2.0) })],
  )
  @debug.assert_eq(
    must_execute(compile("(.a,.b) += (1,2)"), must_parse("null")),
    [
      Value::object({ "a": Value::number(1.0), "b": Value::number(1.0) }),
      Value::object({ "a": Value::number(2.0), "b": Value::number(2.0) }),
    ],
  )
  @debug.assert_eq(must_execute(compile(".[] += .[0]"), must_parse("[1,2]")), [
    Value::array([Value::number(2.0), Value::number(3.0)]),
  ])
  @debug.assert_eq(
    must_execute(
      compile("reduce range(65540;65536;-1) as $i ([]; .[$i] = $i)|.[65536:]"),
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
  @debug.assert_eq(
    must_execute(
      compile("(.a as $x | .b) = \"b\""),
      must_parse("{\"a\":null,\"b\":null}"),
    ),
    [Value::object({ "a": Value::null(), "b": Value::string("b") })],
  )
  @debug.assert_eq(
    must_execute(
      compile("bsearch(4) as $ix | if $ix < 0 then .[-(1+$ix)] = 4 else . end"),
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
  @debug.assert_eq(
    must_execute(
      compile(".[2:4] = ([], [\"a\",\"b\"], [\"a\",\"b\",\"c\"])"),
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
  guard (try execute(compile(".[1:3] = 9"), must_parse("[0,1,2,3]")) catch {
    err =>
      err.to_string() ==
      "A slice of an array can only be assigned another array"
  } noraise {
    _ => false
  }) else {
    fail("expected slice assignment array-only error")
  }
  @debug.assert_eq(
    must_execute(
      compile("try (\"foobar\" | .[1.5:3.5] = \"xyz\") catch ."),
      must_parse("null"),
    ),
    [Value::string("Cannot update string slices")],
  )
  @debug.assert_eq(
    must_execute(
      compile("try ([range(3)] | .[nan] = 9) catch ."),
      must_parse("null"),
    ),
    [Value::string("Cannot set array element at NaN index")],
  )
  @debug.assert_eq(
    must_execute(
      compile("try ([range(10)] | .[1.5:3.5] = [\"xyz\"]) catch ."),
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
  @debug.assert_eq(
    must_execute(
      compile("(.[] | select(. >= 2)) |= empty"),
      must_parse("[1,5,3,0,7]"),
    ),
    [Value::array([Value::number(1.0), Value::number(0.0)])],
  )
  @debug.assert_eq(
    must_execute(
      compile(".[] |= select(. % 2 == 0)"),
      must_parse("[0,1,2,3,4,5]"),
    ),
    [Value::array([Value::number(0.0), Value::number(2.0), Value::number(4.0)])],
  )
  @debug.assert_eq(
    must_execute(
      compile(".foo[1,4,2,3] |= empty"),
      must_parse("{\"foo\":[0,1,2,3,4,5]}"),
    ),
    [
      Value::object({
        "foo": Value::array([Value::number(0.0), Value::number(5.0)]),
      }),
    ],
  )
  @debug.assert_eq(
    must_execute(compile(".[1:2] |= empty"), must_parse("[1,2,3]")),
    [Value::array([Value::number(1.0), Value::number(3.0)])],
  )
  @debug.assert_eq(
    must_execute(
      compile(".[] |= try tonumber"),
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
  @debug.assert_eq(must_execute(compile(".a %= 4"), must_parse("{\"a\":9}")), [
    Value::object({ "a": Value::number(1.0) }),
  ])
}

///|
test "execute update assignment dynamic slice compatibility" {
  @debug.assert_eq(
    must_execute(
      compile("1 as $s | 3 as $e | .[$s:$e] = [9]"),
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
  @debug.assert_eq(
    must_execute(
      compile("1 as $s | 4 as $e | .[$s:$e] |= map(.+10)"),
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
  @debug.assert_eq(
    must_execute(
      compile("1 as $s | 4 as $e | .[$s:$e] |= empty"),
      must_parse("[0,1,2,3,4]"),
    ),
    [Value::array([Value::number(0.0), Value::number(4.0)])],
  )
  @debug.assert_eq(
    must_execute(
      compile("1 as $s | 4 as $e | .a[$s:$e] += [9]"),
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
  @debug.assert_eq(
    must_execute(
      compile("(.[] | .[1:3]) |= map(.+100)"),
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
  guard (try
    execute(
      compile("(.[] | .[1:3]) |= . + 100"),
      must_parse("[[0,1,2,3],[4,5,6,7]]"),
    )
  catch {
    err => err.to_string() == "array ([1,2]) and number (100) cannot be added"
  } noraise {
    _ => false
  }) else {
    fail("expected jq-compatible dynamic slice update type error")
  }
}

///|
test "execute object literal stream product" {
  let j = must_parse("null")
  @debug.assert_eq(must_execute(compile("{a:(1,2)}"), j), [
    Value::object({ "a": Value::number(1.0) }),
    Value::object({ "a": Value::number(2.0) }),
  ])
  @debug.assert_eq(must_execute(compile("{a:(1,2), b:(3,4)}"), j), [
    Value::object({ "a": Value::number(1.0), "b": Value::number(3.0) }),
    Value::object({ "a": Value::number(1.0), "b": Value::number(4.0) }),
    Value::object({ "a": Value::number(2.0), "b": Value::number(3.0) }),
    Value::object({ "a": Value::number(2.0), "b": Value::number(4.0) }),
  ])
  @debug.assert_eq(must_execute(compile("{a:(empty)}"), j), [])
}

///|
test "execute map" {
  let j = must_parse("[1,2,3]")
  @debug.assert_eq(must_execute(compile("map(. + 1)"), j), [
    Value::array([Value::number(2.0), Value::number(3.0), Value::number(4.0)]),
  ])
}

///|
test "execute map object compatibility" {
  let j = must_parse("{\"a\":1}")
  @debug.assert_eq(must_execute(compile("map(. + 1)"), j), [
    Value::array([Value::number(2.0)]),
  ])
  @debug.assert_eq(must_execute(compile("map((., . + 1))"), j), [
    Value::array([Value::number(1.0), Value::number(2.0)]),
  ])
  @debug.assert_eq(must_execute(compile("map(select(. > 1))"), j), [
    Value::array([]),
  ])
}

///|
test "execute map iter errors" {
  guard (try execute(compile("map(. + 1)"), must_parse("1")) catch {
    err => err.to_string() == "Cannot iterate over number (1)"
  } noraise {
    _ => false
  }) else {
    fail("expected map number error")
  }
  guard (try execute(compile("map(. + 1)"), must_parse("null")) catch {
    err => err.to_string() == "Cannot iterate over null (null)"
  } noraise {
    _ => false
  }) else {
    fail("expected map null error")
  }
}

///|
test "execute map_values jq semantics" {
  let obj = must_parse("{\"a\":1,\"b\":2}")
  @debug.assert_eq(must_execute(compile("map_values(select(. > 1))"), obj), [
    Value::object({ "b": Value::number(2.0) }),
  ])
  @debug.assert_eq(must_execute(compile("map_values((., . + 1))"), obj), [
    Value::object({ "a": Value::number(1.0), "b": Value::number(2.0) }),
  ])
  let arr = must_parse("[1,2,3]")
  @debug.assert_eq(must_execute(compile("map_values(. + 1)"), arr), [
    Value::array([Value::number(2.0), Value::number(3.0), Value::number(4.0)]),
  ])
  @debug.assert_eq(must_execute(compile("map_values(select(. > 1))"), arr), [
    Value::array([Value::number(2.0), Value::number(3.0)]),
  ])
  @debug.assert_eq(must_execute(compile("map_values((., . + 1))"), arr), [
    Value::array([Value::number(1.0), Value::number(2.0), Value::number(3.0)]),
  ])
}

///|
test "execute map_values iter errors" {
  guard (try execute(compile("map_values(. + 1)"), must_parse("1")) catch {
    err => err.to_string() == "Cannot iterate over number (1)"
  } noraise {
    _ => false
  }) else {
    fail("expected map_values number error")
  }
  guard (try execute(compile("map_values(. + 1)"), must_parse("null")) catch {
    err => err.to_string() == "Cannot iterate over null (null)"
  } noraise {
    _ => false
  }) else {
    fail("expected map_values null error")
  }
}

///|
test "execute as and variable" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  @debug.assert_eq(must_execute(compile(".a as $x | $x"), j), [
    Value::number(1.0),
  ])
  @debug.assert_eq(must_execute(compile(".a as $x | .b"), j), [
    Value::number(2.0),
  ])
  @debug.assert_eq(must_execute(compile(".a as $x | $x + 1"), j), [
    Value::number(2.0),
  ])
  @debug.assert_eq(
    must_execute(compile(". as $x | $x[]"), must_parse("[1,2,3]")),
    [Value::number(1.0), Value::number(2.0), Value::number(3.0)],
  )
  @debug.assert_eq(
    must_execute(compile("[-1 as $x | 1,$x]"), must_parse("null")),
    [Value::array([Value::number(1.0), Value::number(-1.0)])],
  )
  @debug.assert_eq(
    must_execute(
      compile(
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
  @debug.assert_eq(
    must_execute(
      compile(".[] as [$a,$b] | [$b,$a]"),
      must_parse("[[1],[1,2,3]]"),
    ),
    [
      Value::array([Value::null(), Value::number(1.0)]),
      Value::array([Value::number(2.0), Value::number(1.0)]),
    ],
  )
  @debug.assert_eq(
    must_execute(
      compile(". as {$a, $b:[$c,$d]} | [$a, $b, $c, $d]"),
      must_parse("{\"a\":1,\"b\":[2,{\"d\":3}]}"),
    ),
    [must_parse("[1,[2,{\"d\":3}],2,{\"d\":3}]")],
  )
  @debug.assert_eq(
    must_execute(
      compile(".[] | . as {a:$a} ?// [$a] | $a"),
      must_parse("[{\"a\":1},[2]]"),
    ),
    [Value::number(1.0), Value::number(2.0)],
  )
  @debug.assert_eq(
    must_execute(
      compile("[1, {c:3, d:4}] as [$a, {c:$b, b:$c}] | $a, $b, $c"),
      must_parse("null"),
    ),
    [Value::number(1.0), Value::number(3.0), Value::null()],
  )
  @debug.assert_eq(
    must_execute(
      compile(
        ".[] as [$a] ?// [$b] | if $a != null then error(\"err: \\($a)\") else {$a,$b} end",
      ),
      must_parse("[[3]]"),
    ),
    [must_parse("{\"a\":null,\"b\":3}")],
  )
  @debug.assert_eq(
    must_execute(
      compile(
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
  @debug.assert_eq(
    must_execute(
      compile(". as {(\"e\"+\"x\"+\"p\"):$exp} | $exp"),
      must_parse("{\"exp\":3}"),
    ),
    [Value::number(3.0)],
  )
}

///|
test "execute special variables compatibility" {
  @debug.assert_eq(must_execute(compile("$ENV.PAGER"), must_parse("null")), [
    Value::null(),
  ])
  @debug.assert_eq(
    must_execute(
      compile("{ a, $__loc__, c }"),
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
  @debug.assert_eq(
    must_execute(
      compile(".foo[.baz]"),
      must_parse("{\"foo\":{\"bar\":4},\"baz\":\"bar\"}"),
    ),
    [Value::number(4.0)],
  )
  @debug.assert_eq(
    must_execute(compile("[1,2,3][] as $x | [4,5,6,7][$x]"), must_parse("null")),
    [Value::number(5.0), Value::number(6.0), Value::number(7.0)],
  )
  @debug.assert_eq(
    must_execute(compile("[][.]"), must_parse("1000000000000000000")),
    [Value::null()],
  )
  @debug.assert_eq(
    must_execute(compile("[range(5)] | .[1.1]"), must_parse("null")),
    [Value::number(1.0)],
  )
}

///|
test "execute try" {
  let j = must_parse("{\"a\":\"hi\"}")
  @debug.assert_eq(must_execute(compile("(.a + 1)?"), j), [])
  @debug.assert_eq(must_execute(compile("(.a | .b)?"), j), [])
}

///|
test "execute try/catch" {
  let j = must_parse("{\"a\":\"hi\",\"b\":1}")
  @debug.assert_eq(must_execute(compile("try .a catch .b"), j), [
    Value::string("hi"),
  ])
  @debug.assert_eq(must_execute(compile("try (.a + 1) catch ."), j), [
    Value::string("string (\"hi\") and number (1) cannot be added"),
  ])
  @debug.assert_eq(
    must_execute(compile("try error(\"boom\") catch (. + \"!\")"), j),
    [Value::string("boom!")],
  )
  @debug.assert_eq(
    must_execute(compile("try 2 catch 3 + 4"), must_parse("null")),
    [Value::number(6.0)],
  )
  @debug.assert_eq(
    must_execute(compile("1 + try 2 catch 3 + 4"), must_parse("null")),
    [Value::number(7.0)],
  )
  @debug.assert_eq(
    must_execute(compile("1 + try error(0) catch 3 + 4"), must_parse("null")),
    [Value::number(8.0)],
  )
  @debug.assert_eq(
    must_execute(compile("try (.[999999999] = 0) catch ."), must_parse("null")),
    [Value::string("Array index too large")],
  )
  guard (try execute(compile("try .a + 1"), j) catch {
    err => err.to_string() == "string (\"hi\") and number (1) cannot be added"
  } noraise {
    _ => false
  }) else {
    fail("expected try precedence to match (try .a) + 1")
  }
  @debug.assert_eq(
    must_execute(compile("try -. catch ."), must_parse("\"very-long-string\"")),
    [Value::string("string (\"very-long-string\") cannot be negated")],
  )
  @debug.assert_eq(
    must_execute(
      compile("try (.-.) catch ."),
      must_parse("\"very-long-string\""),
    ),
    [
      Value::string(
        "string (\"very-long-string\") and string (\"very-long-string\") cannot be subtracted",
      ),
    ],
  )
  @debug.assert_eq(
    must_execute(
      compile(
        "try ([\"hi\",\"ho\"][] | if . == \"ho\" then error else . end) catch \"caught \\(.)\"",
      ),
      must_parse("null"),
    ),
    [Value::string("hi"), Value::string("caught ho")],
  )
  @debug.assert_eq(must_execute(compile("[(.*2, error)?]"), must_parse("1")), [
    Value::array([Value::number(2.0)]),
  ])
  @debug.assert_eq(
    must_execute(compile("[repeat(.*2, error)?]"), must_parse("1")),
    [Value::array([Value::number(2.0)])],
  )
}

///|
test "execute reduce/foreach" {
  let j = must_parse("[1,2,3]")
  @debug.assert_eq(must_execute(compile("reduce .[] as $x (0; . + $x)"), j), [
    Value::number(6.0),
  ])
  @debug.assert_eq(must_execute(compile("foreach .[] as $x (0; . + $x)"), j), [
    Value::number(1.0),
    Value::number(3.0),
    Value::number(6.0),
  ])
  @debug.assert_eq(
    must_execute(compile("foreach .[] as $x (0; . + $x; .)"), j),
    [Value::number(1.0), Value::number(3.0), Value::number(6.0)],
  )
  @debug.assert_eq(
    must_execute(
      compile("reduce .[] as [$i,$j] (0; . + $i * $j)"),
      must_parse("[[1,2],[3,4],[5,6]]"),
    ),
    [Value::number(44.0)],
  )
  @debug.assert_eq(
    must_execute(
      compile("foreach .[] as [$i,$j] (0; . + $i * $j; [$i,$j,.])"),
      must_parse("[[1,2],[3,4]]"),
    ),
    [must_parse("[1,2,2]"), must_parse("[3,4,14]")],
  )
  @debug.assert_eq(
    must_execute(
      compile("foreach .[] as $x (0, 1; . + $x)"),
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
  @debug.assert_eq(must_execute(compile("if .a then .b else .c end"), j), [
    Value::number(1.0),
  ])
  let j2 = must_parse("{\"a\":null,\"b\":1,\"c\":2}")
  @debug.assert_eq(must_execute(compile("if .a then .b else .c end"), j2), [
    Value::number(2.0),
  ])
  let j3 = must_parse("{\"a\":false,\"c\":true,\"d\":3,\"e\":4}")
  @debug.assert_eq(
    must_execute(compile("if .a then .b elif .c then .d else .e end"), j3),
    [Value::number(3.0)],
  )
  @debug.assert_eq(must_execute(compile("if .a then .b end"), j2), [j2])
  @debug.assert_eq(
    must_execute(compile("[if 1,null,2 then 3 else 4 end]"), must_parse("null")),
    [must_parse("[3,4,3]")],
  )
  @debug.assert_eq(
    must_execute(compile("[if empty then 3 else 4 end]"), must_parse("null")),
    [Value::array([])],
  )
  @debug.assert_eq(
    must_execute(compile("[if false then 3 end]"), must_parse("7")),
    [must_parse("[7]")],
  )
}

///|
test "execute fallback and empty" {
  let j = must_parse("{\"a\":1,\"b\":2}")
  @debug.assert_eq(must_execute(compile(".a // .b"), j), [Value::number(1.0)])
  @debug.assert_eq(must_execute(compile("empty // .b"), j), [Value::number(2.0)])
  @debug.assert_eq(must_execute(compile("empty"), j), [])
}

///|
test "execute fallback jq semantics with null/false and streams" {
  let j = must_parse("null")
  @debug.assert_eq(must_execute(compile("null // 1"), j), [Value::number(1.0)])
  @debug.assert_eq(must_execute(compile("false // 1"), j), [Value::number(1.0)])
  @debug.assert_eq(must_execute(compile("true // 1"), j), [Value::boolean(true)])
  @debug.assert_eq(must_execute(compile("[false,1] | .[] // 9"), j), [
    Value::number(1.0),
  ])
  @debug.assert_eq(must_execute(compile("[null,false] | .[] // 9"), j), [
    Value::number(9.0),
  ])
  @debug.assert_eq(must_execute(compile("(1,2) // 9"), j), [
    Value::number(1.0),
    Value::number(2.0),
  ])
}

///|
test "execute string contains/starts/ends" {
  let j = must_parse("\"hello\"")
  @debug.assert_eq(must_execute(compile("contains(\"ell\")"), j), [
    Value::boolean(true),
  ])
  @debug.assert_eq(must_execute(compile("contains((\"he\",\"zz\"))"), j), [
    Value::boolean(true),
    Value::boolean(false),
  ])
  @debug.assert_eq(must_execute(compile("contains(empty)"), j), [])
  @debug.assert_eq(must_execute(compile("startswith(\"he\")"), j), [
    Value::boolean(true),
  ])
  @debug.assert_eq(must_execute(compile("startswith((\"h\",\"x\"))"), j), [
    Value::boolean(true),
    Value::boolean(false),
  ])
  @debug.assert_eq(must_execute(compile("startswith(empty)"), j), [])
  @debug.assert_eq(must_execute(compile("endswith(\"lo\")"), j), [
    Value::boolean(true),
  ])
  @debug.assert_eq(must_execute(compile("endswith((\"o\",\"x\"))"), j), [
    Value::boolean(true),
    Value::boolean(false),
  ])
  @debug.assert_eq(must_execute(compile("endswith(empty)"), j), [])
}

///|
test "execute trimstr compatibility" {
  let j = must_parse("\"foobar\"")
  @debug.assert_eq(must_execute(compile("ltrimstr(\"foo\")"), j), [
    Value::string("bar"),
  ])
  @debug.assert_eq(must_execute(compile("ltrimstr(\"bar\")"), j), [
    Value::string("foobar"),
  ])
  @debug.assert_eq(must_execute(compile("rtrimstr(\"bar\")"), j), [
    Value::string("foo"),
  ])
  @debug.assert_eq(must_execute(compile("rtrimstr(\"foo\")"), j), [
    Value::string("foobar"),
  ])
  @debug.assert_eq(must_execute(compile("ltrimstr((\"foo\",\"bar\"))"), j), [
    Value::string("bar"),
    Value::string("foobar"),
  ])
  @debug.assert_eq(must_execute(compile("ltrimstr(empty)"), j), [])
  @debug.assert_eq(must_execute(compile("ltrimstr(\"\")"), j), [
    Value::string("foobar"),
  ])
  @debug.assert_eq(must_execute(compile("rtrimstr(\"\")"), j), [
    Value::string("foobar"),
  ])
  @debug.assert_eq(must_execute(compile("trimstr(\"\")"), j), [
    Value::string("foobar"),
  ])
}

///|
test "execute trim/ltrim/rtrim compatibility" {
  @debug.assert_eq(
    must_execute(compile("trim, ltrim, rtrim"), must_parse("\" abc \"")),
    [Value::string("abc"), Value::string("abc "), Value::string(" abc")],
  )
  @debug.assert_eq(
    must_execute(
      compile("[.[]|trimstr(\"foo\")]"),
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
  guard (try execute(compile("ltrimstr(\"1\")"), must_parse("1")) catch {
    err => err.to_string() == "startswith() requires string inputs"
  } noraise {
    _ => false
  }) else {
    fail("expected ltrimstr input type error")
  }
  guard (try execute(compile("ltrimstr(1)"), must_parse("\"x\"")) catch {
    err => err.to_string() == "startswith() requires string inputs"
  } noraise {
    _ => false
  }) else {
    fail("expected ltrimstr separator type error")
  }
  guard (try execute(compile("rtrimstr(1)"), must_parse("\"x\"")) catch {
    err => err.to_string() == "endswith() requires string inputs"
  } noraise {
    _ => false
  }) else {
    fail("expected rtrimstr separator type error")
  }
  guard (try execute(compile("trim"), must_parse("1")) catch {
    err => err.to_string() == "trim input must be a string"
  } noraise {
    _ => false
  }) else {
    fail("expected trim input type error")
  }
  guard (try execute(compile("ltrim"), must_parse("1")) catch {
    err => err.to_string() == "trim input must be a string"
  } noraise {
    _ => false
  }) else {
    fail("expected ltrim input type error")
  }
  guard (try execute(compile("rtrim"), must_parse("1")) catch {
    err => err.to_string() == "trim input must be a string"
  } noraise {
    _ => false
  }) else {
    fail("expected rtrim input type error")
  }
  guard (try execute(compile("trimstr(\"1\")"), must_parse("1")) catch {
    err => err.to_string() == "startswith() requires string inputs"
  } noraise {
    _ => false
  }) else {
    fail("expected trimstr input type error")
  }
  guard (try execute(compile("trimstr(1)"), must_parse("\"x\"")) catch {
    err => err.to_string() == "startswith() requires string inputs"
  } noraise {
    _ => false
  }) else {
    fail("expected trimstr separator type error")
  }
}

///|
test "execute abs/have_decnum/isempty compatibility" {
  @debug.assert_eq(
    must_execute(compile("map(abs)"), must_parse("[-10,-1.1,-1e-1]")),
    [
      Value::array([Value::number(10.0), Value::number(1.1), Value::number(0.1)]),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("map(abs)|tojson"), must_parse("[-0,0,-10,-1.1]")),
    [Value::string("[-0,0,10,1.1]")],
  )
  @debug.assert_eq(
    must_execute(
      compile("map(abs)|tojson"),
      must_parse("[0.1,1000000000000000002]"),
    ),
    [Value::string("[0.1,1000000000000000002]")],
  )
  @debug.assert_eq(must_execute(compile("abs"), must_parse("\"abc\"")), [
    Value::string("abc"),
  ])
  @debug.assert_eq(must_execute(compile("abs"), must_parse("[1,-2]")), [
    Value::array([Value::number(1.0), Value::number(-2.0)]),
  ])
  @debug.assert_eq(must_execute(compile("abs"), must_parse("{\"a\":-1}")), [
    Value::object({ "a": Value::number(-1.0) }),
  ])
  @debug.assert_eq(must_execute(compile("have_decnum"), must_parse("null")), [
    Value::boolean(true),
  ])
  @debug.assert_eq(
    must_execute(
      compile("\"-1\"|IN(builtins[] / \"/\"|.[1])"),
      must_parse("null"),
    ),
    [Value::boolean(false)],
  )
  @debug.assert_eq(
    must_execute(
      compile("all(builtins[] / \"/\"; .[1]|tonumber >= 0)"),
      must_parse("null"),
    ),
    [Value::boolean(true)],
  )
  @debug.assert_eq(
    must_execute(compile("isempty(empty)"), must_parse("null")),
    [Value::boolean(true)],
  )
  @debug.assert_eq(must_execute(compile("isempty(.[])"), must_parse("[]")), [
    Value::boolean(true),
  ])
  @debug.assert_eq(
    must_execute(compile("isempty(.[])"), must_parse("[1,2,3]")),
    [Value::boolean(false)],
  )
  @debug.assert_eq(
    must_execute(compile("isempty((1,error(\"x\")))"), must_parse("null")),
    [Value::boolean(false)],
  )
}

///|
test "execute numeric/meta builtins compatibility" {
  @debug.assert_eq(
    must_execute(
      compile("map(toboolean)"),
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
  @debug.assert_eq(
    must_execute(compile("[.[]|floor]"), must_parse("[-1.1,1.1,1.9]")),
    [
      Value::array([Value::number(-2.0), Value::number(1.0), Value::number(1.0)]),
    ],
  )
  @debug.assert_eq(must_execute(compile("[.[]|sqrt]"), must_parse("[4,9]")), [
    Value::array([Value::number(2.0), Value::number(3.0)]),
  ])
  @debug.assert_eq(must_execute(compile("pow(2;10)"), must_parse("null")), [
    Value::number(1024.0),
  ])
  @debug.assert_eq(
    must_execute(compile("pow(2;8)|log2|round"), must_parse("null")),
    [Value::number(8.0)],
  )
  @debug.assert_eq(
    must_execute(compile("map(fabs)"), must_parse("[-0,0,-10,-1.1]")),
    [
      Value::array([
        Value::number(0.0),
        Value::number(0.0),
        Value::number(10.0),
        Value::number(1.1),
      ]),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("atan * 4 * 1000000|floor / 1000000"), must_parse("1")),
    [Value::number(3.141592)],
  )
  @debug.assert_eq(
    must_execute(compile("infinite | type, nan | type"), must_parse("null")),
    [Value::string("string"), Value::string("number")],
  )
  guard (try execute(compile("modulemeta"), must_parse("\"c\"")) catch {
    err => err.to_string() == "module not found: c"
  } noraise {
    _ => false
  }) else {
    fail("expected modulemeta missing-module error")
  }
  @debug.assert_eq(
    must_execute(compile("builtins|length > 10"), must_parse("null")),
    [Value::boolean(true)],
  )
}

///|
test "execute numeric/meta builtins errors" {
  guard (try execute(compile("toboolean"), must_parse("\"tru\"")) catch {
    err => err.to_string() == "string (\"tru\") cannot be parsed as a boolean"
  } noraise {
    _ => false
  }) else {
    fail("expected toboolean parse error")
  }
  guard (try
    execute(
      compile("\"true\\u0000x\", \"false\\u0000\" | toboolean"),
      must_parse("null"),
    )
  catch {
    err =>
      err.to_string() ==
      "string (\"true\\u0000x\") cannot be parsed as a boolean"
  } noraise {
    _ => false
  }) else {
    fail("expected toboolean to reject embedded NUL suffix")
  }
  guard (try execute(compile("sqrt"), must_parse("\"x\"")) catch {
    err => err.to_string() == "string (\"x\") only numbers have sqrt"
  } noraise {
    _ => false
  }) else {
    fail("expected sqrt type error")
  }
  guard (try execute(compile("floor"), must_parse("true")) catch {
    err => err.to_string() == "boolean (true) only numbers have floor"
  } noraise {
    _ => false
  }) else {
    fail("expected floor type error")
  }
  guard (try execute(compile("pow(\"x\";2)"), must_parse("null")) catch {
    err => err.to_string() == "pow() requires numeric arguments"
  } noraise {
    _ => false
  }) else {
    fail("expected pow type error")
  }
  guard (try execute(compile("log2"), must_parse("\"x\"")) catch {
    err => err.to_string() == "string (\"x\") only numbers have log2"
  } noraise {
    _ => false
  }) else {
    fail("expected log2 type error")
  }
}

///|
test "execute abs/fabs/isempty errors" {
  guard (try execute(compile("abs"), must_parse("null")) catch {
    err => err.to_string() == "null (null) cannot be negated"
  } noraise {
    _ => false
  }) else {
    fail("expected abs null type error")
  }
  guard (try execute(compile("abs"), must_parse("true")) catch {
    err => err.to_string() == "boolean (true) cannot be negated"
  } noraise {
    _ => false
  }) else {
    fail("expected abs boolean type error")
  }
  guard (try execute(compile("fabs"), must_parse("\"x\"")) catch {
    err => err.to_string() == "string (\"x\") cannot be negated"
  } noraise {
    _ => false
  }) else {
    fail("expected fabs string type error")
  }
  guard (try execute(compile("isempty(.[0])"), must_parse("{\"a\":1}")) catch {
    err => err.to_string() == "Cannot index object with number (0)"
  } noraise {
    _ => false
  }) else {
    fail("expected isempty to propagate pre-first error")
  }
}

///|
test "execute ascii case compatibility" {
  @debug.assert_eq(
    must_execute(compile("ascii_downcase"), must_parse("\"AbC_é\"")),
    [Value::string("abc_é")],
  )
  @debug.assert_eq(
    must_execute(compile("ascii_upcase"), must_parse("\"AbC_é\"")),
    [Value::string("ABC_é")],
  )
}

///|
test "execute ascii case errors" {
  guard (try execute(compile("ascii_upcase"), must_parse("1")) catch {
    err => err.to_string() == "ascii_upcase input must be a string"
  } noraise {
    _ => false
  }) else {
    fail("expected ascii_upcase type error")
  }
  guard (try execute(compile("ascii_downcase"), must_parse("null")) catch {
    err => err.to_string() == "ascii_downcase input must be a string"
  } noraise {
    _ => false
  }) else {
    fail("expected ascii_downcase type error")
  }
}

///|
test "execute utf8bytelength compatibility" {
  @debug.assert_eq(
    must_execute(compile("utf8bytelength"), must_parse("\"asdf\\u03bc\"")),
    [Value::number(6.0)],
  )
  @debug.assert_eq(
    must_execute(compile("utf8bytelength"), must_parse("\"\\u03bc\"")),
    [Value::number(2.0)],
  )
}

///|
test "execute utf8bytelength errors" {
  guard (try execute(compile("utf8bytelength"), must_parse("[]")) catch {
    err => err.to_string() == "array ([]) only strings have UTF-8 byte length"
  } noraise {
    _ => false
  }) else {
    fail("expected utf8bytelength array type error")
  }
  guard (try execute(compile("utf8bytelength"), must_parse("{}")) catch {
    err => err.to_string() == "object ({}) only strings have UTF-8 byte length"
  } noraise {
    _ => false
  }) else {
    fail("expected utf8bytelength object type error")
  }
  guard (try execute(compile("utf8bytelength"), must_parse("55")) catch {
    err => err.to_string() == "number (55) only strings have UTF-8 byte length"
  } noraise {
    _ => false
  }) else {
    fail("expected utf8bytelength number type error")
  }
}

///|
test "execute shared run lanes preserve ordering and repr-sensitive outputs" {
  @debug.assert_eq(
    must_run_json_text(
      ". + {\"a\":9,\"c\":3}, .foo", "{\"b\":1,\"a\":2,\"foo\":\"line\\nbreak\"}",
    ),
    ["{\"b\":1,\"a\":9,\"foo\":\"line\\nbreak\",\"c\":3}", "\"line\\nbreak\""],
  )

  let values = must_run_values(
    ". + {\"a\":9,\"c\":3}, .huge, .n", "{\"b\":1,\"a\":2,\"huge\":9007199254740993,\"n\":1e309}",
  )
  @debug.assert_eq(values.length(), 3)
  @debug.assert_eq(
    values[0].to_json_string(),
    "{\"b\":1,\"a\":9,\"huge\":9007199254740993,\"n\":1E+309,\"c\":3}",
  )
  @debug.assert_eq(values[1].to_json_string(), "9007199254740993")
  @debug.assert_eq(values[2].to_json_string(), "1E+309")
}
