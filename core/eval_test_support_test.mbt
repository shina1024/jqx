///|
pub fn must_parse(input : String) -> Json raise Failure {
  parse(input) catch {
    err => fail("parse failed: " + err.to_string())
  }
}

///|
pub fn must_eval(f : Filter, j : Json) -> Array[Json] raise Failure {
  execute(f, j) catch {
    err => fail("eval failed: " + err.to_string())
  }
}
