///|
// Source under test: cmd/args.mbt

///|
fn cfg_input_matches(cfg : CliArgs, expected : String?) -> Bool {
  match (cfg.input, expected) {
    (None, None) => true
    (Some(actual), Some(expected)) => actual == expected
    _ => false
  }
}

///|
test "parse args -n" {
  let args = ["jqx", "-n", "."]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  @debug.assert_eq(cfg.no_input, true)
  @debug.assert_eq(cfg.raw_input, false)
  @debug.assert_eq(cfg.exit_status, false)
  @debug.assert_eq(cfg.slurp, false)
  @debug.assert_eq(cfg.module_search_paths, [])
  @debug.assert_eq(cfg.filter, ".")
  @debug.assert_eq(cfg_input_matches(cfg, None), true)
}

///|
test "parse args input" {
  let args = ["jqx", ".foo", "{\"foo\":1}"]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  @debug.assert_eq(cfg.no_input, false)
  @debug.assert_eq(cfg.raw_input, false)
  @debug.assert_eq(cfg.exit_status, false)
  @debug.assert_eq(cfg.slurp, false)
  @debug.assert_eq(cfg.module_search_paths, [])
  @debug.assert_eq(cfg.filter, ".foo")
  @debug.assert_eq(cfg_input_matches(cfg, Some("{\"foo\":1}")), true)
}

///|
test "parse args -e" {
  let args = ["jqx", "-e", ".foo", "{\"foo\":1}"]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  @debug.assert_eq(cfg.exit_status, true)
  @debug.assert_eq(cfg.raw_input, false)
  @debug.assert_eq(cfg.no_input, false)
  @debug.assert_eq(cfg.slurp, false)
  @debug.assert_eq(cfg.filter, ".foo")
  @debug.assert_eq(cfg_input_matches(cfg, Some("{\"foo\":1}")), true)
}

///|
test "parse args -e with -n" {
  let args = ["jqx", "-e", "-n", "."]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  @debug.assert_eq(cfg.exit_status, true)
  @debug.assert_eq(cfg.raw_input, false)
  @debug.assert_eq(cfg.no_input, true)
  @debug.assert_eq(cfg.slurp, false)
  @debug.assert_eq(cfg.filter, ".")
  @debug.assert_eq(cfg_input_matches(cfg, None), true)
}

///|
test "parse args -s" {
  let args = ["jqx", "-s", ".", "1"]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  @debug.assert_eq(cfg.slurp, true)
  @debug.assert_eq(cfg.raw_input, false)
  @debug.assert_eq(cfg.no_input, false)
  @debug.assert_eq(cfg.filter, ".")
  @debug.assert_eq(cfg_input_matches(cfg, Some("1")), true)
}

///|
test "parse args -s with -n" {
  let args = ["jqx", "-s", "-n", "."]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  @debug.assert_eq(cfg.slurp, true)
  @debug.assert_eq(cfg.raw_input, false)
  @debug.assert_eq(cfg.no_input, true)
  @debug.assert_eq(cfg.filter, ".")
  @debug.assert_eq(cfg_input_matches(cfg, None), true)
}

///|
test "parse args -R" {
  let args = ["jqx", "-R", "."]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  @debug.assert_eq(cfg.raw_input, true)
  @debug.assert_eq(cfg.raw, false)
  @debug.assert_eq(cfg.slurp, false)
  @debug.assert_eq(cfg.no_input, false)
  @debug.assert_eq(cfg.filter, ".")
  @debug.assert_eq(cfg_input_matches(cfg, None), true)
}

///|
test "parse args -R -s" {
  let args = ["jqx", "-R", "-s", "."]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  @debug.assert_eq(cfg.raw_input, true)
  @debug.assert_eq(cfg.slurp, true)
  @debug.assert_eq(cfg.no_input, false)
  @debug.assert_eq(cfg.filter, ".")
}

///|
test "parse args -R with -n" {
  let args = ["jqx", "-R", "-n", "."]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  @debug.assert_eq(cfg.raw_input, true)
  @debug.assert_eq(cfg.no_input, true)
  @debug.assert_eq(cfg_input_matches(cfg, None), true)
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

///|
test "parse args -L paths" {
  let args = ["jqx", "-L", "modules", "-Llib", "."]
  let parsed = parse_cli_args(args)
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  @debug.assert_eq(cfg.module_search_paths, ["modules", "lib"])
  @debug.assert_eq(cfg.filter, ".")
}

///|
test "parse args -L missing value" {
  let args = ["jqx", "-L"]
  let parsed = parse_cli_args(args)
  guard parsed is Err(msg) && msg == "missing argument for -L" else {
    fail("expected missing argument error for -L")
  }
}

///|
test "parse args defaults to identity when no expression is provided" {
  guard parse_cli_args(["jqx"]) is Ok(cfg) else { fail("expected Ok") }
  @debug.assert_eq(cfg.filter, ".")
  @debug.assert_eq(cfg.compact, false)
}

///|
test "parse args respects -- option terminator" {
  let parsed = parse_cli_args(["jqx", "--", ".foo", "1"])
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  @debug.assert_eq(cfg.filter, ".foo")
  @debug.assert_eq(cfg_input_matches(cfg, Some("1")), true)
}

///|
test "parse args -r and -c are accepted" {
  let parsed = parse_cli_args(["jqx", "-r", "-c", ".", "\"x\""])
  guard parsed is Ok(cfg) else { fail("expected Ok") }
  @debug.assert_eq(cfg.raw, true)
  @debug.assert_eq(cfg.compact, true)
  @debug.assert_eq(cfg.filter, ".")
  @debug.assert_eq(cfg_input_matches(cfg, Some("\"x\"")), true)
}

///|
test "parse args defaults to identity after options" {
  guard parse_cli_args(["jqx", "-r", "-c"]) is Ok(cfg) else {
    fail("expected Ok")
  }
  @debug.assert_eq(cfg.filter, ".")
  @debug.assert_eq(cfg.raw, true)
  @debug.assert_eq(cfg.compact, true)
}
