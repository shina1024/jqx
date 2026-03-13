///|
// Shared test helper for execute-related test files.

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
