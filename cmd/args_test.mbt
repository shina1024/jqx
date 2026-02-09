///|
test "parse args -n" {
  let args = ["jqx", "-n", "."]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  assert_eq(cfg.no_input, true)
  assert_eq(cfg.exit_status, false)
  assert_eq(cfg.slurp, false)
  assert_eq(cfg.filter, ".")
  assert_eq(cfg.input, None)
}

///|
test "parse args input" {
  let args = ["jqx", ".foo", "{\"foo\":1}"]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  assert_eq(cfg.no_input, false)
  assert_eq(cfg.exit_status, false)
  assert_eq(cfg.slurp, false)
  assert_eq(cfg.filter, ".foo")
  assert_eq(cfg.input, Some("{\"foo\":1}"))
}

///|
test "parse args -e" {
  let args = ["jqx", "-e", ".foo", "{\"foo\":1}"]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  assert_eq(cfg.exit_status, true)
  assert_eq(cfg.no_input, false)
  assert_eq(cfg.slurp, false)
  assert_eq(cfg.filter, ".foo")
  assert_eq(cfg.input, Some("{\"foo\":1}"))
}

///|
test "parse args -e with -n" {
  let args = ["jqx", "-e", "-n", "."]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  assert_eq(cfg.exit_status, true)
  assert_eq(cfg.no_input, true)
  assert_eq(cfg.slurp, false)
  assert_eq(cfg.filter, ".")
  assert_eq(cfg.input, None)
}

///|
test "parse args -s" {
  let args = ["jqx", "-s", ".", "1"]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  assert_eq(cfg.slurp, true)
  assert_eq(cfg.no_input, false)
  assert_eq(cfg.filter, ".")
  assert_eq(cfg.input, Some("1"))
}

///|
test "parse args -s with -n" {
  let args = ["jqx", "-s", "-n", "."]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  assert_eq(cfg.slurp, true)
  assert_eq(cfg.no_input, true)
  assert_eq(cfg.filter, ".")
  assert_eq(cfg.input, None)
}

///|
test "parse args unknown option" {
  let args = ["jqx", "-z", "."]
  let parsed = parse_cli_args(args)
  guard parsed is Err(_) else { fail("expected Err") }
}

///|
test "parse args -n with input" {
  let args = ["jqx", "-n", ".", "1"]
  let parsed = parse_cli_args(args)
  guard parsed is Err(_) else { fail("expected Err") }
}

///|
test "parse args too many arguments" {
  let args = ["jqx", ".", "1", "2"]
  let parsed = parse_cli_args(args)
  guard parsed is Err(_) else { fail("expected Err") }
}
