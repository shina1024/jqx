///|
/// Minimal jq filter parser (dot/field/index/iter, pipe, comma)
///
/// This intentionally supports a small core and can be extended later.

///|

///|
pub suberror FilterError {
  InvalidChar(Position, Char)
  InvalidEof
  InvalidNumber(Position, String)
  Diagnostics(Array[String])
} derive(Eq)

///|
pub impl Show for FilterError with output(self, logger) {
  match self {
    InvalidChar({ line, column }, c) =>
      logger
      ..write_string("Invalid character ")
      ..write_string(to_repr(c).to_string())
      ..write_string(" at line ")
      ..write_object(line)
      ..write_string(", column ")
      .write_object(column)
    InvalidEof => logger.write_string("Unexpected end of file")
    InvalidNumber({ line, column }, s) =>
      logger
      ..write_string("Invalid number ")
      ..write_string(s)
      ..write_string(" at line ")
      ..write_object(line)
      ..write_string(", column ")
      .write_object(column)
    Diagnostics(lines) =>
      for i in 0..<lines.length() {
        if i > 0 {
          logger.write_char('\n')
        }
        logger.write_string(lines[i])
      }
  }
}

///|

///|
fn parse_filter_ast(input : StringView) -> Filter raise FilterError {
  let ctx = FilterCursor::make(input)
  let filter = ctx.parse_scoped()
  ctx.skip_ws()
  if ctx.offset >= ctx.end_offset {
    filter
  } else {
    let ch = ctx.input.unsafe_get(ctx.offset).to_int().unsafe_to_char()
    match ch {
      '%' =>
        ctx.raise_syntax_error_at(ctx.offset, "'%'", expecting="end of file")
      '}' =>
        ctx.raise_syntax_error_at(
          ctx.offset,
          "INVALID_CHARACTER",
          expecting="end of file",
        )
      _ => ctx.invalid_char()
    }
  }
}

///|
pub fn compile(input : StringView) -> Filter raise FilterError {
  let filter = parse_filter_ast(input)
  validate_filter_compile_diagnostics(filter, input)
  filter
}

///|
/// Legacy alias. Prefer `compile` for jq-aligned naming.
pub fn parse_filter(input : StringView) -> Filter raise FilterError {
  parse_filter_ast(input)
}
