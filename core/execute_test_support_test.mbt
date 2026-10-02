///|
// Source under test: core/execute*.mbt
//
// Shared test helper for execute-related test files.

///|
using @core {
  type Filter,
  type Value,
  clear_module_sources,
  compile,
  execute,
  parse,
  register_module_source,
  run_compiled_json_text,
  run_compiled_values,
  run_json_text,
  run_values,
}

///|
pub fn must_parse(input : String) -> Value raise Failure {
  parse(input) catch {
    err => fail("parse failed: " + err.to_string())
  }
}

///|
pub fn must_execute(f : Filter, j : Value) -> Array[Value] raise Failure {
  execute(f, j) catch {
    err => fail("execute failed: " + err.to_string())
  }
}

///|
pub fn must_run_values(
  filter : String,
  input : String,
) -> Array[Value] raise Failure {
  run_values(filter, input) catch {
    err => fail("run_values failed: " + err.to_string())
  }
}

///|
pub fn must_run_json_text(
  filter : String,
  input : String,
) -> Array[String] raise Failure {
  run_json_text(filter, input) catch {
    err => fail("run_json_text failed: " + err.to_string())
  }
}
