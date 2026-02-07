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
test "parse slice" {
  inspect(
    parse_filter(".[1:3]"),
    content="Pipe(Identity, Slice(Some(1), Some(3)))",
  )
  inspect(parse_filter(".[:2]"), content="Pipe(Identity, Slice(None, Some(2)))")
  inspect(parse_filter(".[1:]"), content="Pipe(Identity, Slice(Some(1), None))")
  inspect(
    parse_filter(".[1:3]?"),
    content="Pipe(Identity, SliceOpt(Some(1), Some(3)))",
  )
}

///|
test "parse invalid empty slice" {
  guard (try? parse_filter(".[:]")) is Err(_) else {
    fail("expected parse error for empty slice")
  }
}

///|
test "parse iter" {
  inspect(parse_filter(".[]"), content="Pipe(Identity, Iter)")
}

///|
test "parse optional access" {
  inspect(parse_filter(".foo?"), content="Pipe(Identity, FieldOpt(\"foo\"))")
  inspect(parse_filter(".[0]?"), content="Pipe(Identity, IndexOpt(0))")
  inspect(parse_filter(".[]?"), content="Pipe(Identity, IterOpt)")
}

///|
test "parse try" {
  inspect(
    parse_filter("(.a + 1)?"),
    content="Try(Add(Pipe(Identity, Field(\"a\")), Literal(Number(1))))",
  )
}

///|
test "parse try/catch" {
  inspect(
    parse_filter("try .a catch .b"),
    content="TryCatch(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")))",
  )
  inspect(
    parse_filter("try .a"),
    content="TryCatch(Pipe(Identity, Field(\"a\")), Empty)",
  )
}

///|
test "parse reduce/foreach" {
  inspect(
    parse_filter("reduce .[] as $x (0; . + $x)"),
    content="Reduce(Pipe(Identity, Iter), \"x\", Literal(Number(0)), Add(Identity, Var(\"x\")))",
  )
  inspect(
    parse_filter("foreach .[] as $x (0; . + $x; .)"),
    content="Foreach(Pipe(Identity, Iter), \"x\", Literal(Number(0)), Add(Identity, Var(\"x\")), Identity)",
  )
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
test "parse variables and as" {
  inspect(parse_filter("$x"), content="Var(\"x\")")
  inspect(
    parse_filter(".a as $x | $x"),
    content="As(Pipe(Identity, Field(\"a\")), \"x\", Var(\"x\"))",
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
  inspect(parse_filter("not .a"), content="Not(Pipe(Identity, Field(\"a\")))")
}

///|
test "parse arithmetic" {
  inspect(
    parse_filter(".a + .b * .c"),
    content="Add(Pipe(Identity, Field(\"a\")), Mul(Pipe(Identity, Field(\"b\")), Pipe(Identity, Field(\"c\"))))",
  )
  inspect(
    parse_filter("(.a - .b) / 2"),
    content="Div(Sub(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\"))), Literal(Number(2)))",
  )
}

///|
test "parse if-then-else" {
  inspect(
    parse_filter("if .a then .b else .c end"),
    content="IfElse(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")), Pipe(Identity, Field(\"c\")))",
  )
}

///|
test "parse fallback and empty" {
  inspect(
    parse_filter(".a // .b"),
    content="Fallback(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")))",
  )
  inspect(parse_filter("empty"), content="Empty")
}

///|
test "parse array and object literals" {
  inspect(
    parse_filter("[.a, .b]"),
    content="Array([Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\"))])",
  )
  inspect(
    parse_filter("{\"a\": .b, c: .d}"),
    content="Object([(\"a\", Pipe(Identity, Field(\"b\"))), (\"c\", Pipe(Identity, Field(\"d\")))])",
  )
}

///|
test "parse parentheses" {
  inspect(
    parse_filter("(.a, .b)"),
    content="Comma(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")))",
  )
}
