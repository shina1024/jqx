///|
/// Source under test: `core/module_source_fs.mbt`, `core/parser_lowering.mbt`
test "execute import/include filesystem module resolution" {
  clear_module_sources()
  clear_module_search_paths()
  set_module_search_paths(["third_party/jq-tests/tests/modules"])

  assert_eq(
    must_execute(
      parse_filter("import \"a\" as foo; foo::a"),
      must_parse("null"),
    ),
    [Value::string("a")],
  )
  assert_eq(
    must_execute(
      parse_filter("import \"b\" as bar; [bar::a, bar::b]"),
      must_parse("null"),
    ),
    [Value::array([Value::string("b"), Value::string("c")])],
  )
  assert_eq(
    must_execute(parse_filter("include \"shadow1\"; e"), must_parse("null")),
    [Value::number(2.0)],
  )

  clear_module_search_paths()
  clear_module_sources()
}

///|
test "execute import/include filesystem module resolution preserves non-BMP codepoints" {
  clear_module_sources()
  clear_module_search_paths()
  set_module_search_paths(["core/testdata/native_modules"])

  let expected = must_parse("\"\\ud83d\\ude00\"")
  assert_eq(
    must_execute(
      parse_filter("import \"emoji\" as e; e::v"),
      must_parse("null"),
    ),
    [expected],
  )
  assert_eq(
    must_execute(parse_filter("include \"emoji\"; v"), must_parse("null")),
    [expected],
  )

  clear_module_search_paths()
  clear_module_sources()
}
