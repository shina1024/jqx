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
test "conversion helpers bridge Json and core Value" {
  let parsed = @json.parse("{\"z\":0,\"a\":9007199254740993}") catch {
    err => fail("std parse failed: " + err.to_string())
  }
  let core = to_core_value(parsed)
  assert_eq(core.to_json_string(), "{\"z\":0,\"a\":9007199254740993}")
  let roundtrip = from_core_value(core)
  assert_eq(roundtrip.stringify(), "{\"z\":0,\"a\":9007199254740993}")
}

///|
test "compile and execute use public Json surface" {
  let filter = compile(".foo + 1") catch {
    err => fail("compile failed: " + err.to_string())
  }
  let input : Json = { "foo": 41.0 }
  let values = execute(filter, input) catch {
    err => fail("execute failed: " + err.to_string())
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
