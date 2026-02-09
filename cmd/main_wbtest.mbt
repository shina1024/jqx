///|
test "compute exit status" {
  assert_eq(compute_exit_status([]), 4)
  assert_eq(compute_exit_status([@lib.Json::null()]), 1)
  assert_eq(compute_exit_status([@lib.Json::boolean(false)]), 1)
  assert_eq(compute_exit_status([@lib.Json::boolean(true)]), 0)
  assert_eq(compute_exit_status([@lib.Json::number(1.0)]), 0)
  assert_eq(
    compute_exit_status([@lib.Json::number(1.0), @lib.Json::boolean(false)]),
    1,
  )
}

///|
test "parse cli input json basic" {
  let cfg = {
    raw: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    filter: ".",
    input: Some("{\"a\":1}"),
  }
  let parsed = parse_cli_input_json(cfg, "")
  assert_eq(parsed, @lib.Json::object({ "a": @lib.Json::number(1.0) }))
}

///|
test "parse cli input json slurp single" {
  let cfg = {
    raw: false,
    no_input: false,
    exit_status: false,
    slurp: true,
    filter: ".",
    input: Some("{\"a\":1}"),
  }
  let parsed = parse_cli_input_json(cfg, "")
  assert_eq(
    parsed,
    @lib.Json::array([@lib.Json::object({ "a": @lib.Json::number(1.0) })]),
  )
}

///|
test "parse cli input json slurp ndjson" {
  let cfg = {
    raw: false,
    no_input: false,
    exit_status: false,
    slurp: true,
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_input_json(cfg, "1\n2\n3\n")
  assert_eq(
    parsed,
    @lib.Json::array([
      @lib.Json::number(1.0),
      @lib.Json::number(2.0),
      @lib.Json::number(3.0),
    ]),
  )
}

///|
test "parse cli input json slurp empty" {
  let cfg = {
    raw: false,
    no_input: false,
    exit_status: false,
    slurp: true,
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_input_json(cfg, " \n\t\r ")
  assert_eq(parsed, @lib.Json::array([]))
}

///|
test "parse cli input json no-input slurp" {
  let cfg = {
    raw: false,
    no_input: true,
    exit_status: false,
    slurp: true,
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_input_json(cfg, "1\n2\n")
  assert_eq(parsed, @lib.Json::array([]))
}
