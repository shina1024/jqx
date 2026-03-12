///|
// Source under test: jqx.mbt, jqx_public_types.mbt

///|
test "top-level parse returns standard Json" {
  let parsed = parse_json("{\"a\":1,\"b\":[true,null,\"x\"]}") catch {
    err => fail("parse_json failed: " + err.to_string())
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
test "compile returns a filter with run methods on public Json surface" {
  let filter = compile(".foo + 1") catch {
    err => fail("compile failed: " + err.to_string())
  }
  let input : Json = { "foo": 41.0 }
  let values = filter.run(input) catch {
    err => fail("compiled run failed: " + err.to_string())
  }
  assert_eq(values.length(), 1)
  assert_eq(values[0].stringify(), "42")
  let text_values = filter.run_json_text("{\"foo\":41}") catch {
    err => fail("compiled run_json_text failed: " + err.to_string())
  }
  assert_eq(text_values, ["42"])
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
test "run_json_text compatibility lane preserves json text outputs" {
  let values = run_json_text(".", "9007199254740993") catch {
    err => fail("run_json_text failed: " + err.to_string())
  }
  assert_eq(values, ["9007199254740993"])
}

///|
test "run_json_text wraps parse errors in JqxError" {
  guard (try? run_json_text(".", "{")) is Err(JsonParse(_)) else {
    fail("expected wrapped parse error")
  }
}

///|
test "parse_json raises public JsonParseError" {
  guard (try? parse_json("{")) is Err(InvalidEof) else {
    fail("expected public json parse invalid eof")
  }
}

///|
test "compile raises public CompileError" {
  guard (try? compile("%")) is Err(Diagnostics(lines)) && lines.length() > 0 else {
    fail("expected public compile diagnostics")
  }
}

///|
test "compiled filter run raises public RuntimeError with Json payloads" {
  let filter = compile("error({\"code\":1})") catch {
    err => fail("compile failed: " + err.to_string())
  }
  let input : Json = null
  guard (try? filter.run(input)) is Err(Thrown(value)) else {
    fail("expected public thrown eval error")
  }
  assert_eq(value.stringify(), "{\"code\":1}")
}
