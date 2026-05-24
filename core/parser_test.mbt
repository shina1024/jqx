///|
// Source under test: core/parser.mbt, core/parser_cursor.mbt, core/parser_atom.mbt, core/parser_expr.mbt, core/parser_lowering.mbt

///|
test "parse identity" {
  inspect(compile("."), content="Identity")
}

///|
test "parse recurse" {
  inspect(compile(".."), content="Recurse")
}

///|
test "parse field" {
  inspect(
    compile(".foo"),
    content=(
      #|Pipe(Identity, Field("foo"))
    ),
  )
}

///|
test "parse chained fields" {
  inspect(
    compile(".foo.bar"),
    content=(
      #|Pipe(Pipe(Identity, Field("foo")), Field("bar"))
    ),
  )
}

///|
test "parse index" {
  inspect(compile(".[0]"), content="Pipe(Identity, Index(0))")
}

///|
test "parse chained index without extra dot" {
  inspect(
    compile(".a[0]"),
    content=(
      #|Pipe(Pipe(Identity, Field("a")), Index(0))
    ),
  )
  inspect(
    compile(".a[0]?"),
    content=(
      #|Pipe(Pipe(Identity, Field("a")), IndexOpt(0))
    ),
  )
  inspect(
    compile(".a[1:3]"),
    content=(
      #|Pipe(Pipe(Identity, Field("a")), Slice(Some(1), Some(3)))
    ),
  )
}

///|
test "parse slice" {
  inspect(compile(".[1:3]"), content="Pipe(Identity, Slice(Some(1), Some(3)))")
  inspect(compile(".[:2]"), content="Pipe(Identity, Slice(None, Some(2)))")
  inspect(compile(".[1:]"), content="Pipe(Identity, Slice(Some(1), None))")
  inspect(
    compile(".[1:3]?"),
    content="Pipe(Identity, SliceOpt(Some(1), Some(3)))",
  )
}

///|
test "parse invalid empty slice" {
  guard (try? compile(".[:]")) is Err(_) else {
    fail("expected parse error for empty slice")
  }
}

///|
test "parse iter" {
  inspect(compile(".[]"), content="Pipe(Identity, Iter)")
}

///|
test "parse optional access" {
  inspect(
    compile(".foo?"),
    content=(
      #|Pipe(Identity, FieldOpt("foo"))
    ),
  )
  inspect(compile(".[0]?"), content="Pipe(Identity, IndexOpt(0))")
  inspect(compile(".[]?"), content="Pipe(Identity, IterOpt)")
}

///|
test "parse try" {
  inspect(
    compile("(.a + 1)?"),
    content=(
      #|Try(Add(Pipe(Identity, Field("a")), Literal(Number(1, None))))
    ),
  )
}

///|
test "parse try/catch" {
  inspect(
    compile("try .a catch .b"),
    content=(
      #|TryCatch(Pipe(Identity, Field("a")), Pipe(Identity, Field("b")))
    ),
  )
  inspect(
    compile("try .a"),
    content=(
      #|TryCatch(Pipe(Identity, Field("a")), Empty)
    ),
  )
  inspect(
    compile("1 + try 2 catch 3 + 4"),
    content=(
      #|Add(
      #|  Add(
      #|    Literal(Number(1, None)),
      #|    TryCatch(Literal(Number(2, None)), Literal(Number(3, None))),
      #|  ),
      #|  Literal(Number(4, None)),
      #|)
    ),
  )
  inspect(
    compile("try (1/0) catch 9 + 2"),
    content=(
      #|Add(
      #|  TryCatch(
      #|    Div(Literal(Number(1, None)), Literal(Number(0, None))),
      #|    Literal(Number(9, None)),
      #|  ),
      #|  Literal(Number(2, None)),
      #|)
    ),
  )
  guard (try? compile("try 1/0 catch 9")) is Err(_) else {
    fail("expected parse error for unparenthesized try/catch arithmetic")
  }
}

///|
test "parse reduce/foreach" {
  inspect(
    compile("reduce .[] as $x (0; . + $x)"),
    content=(
      #|Reduce(
      #|  Pipe(Identity, Iter),
      #|  "x",
      #|  Literal(Number(0, None)),
      #|  Add(Identity, Var("x")),
      #|)
    ),
  )
  inspect(
    compile("foreach .[] as $x (0; . + $x; .)"),
    content=(
      #|Foreach(
      #|  Pipe(Identity, Iter),
      #|  "x",
      #|  Literal(Number(0, None)),
      #|  Add(Identity, Var("x")),
      #|  Identity,
      #|)
    ),
  )
  inspect(
    compile("foreach .[] as $x (0; . + $x)"),
    content=(
      #|Foreach(
      #|  Pipe(Identity, Iter),
      #|  "x",
      #|  Literal(Number(0, None)),
      #|  Add(Identity, Var("x")),
      #|  Identity,
      #|)
    ),
  )
  guard (try? compile("reduce .[] as [$i,$j] (0; . + $i * $j)")) is Ok(_) else {
    fail("expected reduce as-pattern parse")
  }
  guard (try? compile("foreach .[] as {x:$x,y:$y} (0; . + $x + $y; [$x,$y,.])"))
    is Ok(_) else {
    fail("expected foreach as-pattern parse")
  }
}

///|
test "parse string key index" {
  inspect(
    compile(".[\"foo\"]"),
    content=(
      #|Pipe(Identity, Field("foo"))
    ),
  )
  inspect(
    compile(".\"foo\".\"bar\""),
    content=(
      #|Pipe(Pipe(Identity, Field("foo")), Field("bar"))
    ),
  )
}

///|
test "parse dynamic bracket index" {
  guard (try? compile(".foo[.baz]")) is Ok(_) else {
    fail("expected dynamic index parse")
  }
  guard (try? compile("1 as $x | [1,2,3][$x]")) is Ok(_) else {
    fail("expected variable index parse")
  }
  guard (try? compile("[range(5)] | .[1.1]")) is Ok(_) else {
    fail("expected float index parse")
  }
  guard (try? compile("$ENV.PAGER")) is Ok(_) else {
    fail("expected variable field postfix parse")
  }
  guard (try? compile("env.PAGER")) is Ok(_) else {
    fail("expected builtin field postfix parse")
  }
}

///|
test "parse dynamic slice bounds" {
  guard (try? compile(".[:rindex(\"x\")]")) is Ok(_) else {
    fail("expected dynamic end slice parse")
  }
  guard (try? compile("map([1,2][0:.])")) is Ok(_) else {
    fail("expected identity end slice parse")
  }
  guard (try? compile("[range(3)] | .[nan:1]")) is Ok(_) else {
    fail("expected nan start slice parse")
  }
  guard (try? compile("[range(3)] | .[1:nan]")) is Ok(_) else {
    fail("expected nan end slice parse")
  }
}

///|
test "parse pipe and comma" {
  inspect(
    compile(".foo | .bar, .baz"),
    content=(
      #|Pipe(
      #|  Pipe(Identity, Field("foo")),
      #|  Comma(Pipe(Identity, Field("bar")), Pipe(Identity, Field("baz"))),
      #|)
    ),
  )
  inspect(
    compile("{x:(1,2)},{x:3} | .x"),
    content=(
      #|Pipe(
      #|  Comma(
      #|    Object([("x", Comma(Literal(Number(1, None)), Literal(Number(2, None))))]),
      #|    Object([("x", Literal(Number(3, None)))]),
      #|  ),
      #|  Pipe(Identity, Field("x")),
      #|)
    ),
  )
}

///|
test "parse literals" {
  inspect(
    compile("null"),
    content=(
      #|Literal(JNull)
    ),
  )
  inspect(
    compile("true"),
    content=(
      #|Literal(JTrue)
    ),
  )
  inspect(
    compile("false"),
    content=(
      #|Literal(JFalse)
    ),
  )
  inspect(
    compile("\"hi\""),
    content=(
      #|Literal(String("hi"))
    ),
  )
  inspect(
    compile("123"),
    content=(
      #|Literal(Number(123, None))
    ),
  )
  inspect(
    compile("@uri"),
    content=(
      #|Builtin("@uri")
    ),
  )
  guard (try? compile("(@uri|@urid)")) is Ok(_) else {
    fail("expected format filter parse")
  }
  guard (try? compile("@html \"<b>\\(.)</b>\"")) is Ok(_) else {
    fail("expected @html format string parse")
  }
  guard (try? compile("@sh \"echo \\(.)\"")) is Ok(_) else {
    fail("expected @sh format string parse")
  }
  guard (try? compile(".00005")) is Ok(_) else {
    fail("expected leading-dot number literal parse")
  }
  guard (try? compile("select(.>.00005)")) is Ok(_) else {
    fail("expected leading-dot number literal parse in comparison")
  }
}

///|
test "parse builtin" {
  inspect(
    compile("length"),
    content=(
      #|Builtin("length")
    ),
  )
  inspect(
    compile("type"),
    content=(
      #|Builtin("type")
    ),
  )
  inspect(
    compile("keys"),
    content=(
      #|Builtin("keys")
    ),
  )
}

///|
test "parse def no-arg minimal" {
  guard (try? compile("def inc: . + 1; . | inc")) is Ok(_) else {
    fail("expected simple no-arg def parse")
  }
  guard (try? compile("def inc: . + 1; def twice: inc | inc; . | twice"))
    is Ok(_) else {
    fail("expected chained no-arg def parse")
  }
  guard (try? compile("def f(x): x; [f(1), f(2)]")) is Ok(_) else {
    fail("expected parse success for def parameters")
  }
  guard (try? compile(
      "def f: . + 1; def g: def g: . + 100; f | g | f; (f | g), g",
    ))
    is Ok(_) else {
    fail("expected parse success for nested local defs in def body")
  }
  guard (try? compile(
      "[[20,10][1,0] as $x | def f: (100,200) as $y | def g: [$x + $y, .]; . + $x | g; f[0] | [f][0][1] | f]",
    ))
    is Ok(_) else {
    fail("expected parse success for local defs in array element")
  }
}

///|
test "parse call" {
  inspect(
    compile("select(.a)"),
    content=(
      #|Call("select", [Pipe(Identity, Field("a"))])
    ),
  )
  inspect(
    compile("setpath([\"a\"]; 1)"),
    content=(
      #|Call(
      #|  "setpath",
      #|  [Array([Literal(String("a"))]), Literal(Number(1, None))],
      #|)
    ),
  )
  inspect(
    compile("setpath(([\"a\"], [\"b\"]); 1)"),
    content=(
      #|Call(
      #|  "setpath",
      #|  [
      #|    Comma(Array([Literal(String("a"))]), Array([Literal(String("b"))])),
      #|    Literal(Number(1, None)),
      #|  ],
      #|)
    ),
  )
}

///|
test "parse qualified callable names" {
  inspect(
    compile("foo::bar"),
    content=(
      #|Builtin("foo::bar")
    ),
  )
  inspect(
    compile("foo::bar(1)"),
    content=(
      #|Call("foo::bar", [Literal(Number(1, None))])
    ),
  )
  inspect(
    compile("a::b::c"),
    content=(
      #|Builtin("a::b::c")
    ),
  )
}

///|
test "parse variables and as" {
  inspect(
    compile(".a as $x | $x"),
    content=(
      #|As(Pipe(Identity, Field("a")), "x", Var("x"))
    ),
  )
  inspect(
    compile(". as $x | $x[]"),
    content=(
      #|As(Identity, "x", Pipe(Var("x"), Iter))
    ),
  )
}

///|
test "parse as pattern bindings" {
  guard (try? compile(".[] as [$a, {j:$j}] | [$a, $j]")) is Ok(_) else {
    fail("expected array/object as-pattern parse")
  }
  guard (try? compile(". as {$a, $b:[$c,$d]} | [$a, $b, $c, $d]")) is Ok(_) else {
    fail("expected object as-pattern parse")
  }
  guard (try? compile(".[] | . as {a:$a} ?// [$a] | $a")) is Ok(_) else {
    fail("expected ?// parse")
  }
  guard (try? compile(". as [] | null")) is Err(_) else {
    fail("expected parse error for empty array as-pattern")
  }
  guard (try? compile(". as {} | null")) is Err(_) else {
    fail("expected parse error for empty object as-pattern")
  }
}

///|
test "parse compare" {
  inspect(
    compile(".a == .b"),
    content=(
      #|Eq(Pipe(Identity, Field("a")), Pipe(Identity, Field("b")))
    ),
  )
  inspect(
    compile(".a != .b"),
    content=(
      #|Neq(Pipe(Identity, Field("a")), Pipe(Identity, Field("b")))
    ),
  )
  inspect(
    compile(".a < .b"),
    content=(
      #|Lt(Pipe(Identity, Field("a")), Pipe(Identity, Field("b")))
    ),
  )
  inspect(
    compile(".a <= .b"),
    content=(
      #|Lte(Pipe(Identity, Field("a")), Pipe(Identity, Field("b")))
    ),
  )
  inspect(
    compile(".a > .b"),
    content=(
      #|Gt(Pipe(Identity, Field("a")), Pipe(Identity, Field("b")))
    ),
  )
  inspect(
    compile(".a >= .b"),
    content=(
      #|Gte(Pipe(Identity, Field("a")), Pipe(Identity, Field("b")))
    ),
  )
}

///|
test "parse logical" {
  inspect(
    compile(".a and .b"),
    content=(
      #|And(Pipe(Identity, Field("a")), Pipe(Identity, Field("b")))
    ),
  )
  inspect(
    compile(".a or .b"),
    content=(
      #|Or(Pipe(Identity, Field("a")), Pipe(Identity, Field("b")))
    ),
  )
  inspect(compile("not"), content="Not(Identity)")
  inspect(
    compile(".a | not"),
    content=(
      #|Pipe(Pipe(Identity, Field("a")), Not(Identity))
    ),
  )
  inspect(
    compile("not .a"),
    content=(
      #|Not(Pipe(Identity, Field("a")))
    ),
  )
}

///|
test "parse arithmetic" {
  inspect(
    compile(".a + .b * .c"),
    content=(
      #|Add(
      #|  Pipe(Identity, Field("a")),
      #|  Mul(Pipe(Identity, Field("b")), Pipe(Identity, Field("c"))),
      #|)
    ),
  )
  inspect(
    compile("1+2"),
    content=(
      #|Add(Literal(Number(1, None)), Literal(Number(2, None)))
    ),
  )
  inspect(
    compile("1-2"),
    content=(
      #|Sub(Literal(Number(1, None)), Literal(Number(2, None)))
    ),
  )
  inspect(
    compile("(.a - .b) / 2"),
    content=(
      #|Div(
      #|  Sub(Pipe(Identity, Field("a")), Pipe(Identity, Field("b"))),
      #|  Literal(Number(2, None)),
      #|)
    ),
  )
  inspect(
    compile("10 % 3"),
    content=(
      #|Mod(Literal(Number(10, None)), Literal(Number(3, None)))
    ),
  )
  inspect(
    compile("-."),
    content=(
      #|Call("__neg", [Identity])
    ),
  )
  inspect(
    compile("-(.a + 1)"),
    content=(
      #|Call(
      #|  "__neg",
      #|  [Add(Pipe(Identity, Field("a")), Literal(Number(1, None)))],
      #|)
    ),
  )
}

///|
test "parse if-then-else" {
  inspect(
    compile("if .a then .b else .c end"),
    content=(
      #|IfElse(
      #|  Pipe(Identity, Field("a")),
      #|  Pipe(Identity, Field("b")),
      #|  Pipe(Identity, Field("c")),
      #|)
    ),
  )
  inspect(
    compile("if .a then .b elif .c then .d else .e end"),
    content=(
      #|IfElse(
      #|  Pipe(Identity, Field("a")),
      #|  Pipe(Identity, Field("b")),
      #|  IfElse(
      #|    Pipe(Identity, Field("c")),
      #|    Pipe(Identity, Field("d")),
      #|    Pipe(Identity, Field("e")),
      #|  ),
      #|)
    ),
  )
  inspect(
    compile("if .a then .b end"),
    content=(
      #|IfElse(
      #|  Pipe(Identity, Field("a")),
      #|  Pipe(Identity, Field("b")),
      #|  Identity,
      #|)
    ),
  )
}

///|
test "parse fallback and empty" {
  inspect(
    compile(".a // .b"),
    content=(
      #|Fallback(Pipe(Identity, Field("a")), Pipe(Identity, Field("b")))
    ),
  )
  inspect(compile("empty"), content="Empty")
}

///|
test "parse update assignment operators" {
  inspect(
    compile(".a |= . + 1"),
    content=(
      #|IfElse(
      #|  Call(
      #|    "isempty",
      #|    [
      #|      Pipe(
      #|        Call("getpath", [Literal(Array([String("a")]))]),
      #|        Add(Identity, Literal(Number(1, None))),
      #|      ),
      #|    ],
      #|  ),
      #|  Call("delpaths", [Literal(Array([Array([String("a")])]))]),
      #|  Call(
      #|    "setpath",
      #|    [
      #|      Literal(Array([String("a")])),
      #|      Call(
      #|        "first",
      #|        [
      #|          Pipe(
      #|            Call("getpath", [Literal(Array([String("a")]))]),
      #|            Add(Identity, Literal(Number(1, None))),
      #|          ),
      #|        ],
      #|      ),
      #|    ],
      #|  ),
      #|)
    ),
  )
  inspect(
    compile(".a += 2"),
    content=(
      #|Call(
      #|  "setpath",
      #|  [
      #|    Literal(Array([String("a")])),
      #|    Add(
      #|      Call("getpath", [Literal(Array([String("a")]))]),
      #|      Literal(Number(2, None)),
      #|    ),
      #|  ],
      #|)
    ),
  )
  inspect(
    compile(".a //= 0"),
    content=(
      #|Call(
      #|  "setpath",
      #|  [
      #|    Literal(Array([String("a")])),
      #|    Fallback(
      #|      Call("getpath", [Literal(Array([String("a")]))]),
      #|      Literal(Number(0, None)),
      #|    ),
      #|  ],
      #|)
    ),
  )
  inspect(
    compile(".[0] *= 3"),
    content=(
      #|Call(
      #|  "setpath",
      #|  [
      #|    Literal(Array([Number(0, None)])),
      #|    Mul(
      #|      Call("getpath", [Literal(Array([Number(0, None)]))]),
      #|      Literal(Number(3, None)),
      #|    ),
      #|  ],
      #|)
    ),
  )
  inspect(
    compile(".a = 1"),
    content=(
      #|Call(
      #|  "setpath",
      #|  [Literal(Array([String("a")])), Literal(Number(1, None))],
      #|)
    ),
  )
  inspect(
    compile(".a %= 2"),
    content=(
      #|Call(
      #|  "setpath",
      #|  [
      #|    Literal(Array([String("a")])),
      #|    Mod(
      #|      Call("getpath", [Literal(Array([String("a")]))]),
      #|      Literal(Number(2, None)),
      #|    ),
      #|  ],
      #|)
    ),
  )
}

///|
test "parse update assignment dynamic lhs" {
  guard (try? compile(".[] |= . + 1")) is Ok(_) else {
    fail("expected parse success for dynamic update assignment lhs")
  }
  guard (try? compile("(.a, .b) = range(3)")) is Ok(_) else {
    fail("expected parse success for grouped update assignment lhs")
  }
  guard (try? compile("1 as $s | 3 as $e | .[$s:$e] = [9]")) is Ok(_) else {
    fail("expected parse success for dynamic slice bounds in update lhs")
  }
  guard (try? compile("(.[] | .[1:3]) |= map(.+100)")) is Ok(_) else {
    fail("expected parse success for dynamic base slice update lhs")
  }
}

///|
test "parse update assignment precedence" {
  inspect(
    compile("1 < 2 | . + 1"),
    content=(
      #|Pipe(
      #|  Lt(Literal(Number(1, None)), Literal(Number(2, None))),
      #|  Add(Identity, Literal(Number(1, None))),
      #|)
    ),
  )
  guard (try? compile(".a = .b | .a")) is Ok(_) else {
    fail("expected parse success for pipe after update assignment")
  }
  guard (try? compile(".a = .b // 1 | .a")) is Ok(_) else {
    fail("expected parse success for fallback after update assignment")
  }
  guard (try? compile("reduce .[] as {$x,$y} (null; .x += $x | .y += [$y])"))
    is Ok(_) else {
    fail("expected parse success for reduce update pipeline")
  }
}

///|
test "parse array and object literals" {
  inspect(
    compile("[.a, .b]"),
    content=(
      #|Array([Comma(Pipe(Identity, Field("a")), Pipe(Identity, Field("b")))])
    ),
  )
  inspect(
    compile("[10 > 0, 1 == 2]"),
    content=(
      #|Array(
      #|  [
      #|    Comma(
      #|      Gt(Literal(Number(10, None)), Literal(Number(0, None))),
      #|      Eq(Literal(Number(1, None)), Literal(Number(2, None))),
      #|    ),
      #|  ],
      #|)
    ),
  )
  inspect(
    compile("{\"a\": .b, c: .d}"),
    content=(
      #|Object([("a", Pipe(Identity, Field("b"))), ("c", Pipe(Identity, Field("d")))])
    ),
  )
  inspect(
    compile("{\"ok\": (10 > 0)}"),
    content=(
      #|Object([("ok", Gt(Literal(Number(10, None)), Literal(Number(0, None))))])
    ),
  )
  inspect(
    compile("{a, \"b\", c: .d}"),
    content=(
      #|Object(
      #|  [
      #|    ("a", Pipe(Identity, Field("a"))),
      #|    ("b", Pipe(Identity, Field("b"))),
      #|    ("c", Pipe(Identity, Field("d"))),
      #|  ],
      #|)
    ),
  )
  inspect(
    compile(". as $x | { $x }"),
    content=(
      #|As(Identity, "x", Object([("x", Var("x"))]))
    ),
  )
  inspect(
    compile(".[1,2]"),
    content="Pipe(Identity, Comma(Index(1), Index(2)))",
  )
  inspect(
    compile(".[\"a\", \"b\"]"),
    content=(
      #|Pipe(Identity, Comma(Field("a"), Field("b")))
    ),
  )
  inspect(
    compile("[1,2][]"),
    content=(
      #|Pipe(
      #|  Array([Comma(Literal(Number(1, None)), Literal(Number(2, None)))]),
      #|  Iter,
      #|)
    ),
  )
  guard (try? compile("{a,b,(.d):.a,e:.b}")) is Ok(_) else {
    fail("expected dynamic object key parse")
  }
  guard (try? compile("{\"a\",b,\"a$\\(1+1)\"}")) is Ok(_) else {
    fail("expected interpolated object key parse")
  }
  guard (try? compile("{x: try 1, y: try error catch 2, z: if true then 3 end}"))
    is Ok(_) else {
    fail("expected object literal parse with try/catch values")
  }
  guard (try? compile("{a,$__loc__,c}")) is Ok(_) else {
    fail("expected variable shorthand object key parse")
  }
  guard (try? compile(
      "1 as $x | \"2\" as $y | \"3\" as $z | { $x, as, $y: 4, ($z): 5, if: 6, foo: 7 }",
    ))
    is Ok(_) else {
    fail("expected variable object key parse")
  }
}

///|
test "parse interpolated string literal" {
  guard (try? compile("\"invalid value: \\(.)\"")) is Ok(_) else {
    fail("expected string interpolation parse")
  }
  guard (try? compile("try error(\"\\($__loc__)\") catch .")) is Ok(_) else {
    fail("expected __loc__ interpolation parse")
  }
}

///|
test "parse parentheses" {
  inspect(
    compile("(.a, .b)"),
    content=(
      #|Comma(Pipe(Identity, Field("a")), Pipe(Identity, Field("b")))
    ),
  )
}
