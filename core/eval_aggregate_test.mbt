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
  assert_eq(must_eval(parse_filter("any(.[]; . > 2)"), must_parse("[1,2,3]")), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("all(.[]; . > 0)"), must_parse("[1,2,3]")), [
    Json::boolean(true),
  ])
  assert_eq(must_eval(parse_filter("all(.[]; . > 2)"), must_parse("[1,2,3]")), [
    Json::boolean(false),
  ])
  assert_eq(must_eval(parse_filter("any(.[]; . > 9)"), must_parse("[1,2,3]")), [
    Json::boolean(false),
  ])
  assert_eq(
    must_eval(parse_filter("any(true, error; .)"), must_parse("\"badness\"")),
    [Json::boolean(true)],
  )
  assert_eq(
    must_eval(parse_filter("all(false, error; .)"), must_parse("\"badness\"")),
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
  guard (try? eval(parse_filter("error"), must_parse("\"x\""))) is Err(err) &&
    err.to_string() == "\"x\"" else {
    fail("expected error builtin")
  }
  guard (try? eval(parse_filter("error(\"boom\")"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "boom" else {
    fail("expected error(msg) call")
  }
}

///|
test "eval pick compatibility" {
  assert_eq(must_eval(parse_filter("pick(.a.b.c)"), must_parse("null")), [
    Json::object({
      "a": Json::object({ "b": Json::object({ "c": Json::null() }) }),
    }),
  ])
  assert_eq(must_eval(parse_filter("pick(first)"), must_parse("[1,2]")), [
    Json::array([Json::number(1.0)]),
  ])
  assert_eq(
    must_eval(parse_filter("pick(first|first)"), must_parse("[[10,20],30]")),
    [Json::array([Json::array([Json::number(10.0)])])],
  )
  assert_eq(
    must_eval(
      parse_filter("pick(.a, .b.c, .x)"),
      must_parse("{\"a\":1, \"b\":{\"c\":2,\"d\":3}, \"e\":4}"),
    ),
    [
      Json::object({
        "a": Json::number(1.0),
        "b": Json::object({ "c": Json::number(2.0) }),
        "x": Json::null(),
      }),
    ],
  )
  assert_eq(
    must_eval(parse_filter("pick(.[2], .[0], .[0])"), must_parse("[1,2,3,4]")),
    [Json::array([Json::number(1.0), Json::null(), Json::number(3.0)])],
  )
}

///|
test "eval pick errors" {
  guard (try? eval(parse_filter("pick(last)"), must_parse("[1,2]"))) is Err(err) &&
    err.to_string() == "Out of bounds negative array index" else {
    fail("expected pick(last) negative index error")
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
test "eval add call compatibility" {
  assert_eq(
    must_eval(
      parse_filter(
        "[add(null), add(range(range(10))), add(empty), add(10,range(10))]",
      ),
      must_parse("null"),
    ),
    [
      Json::array([
        Json::null(),
        Json::number(120.0),
        Json::null(),
        Json::number(55.0),
      ]),
    ],
  )
  assert_eq(
    must_eval(
      parse_filter("add(.[].a)"),
      must_parse("[{\"a\":3}, {\"a\":5}, {\"b\":6}]"),
    ),
    [Json::number(8.0)],
  )
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
