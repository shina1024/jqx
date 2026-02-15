///|
// Source under test: core/parser.mbt, core/parser_cursor.mbt, core/parser_atom.mbt, core/parser_expr.mbt, core/parser_lowering.mbt

///|
test "parse identity" {
  inspect(parse_filter("."), content="Identity")
}

///|
test "parse recurse" {
  inspect(parse_filter(".."), content="Recurse")
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
test "parse chained index without extra dot" {
  inspect(
    parse_filter(".a[0]"),
    content="Pipe(Pipe(Identity, Field(\"a\")), Index(0))",
  )
  inspect(
    parse_filter(".a[0]?"),
    content="Pipe(Pipe(Identity, Field(\"a\")), IndexOpt(0))",
  )
  inspect(
    parse_filter(".a[1:3]"),
    content="Pipe(Pipe(Identity, Field(\"a\")), Slice(Some(1), Some(3)))",
  )
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
  inspect(
    parse_filter("foreach .[] as $x (0; . + $x)"),
    content="Foreach(Pipe(Identity, Iter), \"x\", Literal(Number(0)), Add(Identity, Var(\"x\")), Identity)",
  )
  guard (try? parse_filter("reduce .[] as [$i,$j] (0; . + $i * $j)")) is Ok(_) else {
    fail("expected reduce as-pattern parse")
  }
  guard (try? parse_filter(
      "foreach .[] as {x:$x,y:$y} (0; . + $x + $y; [$x,$y,.])",
    ))
    is Ok(_) else {
    fail("expected foreach as-pattern parse")
  }
}

///|
test "parse string key index" {
  inspect(parse_filter(".[\"foo\"]"), content="Pipe(Identity, Field(\"foo\"))")
  inspect(
    parse_filter(".\"foo\".\"bar\""),
    content="Pipe(Pipe(Identity, Field(\"foo\")), Field(\"bar\"))",
  )
}

///|
test "parse dynamic bracket index" {
  guard (try? parse_filter(".foo[.baz]")) is Ok(_) else {
    fail("expected dynamic index parse")
  }
  guard (try? parse_filter("[1,2,3][$x]")) is Ok(_) else {
    fail("expected variable index parse")
  }
  guard (try? parse_filter("[range(5)] | .[1.1]")) is Ok(_) else {
    fail("expected float index parse")
  }
  guard (try? parse_filter("$ENV.PAGER")) is Ok(_) else {
    fail("expected variable field postfix parse")
  }
  guard (try? parse_filter("env.PAGER")) is Ok(_) else {
    fail("expected builtin field postfix parse")
  }
}

///|
test "parse dynamic slice bounds" {
  guard (try? parse_filter(".[:rindex(\"x\")]")) is Ok(_) else {
    fail("expected dynamic end slice parse")
  }
  guard (try? parse_filter("map([1,2][0:.])")) is Ok(_) else {
    fail("expected identity end slice parse")
  }
  guard (try? parse_filter("[range(3)] | .[nan:1]")) is Ok(_) else {
    fail("expected nan start slice parse")
  }
  guard (try? parse_filter("[range(3)] | .[1:nan]")) is Ok(_) else {
    fail("expected nan end slice parse")
  }
}

///|
test "parse pipe and comma" {
  inspect(
    parse_filter(".foo | .bar, .baz"),
    content="Pipe(Pipe(Identity, Field(\"foo\")), Comma(Pipe(Identity, Field(\"bar\")), Pipe(Identity, Field(\"baz\"))))",
  )
  inspect(
    parse_filter("{x:(1,2)},{x:3} | .x"),
    content="Pipe(Comma(Object([(\"x\", Comma(Literal(Number(1)), Literal(Number(2))))]), Object([(\"x\", Literal(Number(3)))])), Pipe(Identity, Field(\"x\")))",
  )
}

///|
test "parse literals" {
  inspect(parse_filter("null"), content="Literal(Null)")
  inspect(parse_filter("true"), content="Literal(True)")
  inspect(parse_filter("false"), content="Literal(False)")
  inspect(parse_filter("\"hi\""), content="Literal(String(\"hi\"))")
  inspect(parse_filter("123"), content="Literal(Number(123))")
  inspect(parse_filter("@uri"), content="Builtin(\"@uri\")")
  guard (try? parse_filter("(@uri|@urid)")) is Ok(_) else {
    fail("expected format filter parse")
  }
  guard (try? parse_filter(".00005")) is Ok(_) else {
    fail("expected leading-dot number literal parse")
  }
  guard (try? parse_filter("select(.>.00005)")) is Ok(_) else {
    fail("expected leading-dot number literal parse in comparison")
  }
}

///|
test "parse builtin" {
  inspect(parse_filter("length"), content="Builtin(\"length\")")
  inspect(parse_filter("type"), content="Builtin(\"type\")")
  inspect(parse_filter("keys"), content="Builtin(\"keys\")")
}

///|
test "parse def no-arg minimal" {
  inspect(
    parse_filter("def inc: . + 1; . | inc"),
    content="Pipe(Identity, Add(Identity, Literal(Number(1))))",
  )
  guard (try? parse_filter("def inc: . + 1; def twice: inc | inc; . | twice"))
    is Ok(_) else {
    fail("expected chained no-arg def parse")
  }
  guard (try? parse_filter("def f(x): x; [f(1), f(2)]")) is Ok(_) else {
    fail("expected parse success for def parameters")
  }
  guard (try? parse_filter(
      "def f: . + 1; def g: def g: . + 100; f | g | f; (f | g), g",
    ))
    is Ok(_) else {
    fail("expected parse success for nested local defs in def body")
  }
  guard (try? parse_filter(
      "[[20,10][1,0] as $x | def f: (100,200) as $y | def g: [$x + $y, .]; . + $x | g; f[0] | [f][0][1] | f]",
    ))
    is Ok(_) else {
    fail("expected parse success for local defs in array element")
  }
}

///|
test "parse call" {
  inspect(
    parse_filter("select(.a)"),
    content="Call(\"select\", [Pipe(Identity, Field(\"a\"))])",
  )
  inspect(
    parse_filter("setpath([\"a\"]; 1)"),
    content="Call(\"setpath\", [Array([Literal(String(\"a\"))]), Literal(Number(1))])",
  )
  inspect(
    parse_filter("setpath(([\"a\"], [\"b\"]); 1)"),
    content="Call(\"setpath\", [Comma(Array([Literal(String(\"a\"))]), Array([Literal(String(\"b\"))])), Literal(Number(1))])",
  )
}

///|
test "parse variables and as" {
  inspect(parse_filter("$x"), content="Var(\"x\")")
  inspect(
    parse_filter(".a as $x | $x"),
    content="As(Pipe(Identity, Field(\"a\")), \"x\", Var(\"x\"))",
  )
  inspect(
    parse_filter(". as $x | $x[]"),
    content="As(Identity, \"x\", Pipe(Var(\"x\"), Iter))",
  )
}

///|
test "parse as pattern bindings" {
  guard (try? parse_filter(".[] as [$a, {j:$j}] | [$a, $j]")) is Ok(_) else {
    fail("expected array/object as-pattern parse")
  }
  guard (try? parse_filter(". as {$a, $b:[$c,$d]} | [$a, $b, $c, $d]")) is Ok(_) else {
    fail("expected object as-pattern parse")
  }
  guard (try? parse_filter(".[] | . as {a:$a} ?// [$a] | $a")) is Ok(_) else {
    fail("expected ?// parse")
  }
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
  inspect(parse_filter("not"), content="Not(Identity)")
  inspect(
    parse_filter(".a | not"),
    content="Pipe(Pipe(Identity, Field(\"a\")), Not(Identity))",
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
    parse_filter("1+2"),
    content="Add(Literal(Number(1)), Literal(Number(2)))",
  )
  inspect(
    parse_filter("1-2"),
    content="Sub(Literal(Number(1)), Literal(Number(2)))",
  )
  inspect(
    parse_filter("(.a - .b) / 2"),
    content="Div(Sub(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\"))), Literal(Number(2)))",
  )
  inspect(
    parse_filter("10 % 3"),
    content="Mod(Literal(Number(10)), Literal(Number(3)))",
  )
  inspect(parse_filter("-."), content="Sub(Literal(Number(0)), Identity)")
  inspect(
    parse_filter("-(.a + 1)"),
    content="Sub(Literal(Number(0)), Add(Pipe(Identity, Field(\"a\")), Literal(Number(1))))",
  )
}

///|
test "parse if-then-else" {
  inspect(
    parse_filter("if .a then .b else .c end"),
    content="IfElse(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")), Pipe(Identity, Field(\"c\")))",
  )
  inspect(
    parse_filter("if .a then .b elif .c then .d else .e end"),
    content="IfElse(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")), IfElse(Pipe(Identity, Field(\"c\")), Pipe(Identity, Field(\"d\")), Pipe(Identity, Field(\"e\"))))",
  )
  inspect(
    parse_filter("if .a then .b end"),
    content="IfElse(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")), Identity)",
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
test "parse update assignment operators" {
  inspect(
    parse_filter(".a |= . + 1"),
    content="IfElse(Call(\"isempty\", [Pipe(Call(\"getpath\", [Literal(Array([String(\"a\")]))]), Add(Identity, Literal(Number(1))))]), Call(\"delpaths\", [Literal(Array([Array([String(\"a\")])]))]), Call(\"setpath\", [Literal(Array([String(\"a\")])), Call(\"first\", [Pipe(Call(\"getpath\", [Literal(Array([String(\"a\")]))]), Add(Identity, Literal(Number(1))))])]))",
  )
  inspect(
    parse_filter(".a += 2"),
    content="Call(\"setpath\", [Literal(Array([String(\"a\")])), Add(Call(\"getpath\", [Literal(Array([String(\"a\")]))]), Literal(Number(2)))])",
  )
  inspect(
    parse_filter(".a //= 0"),
    content="Call(\"setpath\", [Literal(Array([String(\"a\")])), Fallback(Call(\"getpath\", [Literal(Array([String(\"a\")]))]), Literal(Number(0)))])",
  )
  inspect(
    parse_filter(".[0] *= 3"),
    content="Call(\"setpath\", [Literal(Array([Number(0)])), Mul(Call(\"getpath\", [Literal(Array([Number(0)]))]), Literal(Number(3)))])",
  )
  inspect(
    parse_filter(".a = 1"),
    content="Call(\"setpath\", [Literal(Array([String(\"a\")])), Literal(Number(1))])",
  )
  inspect(
    parse_filter(".a %= 2"),
    content="Call(\"setpath\", [Literal(Array([String(\"a\")])), Mod(Call(\"getpath\", [Literal(Array([String(\"a\")]))]), Literal(Number(2)))])",
  )
}

///|
test "parse update assignment dynamic lhs" {
  guard (try? parse_filter(".[] |= . + 1")) is Ok(_) else {
    fail("expected parse success for dynamic update assignment lhs")
  }
  guard (try? parse_filter("(.a, .b) = range(3)")) is Ok(_) else {
    fail("expected parse success for grouped update assignment lhs")
  }
}

///|
test "parse update assignment precedence" {
  inspect(
    parse_filter("1 < 2 | . + 1"),
    content="Pipe(Lt(Literal(Number(1)), Literal(Number(2))), Add(Identity, Literal(Number(1))))",
  )
  guard (try? parse_filter(".a = .b | .a")) is Ok(_) else {
    fail("expected parse success for pipe after update assignment")
  }
  guard (try? parse_filter(".a = .b // 1 | .a")) is Ok(_) else {
    fail("expected parse success for fallback after update assignment")
  }
  guard (try? parse_filter(
      "reduce .[] as {$x,$y} (null; .x += $x | .y += [$y])",
    ))
    is Ok(_) else {
    fail("expected parse success for reduce update pipeline")
  }
}

///|
test "parse array and object literals" {
  inspect(
    parse_filter("[.a, .b]"),
    content="Array([Comma(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")))])",
  )
  inspect(
    parse_filter("[10 > 0, 1 == 2]"),
    content="Array([Comma(Gt(Literal(Number(10)), Literal(Number(0))), Eq(Literal(Number(1)), Literal(Number(2))))])",
  )
  inspect(
    parse_filter("{\"a\": .b, c: .d}"),
    content="Object([(\"a\", Pipe(Identity, Field(\"b\"))), (\"c\", Pipe(Identity, Field(\"d\")))])",
  )
  inspect(
    parse_filter("{\"ok\": (10 > 0)}"),
    content="Object([(\"ok\", Gt(Literal(Number(10)), Literal(Number(0))))])",
  )
  inspect(
    parse_filter("{a, \"b\", c: .d}"),
    content="Object([(\"a\", Pipe(Identity, Field(\"a\"))), (\"b\", Pipe(Identity, Field(\"b\"))), (\"c\", Pipe(Identity, Field(\"d\")))])",
  )
  inspect(parse_filter("{ $x }"), content="Object([(\"x\", Var(\"x\"))])")
  inspect(
    parse_filter(".[1,2]"),
    content="Pipe(Identity, Comma(Index(1), Index(2)))",
  )
  inspect(
    parse_filter(".[\"a\", \"b\"]"),
    content="Pipe(Identity, Comma(Field(\"a\"), Field(\"b\")))",
  )
  inspect(
    parse_filter("[1,2][]"),
    content="Pipe(Array([Comma(Literal(Number(1)), Literal(Number(2)))]), Iter)",
  )
  guard (try? parse_filter("{a,b,(.d):.a,e:.b}")) is Ok(_) else {
    fail("expected dynamic object key parse")
  }
  guard (try? parse_filter("{\"a\",b,\"a$\\(1+1)\"}")) is Ok(_) else {
    fail("expected interpolated object key parse")
  }
  guard (try? parse_filter(
      "{x: try 1, y: try error catch 2, z: if true then 3 end}",
    ))
    is Ok(_) else {
    fail("expected object literal parse with try/catch values")
  }
  guard (try? parse_filter("{a,$__loc__,c}")) is Ok(_) else {
    fail("expected variable shorthand object key parse")
  }
  guard (try? parse_filter(
      "1 as $x | \"2\" as $y | \"3\" as $z | { $x, as, $y: 4, ($z): 5, if: 6, foo: 7 }",
    ))
    is Ok(_) else {
    fail("expected variable object key parse")
  }
}

///|
test "parse interpolated string literal" {
  guard (try? parse_filter("\"invalid value: \\(.)\"")) is Ok(_) else {
    fail("expected string interpolation parse")
  }
  guard (try? parse_filter("try error(\"\\($__loc__)\") catch .")) is Ok(_) else {
    fail("expected __loc__ interpolation parse")
  }
}

///|
test "parse parentheses" {
  inspect(
    parse_filter("(.a, .b)"),
    content="Comma(Pipe(Identity, Field(\"a\")), Pipe(Identity, Field(\"b\")))",
  )
}
