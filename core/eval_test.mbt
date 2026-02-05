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
test "eval index and iter" {
  let j = must_parse("[1,2,3]")
  let f1 = parse_filter(".[1]")
  let f2 = parse_filter(".[]")
  assert_eq(must_eval(f1, j), [Json::number(2.0)])
  assert_eq(
    must_eval(f2, j),
    [Json::number(1.0), Json::number(2.0), Json::number(3.0)],
  )
}

///|
test "eval pipe and comma" {
  let j = must_parse("{\"a\":{\"b\":2},\"c\":3}")
  let f = parse_filter(".a | .b, .c")
  assert_eq(
    must_eval(f, j),
    [Json::number(2.0), Json::number(3.0)],
  )
}

///|
test "eval literal" {
  let j = must_parse("null")
  let f = parse_filter("\"hi\"")
  assert_eq(must_eval(f, j), [Json::string("hi")])
}

///|
test "eval iter non-array errors" {
  let j = must_parse("1")
  let f = parse_filter(".[]")
  guard (try? eval(f, j)) is Err(_) else {
    fail("expected error for iter over non-array/object")
  }
}
