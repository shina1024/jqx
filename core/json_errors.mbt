///|
pub struct Position {
  line : Int // 1-based
  column : Int // 1-based
} derive(Eq, Debug)

///|
pub suberror ParseError {
  InvalidChar(Position, Char)
  InvalidEof
  DepthLimitExceeded
  InvalidNumericLiteral(Position)
  InvalidNumericLiteralAtEof(Position)
  InvalidStringLiteral(Position)
  InvalidStringLiteralAtEof(Position)
} derive(Eq, Debug)

///|
pub impl Show for ParseError with fn output(self, logger) {
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
    DepthLimitExceeded => logger.write_string("Exceeds depth limit for parsing")
    InvalidNumericLiteral({ line, column }) =>
      logger
      ..write_string("Invalid numeric literal at line ")
      ..write_object(line)
      ..write_string(", column ")
      .write_object(column)
    InvalidNumericLiteralAtEof({ line, column }) =>
      logger
      ..write_string("Invalid numeric literal at EOF at line ")
      ..write_object(line)
      ..write_string(", column ")
      .write_object(column)
    InvalidStringLiteral({ line, column }) =>
      logger
      ..write_string("Invalid string literal; expected \", but got ' at line ")
      ..write_object(line)
      ..write_string(", column ")
      .write_object(column)
    InvalidStringLiteralAtEof({ line, column }) =>
      logger
      ..write_string(
        "Invalid string literal; expected \", but got ' at EOF at line ",
      )
      ..write_object(line)
      ..write_string(", column ")
      .write_object(column)
  }
}

///|
pub suberror RunError {
  Parse(ParseError)
  Filter(FilterError)
  Eval(EvalError)
} derive(Eq, Debug)

///|
pub impl Show for RunError with fn output(self, logger) {
  match self {
    Parse(err) => Show::output(err, logger)
    Filter(err) => Show::output(err, logger)
    Eval(err) => Show::output(err, logger)
  }
}
