///|
// Source under test: js/jqx_js.mbt

///|
test "offset_from_line_column handles valid and invalid positions" {
  let input = "a\nbc"
  assert_eq(offset_from_line_column(input, 1, 1), 0)
  assert_eq(offset_from_line_column(input, 1, 2), 1)
  assert_eq(offset_from_line_column(input, 2, 1), 2)
  assert_eq(offset_from_line_column(input, 2, 3), 4)
  assert_eq(offset_from_line_column(input, 3, 1), -1)
  assert_eq(offset_from_line_column(input, 0, 1), -1)
}

///|
fn expect_parse_error(input : String) -> @core.ParseError {
  guard (try? @core.parse(input)) is Err(err) else {
    abort("expected parse error: " + input)
  }
  err
}

///|
fn expect_filter_error(input : String) -> @core.FilterError {
  guard (try? @core.compile(input)) is Err(err) else {
    abort("expected filter error: " + input)
  }
  err
}

///|
test "parse_error_to_jqx_error maps parse variants" {
  let invalid_numeric_input = "Nax]"
  let invalid_numeric = expect_parse_error(invalid_numeric_input)
  let mapped_invalid_numeric = parse_error_to_jqx_error(
    invalid_numeric_input, invalid_numeric,
  )
  assert_eq(mapped_invalid_numeric.code, "parse_invalid_numeric_literal")
  assert_eq(mapped_invalid_numeric.line, 1)
  assert_eq(mapped_invalid_numeric.column, 4)
  assert_eq(mapped_invalid_numeric.offset, 3)

  let invalid_numeric_eof_input = "NaN10"
  let invalid_numeric_eof = expect_parse_error(invalid_numeric_eof_input)
  let mapped_invalid_numeric_eof = parse_error_to_jqx_error(
    invalid_numeric_eof_input, invalid_numeric_eof,
  )
  assert_eq(
    mapped_invalid_numeric_eof.code,
    "parse_invalid_numeric_literal_at_eof",
  )
  assert_eq(mapped_invalid_numeric_eof.line, 1)
  assert_eq(mapped_invalid_numeric_eof.column, 5)
  assert_eq(mapped_invalid_numeric_eof.offset, 4)

  let invalid_string_input = "'a'b"
  let invalid_string = expect_parse_error(invalid_string_input)
  let mapped_invalid_string = parse_error_to_jqx_error(
    invalid_string_input, invalid_string,
  )
  assert_eq(mapped_invalid_string.code, "parse_invalid_string_literal")
  assert_eq(mapped_invalid_string.line, 1)
  assert_eq(mapped_invalid_string.column, 4)
  assert_eq(mapped_invalid_string.offset, 3)

  let invalid_string_eof_input = "'a"
  let invalid_string_eof = expect_parse_error(invalid_string_eof_input)
  let mapped_invalid_string_eof = parse_error_to_jqx_error(
    invalid_string_eof_input, invalid_string_eof,
  )
  assert_eq(
    mapped_invalid_string_eof.code,
    "parse_invalid_string_literal_at_eof",
  )
  assert_eq(mapped_invalid_string_eof.line, 1)
  assert_eq(mapped_invalid_string_eof.column, 2)
  assert_eq(mapped_invalid_string_eof.offset, 1)

  let deep_input_buf = StringBuilder::new()
  for _ in 0..<1025 {
    deep_input_buf.write_char('[')
  }
  for _ in 0..<1025 {
    deep_input_buf.write_char(']')
  }
  let deep_input = deep_input_buf.to_string()
  let depth = expect_parse_error(deep_input)
  assert_eq(
    parse_error_to_jqx_error(deep_input, depth),
    jqx_error("parse_depth_limit_exceeded", depth.to_string()),
  )
}

///|
test "filter_error_to_jqx_error maps filter variants" {
  let invalid_number_input = "1e+"
  let invalid_number = expect_filter_error(invalid_number_input)
  let mapped_invalid_number = filter_error_to_jqx_error(
    invalid_number_input, invalid_number,
  )
  assert_eq(mapped_invalid_number.code, "filter_invalid_number")
  assert_eq(mapped_invalid_number.line, 1)
  assert_eq(mapped_invalid_number.column, 1)
  assert_eq(mapped_invalid_number.offset, 0)

  let invalid_eof_input = ".["
  let invalid_eof = expect_filter_error(invalid_eof_input)
  assert_eq(
    filter_error_to_jqx_error(invalid_eof_input, invalid_eof),
    jqx_error("filter_invalid_eof", invalid_eof.to_string()),
  )

  let diagnostics_input = "def f: g; def g: .; f"
  let diagnostics = expect_filter_error(diagnostics_input)
  assert_eq(
    filter_error_to_jqx_error(diagnostics_input, diagnostics),
    jqx_error("filter_diagnostics", diagnostics.to_string()),
  )
}
