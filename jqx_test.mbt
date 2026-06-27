///|
// Source under test: jqx.mbt, jqx_public_types.mbt

///|
fn nested_json_array_text(depth : Int, leaf : String) -> String {
  let buf = StringBuilder()
  for _ in 0..<depth {
    buf.write_char('[')
  }
  buf.write_string(leaf)
  for _ in 0..<depth {
    buf.write_char(']')
  }
  buf.to_string()
}

///|
test "top-level parse returns standard Json" {
  let parsed = parse_json("{\"a\":1,\"b\":[true,null,\"x\"]}") catch {
    err => fail("parse_json failed: " + err.to_string())
  }
  @debug.assert_eq(parsed.stringify(), "{\"a\":1,\"b\":[true,null,\"x\"]}")
}

///|
test "run roundtrips standard Json values without exposing core types" {
  let parsed = @json.parse("{\"z\":0,\"a\":9007199254740993}") catch {
    err => fail("std parse failed: " + err.to_string())
  }
  let outputs = run(".", parsed) catch {
    err => fail("run failed: " + err.to_string())
  }
  @debug.assert_eq(outputs.length(), 1)
  @debug.assert_eq(outputs[0].stringify(), "{\"z\":0,\"a\":9007199254740993}")
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
  @debug.assert_eq(values.length(), 1)
  @debug.assert_eq(values[0].stringify(), "42")
  let text_values = filter.run_json_text("{\"foo\":41}") catch {
    err => fail("compiled run_json_text failed: " + err.to_string())
  }
  @debug.assert_eq(text_values, ["42"])
}

///|
test "run convenience lane executes filter strings on Json" {
  let input : Json = { "foo": 9.0 }
  let values = run(".foo", input) catch {
    err => fail("run failed: " + err.to_string())
  }
  @debug.assert_eq(values.length(), 1)
  @debug.assert_eq(values[0].stringify(), "9")
}

///|
test "run preserves public Json object order across updates" {
  let input = @json.parse("{\"b\":1,\"a\":2,\"huge\":9007199254740993}") catch {
    err => fail("std parse failed: " + err.to_string())
  }
  let outputs = run(". + {\"a\":9,\"c\":3}", input) catch {
    err => fail("run failed: " + err.to_string())
  }
  @debug.assert_eq(outputs.length(), 1)
  @debug.assert_eq(
    outputs[0].stringify(),
    "{\"b\":1,\"a\":9,\"huge\":9007199254740993,\"c\":3}",
  )
}

///|
test "run_json_text compatibility lane preserves json text outputs" {
  let values = run_json_text(".", "9007199254740993") catch {
    err => fail("run_json_text failed: " + err.to_string())
  }
  @debug.assert_eq(values, ["9007199254740993"])
}

///|
test "run_json_text preserves escaped strings and large-number repr" {
  let values = run_json_text(
    ".foo, .n, .huge", "{\"foo\":\"line\\nbreak\",\"n\":1e309,\"huge\":9007199254740993}",
  ) catch {
    err => fail("run_json_text failed: " + err.to_string())
  }
  @debug.assert_eq(values, ["\"line\\nbreak\"", "1e309", "9007199254740993"])
}

///|
test "run raises compile errors through RunError" {
  guard (try run("%", null) catch {
    Compile(Diagnostics(lines)) => lines.length() > 0
    _ => false
  } noraise {
    _ => false
  }) else {
    fail("expected wrapped compile error")
  }
}

///|
test "run raises runtime errors through RunError" {
  guard (try run("error({\"code\":1})", null) catch {
    Runtime(Thrown(value)) => value.stringify() == "{\"code\":1}"
    _ => false
  } noraise {
    _ => false
  }) else {
    fail("expected wrapped runtime error")
  }
}

///|
test "run_json_text raises JsonTextRunError parse errors" {
  guard (try run_json_text(".", "{") catch {
    JsonParse(_) => true
    _ => false
  } noraise {
    _ => false
  }) else {
    fail("expected wrapped parse error")
  }
}

///|
test "run_json_text raises JsonTextRunError compile errors" {
  guard (try run_json_text("%", "{}") catch {
    Compile(Diagnostics(lines)) => lines.length() > 0
    _ => false
  } noraise {
    _ => false
  }) else {
    fail("expected wrapped compile error")
  }
}

///|
test "parse_json raises public JsonParseError" {
  guard (try parse_json("{") catch {
    InvalidEof => true
    _ => false
  } noraise {
    _ => false
  }) else {
    fail("expected public json parse invalid eof")
  }
}

///|
test "compile raises public CompileError" {
  guard (try compile("%") catch {
    Diagnostics(lines) => lines.length() > 0
    _ => false
  } noraise {
    _ => false
  }) else {
    fail("expected public compile diagnostics")
  }
}

///|
test "compiled filter run raises public RuntimeError with Json payloads" {
  let filter = compile("error({\"code\":1})") catch {
    err => fail("compile failed: " + err.to_string())
  }
  let input : Json = null
  guard (try filter.run(input) catch {
    Thrown(value) => value.stringify() == "{\"code\":1}"
    _ => false
  } noraise {
    _ => false
  }) else {
    fail("expected public thrown eval error")
  }
}

///|
test "compiled filter run_json_text preserves order and repr-sensitive outputs" {
  let filter = compile(". + {\"a\":9,\"c\":3}, .huge") catch {
    err => fail("compile failed: " + err.to_string())
  }
  let outputs = filter.run_json_text(
    "{\"b\":1,\"a\":2,\"huge\":9007199254740993}",
  ) catch {
    err => fail("compiled run_json_text failed: " + err.to_string())
  }
  @debug.assert_eq(outputs, [
    "{\"b\":1,\"a\":9,\"huge\":9007199254740993,\"c\":3}", "9007199254740993",
  ])
}

///|
test "compiled filter run_json_text raises CompiledJsonTextRunError parse errors" {
  let filter = compile(".") catch {
    err => fail("compile failed: " + err.to_string())
  }
  guard (try filter.run_json_text("{") catch {
    JsonParse(_) => true
    _ => false
  } noraise {
    _ => false
  }) else {
    fail("expected compiled text parse error")
  }
}

///|
test "public run_json_text follows jq 1.8.2 print depth beyond old limit" {
  let beyond_old_limit = nested_json_array_text(257, "0")
  let outputs = run_json_text(".", beyond_old_limit) catch {
    err =>
      fail("run_json_text failed beyond old depth limit: " + err.to_string())
  }
  @debug.assert_eq(outputs, [beyond_old_limit])
}
