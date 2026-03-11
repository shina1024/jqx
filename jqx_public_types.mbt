///|
pub struct Position {
  line : Int
  column : Int
} derive(Eq)

///|
pub impl Show for Position with output(self, logger) {
  logger
  ..write_string("Position(line=")
  ..write_object(self.line)
  ..write_string(", column=")
  ..write_object(self.column)
  .write_char(')')
}

///|
pub suberror ParseError {
  InvalidChar(Position, Char)
  InvalidEof
  DepthLimitExceeded
  InvalidNumericLiteral(Position)
  InvalidNumericLiteralAtEof(Position)
  InvalidStringLiteral(Position)
  InvalidStringLiteralAtEof(Position)
} derive(Eq)

///|
pub impl Show for ParseError with output(self, logger) {
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
    DepthLimitExceeded =>
      logger.write_string(
        "Depth limit exceeded, please increase the max_nesting_depth parameter",
      )
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
pub suberror EvalError {
  TypeError(String)
  Thrown(Json)
  UnknownFunction(String)
  UnknownVariable(String)
  BreakSignal(String, Array[Json])
  Partial(Array[Json], Json, String)
} derive(Eq)

///|
pub impl Show for EvalError with output(self, logger) {
  match self {
    TypeError(msg) => logger.write_string(msg)
    Thrown(value) =>
      match value {
        String(s) => logger.write_string(s)
        _ => logger.write_string(value.stringify())
      }
    UnknownFunction(name) => logger.write_string("Unknown function: " + name)
    UnknownVariable(name) => logger.write_string("Unknown variable: $" + name)
    BreakSignal(name, _) => logger.write_string("break $" + name)
    Partial(_, _, message) => logger.write_string(message)
  }
}

///|
pub struct CompiledFilter {
  priv filter : @core.Filter
}

///|
pub suberror JqxError {
  Parse(ParseError)
  Filter(FilterError)
  Eval(EvalError)
} derive(Eq)

///|
pub impl Show for JqxError with output(self, logger) {
  match self {
    Parse(err) => Show::output(err, logger)
    Filter(err) => Show::output(err, logger)
    Eval(err) => Show::output(err, logger)
  }
}

///|
fn position_from_core(input : @core.Position) -> Position {
  { line: input.line, column: input.column }
}

///|
fn parse_error_from_core(input : @core.ParseError) -> ParseError {
  match input {
    @core.InvalidChar(pos, ch) => InvalidChar(position_from_core(pos), ch)
    @core.InvalidEof => InvalidEof
    @core.DepthLimitExceeded => DepthLimitExceeded
    @core.InvalidNumericLiteral(pos) =>
      InvalidNumericLiteral(position_from_core(pos))
    @core.InvalidNumericLiteralAtEof(pos) =>
      InvalidNumericLiteralAtEof(position_from_core(pos))
    @core.InvalidStringLiteral(pos) =>
      InvalidStringLiteral(position_from_core(pos))
    @core.InvalidStringLiteralAtEof(pos) =>
      InvalidStringLiteralAtEof(position_from_core(pos))
  }
}

///|
fn filter_error_from_core(input : @core.FilterError) -> FilterError {
  match input {
    @core.InvalidChar(pos, ch) => InvalidChar(position_from_core(pos), ch)
    @core.InvalidEof => InvalidEof
    @core.InvalidNumber(pos, raw) => InvalidNumber(position_from_core(pos), raw)
    @core.Diagnostics(lines) => Diagnostics(lines)
  }
}

///|
fn eval_error_from_core(input : @core.EvalError) -> EvalError {
  match input {
    @core.TypeError(msg) => TypeError(msg)
    @core.Thrown(value) => Thrown(from_core_value(value))
    @core.UnknownFunction(name) => UnknownFunction(name)
    @core.UnknownVariable(name) => UnknownVariable(name)
    @core.BreakSignal(name, values) =>
      BreakSignal(name, values.map(from_core_value))
    @core.Partial(values, catch_input, message) =>
      Partial(
        values.map(from_core_value),
        from_core_value(catch_input),
        message,
      )
  }
}
