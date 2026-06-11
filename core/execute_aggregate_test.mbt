///|
// Source under test: core/builtin_numeric.mbt, core/builtin_stream.mbt

///|
test "execute any/all compatibility" {
  @debug.assert_eq(must_execute(compile("any"), must_parse("[true,false]")), [
    Value::boolean(true),
  ])
  @debug.assert_eq(must_execute(compile("all"), must_parse("[true,false]")), [
    Value::boolean(false),
  ])
  @debug.assert_eq(must_execute(compile("any"), must_parse("[]")), [
    Value::boolean(false),
  ])
  @debug.assert_eq(must_execute(compile("all"), must_parse("[]")), [
    Value::boolean(true),
  ])
  @debug.assert_eq(
    must_execute(compile("any"), must_parse("{\"a\":false,\"b\":true}")),
    [Value::boolean(true)],
  )
  @debug.assert_eq(
    must_execute(compile("all"), must_parse("{\"a\":false,\"b\":true}")),
    [Value::boolean(false)],
  )
  @debug.assert_eq(must_execute(compile("any"), must_parse("{}")), [
    Value::boolean(false),
  ])
  @debug.assert_eq(must_execute(compile("all"), must_parse("{}")), [
    Value::boolean(true),
  ])
  @debug.assert_eq(must_execute(compile("any(. > 2)"), must_parse("[1,2,3]")), [
    Value::boolean(true),
  ])
  @debug.assert_eq(must_execute(compile("all(. > 0)"), must_parse("[1,2,3]")), [
    Value::boolean(true),
  ])
  @debug.assert_eq(must_execute(compile("all(. > 2)"), must_parse("[1,2,3]")), [
    Value::boolean(false),
  ])
  @debug.assert_eq(must_execute(compile("any(empty)"), must_parse("[1,2,3]")), [
    Value::boolean(false),
  ])
  @debug.assert_eq(must_execute(compile("all(empty)"), must_parse("[1,2,3]")), [
    Value::boolean(true),
  ])
  @debug.assert_eq(
    must_execute(compile("any((false,true))"), must_parse("[1,2,3]")),
    [Value::boolean(true)],
  )
  @debug.assert_eq(
    must_execute(compile("all((true,false))"), must_parse("[1,2,3]")),
    [Value::boolean(false)],
  )
  @debug.assert_eq(
    must_execute(compile("any(. > 0)"), must_parse("{\"a\":1,\"b\":0}")),
    [Value::boolean(true)],
  )
  @debug.assert_eq(
    must_execute(compile("all(. > 0)"), must_parse("{\"a\":1,\"b\":0}")),
    [Value::boolean(false)],
  )
  @debug.assert_eq(
    must_execute(compile("any(.[]; . > 2)"), must_parse("[1,2,3]")),
    [Value::boolean(true)],
  )
  @debug.assert_eq(
    must_execute(compile("all(.[]; . > 0)"), must_parse("[1,2,3]")),
    [Value::boolean(true)],
  )
  @debug.assert_eq(
    must_execute(compile("all(.[]; . > 2)"), must_parse("[1,2,3]")),
    [Value::boolean(false)],
  )
  @debug.assert_eq(
    must_execute(compile("any(.[]; . > 9)"), must_parse("[1,2,3]")),
    [Value::boolean(false)],
  )
  @debug.assert_eq(
    must_execute(compile("any(true, error; .)"), must_parse("\"badness\"")),
    [Value::boolean(true)],
  )
  @debug.assert_eq(
    must_execute(compile("all(false, error; .)"), must_parse("\"badness\"")),
    [Value::boolean(false)],
  )
}

///|
test "execute any/all errors" {
  guard (try execute(compile("any"), must_parse("1")) catch {
    err => err.to_string() == "Cannot iterate over number (1)"
  } noraise {
    _ => false
  }) else {
    fail("expected any number iterate error")
  }
  guard (try execute(compile("all"), must_parse("null")) catch {
    err => err.to_string() == "Cannot iterate over null (null)"
  } noraise {
    _ => false
  }) else {
    fail("expected all null iterate error")
  }
  guard (try execute(compile("any"), must_parse("\"ab\"")) catch {
    err => err.to_string() == "Cannot iterate over string (\"ab\")"
  } noraise {
    _ => false
  }) else {
    fail("expected any string iterate error")
  }
  guard (try execute(compile("any(.)"), must_parse("1")) catch {
    err => err.to_string() == "Cannot iterate over number (1)"
  } noraise {
    _ => false
  }) else {
    fail("expected any(cond) number iterate error")
  }
  guard (try execute(compile("all(.)"), must_parse("null")) catch {
    err => err.to_string() == "Cannot iterate over null (null)"
  } noraise {
    _ => false
  }) else {
    fail("expected all(cond) null iterate error")
  }
  guard (try execute(compile("error"), must_parse("\"x\"")) catch {
    err => err.to_string() == "x"
  } noraise {
    _ => false
  }) else {
    fail("expected error builtin")
  }
  guard (try execute(compile("error(\"boom\")"), must_parse("null")) catch {
    err => err.to_string() == "boom"
  } noraise {
    _ => false
  }) else {
    fail("expected error(msg) call")
  }
}

///|
test "execute pick compatibility" {
  @debug.assert_eq(must_execute(compile("pick(.a.b.c)"), must_parse("null")), [
    Value::object({
      "a": Value::object({ "b": Value::object({ "c": Value::null() }) }),
    }),
  ])
  @debug.assert_eq(must_execute(compile("pick(first)"), must_parse("[1,2]")), [
    Value::array([Value::number(1.0)]),
  ])
  @debug.assert_eq(
    must_execute(compile("pick(first|first)"), must_parse("[[10,20],30]")),
    [Value::array([Value::array([Value::number(10.0)])])],
  )
  @debug.assert_eq(
    must_execute(
      compile("pick(.a, .b.c, .x)"),
      must_parse("{\"a\":1, \"b\":{\"c\":2,\"d\":3}, \"e\":4}"),
    ),
    [
      Value::object({
        "a": Value::number(1.0),
        "b": Value::object({ "c": Value::number(2.0) }),
        "x": Value::null(),
      }),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("pick(.[2], .[0], .[0])"), must_parse("[1,2,3,4]")),
    [Value::array([Value::number(1.0), Value::null(), Value::number(3.0)])],
  )
}

///|
test "execute pick errors" {
  guard (try execute(compile("pick(last)"), must_parse("[1,2]")) catch {
    err => err.to_string() == "Out of bounds negative array index"
  } noraise {
    _ => false
  }) else {
    fail("expected pick(last) negative index error")
  }
}

///|
test "execute jq type-filter builtins" {
  @debug.assert_eq(must_execute(compile("values"), must_parse("null")), [])
  @debug.assert_eq(must_execute(compile("values"), must_parse("1")), [
    Value::number(1.0),
  ])
  @debug.assert_eq(must_execute(compile("nulls"), must_parse("null")), [
    Value::null(),
  ])
  @debug.assert_eq(must_execute(compile("nulls"), must_parse("1")), [])
  @debug.assert_eq(must_execute(compile("booleans"), must_parse("true")), [
    Value::boolean(true),
  ])
  @debug.assert_eq(must_execute(compile("booleans"), must_parse("1")), [])
  @debug.assert_eq(must_execute(compile("numbers"), must_parse("1")), [
    Value::number(1.0),
  ])
  @debug.assert_eq(must_execute(compile("numbers"), must_parse("\"1\"")), [])
  @debug.assert_eq(must_execute(compile("strings"), must_parse("\"x\"")), [
    Value::string("x"),
  ])
  @debug.assert_eq(must_execute(compile("arrays"), must_parse("[]")), [
    Value::array([]),
  ])
  @debug.assert_eq(must_execute(compile("objects"), must_parse("{}")), [
    Value::object(Map([])),
  ])
  @debug.assert_eq(must_execute(compile("iterables"), must_parse("{}")), [
    Value::object(Map([])),
  ])
  @debug.assert_eq(must_execute(compile("iterables"), must_parse("1")), [])
  @debug.assert_eq(must_execute(compile("scalars"), must_parse("1")), [
    Value::number(1.0),
  ])
  @debug.assert_eq(must_execute(compile("scalars"), must_parse("{}")), [])
}

///|
test "execute add builtin compatibility" {
  @debug.assert_eq(must_execute(compile("add"), must_parse("[1,2,3]")), [
    Value::number(6.0),
  ])
  @debug.assert_eq(must_execute(compile("add"), must_parse("[]")), [
    Value::null(),
  ])
  @debug.assert_eq(must_execute(compile("add"), must_parse("{}")), [
    Value::null(),
  ])
  @debug.assert_eq(
    must_execute(compile("add"), must_parse("{\"a\":1,\"b\":2}")),
    [Value::number(3.0)],
  )
  @debug.assert_eq(must_execute(compile("add"), must_parse("[\"a\",\"b\"]")), [
    Value::string("ab"),
  ])
  @debug.assert_eq(must_execute(compile("add"), must_parse("[[1],[2]]")), [
    Value::array([Value::number(1.0), Value::number(2.0)]),
  ])
  @debug.assert_eq(
    must_execute(compile("add"), must_parse("[{\"a\":1},{\"b\":2}]")),
    [Value::object({ "a": Value::number(1.0), "b": Value::number(2.0) })],
  )
  @debug.assert_eq(must_execute(compile("add"), must_parse("[null,1]")), [
    Value::number(1.0),
  ])
  @debug.assert_eq(must_execute(compile("add"), must_parse("[1,null]")), [
    Value::number(1.0),
  ])
  @debug.assert_eq(must_execute(compile("add"), must_parse("[null,null]")), [
    Value::null(),
  ])
}

///|
test "execute add builtin errors" {
  guard (try execute(compile("add"), must_parse("null")) catch {
    err => err.to_string() == "Cannot iterate over null (null)"
  } noraise {
    _ => false
  }) else {
    fail("expected add null iterate error")
  }
  guard (try execute(compile("add"), must_parse("1")) catch {
    err => err.to_string() == "Cannot iterate over number (1)"
  } noraise {
    _ => false
  }) else {
    fail("expected add number iterate error")
  }
  guard (try execute(compile("add"), must_parse("[true,false]")) catch {
    err =>
      err.to_string() == "boolean (true) and boolean (false) cannot be added"
  } noraise {
    _ => false
  }) else {
    fail("expected add type mismatch error")
  }
}

///|
test "execute add call compatibility" {
  @debug.assert_eq(
    must_execute(
      compile(
        "[add(null), add(range(range(10))), add(empty), add(10,range(10))]",
      ),
      must_parse("null"),
    ),
    [
      Value::array([
        Value::null(),
        Value::number(120.0),
        Value::null(),
        Value::number(55.0),
      ]),
    ],
  )
  @debug.assert_eq(
    must_execute(
      compile("add(.[].a)"),
      must_parse("[{\"a\":3}, {\"a\":5}, {\"b\":6}]"),
    ),
    [Value::number(8.0)],
  )
}

///|
test "execute sort compatibility" {
  @debug.assert_eq(must_execute(compile("sort"), must_parse("[3,1,2]")), [
    Value::array([Value::number(1.0), Value::number(2.0), Value::number(3.0)]),
  ])
  @debug.assert_eq(
    must_execute(compile("sort"), must_parse("[{},[],\"a\",0,true,false,null]")),
    [
      Value::array([
        Value::null(),
        Value::boolean(false),
        Value::boolean(true),
        Value::number(0.0),
        Value::string("a"),
        Value::array([]),
        Value::object(Map([])),
      ]),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("sort"), must_parse("[[1,2],[1,1],[1],[]]")),
    [
      Value::array([
        Value::array([]),
        Value::array([Value::number(1.0)]),
        Value::array([Value::number(1.0), Value::number(1.0)]),
        Value::array([Value::number(1.0), Value::number(2.0)]),
      ]),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("sort"), must_parse("[{\"a\":2},{\"a\":1}]")),
    [
      Value::array([
        Value::object({ "a": Value::number(1.0) }),
        Value::object({ "a": Value::number(2.0) }),
      ]),
    ],
  )
}

///|
test "execute sort errors" {
  guard (try execute(compile("sort"), must_parse("1")) catch {
    err =>
      err.to_string() == "number (1) cannot be sorted, as it is not an array"
  } noraise {
    _ => false
  }) else {
    fail("expected sort non-array type error")
  }
  guard (try execute(compile("sort"), must_parse("null")) catch {
    err =>
      err.to_string() == "null (null) cannot be sorted, as it is not an array"
  } noraise {
    _ => false
  }) else {
    fail("expected sort null type error")
  }
}

///|
test "execute sort_by compatibility" {
  @debug.assert_eq(
    must_execute(compile("sort_by(.a)"), must_parse("[{\"a\":2},{\"a\":1}]")),
    [
      Value::array([
        Value::object({ "a": Value::number(1.0) }),
        Value::object({ "a": Value::number(2.0) }),
      ]),
    ],
  )
  @debug.assert_eq(must_execute(compile("sort_by(.)"), must_parse("[3,1,2]")), [
    Value::array([Value::number(1.0), Value::number(2.0), Value::number(3.0)]),
  ])
  @debug.assert_eq(
    must_execute(compile("sort_by(empty)"), must_parse("[{\"a\":2},{\"a\":1}]")),
    [
      Value::array([
        Value::object({ "a": Value::number(2.0) }),
        Value::object({ "a": Value::number(1.0) }),
      ]),
    ],
  )
  @debug.assert_eq(
    must_execute(
      compile("sort_by(.a, .b)"),
      must_parse("[{\"a\":1,\"b\":2},{\"a\":1,\"b\":1},{\"a\":0,\"b\":3}]"),
    ),
    [
      Value::array([
        Value::object({ "a": Value::number(0.0), "b": Value::number(3.0) }),
        Value::object({ "a": Value::number(1.0), "b": Value::number(1.0) }),
        Value::object({ "a": Value::number(1.0), "b": Value::number(2.0) }),
      ]),
    ],
  )
}

///|
test "execute sort_by errors" {
  guard (try execute(compile("sort_by(.)"), must_parse("1")) catch {
    err => err.to_string() == "Cannot iterate over number (1)"
  } noraise {
    _ => false
  }) else {
    fail("expected sort_by non-array error")
  }
}

///|
test "execute group_by compatibility" {
  @debug.assert_eq(
    must_execute(
      compile("group_by(.a)"),
      must_parse("[{\"a\":2},{\"a\":1},{\"a\":2}]"),
    ),
    [
      Value::array([
        Value::array([Value::object({ "a": Value::number(1.0) })]),
        Value::array([
          Value::object({ "a": Value::number(2.0) }),
          Value::object({ "a": Value::number(2.0) }),
        ]),
      ]),
    ],
  )
  @debug.assert_eq(
    must_execute(compile("group_by(.)"), must_parse("[3,1,2,1]")),
    [
      Value::array([
        Value::array([Value::number(1.0), Value::number(1.0)]),
        Value::array([Value::number(2.0)]),
        Value::array([Value::number(3.0)]),
      ]),
    ],
  )
  @debug.assert_eq(must_execute(compile("group_by(.)"), must_parse("[]")), [
    Value::array([]),
  ])
  @debug.assert_eq(
    must_execute(
      compile("group_by(empty)"),
      must_parse("[{\"a\":2},{\"a\":1}]"),
    ),
    [
      Value::array([
        Value::array([
          Value::object({ "a": Value::number(2.0) }),
          Value::object({ "a": Value::number(1.0) }),
        ]),
      ]),
    ],
  )
}

///|
test "execute group_by errors" {
  guard (try execute(compile("group_by(.)"), must_parse("1")) catch {
    err => err.to_string() == "Cannot iterate over number (1)"
  } noraise {
    _ => false
  }) else {
    fail("expected group_by non-array error")
  }
}

///|
test "execute min/max compatibility" {
  @debug.assert_eq(must_execute(compile("min"), must_parse("[3,1,2]")), [
    Value::number(1.0),
  ])
  @debug.assert_eq(must_execute(compile("max"), must_parse("[3,1,2]")), [
    Value::number(3.0),
  ])
  @debug.assert_eq(must_execute(compile("min"), must_parse("[]")), [
    Value::null(),
  ])
  @debug.assert_eq(must_execute(compile("max"), must_parse("[]")), [
    Value::null(),
  ])
  @debug.assert_eq(
    must_execute(compile("min"), must_parse("[{\"a\":2},{\"a\":1}]")),
    [Value::object({ "a": Value::number(1.0) })],
  )
  @debug.assert_eq(
    must_execute(compile("max"), must_parse("[{\"a\":2},{\"a\":1}]")),
    [Value::object({ "a": Value::number(2.0) })],
  )
}

///|
test "execute min/max errors" {
  guard (try execute(compile("min"), must_parse("1")) catch {
    err =>
      err.to_string() == "number (1) and number (1) cannot be iterated over"
  } noraise {
    _ => false
  }) else {
    fail("expected min non-array iterate error")
  }
  guard (try execute(compile("max"), must_parse("null")) catch {
    err =>
      err.to_string() == "null (null) and null (null) cannot be iterated over"
  } noraise {
    _ => false
  }) else {
    fail("expected max null iterate error")
  }
}

///|
test "execute min_by/max_by compatibility" {
  @debug.assert_eq(
    must_execute(compile("min_by(.a)"), must_parse("[{\"a\":2},{\"a\":1}]")),
    [Value::object({ "a": Value::number(1.0) })],
  )
  @debug.assert_eq(
    must_execute(compile("max_by(.a)"), must_parse("[{\"a\":2},{\"a\":1}]")),
    [Value::object({ "a": Value::number(2.0) })],
  )
  @debug.assert_eq(must_execute(compile("min_by(.)"), must_parse("[3,1,2]")), [
    Value::number(1.0),
  ])
  @debug.assert_eq(must_execute(compile("max_by(.)"), must_parse("[3,1,2]")), [
    Value::number(3.0),
  ])
  @debug.assert_eq(must_execute(compile("min_by(.)"), must_parse("[]")), [
    Value::null(),
  ])
  @debug.assert_eq(must_execute(compile("max_by(.)"), must_parse("[]")), [
    Value::null(),
  ])
  @debug.assert_eq(
    must_execute(compile("min_by(empty)"), must_parse("[{\"a\":2},{\"a\":1}]")),
    [Value::object({ "a": Value::number(2.0) })],
  )
  @debug.assert_eq(
    must_execute(compile("max_by(empty)"), must_parse("[{\"a\":2},{\"a\":1}]")),
    [Value::object({ "a": Value::number(1.0) })],
  )
  @debug.assert_eq(
    must_execute(
      compile("max_by(.k)"),
      must_parse("[{\"k\":1,\"id\":\"a\"},{\"k\":1,\"id\":\"b\"}]"),
    ),
    [Value::object({ "k": Value::number(1.0), "id": Value::string("b") })],
  )
}

///|
test "execute min_by/max_by errors" {
  guard (try execute(compile("min_by(.)"), must_parse("1")) catch {
    err => err.to_string() == "Cannot iterate over number (1)"
  } noraise {
    _ => false
  }) else {
    fail("expected min_by non-array error")
  }
  guard (try execute(compile("max_by(.)"), must_parse("1")) catch {
    err => err.to_string() == "Cannot iterate over number (1)"
  } noraise {
    _ => false
  }) else {
    fail("expected max_by non-array error")
  }
}

///|
test "execute unique compatibility" {
  @debug.assert_eq(must_execute(compile("unique"), must_parse("[1,2,1,3]")), [
    Value::array([Value::number(1.0), Value::number(2.0), Value::number(3.0)]),
  ])
  @debug.assert_eq(must_execute(compile("unique"), must_parse("[]")), [
    Value::array([]),
  ])
  @debug.assert_eq(
    must_execute(
      compile("unique"),
      must_parse("[{\"a\":2},{\"a\":1},{\"a\":2}]"),
    ),
    [
      Value::array([
        Value::object({ "a": Value::number(1.0) }),
        Value::object({ "a": Value::number(2.0) }),
      ]),
    ],
  )
}

///|
test "execute unique errors" {
  guard (try execute(compile("unique"), must_parse("1")) catch {
    err =>
      err.to_string() == "number (1) cannot be sorted, as it is not an array"
  } noraise {
    _ => false
  }) else {
    fail("expected unique non-array type error")
  }
  guard (try execute(compile("unique"), must_parse("null")) catch {
    err =>
      err.to_string() == "null (null) cannot be sorted, as it is not an array"
  } noraise {
    _ => false
  }) else {
    fail("expected unique null type error")
  }
}

///|
test "execute unique_by compatibility" {
  @debug.assert_eq(
    must_execute(
      compile("unique_by(.a)"),
      must_parse(
        "[{\"a\":2,\"b\":\"x\"},{\"a\":1,\"b\":\"x\"},{\"a\":2,\"b\":\"y\"}]",
      ),
    ),
    [
      Value::array([
        Value::object({ "a": Value::number(1.0), "b": Value::string("x") }),
        Value::object({ "a": Value::number(2.0), "b": Value::string("x") }),
      ]),
    ],
  )
  @debug.assert_eq(must_execute(compile("unique_by(.)"), must_parse("[]")), [
    Value::array([]),
  ])
  @debug.assert_eq(
    must_execute(
      compile("unique_by(empty)"),
      must_parse("[{\"a\":2},{\"a\":1}]"),
    ),
    [Value::array([Value::object({ "a": Value::number(2.0) })])],
  )
  @debug.assert_eq(
    must_execute(
      compile("unique_by((.a,.b))"),
      must_parse("[{\"a\":2},{\"a\":1}]"),
    ),
    [
      Value::array([
        Value::object({ "a": Value::number(1.0) }),
        Value::object({ "a": Value::number(2.0) }),
      ]),
    ],
  )
}

///|
test "execute unique_by errors" {
  guard (try execute(compile("unique_by(.)"), must_parse("1")) catch {
    err => err.to_string() == "Cannot iterate over number (1)"
  } noraise {
    _ => false
  }) else {
    fail("expected unique_by non-array error")
  }
}
