///|
// Source under test: core/parser_diagnostics.mbt

///|
fn has_no_compile_diagnostic(diag : CompileDiagnostic?) -> Bool {
  diag is None
}

///|
fn is_unknown_variable_diagnostic(
  diag : CompileDiagnostic?,
  name : String,
) -> Bool {
  diag is Some(UnknownVariable(found)) && found == name
}

///|
fn is_undefined_label_diagnostic(
  diag : CompileDiagnostic?,
  name : String,
) -> Bool {
  diag is Some(UndefinedLabel(found)) && found == name
}

///|
test "compile first diagnostic handles unknown variables and labels" {
  guard is_unknown_variable_diagnostic(
    compile_first_diagnostic(Filter::var_("x"), [], []),
    "x",
  ) else {
    fail("expected unknown variable diagnostic for direct var")
  }
  guard has_no_compile_diagnostic(
    compile_first_diagnostic(Filter::var_("ENV"), [], []),
  ) else {
    fail("expected no diagnostic for $ENV")
  }
  guard has_no_compile_diagnostic(
    compile_first_diagnostic(Filter::var_("__loc__"), [], []),
  ) else {
    fail("expected no diagnostic for $__loc__")
  }
  guard is_undefined_label_diagnostic(
    compile_first_diagnostic(Filter::break_("outer"), [], []),
    "outer",
  ) else {
    fail("expected undefined label diagnostic")
  }
  guard has_no_compile_diagnostic(
    compile_first_diagnostic(Filter::break_("outer"), [], ["outer"]),
  ) else {
    fail("expected no diagnostic for bound label")
  }
}

///|
test "compile first diagnostic respects binding scopes" {
  let reduce_filter = Filter::reduce(
    Filter::iter(),
    "x",
    Filter::literal(Json::number(0.0)),
    Filter::add(Filter::identity(), Filter::var_("x")),
  )
  let foreach_filter = Filter::foreach(
    Filter::iter(),
    "x",
    Filter::literal(Json::number(0.0)),
    Filter::add(Filter::identity(), Filter::var_("x")),
    Filter::var_("x"),
  )
  let as_filter = Filter::as_(
    Filter::identity(),
    "v",
    Filter::add(Filter::var_("v"), Filter::literal(Json::number(1.0))),
  )
  guard has_no_compile_diagnostic(
    compile_first_diagnostic(reduce_filter, [], []),
  ) else {
    fail("expected reduce binding to resolve")
  }
  guard has_no_compile_diagnostic(
    compile_first_diagnostic(foreach_filter, [], []),
  ) else {
    fail("expected foreach binding to resolve")
  }
  guard has_no_compile_diagnostic(compile_first_diagnostic(as_filter, [], [])) else {
    fail("expected as-binding to resolve")
  }
}

///|
test "compile signatures and offsets helpers" {
  let defs : Array[(String, Array[String], Filter)] = [
    ("f", [], Filter::identity()),
    ("g", ["x", "y"], Filter::add(Filter::var_("x"), Filter::var_("y"))),
  ]
  assert_eq(compile_scope_signatures(defs), [("f", 0), ("g", 2)])
  assert_eq(compile_find_token_offset("$x + $y", "$y"), Some(5))
  assert_eq(compile_find_token_offset("$x + $y", "$z"), None)
  assert_eq(compile_has_signature([("f", 0), ("g", 1)], "g", 1), true)
  assert_eq(compile_has_signature([("f", 0), ("g", 1)], "g", 0), false)
}

///|
test "compile unresolved local call detection" {
  let all = [("f", 0), ("g", 0)]
  assert_eq(
    compile_first_unresolved_local_call(Filter::builtin("g"), [("f", 0)], all),
    Some(("g", 0)),
  )
  assert_eq(
    compile_first_unresolved_local_call(Filter::builtin("g"), [("g", 0)], all),
    None,
  )
  assert_eq(
    compile_first_unresolved_local_call(
      Filter::call("g", [Filter::identity()]),
      [("f", 1)],
      [("f", 1), ("g", 1)],
    ),
    Some(("g", 1)),
  )
}

///|
test "compile forward reference detection in scope" {
  let defs_forward : Array[(String, Array[String], Filter)] = [
    ("f", [], Filter::builtin("g")),
    ("g", [], Filter::identity()),
  ]
  let defs_ordered : Array[(String, Array[String], Filter)] = [
    ("g", [], Filter::identity()),
    ("f", [], Filter::builtin("g")),
  ]
  let defs_arity : Array[(String, Array[String], Filter)] = [
    ("f", ["x"], Filter::call("g", [Filter::var_("x")])),
    ("g", ["y"], Filter::var_("y")),
  ]
  assert_eq(compile_first_forward_ref_in_scope(defs_forward), Some(("g", 0)))
  assert_eq(compile_first_forward_ref_in_scope(defs_ordered), None)
  assert_eq(compile_first_forward_ref_in_scope(defs_arity), Some(("g", 1)))
}

///|
test "validate diagnostics reports unknown variable and label" {
  guard (try? validate_filter_compile_diagnostics(Filter::var_("x"), "$x"))
    is Err(Diagnostics(lines)) &&
    lines.length() == 1 &&
    lines[0].contains("$x is not defined") else {
    fail("expected unknown variable diagnostic")
  }
  guard (try? validate_filter_compile_diagnostics(
      Filter::break_("loop"),
      "break $loop",
    ))
    is Err(Diagnostics(lines)) &&
    lines.length() == 1 &&
    lines[0].contains("$*label-loop is not defined") else {
    fail("expected undefined label diagnostic")
  }
}

///|
test "validate diagnostics reports forward references from compile()" {
  guard (try? compile("def f: g; def g: .; f")) is Err(Diagnostics(lines)) &&
    lines.length() == 1 &&
    lines[0].contains("g/0 is not defined") else {
    fail("expected forward-reference diagnostic")
  }
  guard (try? compile("def g: .; def f: g; f")) is Ok(_) else {
    fail("expected ordered definitions to compile")
  }
}
