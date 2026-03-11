///|
// Source under test: jqx.mbt, jqx_json_convert.mbt, jqx_public_types.mbt

///|
test "top-level parse returns standard Json" {
  let parsed = parse("{\"a\":1,\"b\":[true,null,\"x\"]}") catch {
    err => fail("parse failed: " + err.to_string())
  }
  assert_eq(parsed.stringify(), "{\"a\":1,\"b\":[true,null,\"x\"]}")
}

///|
test "run roundtrips standard Json values without exposing core types" {
  let parsed = @json.parse("{\"z\":0,\"a\":9007199254740993}") catch {
    err => fail("std parse failed: " + err.to_string())
  }
  let outputs = run(".", parsed) catch {
    err => fail("run failed: " + err.to_string())
  }
  assert_eq(outputs.length(), 1)
  assert_eq(outputs[0].stringify(), "{\"z\":0,\"a\":9007199254740993}")
}

///|
test "compile and run_compiled use public Json surface" {
  let filter = compile(".foo + 1") catch {
    err => fail("compile failed: " + err.to_string())
  }
  let input : Json = { "foo": 41.0 }
  let values = run_compiled(filter, input) catch {
    err => fail("run_compiled failed: " + err.to_string())
  }
  assert_eq(values.length(), 1)
  assert_eq(values[0].stringify(), "42")
}

///|
test "run convenience lane executes filter strings on Json" {
  let input : Json = { "foo": 9.0 }
  let values = run(".foo", input) catch {
    err => fail("run failed: " + err.to_string())
  }
  assert_eq(values.length(), 1)
  assert_eq(values[0].stringify(), "9")
}

///|
test "run_text compatibility lane preserves json text outputs" {
  let values = run_text(".", "9007199254740993") catch {
    err => fail("run_text failed: " + err.to_string())
  }
  assert_eq(values, ["9007199254740993"])
}

///|
test "run_text wraps parse errors in JqxError" {
  guard (try? run_text(".", "{")) is Err(Parse(_)) else {
    fail("expected wrapped parse error")
  }
}

///|
test "parse raises public ParseError" {
  guard (try? parse("{")) is Err(InvalidEof) else {
    fail("expected public parse invalid eof")
  }
}

///|
test "compile raises public FilterError" {
  guard (try? compile("%")) is Err(Diagnostics(lines)) && lines.length() > 0 else {
    fail("expected public filter diagnostics")
  }
}

///|
test "run_compiled raises public EvalError with Json payloads" {
  let filter = compile("error({\"code\":1})") catch {
    err => fail("compile failed: " + err.to_string())
  }
  let input : Json = null
  guard (try? run_compiled(filter, input)) is Err(Thrown(value)) else {
    fail("expected public thrown eval error")
  }
  assert_eq(value.stringify(), "{\"code\":1}")
}
