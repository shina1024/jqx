///|
test "parse args -n" {
  let args = ["jqx", "-n", "."]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  assert_eq(cfg.no_input, true)
  assert_eq(cfg.filter, ".")
  assert_eq(cfg.input, None)
}

///|
test "parse args input" {
  let args = ["jqx", ".foo", "{\"foo\":1}"]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  assert_eq(cfg.no_input, false)
  assert_eq(cfg.filter, ".foo")
  assert_eq(cfg.input, Some("{\"foo\":1}"))
}
