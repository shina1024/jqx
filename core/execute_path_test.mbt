///|
// Source under test: core/path_ops.mbt, core/builtin_path.mbt

///|
test "execute getpath compatibility" {
  let j = must_parse("{\"a\":[1,2],\"b\":{\"c\":3}}")
  assert_eq(must_execute(parse_filter("getpath([\"a\",1])"), j), [
    Json::number(2.0),
  ])
  assert_eq(must_execute(parse_filter("getpath([\"b\",\"c\"])"), j), [
    Json::number(3.0),
  ])
  assert_eq(must_execute(parse_filter("getpath([\"a\",9])"), j), [Json::null()])
  assert_eq(must_execute(parse_filter("getpath([\"x\"])"), j), [Json::null()])
  assert_eq(
    must_execute(parse_filter("getpath(( [\"a\",0], [\"a\",1] ))"), j),
    [Json::number(1.0), Json::number(2.0)],
  )
  assert_eq(must_execute(parse_filter("getpath([])"), j), [j])
  assert_eq(must_execute(parse_filter("getpath(empty)"), j), [])
  assert_eq(
    must_execute(parse_filter("getpath([1.9])"), must_parse("[10,20,30]")),
    [Json::number(20.0)],
  )
  assert_eq(
    must_execute(parse_filter("getpath([\"a\"])"), must_parse("null")),
    [Json::null()],
  )
  assert_eq(must_execute(parse_filter("getpath([0])"), must_parse("null")), [
    Json::null(),
  ])
  assert_eq(must_execute(parse_filter("getpath([{}])"), must_parse("null")), [
    Json::null(),
  ])
}

///|
test "execute getpath errors" {
  guard (try? execute(parse_filter("getpath(\"a\")"), must_parse("{\"a\":1}")))
    is Err(err) &&
    err.to_string() == "Path must be specified as an array" else {
    fail("expected getpath path-array type error")
  }
  guard (try? execute(parse_filter("getpath([\"a\"])"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "Cannot index number with string \"a\"" else {
    fail("expected getpath number string-index error")
  }
  guard (try? execute(parse_filter("getpath([0])"), must_parse("{\"a\":1}")))
    is Err(err) &&
    err.to_string() == "Cannot index object with number" else {
    fail("expected getpath object number-index error")
  }
  guard (try? execute(parse_filter("getpath([\"a\"])"), must_parse("[1,2]")))
    is Err(err) &&
    err.to_string() == "Cannot index array with string \"a\"" else {
    fail("expected getpath array string-index error")
  }
  guard (try? execute(parse_filter("getpath([true])"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "Cannot index null with boolean" else {
    fail("expected getpath null boolean-index error")
  }
  guard (try? execute(parse_filter("getpath([[]])"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "Cannot index null with array" else {
    fail("expected getpath null array-index error")
  }
}

///|
test "execute setpath compatibility" {
  assert_eq(
    must_execute(parse_filter("setpath([\"a\"];2)"), must_parse("{\"a\":1}")),
    [Json::object({ "a": Json::number(2.0) })],
  )
  assert_eq(
    must_execute(parse_filter("setpath([\"a\",\"b\"];1)"), must_parse("{}")),
    [Json::object({ "a": Json::object({ "b": Json::number(1.0) }) })],
  )
  assert_eq(must_execute(parse_filter("setpath([2];1)"), must_parse("[]")), [
    Json::array([Json::null(), Json::null(), Json::number(1.0)]),
  ])
  assert_eq(
    must_execute(parse_filter("setpath([-1];9)"), must_parse("[0,1]")),
    [Json::array([Json::number(0.0), Json::number(9.0)])],
  )
  assert_eq(
    must_execute(parse_filter("setpath([1.9];9)"), must_parse("[0,1]")),
    [Json::array([Json::number(0.0), Json::number(9.0)])],
  )
  assert_eq(
    must_execute(parse_filter("setpath([\"a\"];2)"), must_parse("null")),
    [Json::object({ "a": Json::number(2.0) })],
  )
  assert_eq(must_execute(parse_filter("setpath([0];2)"), must_parse("null")), [
    Json::array([Json::number(2.0)]),
  ])
  assert_eq(
    must_execute(parse_filter("setpath([];2)"), must_parse("{\"a\":1}")),
    [Json::number(2.0)],
  )
  assert_eq(
    must_execute(
      parse_filter("setpath(([\"a\"],[\"b\"]);(2,3))"),
      must_parse("{\"a\":1}"),
    ),
    [
      Json::object({ "a": Json::number(2.0) }),
      Json::object({ "a": Json::number(1.0), "b": Json::number(2.0) }),
      Json::object({ "a": Json::number(3.0) }),
      Json::object({ "a": Json::number(1.0), "b": Json::number(3.0) }),
    ],
  )
  assert_eq(
    must_execute(parse_filter("setpath(empty;2)"), must_parse("{\"a\":1}")),
    [],
  )
  assert_eq(
    must_execute(
      parse_filter("setpath([\"a\"];empty)"),
      must_parse("{\"a\":1}"),
    ),
    [],
  )
  assert_eq(
    must_execute(
      parse_filter("setpath((empty,[\"a\"]);2)"),
      must_parse("{\"a\":1}"),
    ),
    [Json::object({ "a": Json::number(2.0) })],
  )
  assert_eq(
    must_execute(parse_filter("setpath([\"a\",2];1)"), must_parse("{}")),
    [
      Json::object({
        "a": Json::array([Json::null(), Json::null(), Json::number(1.0)]),
      }),
    ],
  )
  assert_eq(
    must_execute(parse_filter("setpath([0,\"a\"];1)"), must_parse("[]")),
    [Json::array([Json::object({ "a": Json::number(1.0) })])],
  )
}

///|
test "execute setpath errors" {
  guard (try? execute(parse_filter("setpath(\"a\";2)"), must_parse("{\"a\":1}")))
    is Err(err) &&
    err.to_string() == "Path must be specified as an array" else {
    fail("expected setpath path-array error")
  }
  guard (try? execute(parse_filter("setpath([{}];2)"), must_parse("{\"a\":1}")))
    is Err(err) &&
    err.to_string() == "Cannot index object with object" else {
    fail("expected setpath object-key type error")
  }
  guard (try? execute(
      parse_filter("setpath([[\"a\"]];2)"),
      must_parse("{\"a\":1}"),
    ))
    is Err(err) &&
    err.to_string() == "Cannot index object with array" else {
    fail("expected setpath array-key type error")
  }
  guard (try? execute(parse_filter("setpath([\"a\"];2)"), must_parse("[1,2]")))
    is Err(err) &&
    err.to_string() == "Cannot index array with string \"a\"" else {
    fail("expected setpath array string-index error")
  }
  guard (try? execute(parse_filter("setpath([0];2)"), must_parse("{\"a\":1}")))
    is Err(err) &&
    err.to_string() == "Cannot index object with number" else {
    fail("expected setpath object number-index error")
  }
  guard (try? execute(parse_filter("setpath([\"a\"];2)"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "Cannot index number with string \"a\"" else {
    fail("expected setpath number string-index error")
  }
  guard (try? execute(parse_filter("setpath([0];2)"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "Cannot index number with number" else {
    fail("expected setpath number index error")
  }
  guard (try? execute(parse_filter("setpath([true];2)"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "Cannot index null with boolean" else {
    fail("expected setpath null boolean-index error")
  }
  guard (try? execute(parse_filter("setpath([[]];2)"), must_parse("null")))
    is Err(err) &&
    err.to_string() == "Cannot index null with array" else {
    fail("expected setpath null array-index error")
  }
  guard (try? execute(
      parse_filter("setpath([(1e308 * 10)];2)"),
      must_parse("[]"),
    ))
    is Err(err) &&
    err.to_string() == "Array index too large" else {
    fail("expected setpath array index too large error")
  }
  guard (try? execute(
      parse_filter("setpath([134217728];2)"),
      must_parse("null"),
    ))
    is Err(err) &&
    err.to_string() == "Array index too large" else {
    fail("expected setpath expansion-limit array index too large error")
  }
  guard (try? execute(
      parse_filter("setpath([999999999];2)"),
      must_parse("null"),
    ))
    is Err(err) &&
    err.to_string() == "Array index too large" else {
    fail("expected setpath huge array index too large error")
  }
  guard (try? execute(
      parse_filter("setpath([((1e308 * 10) - (1e308 * 10))];2)"),
      must_parse("[]"),
    ))
    is Err(err) &&
    err.to_string() == "Cannot set array element at NaN index" else {
    fail("expected setpath NaN index error")
  }
  guard (try? execute(parse_filter("setpath([-1];2)"), must_parse("[]")))
    is Err(err) &&
    err.to_string() == "Out of bounds negative array index" else {
    fail("expected setpath negative index error")
  }
  guard (try? execute(
      parse_filter("setpath([-999999999];2)"),
      must_parse("null"),
    ))
    is Err(err) &&
    err.to_string() == "Out of bounds negative array index" else {
    fail("expected setpath huge negative index error")
  }
  guard (try? execute(parse_filter("setpath([\"a\",-1];1)"), must_parse("{}")))
    is Err(err) &&
    err.to_string() == "Out of bounds negative array index" else {
    fail("expected setpath nested negative index error")
  }
  guard (try? execute(parse_filter("setpath([{}];2)"), must_parse("[1,2]")))
    is Err(err) &&
    err.to_string() == "Array/string slice indices must be integers" else {
    fail("expected setpath object index-in-array error")
  }
  guard (try? execute(parse_filter("setpath([[]];2)"), must_parse("[1,2]")))
    is Err(err) &&
    err.to_string() == "Cannot update field at array index of array" else {
    fail("expected setpath array index-in-array error")
  }
  assert_eq(
    must_execute(parse_filter("setpath(.foo;empty)"), must_parse("1")),
    [],
  )
  assert_eq(
    must_execute(parse_filter("setpath(\"a\";empty)"), must_parse("1")),
    [],
  )
}

///|
test "execute delpaths compatibility" {
  assert_eq(
    must_execute(
      parse_filter("delpaths([[\"a\"]])"),
      must_parse("{\"a\":1,\"b\":2}"),
    ),
    [Json::object({ "b": Json::number(2.0) })],
  )
  assert_eq(
    must_execute(
      parse_filter("delpaths([[\"a\",\"b\"],[\"d\"]])"),
      must_parse("{\"a\":{\"b\":1,\"c\":2},\"d\":3}"),
    ),
    [Json::object({ "a": Json::object({ "c": Json::number(2.0) }) })],
  )
  assert_eq(
    must_execute(parse_filter("delpaths([[1]])"), must_parse("[10,20,30]")),
    [Json::array([Json::number(10.0), Json::number(30.0)])],
  )
  assert_eq(
    must_execute(parse_filter("delpaths([[1],[0]])"), must_parse("[10,20,30]")),
    [Json::array([Json::number(30.0)])],
  )
  assert_eq(
    must_execute(parse_filter("delpaths([[-1]])"), must_parse("[10,20,30]")),
    [Json::array([Json::number(10.0), Json::number(20.0)])],
  )
  assert_eq(
    must_execute(parse_filter("delpaths([[9]])"), must_parse("[10,20,30]")),
    [Json::array([Json::number(10.0), Json::number(20.0), Json::number(30.0)])],
  )
  assert_eq(
    must_execute(
      parse_filter("delpaths([[\"a\"],[0],[true]])"),
      must_parse("null"),
    ),
    [Json::null()],
  )
  assert_eq(
    must_execute(parse_filter("delpaths([[]])"), must_parse("{\"a\":1}")),
    [Json::null()],
  )
  assert_eq(must_execute(parse_filter("delpaths([[]])"), must_parse("1")), [
    Json::null(),
  ])
  assert_eq(
    must_execute(
      parse_filter("delpaths([[\"a\",\"x\"]])"),
      must_parse("{\"a\":{\"b\":1}}"),
    ),
    [Json::object({ "a": Json::object({ "b": Json::number(1.0) }) })],
  )
  assert_eq(
    must_execute(
      parse_filter("delpaths([[\"a\",\"x\"]])"),
      must_parse("{\"a\":null}"),
    ),
    [Json::object({ "a": Json::null() })],
  )
  assert_eq(
    must_execute(parse_filter("delpaths(empty)"), must_parse("{\"a\":1}")),
    [],
  )
  assert_eq(
    must_execute(
      parse_filter("delpaths(([[\"a\"]],[]))"),
      must_parse("{\"a\":1}"),
    ),
    [Json::object(Map::new()), Json::object({ "a": Json::number(1.0) })],
  )
}

///|
test "execute delpaths errors" {
  guard (try? execute(parse_filter("delpaths(\"a\")"), must_parse("{\"a\":1}")))
    is Err(err) &&
    err.to_string() == "Paths must be specified as an array" else {
    fail("expected delpaths paths-array error")
  }
  guard (try? execute(
      parse_filter("delpaths([\"a\"])"),
      must_parse("{\"a\":1}"),
    ))
    is Err(err) &&
    err.to_string() == "Path must be specified as array, not string" else {
    fail("expected delpaths path type error")
  }
  guard (try? execute(parse_filter("delpaths([1])"), must_parse("{\"a\":1}")))
    is Err(err) &&
    err.to_string() == "Path must be specified as array, not number" else {
    fail("expected delpaths numeric path type error")
  }
  guard (try? execute(parse_filter("delpaths([[\"a\"]])"), must_parse("1")))
    is Err(err) &&
    err.to_string() == "Cannot delete fields from number" else {
    fail("expected delpaths scalar delete error")
  }
  guard (try? execute(parse_filter("delpaths([[0]])"), must_parse("\"x\"")))
    is Err(err) &&
    err.to_string() == "Cannot delete fields from string" else {
    fail("expected delpaths string delete error")
  }
  guard (try? execute(parse_filter("delpaths([[0]])"), must_parse("true")))
    is Err(err) &&
    err.to_string() == "Cannot delete fields from boolean" else {
    fail("expected delpaths boolean delete error")
  }
  guard (try? execute(parse_filter("delpaths([[0]])"), must_parse("{\"a\":1}")))
    is Err(err) &&
    err.to_string() == "Cannot delete number field of object" else {
    fail("expected delpaths object number-field error")
  }
  guard (try? execute(
      parse_filter("delpaths([[true]])"),
      must_parse("{\"a\":1}"),
    ))
    is Err(err) &&
    err.to_string() == "Cannot delete boolean field of object" else {
    fail("expected delpaths object boolean-field error")
  }
  guard (try? execute(parse_filter("delpaths([[{}]])"), must_parse("{\"a\":1}")))
    is Err(err) &&
    err.to_string() == "Cannot delete object field of object" else {
    fail("expected delpaths object object-field error")
  }
  guard (try? execute(parse_filter("delpaths([[[]]])"), must_parse("{\"a\":1}")))
    is Err(err) &&
    err.to_string() == "Cannot delete array field of object" else {
    fail("expected delpaths object array-field error")
  }
  guard (try? execute(
      parse_filter("delpaths([[null]])"),
      must_parse("{\"a\":1}"),
    ))
    is Err(err) &&
    err.to_string() == "Cannot delete null field of object" else {
    fail("expected delpaths object null-field error")
  }
  guard (try? execute(parse_filter("delpaths([[\"a\"]])"), must_parse("[1,2]")))
    is Err(err) &&
    err.to_string() == "Cannot delete string element of array" else {
    fail("expected delpaths array string-element error")
  }
  guard (try? execute(parse_filter("delpaths([[true]])"), must_parse("[1,2]")))
    is Err(err) &&
    err.to_string() == "Cannot delete boolean element of array" else {
    fail("expected delpaths array boolean-element error")
  }
  guard (try? execute(parse_filter("delpaths([[null]])"), must_parse("[1,2]")))
    is Err(err) &&
    err.to_string() == "Cannot delete null element of array" else {
    fail("expected delpaths array null-element error")
  }
  guard (try? execute(parse_filter("delpaths([[[]]])"), must_parse("[1,2]")))
    is Err(err) &&
    err.to_string() == "Cannot delete array element of array" else {
    fail("expected delpaths array array-element error")
  }
  guard (try? execute(parse_filter("delpaths([[{}]])"), must_parse("[1,2]")))
    is Err(err) &&
    err.to_string() == "Array/string slice indices must be integers" else {
    fail("expected delpaths array object-index error")
  }
}

///|
test "execute path compatibility" {
  assert_eq(must_execute(parse_filter("path(.foo[0,1])"), must_parse("null")), [
    Json::array([Json::string("foo"), Json::number(0.0)]),
    Json::array([Json::string("foo"), Json::number(1.0)]),
  ])
  assert_eq(
    must_execute(parse_filter("path(.[] | select(.>3))"), must_parse("[1,5,3]")),
    [Json::array([Json::number(1.0)])],
  )
  assert_eq(must_execute(parse_filter("path(.)"), must_parse("42")), [
    Json::array([]),
  ])
  assert_eq(must_execute(parse_filter("path(.a[0].b)"), must_parse("null")), [
    Json::array([Json::string("a"), Json::number(0.0), Json::string("b")]),
  ])
  assert_eq(
    must_execute(
      parse_filter("path(.a[path(.b)[0]])"),
      must_parse("{\"a\":{\"b\":0}}"),
    ),
    [Json::array([Json::string("a"), Json::string("b")])],
  )
  assert_eq(
    must_execute(parse_filter("[path(..)]"), must_parse("{\"a\":[{\"b\":1}]}")),
    [
      Json::array([
        Json::array([]),
        Json::array([Json::string("a")]),
        Json::array([Json::string("a"), Json::number(0.0)]),
        Json::array([Json::string("a"), Json::number(0.0), Json::string("b")]),
      ]),
    ],
  )
}

///|
test "execute path invalid expression errors" {
  guard (try? execute(
      parse_filter("path(.a | map(select(.b == 0)))"),
      must_parse("{\"a\":[{\"b\":0}]}"),
    ))
    is Err(err) &&
    err.to_string() == "Invalid path expression with result [{\"b\":0}]" else {
    fail("expected invalid path expression result error")
  }
  guard (try? execute(
      parse_filter("path(.a | map(select(.b == 0)) | .[0])"),
      must_parse("{\"a\":[{\"b\":0}]}"),
    ))
    is Err(err) &&
    err.to_string() ==
    "Invalid path expression near attempt to access element 0 of [{\"b\":0}]" else {
    fail("expected invalid path expression index access error")
  }
  guard (try? execute(
      parse_filter("path(.a | map(select(.b == 0)) | .c)"),
      must_parse("{\"a\":[{\"b\":0}]}"),
    ))
    is Err(err) &&
    err.to_string() ==
    "Invalid path expression near attempt to access element \"c\" of [{\"b\":0}]" else {
    fail("expected invalid path expression field access error")
  }
  guard (try? execute(
      parse_filter("path(.a | map(select(.b == 0)) | .[])"),
      must_parse("{\"a\":[{\"b\":0}]}"),
    ))
    is Err(err) &&
    err.to_string() ==
    "Invalid path expression near attempt to iterate through [{\"b\":0}]" else {
    fail("expected invalid path expression iterate error")
  }
}

///|
test "execute del compatibility" {
  assert_eq(
    must_execute(
      parse_filter("del(.[2:4],.[0],.[-2:])"),
      must_parse("[0,1,2,3,4,5,6,7]"),
    ),
    [Json::array([Json::number(1.0), Json::number(4.0), Json::number(5.0)])],
  )
  assert_eq(
    must_execute(
      parse_filter(
        "del(.), del(empty), del((.foo,.bar,.baz) | .[2,3,0]), del(.foo[0], .bar[0], .foo, .baz.bar[0].x)",
      ),
      must_parse("{\"foo\": [0,1,2,3,4], \"bar\": [0,1]}"),
    ),
    [
      Json::null(),
      Json::object({
        "bar": Json::array([Json::number(0.0), Json::number(1.0)]),
        "foo": Json::array([
          Json::number(0.0),
          Json::number(1.0),
          Json::number(2.0),
          Json::number(3.0),
          Json::number(4.0),
        ]),
      }),
      Json::object({
        "bar": Json::array([Json::number(1.0)]),
        "foo": Json::array([Json::number(1.0), Json::number(4.0)]),
      }),
      Json::object({ "bar": Json::array([Json::number(1.0)]) }),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("del(.[1], .[-6], .[2], .[-3:9])"),
      must_parse("[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]"),
    ),
    [
      Json::array([
        Json::number(0.0),
        Json::number(3.0),
        Json::number(5.0),
        Json::number(6.0),
        Json::number(9.0),
      ]),
    ],
  )
  assert_eq(
    must_execute(
      parse_filter("del(.foo)"),
      must_parse("{\"foo\": 42, \"bar\": 9001, \"baz\": 42}"),
    ),
    [Json::object({ "bar": Json::number(9001.0), "baz": Json::number(42.0) })],
  )
  assert_eq(
    must_execute(
      parse_filter("del(.[1, 2])"),
      must_parse("[\"foo\", \"bar\", \"baz\"]"),
    ),
    [Json::array([Json::string("foo")])],
  )
  assert_eq(must_execute(parse_filter("del(empty)"), must_parse("1")), [
    Json::number(1.0),
  ])
}

///|
test "execute paths compatibility" {
  let obj = must_parse("{\"a\":1,\"b\":[2,3]}")
  assert_eq(must_execute(parse_filter("paths"), obj), [
    Json::array([Json::string("a")]),
    Json::array([Json::string("b")]),
    Json::array([Json::string("b"), Json::number(0.0)]),
    Json::array([Json::string("b"), Json::number(1.0)]),
  ])
  assert_eq(must_execute(parse_filter("paths(type==\"number\")"), obj), [
    Json::array([Json::string("a")]),
    Json::array([Json::string("b"), Json::number(0.0)]),
    Json::array([Json::string("b"), Json::number(1.0)]),
  ])
  assert_eq(must_execute(parse_filter("paths(type==\"array\" or .==3)"), obj), [
    Json::array([Json::string("b")]),
    Json::array([Json::string("b"), Json::number(1.0)]),
  ])
  assert_eq(
    must_execute(parse_filter("paths"), must_parse("[1,[2],{\"a\":3}]")),
    [
      Json::array([Json::number(0.0)]),
      Json::array([Json::number(1.0)]),
      Json::array([Json::number(1.0), Json::number(0.0)]),
      Json::array([Json::number(2.0)]),
      Json::array([Json::number(2.0), Json::string("a")]),
    ],
  )
  assert_eq(must_execute(parse_filter("paths"), must_parse("1")), [])
  assert_eq(must_execute(parse_filter("paths"), must_parse("null")), [])
  assert_eq(must_execute(parse_filter("paths"), must_parse("{}")), [])
  assert_eq(must_execute(parse_filter("paths"), must_parse("[]")), [])
  assert_eq(must_execute(parse_filter("paths(.)"), must_parse("1")), [])
  assert_eq(
    must_execute(
      parse_filter("paths(values)"),
      must_parse("{\"a\":null,\"b\":1}"),
    ),
    [Json::array([Json::string("b")])],
  )
  assert_eq(must_execute(parse_filter("paths(empty)"), obj), [])
  assert_eq(
    must_execute(parse_filter("paths((true,true))"), must_parse("{\"a\":1}")),
    [Json::array([Json::string("a")])],
  )
}

///|
test "execute paths errors" {
  guard (try? execute(parse_filter("paths(.foo)"), must_parse("{\"a\":1}")))
    is Err(err) &&
    err.to_string() == "Cannot index number with string \"foo\"" else {
    fail("expected paths predicate string-index error")
  }
  guard (try? execute(parse_filter("paths(.[0])"), must_parse("{\"a\":1}")))
    is Err(err) &&
    err.to_string() == "Cannot index number with number" else {
    fail("expected paths predicate number-index error")
  }
}
