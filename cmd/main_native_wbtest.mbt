///|
// Source under test: cmd/main_cli.mbt

///|
test "run cli applies module search paths" {
  @lib.clear_module_sources()
  @lib.clear_module_search_paths()
  let result = run_cli(
    [
      "jqx", "-n", "-L", "third_party/jq-tests/tests/modules", "import \"a\" as foo; foo::a",
    ],
    "",
  )
  assert_eq(result.lines, ["\"a\""])
  assert_eq(result.exit_code, None)
  @lib.clear_module_search_paths()
  @lib.clear_module_sources()
}
