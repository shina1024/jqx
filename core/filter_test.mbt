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
