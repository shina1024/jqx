///|
// Source under test: core/json_parse.mbt

///|
test "parse primitives" {
  @debug.assert_eq(parse("null"), Value::null())
  @debug.assert_eq(parse("true"), Value::boolean(true))
  @debug.assert_eq(parse("false"), Value::boolean(false))
}

///|
test "parse numbers and arrays" {
  let json = parse("[1, -2, 3.5, 1e2]") catch {
    err => fail("parse failed: " + err.to_string())
  }
  @debug.assert_eq(
    json,
    Value::array([
      Value::number(1.0),
      Value::number(-2.0),
      Value::number(3.5),
      Value::number(100.0),
    ]),
  )
}

///|
test "parse non-finite number tokens" {
  guard (try parse("Infinity") catch {
    _ => false
  } noraise {
    Number(n, _) => n == @double.infinity
    _ => false
  }) else {
    fail("expected Infinity parse")
  }
  guard (try parse("-Infinity") catch {
    _ => false
  } noraise {
    Number(n, _) => n == @double.neg_infinity
    _ => false
  }) else {
    fail("expected -Infinity parse")
  }
  guard (try parse("NaN") catch {
    _ => false
  } noraise {
    Number(n, _) => n != n
    _ => false
  }) else {
    fail("expected NaN parse")
  }
  guard (try parse("-NaN") catch {
    _ => false
  } noraise {
    Number(n, _) => n != n
    _ => false
  }) else {
    fail("expected -NaN parse")
  }
  guard (try parse("inf") catch {
    _ => false
  } noraise {
    Number(n, _) => n == @double.infinity
    _ => false
  }) else {
    fail("expected inf parse")
  }
  guard (try parse("+nan") catch {
    _ => false
  } noraise {
    Number(n, _) => n != n
    _ => false
  }) else {
    fail("expected +nan parse")
  }
  let obj = parse("{\"a\":nan,\"b\":-NaN,\"c\":inf,\"d\":-infinity}") catch {
    err => fail("parse failed: " + err.to_string())
  }
  @debug.assert_eq(
    obj.to_json_string(),
    "{\"a\":null,\"b\":null,\"c\":1.7976931348623157e+308,\"d\":-1.7976931348623157e+308}",
  )
  guard (try parse("NaN10") catch {
    InvalidNumericLiteralAtEof({ line: 1, column: 5 }) => true
    _ => false
  } noraise {
    _ => false
  }) else {
    fail("expected NaN10 parse to report invalid numeric literal at EOF")
  }
}

///|
test "parse large integer keeps repr" {
  let json = parse("9007199254740993") catch {
    err => fail("parse failed: " + err.to_string())
  }
  @debug.assert_eq(
    json,
    Value::number(9007199254740992.0, repr="9007199254740993"),
  )
}

///|
test "parse object" {
  let json = parse("{\"a\":1,\"b\":[true,false]}") catch {
    err => fail("parse failed: " + err.to_string())
  }
  @debug.assert_eq(
    json,
    Value::object({
      "a": Value::number(1.0),
      "b": Value::array([Value::boolean(true), Value::boolean(false)]),
    }),
  )
}

///|
test "parse string escapes" {
  let json = parse("\"\\n\\t\\\"\"") catch {
    err => fail("parse failed: " + err.to_string())
  }
  @debug.assert_eq(json, Value::string("\n\t\""))
}

///|
test "parse whitespace" {
  let json = parse(" \n\t[1, 2]\r ") catch {
    err => fail("parse failed: " + err.to_string())
  }
  @debug.assert_eq(json, Value::array([Value::number(1.0), Value::number(2.0)]))
}

///|
test "parse errors" {
  guard (try parse("") catch {
    InvalidEof => true
    _ => false
  } noraise {
    _ => false
  }) else {
    fail("expected InvalidEof for empty input")
  }
  guard (try parse("]") catch {
    InvalidChar(_, _) => true
    _ => false
  } noraise {
    _ => false
  }) else {
    fail("expected InvalidChar for unexpected token")
  }
  guard (try parse("{\"a\":1") catch {
    InvalidEof => true
    _ => false
  } noraise {
    _ => false
  }) else {
    fail("expected InvalidEof for missing closing brace")
  }
}
