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
pub suberror JsonParseError {
  InvalidChar(Position, Char)
  InvalidEof
  DepthLimitExceeded
  InvalidNumericLiteral(Position)
  InvalidNumericLiteralAtEof(Position)
  InvalidStringLiteral(Position)
  InvalidStringLiteralAtEof(Position)
} derive(Eq)

///|
pub impl Show for JsonParseError with output(self, logger) {
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
pub suberror CompileError {
  InvalidChar(Position, Char)
  InvalidEof
  InvalidNumber(Position, String)
  Diagnostics(Array[String])
} derive(Eq)

///|
pub impl Show for CompileError with output(self, logger) {
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
pub suberror RuntimeError {
  TypeError(String)
  Thrown(Json)
  UnknownFunction(String)
  UnknownVariable(String)
  BreakSignal(String, Array[Json])
  Partial(Array[Json], Json, String)
} derive(Eq)

///|
pub impl Show for RuntimeError with output(self, logger) {
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
  JsonParse(JsonParseError)
  Compile(CompileError)
  Runtime(RuntimeError)
} derive(Eq)

///|
pub impl Show for JqxError with output(self, logger) {
  match self {
    JsonParse(err) => Show::output(err, logger)
    Compile(err) => Show::output(err, logger)
    Runtime(err) => Show::output(err, logger)
  }
}

///|
fn jqx_error_from_core(input : @core.RunError) -> JqxError {
  match input {
    @core.Parse(err) => JsonParse(json_parse_error_from_core(err))
    @core.Filter(err) => Compile(compile_error_from_core(err))
    @core.Eval(err) => Runtime(runtime_error_from_core(err))
  }
}

///|
fn position_from_core(input : @core.Position) -> Position {
  { line: input.line, column: input.column }
}

///|
fn json_parse_error_from_core(input : @core.ParseError) -> JsonParseError {
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
fn compile_error_from_core(input : @core.FilterError) -> CompileError {
  match input {
    @core.InvalidChar(pos, ch) => InvalidChar(position_from_core(pos), ch)
    @core.InvalidEof => InvalidEof
    @core.InvalidNumber(pos, raw) => InvalidNumber(position_from_core(pos), raw)
    @core.Diagnostics(lines) => Diagnostics(lines)
  }
}

///|
fn runtime_error_from_core(input : @core.EvalError) -> RuntimeError {
  match input {
    @core.TypeError(msg) => TypeError(msg)
    @core.Thrown(value) => Thrown(@core.Value::to_json(value))
    @core.UnknownFunction(name) => UnknownFunction(name)
    @core.UnknownVariable(name) => UnknownVariable(name)
    @core.BreakSignal(name, values) =>
      BreakSignal(name, @core.values_to_json(values))
    @core.Partial(values, catch_input, message) =>
      Partial(
        @core.values_to_json(values),
        @core.Value::to_json(catch_input),
        message,
      )
  }
}
