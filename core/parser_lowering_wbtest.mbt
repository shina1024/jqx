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
