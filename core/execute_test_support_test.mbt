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
