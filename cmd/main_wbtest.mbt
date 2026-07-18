///|
// Source under test: cmd/main.mbt, cmd/main_cli.mbt

///|
test "compute exit status" {
  @debug.assert_eq(compute_exit_status([]), 4)
  @debug.assert_eq(compute_exit_status([@lib.Value::null()]), 1)
  @debug.assert_eq(compute_exit_status([@lib.Value::boolean(false)]), 1)
  @debug.assert_eq(compute_exit_status([@lib.Value::boolean(true)]), 0)
  @debug.assert_eq(compute_exit_status([@lib.Value::number(1.0)]), 0)
  @debug.assert_eq(
    compute_exit_status([@lib.Value::number(1.0), @lib.Value::boolean(false)]),
    1,
  )
}

///|
test "parse cli inputs json basic" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: Some("{\"a\":1}"),
  }
  let parsed = parse_cli_inputs(cfg, "")
  @debug.assert_eq(parsed, [
    @lib.Value::object({ "a": @lib.Value::number(1.0) }),
  ])
}

///|
test "parse cli inputs direct input overrides stdin" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: Some("{\"a\":2}"),
  }
  let parsed = parse_cli_inputs(cfg, "{\"a\":1}")
  @debug.assert_eq(parsed, [
    @lib.Value::object({ "a": @lib.Value::number(2.0) }),
  ])
}

///|
test "parse cli inputs json stream accepts leading bom" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "\u{FEFF}\"byte order mark\"")
  @debug.assert_eq(parsed, [@lib.Value::string("byte order mark")])
}

///|
test "parse cli inputs json stream ndjson" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "1\n2\n3\n")
  @debug.assert_eq(parsed, [
    @lib.Value::number(1.0),
    @lib.Value::number(2.0),
    @lib.Value::number(3.0),
  ])
}

///|
test "parse cli inputs json stream whitespace separated" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "1 2")
  @debug.assert_eq(parsed, [@lib.Value::number(1.0), @lib.Value::number(2.0)])
}

///|
test "parse cli inputs json stream adjacent structured values" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "{}[]\"x\"")
  @debug.assert_eq(parsed, [
    @lib.Value::object(Map([])),
    @lib.Value::array([]),
    @lib.Value::string("x"),
  ])
}

///|
test "parse cli inputs json stream invalid scalar adjacency" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  guard (try parse_cli_inputs(cfg, "1-2") catch {
    _ => true
  } noraise {
    _ => false
  }) else {
    fail("expected parse error for invalid scalar adjacency")
  }
}

///|
test "parse cli inputs json empty stdin" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, " \n\t\r ")
  @debug.assert_eq(parsed, [])
}

///|
test "parse cli inputs json slurp single" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: true,
    module_search_paths: [],
    filter: ".",
    input: Some("{\"a\":1}"),
  }
  let parsed = parse_cli_inputs(cfg, "")
  @debug.assert_eq(parsed, [
    @lib.Value::array([@lib.Value::object({ "a": @lib.Value::number(1.0) })]),
  ])
}

///|
test "parse cli inputs json slurp ndjson" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: true,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "1\n2\n3\n")
  @debug.assert_eq(parsed, [
    @lib.Value::array([
      @lib.Value::number(1.0),
      @lib.Value::number(2.0),
      @lib.Value::number(3.0),
    ]),
  ])
}

///|
test "parse cli inputs json slurp whitespace separated" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: true,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "1 2")
  @debug.assert_eq(parsed, [
    @lib.Value::array([@lib.Value::number(1.0), @lib.Value::number(2.0)]),
  ])
}

///|
test "parse cli inputs json slurp empty" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: true,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, " \n\t\r ")
  @debug.assert_eq(parsed, [@lib.Value::array([])])
}

///|
test "parse cli inputs no-input with slurp" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: false,
    no_input: true,
    exit_status: false,
    slurp: true,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "1\n2\n")
  @debug.assert_eq(parsed, [@lib.Value::null()])
}

///|
test "parse cli inputs raw lines" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: true,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "a\nb\n")
  @debug.assert_eq(parsed, [@lib.Value::string("a"), @lib.Value::string("b")])
}

///|
test "parse cli inputs raw lines keep empty records" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: true,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "a\n\nb\n")
  @debug.assert_eq(parsed, [
    @lib.Value::string("a"),
    @lib.Value::string(""),
    @lib.Value::string("b"),
  ])
}

///|
test "parse cli inputs raw lines trim crlf" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: true,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "a\r\nb\r\n")
  @debug.assert_eq(parsed, [@lib.Value::string("a"), @lib.Value::string("b")])
}

///|
test "parse cli inputs raw slurp" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: true,
    no_input: false,
    exit_status: false,
    slurp: true,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "a\nb\n")
  @debug.assert_eq(parsed, [@lib.Value::string("a\nb\n")])
}

///|
test "parse cli inputs raw direct input slurp" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: true,
    no_input: false,
    exit_status: false,
    slurp: true,
    module_search_paths: [],
    filter: ".",
    input: Some("a\nb\n"),
  }
  let parsed = parse_cli_inputs(cfg, "ignored\n")
  @debug.assert_eq(parsed, [@lib.Value::string("a\nb\n")])
}

///|
test "parse cli inputs raw no-input takes precedence" {
  let cfg = {
    raw: false,
    compact: false,
    raw_input: true,
    no_input: true,
    exit_status: false,
    slurp: true,
    module_search_paths: [],
    filter: ".",
    input: None,
  }
  let parsed = parse_cli_inputs(cfg, "a\n")
  @debug.assert_eq(parsed, [@lib.Value::null()])
}

///|
test "split error lines keeps trailing empty line" {
  @debug.assert_eq(split_error_lines("line1\nline2\n"), ["line1", "line2", ""])
  @debug.assert_eq(split_error_lines("single"), ["single"])
}

///|

///|
fn exit_code_matches(actual : Int?, expected : Int?) -> Bool {
  match (actual, expected) {
    (None, None) => true
    (Some(actual), Some(expected)) => actual == expected
    _ => false
  }
}

///|
test "format error message rewrites line and column" {
  @debug.assert_eq(
    format_error_message("Invalid number abc at line 3, column 14"),
    "jqx: error (at <stdin>:3:14): Invalid number abc",
  )
  @debug.assert_eq(
    format_error_message("Unexpected end of file"),
    "jqx: error: Unexpected end of file",
  )
}

///|
test "run cli defaults to identity when filter is missing" {
  let result = run_cli(["jqx"], "{\"foo\":1}")
  @debug.assert_eq(result.stdout_lines, ["{\n  \"foo\": 1\n}"])
  @debug.assert_eq(result.stderr_lines, [])
  @debug.assert_eq(exit_code_matches(result.exit_code, None), true)
}

///|
test "run cli usage text uses jqx command" {
  @debug.assert_eq(
    usage_summary_line(),
    "Usage: jqx [options] [\"<filter>\"] [\"<json>\"]",
  )
}

///|
test "run cli reports arg parse errors with short usage" {
  let result = run_cli(["jqx", "-L"], "")
  @debug.assert_eq(result.stdout_lines, [])
  @debug.assert_eq(result.stderr_lines, [
    "jqx: error: missing argument for -L",
    usage_summary_line(),
  ])
  @debug.assert_eq(exit_code_matches(result.exit_code, Some(2)), true)
}

///|
test "run cli executes stdin input" {
  let result = run_cli(["jqx", ".foo"], "{\"foo\":1}")
  @debug.assert_eq(result.stdout_lines, ["1"])
  @debug.assert_eq(result.stderr_lines, [])
  @debug.assert_eq(exit_code_matches(result.exit_code, None), true)
}

///|
test "run cli direct input raw string parity case" {
  @debug.assert_eq(format_output(true, false, @lib.Value::string("bar")), "bar")
  let result = run_cli(["jqx", "-r", ".foo", "{\"foo\":\"bar\"}"], "")
  @debug.assert_eq(result.stdout_lines, ["bar"])
  @debug.assert_eq(result.stderr_lines, [])
  @debug.assert_eq(exit_code_matches(result.exit_code, None), true)
}

///|
test "run cli computes -e exit status" {
  let result = run_cli(["jqx", "-e", ".", "null"], "")
  @debug.assert_eq(result.stdout_lines, ["null"])
  @debug.assert_eq(result.stderr_lines, [])
  @debug.assert_eq(exit_code_matches(result.exit_code, Some(1)), true)
}

///|
test "run cli formats compile errors" {
  let result = run_cli(["jqx", ".['x']", "null"], "")
  @debug.assert_eq(exit_code_matches(result.exit_code, Some(3)), true)
  @debug.assert_eq(result.stdout_lines, [])
  guard result.stderr_lines.length() == 1 &&
    result.stderr_lines[0].contains("jqx: error (at <stdin>:1:3):") &&
    result.stderr_lines[0].contains("Invalid character") else {
    fail("expected formatted compile error line")
  }
}

///|
test "run cli runtime error parity corpus case" {
  let result = run_cli(["jqx", ".[] | tonumber", "[1,\"x\"]"], "")
  @debug.assert_eq(exit_code_matches(result.exit_code, Some(5)), true)
  guard result.stdout_lines == ["1"] &&
    result.stderr_lines.length() == 1 &&
    result.stderr_lines[0].contains("cannot be parsed as a number") else {
    fail("expected partial output on stdout and runtime error on stderr")
  }
}

///|
test "parse json value end reports structured and string eof errors" {
  guard (try parse_json_value_end("{\"a\":1", 0) catch {
    _ => true
  } noraise {
    _ => false
  }) else {
    fail("expected parse error for unclosed object")
  }
  guard (try parse_json_value_end("{]", 0) catch {
    _ => true
  } noraise {
    _ => false
  }) else {
    fail("expected parse error for mismatched braces")
  }
  guard (try parse_json_value_end("\"abc", 0) catch {
    _ => true
  } noraise {
    _ => false
  }) else {
    fail("expected parse error for unclosed string")
  }
}

///|
test "parse json value end handles escaped quotes" {
  let structured = "{\"a\":\"b\\\"c\"}"
  let string_value = "\"a\\\"b\""
  @debug.assert_eq(parse_json_value_end(structured, 0), structured.length())
  @debug.assert_eq(parse_json_value_end(string_value, 0), string_value.length())
}

///|
test "parse raw lines handles empty and no-trailing-newline" {
  @debug.assert_eq(parse_raw_lines(""), [])
  @debug.assert_eq(parse_raw_lines("last"), [@lib.Value::string("last")])
}

///|
test "render error lines skips empties and falls back on blank input" {
  @debug.assert_eq(render_error_lines("line1\n\nline2\n"), [
    "jqx: error: line1", "jqx: error: line2",
  ])
  @debug.assert_eq(render_error_lines(""), ["jqx: error: "])
}

///|
test "cli reads stdin only for parsed stdin input" {
  @debug.assert_eq(cli_reads_stdin(["jqx"]), true)
  @debug.assert_eq(cli_reads_stdin(["jqx", "."]), true)
  @debug.assert_eq(cli_reads_stdin(["jqx", ".", "1"]), false)
  @debug.assert_eq(cli_reads_stdin(["jqx", "-n", "."]), false)
  @debug.assert_eq(cli_reads_stdin(["jqx", "-L"]), false)
}

///|
test "configure module search paths accepts explicit paths" {
  configure_module_search_paths({
    raw: false,
    compact: false,
    raw_input: false,
    no_input: false,
    exit_status: false,
    slurp: false,
    module_search_paths: ["third_party/jq-tests/tests/modules"],
    filter: ".",
    input: None,
  })
  @lib.clear_module_search_paths()
}

///|
test "format error message falls back for malformed locations" {
  @debug.assert_eq(
    format_error_message("Invalid number abc at line x, column 14"),
    "jqx: error: Invalid number abc at line x, column 14",
  )
  @debug.assert_eq(
    format_error_message("Invalid number abc at line 3"),
    "jqx: error: Invalid number abc at line 3",
  )
}
