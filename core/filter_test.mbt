///|
test "parse identity" {
  inspect(parse_filter("."), content="Identity")
}

///|
test "parse field" {
  inspect(parse_filter(".foo"), content="Pipe(Identity, Field(\"foo\"))")
}

///|
test "parse chained fields" {
  inspect(
    parse_filter(".foo.bar"),
    content="Pipe(Pipe(Identity, Field(\"foo\")), Field(\"bar\"))",
  )
}

///|
test "parse index" {
  inspect(parse_filter(".[0]"), content="Pipe(Identity, Index(0))")
}

///|
test "parse iter" {
  inspect(parse_filter(".[]"), content="Pipe(Identity, Iter)")
}

///|
test "parse string key index" {
  inspect(parse_filter(".[\"foo\"]"), content="Pipe(Identity, Field(\"foo\"))")
}

///|
test "parse pipe and comma" {
  inspect(
    parse_filter(".foo | .bar, .baz"),
    content="Comma(Pipe(Pipe(Identity, Field(\"foo\")), Pipe(Identity, Field(\"bar\"))), Pipe(Identity, Field(\"baz\")))",
  )
}

///|
test "parse literals" {
  inspect(parse_filter("null"), content="Literal(Null)")
  inspect(parse_filter("true"), content="Literal(True)")
  inspect(parse_filter("false"), content="Literal(False)")
  inspect(parse_filter("\"hi\""), content="Literal(String(\"hi\"))")
  inspect(parse_filter("123"), content="Literal(Number(123))")
}

///|
test "parse builtin" {
  inspect(parse_filter("length"), content="Builtin(\"length\")")
  inspect(parse_filter("type"), content="Builtin(\"type\")")
  inspect(parse_filter("keys"), content="Builtin(\"keys\")")
}

///|
test "parse call" {
  inspect(
    parse_filter("select(.a)"),
    content="Call(\"select\", [Pipe(Identity, Field(\"a\"))])",
  )
}

///|
test "parse compare" {
  inspect(
    parse_filter(".a == .b"),
    content="Eq(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")))",
  )
  inspect(
    parse_filter(".a != .b"),
    content="Neq(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")))",
  )
  inspect(
    parse_filter(".a < .b"),
    content="Lt(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")))",
  )
  inspect(
    parse_filter(".a <= .b"),
    content="Lte(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")))",
  )
  inspect(
    parse_filter(".a > .b"),
    content="Gt(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")))",
  )
  inspect(
    parse_filter(".a >= .b"),
    content="Gte(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")))",
  )
}

///|
test "parse logical" {
  inspect(
    parse_filter(".a and .b"),
    content="And(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")))",
  )
  inspect(
    parse_filter(".a or .b"),
    content="Or(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")))",
  )
  inspect(
    parse_filter("not .a"),
    content="Not(Pipe(Identity, Field(\"a\")))",
  )
}

///|
test "parse array and object literals" {
  inspect(parse_filter("[.a, .b]"), content="Array([Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\"))])")
  inspect(parse_filter("{\"a\": .b, c: .d}"), content="Object([(\"a\", Pipe(Identity, Field(\"b\"))), (\"c\", Pipe(Identity, Field(\"d\")))])")
}

///|
test "parse parentheses" {
  inspect(
    parse_filter("(.a, .b)"),
    content="Comma(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")))",
  )
}
