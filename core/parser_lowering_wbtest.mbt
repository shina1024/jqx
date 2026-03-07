///|
// Source under test: core/parser_lowering.mbt

///|
fn compile_diagnostic_contains(source : String, message : String) -> Bool {
  guard (try? compile(source)) is Err(Diagnostics(lines)) &&
    lines.length() == 1 &&
    lines[0].contains(message) else {
    return false
  }
  true
}

///|
test "module declaration metadata must be constant object" {
  guard (try? compile("module {}; .")) is Ok(_) else {
    fail("expected empty module metadata to compile")
  }
  guard (try? compile("module {\"name\": \"j\" + \"qx\", \"empty\": []}; ."))
    is Ok(_) else {
    fail("expected constant string-add and empty-array metadata to compile")
  }
  guard compile_diagnostic_contains(
    "module .; .", "Module metadata must be constant",
  ) else {
    fail("expected module metadata constant diagnostic")
  }
  guard compile_diagnostic_contains(
    "module 1; .", "Module metadata must be an object",
  ) else {
    fail("expected module metadata object diagnostic")
  }
  guard compile_diagnostic_contains(
    "module {\"items\": [1]}; .", "Module metadata must be constant",
  ) else {
    fail("expected non-empty array metadata constant diagnostic")
  }
}

///|
test "import and include metadata diagnostics" {
  clear_module_sources()
  register_module_source("a", "def a: \"a\";")

  guard (try? compile("import \"a\" as foo {}; foo::a")) is Ok(_) else {
    fail("expected constant import metadata to compile")
  }

  guard compile_diagnostic_contains(
    "import \"a\\(.)\" as foo; foo::a", "Import path must be constant",
  ) else {
    fail("expected import path constant diagnostic")
  }
  guard compile_diagnostic_contains(
    "import \"a\" as foo .; foo::a", "Module metadata must be constant",
  ) else {
    fail("expected import metadata constant diagnostic")
  }
  guard compile_diagnostic_contains(
    "include \"a\" 1; a", "Module metadata must be an object",
  ) else {
    fail("expected include metadata object diagnostic")
  }

  clear_module_sources()
}

///|
test "as pattern object key diagnostics cover scalar constants" {
  guard compile_diagnostic_contains(
    ". as { (true): $x }; $x", "Cannot use boolean (true) as object key",
  ) else {
    fail("expected boolean true object key diagnostic")
  }
  guard compile_diagnostic_contains(
    ". as { (false): $x }; $x", "Cannot use boolean (false) as object key",
  ) else {
    fail("expected boolean false object key diagnostic")
  }
  guard compile_diagnostic_contains(
    ". as { (null): $x }; $x", "Cannot use null (null) as object key",
  ) else {
    fail("expected null object key diagnostic")
  }
  guard compile_diagnostic_contains(
    ". as { (1): $x }; $x", "Cannot use number (1) as object key",
  ) else {
    fail("expected number object key diagnostic")
  }
}
