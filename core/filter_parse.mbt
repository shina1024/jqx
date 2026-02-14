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
} derive(Eq)

///|
pub impl Show for FilterError with output(self, logger) {
  match self {
    InvalidChar({ line, column }, c) =>
      logger
      ..write_string("Invalid character ")
      ..write_string(repr(c))
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
  }
}

///|

///|
pub fn compile(input : StringView) -> Filter raise FilterError {
  let ctx = FilterCursor::make(input)
  let filter = ctx.parse_scoped()
  ctx.skip_ws()
  if ctx.offset >= ctx.end_offset {
    filter
  } else {
    ctx.invalid_char()
  }
}

///|
/// Legacy alias. Prefer `compile` for jq-aligned naming.
pub fn parse_filter(input : StringView) -> Filter raise FilterError {
  compile(input)
}
