///|
// Source under test: cmd/main.mbt

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
test "parse cli inputs json basic" {
  let cfg = {
    raw: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: Some("{\"a\":1}"),
  }
  let parsed = parse_cli_inputs(cfg, "")
  assert_eq(parsed, [@lib.Json::object({ "a": @lib.Json::number(1.0) })])
}

///|
test "parse cli inputs json stream accepts leading bom" {
  let cfg = {
    raw: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "\u{FEFF}\"byte order mark\"")
  assert_eq(parsed, [@lib.Json::string("byte order mark")])
}

///|
test "parse cli inputs json stream ndjson" {
  let cfg = {
    raw: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "1\n2\n3\n")
  assert_eq(parsed, [
    @lib.Json::number(1.0),
    @lib.Json::number(2.0),
    @lib.Json::number(3.0),
  ])
}

///|
test "parse cli inputs json stream whitespace separated" {
  let cfg = {
    raw: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "1 2")
  assert_eq(parsed, [@lib.Json::number(1.0), @lib.Json::number(2.0)])
}

///|
test "parse cli inputs json stream adjacent structured values" {
  let cfg = {
    raw: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "{}[]\"x\"")
  assert_eq(parsed, [
    @lib.Json::object({}),
    @lib.Json::array([]),
    @lib.Json::string("x"),
  ])
}

///|
test "parse cli inputs json stream invalid scalar adjacency" {
  let cfg = {
    raw: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  guard (try? parse_cli_inputs(cfg, "1-2")) is Err(_) else {
    fail("expected parse error for invalid scalar adjacency")
  }
}

///|
test "parse cli inputs json empty stdin" {
  let cfg = {
    raw: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, " \n\t\r ")
  assert_eq(parsed, [])
}

///|
test "parse cli inputs json slurp single" {
  let cfg = {
    raw: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: true,
    module_search_paths: [],
    filter: ".",
    input: Some("{\"a\":1}"),
  }
  let parsed = parse_cli_inputs(cfg, "")
  assert_eq(parsed, [
    @lib.Json::array([@lib.Json::object({ "a": @lib.Json::number(1.0) })]),
  ])
}

///|
test "parse cli inputs json slurp ndjson" {
  let cfg = {
    raw: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: true,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "1\n2\n3\n")
  assert_eq(parsed, [
    @lib.Json::array([
      @lib.Json::number(1.0),
      @lib.Json::number(2.0),
      @lib.Json::number(3.0),
    ]),
  ])
}

///|
test "parse cli inputs json slurp whitespace separated" {
  let cfg = {
    raw: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: true,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "1 2")
  assert_eq(parsed, [
    @lib.Json::array([@lib.Json::number(1.0), @lib.Json::number(2.0)]),
  ])
}

///|
test "parse cli inputs json slurp empty" {
  let cfg = {
    raw: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: true,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, " \n\t\r ")
  assert_eq(parsed, [@lib.Json::array([])])
}

///|
test "parse cli inputs no-input with slurp" {
  let cfg = {
    raw: false,
    raw_input: false,
    no_input: true,
    exit_status: false,
    slurp: true,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "1\n2\n")
  assert_eq(parsed, [@lib.Json::null()])
}

///|
test "parse cli inputs raw lines" {
  let cfg = {
    raw: false,
    raw_input: true,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "a\nb\n")
  assert_eq(parsed, [@lib.Json::string("a"), @lib.Json::string("b")])
}

///|
test "parse cli inputs raw lines keep empty records" {
  let cfg = {
    raw: false,
    raw_input: true,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "a\n\nb\n")
  assert_eq(parsed, [
    @lib.Json::string("a"),
    @lib.Json::string(""),
    @lib.Json::string("b"),
  ])
}

///|
test "parse cli inputs raw lines trim crlf" {
  let cfg = {
    raw: false,
    raw_input: true,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "a\r\nb\r\n")
  assert_eq(parsed, [@lib.Json::string("a"), @lib.Json::string("b")])
}

///|
test "parse cli inputs raw slurp" {
  let cfg = {
    raw: false,
    raw_input: true,
    no_input: false,
    exit_status: false,
    slurp: true,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "a\nb\n")
  assert_eq(parsed, [@lib.Json::string("a\nb\n")])
}

///|
test "parse cli inputs raw no-input takes precedence" {
  let cfg = {
    raw: false,
    raw_input: true,
    no_input: true,
    exit_status: false,
    slurp: true,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "a\n")
  assert_eq(parsed, [@lib.Json::null()])
}

///|
test "split error lines keeps trailing empty line" {
  assert_eq(split_error_lines("line1\nline2\n"), ["line1", "line2", ""])
  assert_eq(split_error_lines("single"), ["single"])
}

///|
test "format error message rewrites line and column" {
  assert_eq(
    format_error_message("Invalid number abc at line 3, column 14"),
    "jqx: error (at <stdin>:3:14): Invalid number abc",
  )
  assert_eq(
    format_error_message("Unexpected end of file"),
    "jqx: error: Unexpected end of file",
  )
}

///|
test "parse json value end reports structured and string eof errors" {
  guard (try? parse_json_value_end("{\"a\":1", 0)) is Err(_) else {
    fail("expected parse error for unclosed object")
  }
  guard (try? parse_json_value_end("{]", 0)) is Err(_) else {
    fail("expected parse error for mismatched braces")
  }
  guard (try? parse_json_value_end("\"abc", 0)) is Err(_) else {
    fail("expected parse error for unclosed string")
  }
}

///|
test "parse raw lines handles empty and no-trailing-newline" {
  assert_eq(parse_raw_lines(""), [])
  assert_eq(parse_raw_lines("last"), [@lib.Json::string("last")])
}
