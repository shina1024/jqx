///|
/// Minimal JS/TS-facing API.
/// Keep this surface area small for stability.

///|
pub struct JqxError {
  code : String
  message : String
  line : Int
  column : Int
  offset : Int
} derive(Eq, Show)

///|
fn jqx_error(
  code : String,
  message : String,
  line? : Int = -1,
  column? : Int = -1,
  offset? : Int = -1,
) -> JqxError {
  { code, message, line, column, offset }
}

///|
fn offset_from_line_column(input : String, line : Int, column : Int) -> Int {
  if line <= 0 || column <= 0 {
    return -1
  }
  let mut offset = 0
  let mut current_line = 1
  let mut current_column = 1
  for {
    if current_line == line && current_column == column {
      return offset
    }
    if offset >= input.length() {
      break
    }
    let ch = input.unsafe_get(offset).to_int().unsafe_to_char()
    offset += 1
    if ch == '\n' {
      current_line += 1
      current_column = 1
    } else {
      current_column += 1
    }
  }
  if current_line == line && current_column == column {
    offset
  } else {
    -1
  }
}

///|
fn parse_error_to_jqx_error(input : String, err : @core.ParseError) -> JqxError {
  match err {
    @core.InvalidChar({ line, column }, _) =>
      jqx_error(
        "parse_invalid_char",
        err.to_string(),
        line~,
        column~,
        offset=offset_from_line_column(input, line, column),
      )
    @core.InvalidEof => jqx_error("parse_invalid_eof", err.to_string())
    @core.DepthLimitExceeded =>
      jqx_error("parse_depth_limit_exceeded", err.to_string())
    @core.InvalidNumericLiteral({ line, column }) =>
      jqx_error(
        "parse_invalid_numeric_literal",
        err.to_string(),
        line~,
        column~,
        offset=offset_from_line_column(input, line, column),
      )
    @core.InvalidNumericLiteralAtEof({ line, column }) =>
      jqx_error(
        "parse_invalid_numeric_literal_at_eof",
        err.to_string(),
        line~,
        column~,
        offset=offset_from_line_column(input, line, column),
      )
    @core.InvalidStringLiteral({ line, column }) =>
      jqx_error(
        "parse_invalid_string_literal",
        err.to_string(),
        line~,
        column~,
        offset=offset_from_line_column(input, line, column),
      )
    @core.InvalidStringLiteralAtEof({ line, column }) =>
      jqx_error(
        "parse_invalid_string_literal_at_eof",
        err.to_string(),
        line~,
        column~,
        offset=offset_from_line_column(input, line, column),
      )
  }
}

///|
fn filter_error_to_jqx_error(
  input : String,
  err : @core.FilterError,
) -> JqxError {
  match err {
    @core.InvalidChar({ line, column }, _) =>
      jqx_error(
        "filter_invalid_char",
        err.to_string(),
        line~,
        column~,
        offset=offset_from_line_column(input, line, column),
      )
    @core.InvalidEof => jqx_error("filter_invalid_eof", err.to_string())
    @core.InvalidNumber({ line, column }, _) =>
      jqx_error(
        "filter_invalid_number",
        err.to_string(),
        line~,
        column~,
        offset=offset_from_line_column(input, line, column),
      )
  }
}

///|
fn eval_error_to_jqx_error(err : @core.EvalError) -> JqxError {
  match err {
    @core.TypeError(msg) => jqx_error("eval_type_error", msg)
    @core.Thrown(_) => jqx_error("eval_thrown", err.to_string())
    @core.UnknownFunction(_) =>
      jqx_error("eval_unknown_function", err.to_string())
    @core.UnknownVariable(_) =>
      jqx_error("eval_unknown_variable", err.to_string())
    @core.Partial(_, _, _) => jqx_error("eval_partial", err.to_string())
  }
}

///|
fn json_values_to_strings(values : Array[@core.Json]) -> Array[String] {
  let out = []
  for value in values {
    out.push(value.to_json_string())
  }
  out
}

///|
pub fn parseJson(input : String) -> @core.Json raise @core.ParseError {
  @core.parse(input)
}

///|
pub fn tryParseJson(input : String) -> Result[@core.Json, JqxError] {
  Ok(@core.parse(input)) catch {
    err => Err(parse_error_to_jqx_error(input, err))
  }
}

///|
pub fn safeParseJson(input : String) -> Result[@core.Json, JqxError] {
  tryParseJson(input)
}

///|
pub fn compile(input : String) -> @core.Filter raise @core.FilterError {
  @core.compile(input)
}

///|
pub fn parseFilter(input : String) -> @core.Filter raise @core.FilterError {
  compile(input)
}

///|
pub fn tryCompile(input : String) -> Result[@core.Filter, JqxError] {
  Ok(@core.compile(input)) catch {
    err => Err(filter_error_to_jqx_error(input, err))
  }
}

///|
pub fn tryParseFilter(input : String) -> Result[@core.Filter, JqxError] {
  tryCompile(input)
}

///|
pub fn safeCompile(input : String) -> Result[@core.Filter, JqxError] {
  tryCompile(input)
}

///|
pub fn safeParseFilter(input : String) -> Result[@core.Filter, JqxError] {
  safeCompile(input)
}

///|
pub fn execute(
  filter : @core.Filter,
  input : @core.Json,
) -> Array[@core.Json] raise @core.EvalError {
  @core.execute(filter, input)
}

///|
pub fn tryExecute(
  filter : @core.Filter,
  input : @core.Json,
) -> Result[Array[@core.Json], JqxError] {
  Ok(@core.execute(filter, input)) catch {
    err => Err(eval_error_to_jqx_error(err))
  }
}

///|
pub fn safeExecute(
  filter : @core.Filter,
  input : @core.Json,
) -> Result[Array[@core.Json], JqxError] {
  tryExecute(filter, input)
}

///|
/// Compatibility lane for precompiled filters:
/// parse input JSON, execute filter, and return JSON text outputs.
pub fn runCompiled(
  filter : @core.Filter,
  input : String,
) -> Result[Array[String], JqxError] {
  match tryParseJson(input) {
    Ok(value) =>
      match tryExecute(filter, value) {
        Ok(outputs) => Ok(json_values_to_strings(outputs))
        Err(err) => Err(err)
      }
    Err(err) => Err(err)
  }
}

///|
/// Convenience lane for precompiled filters.
pub fn runCompiledValues(
  filter : @core.Filter,
  input : String,
) -> Result[Array[@core.Json], JqxError] {
  match tryParseJson(input) {
    Ok(value) => tryExecute(filter, value)
    Err(err) => Err(err)
  }
}

///|
/// Compatibility lane:
/// returns JSON text so large numbers and repr are preserved.
pub fn executeToJsonStrings(
  filter : String,
  input : String,
) -> Result[Array[String], JqxError] {
  match tryCompile(filter) {
    Ok(compiled) => runCompiled(compiled, input)
    Err(err) => Err(err)
  }
}

///|
/// Compatibility lane alias.
pub fn run(filter : String, input : String) -> Result[Array[String], JqxError] {
  executeToJsonStrings(filter, input)
}

///|
/// Compatibility lane explicit entrypoint.
pub fn runCompat(
  filter : String,
  input : String,
) -> Result[Array[String], JqxError] {
  executeToJsonStrings(filter, input)
}

///|
/// Convenience lane:
/// returns core Json values (Number uses Double semantics internally).
pub fn runValues(
  filter : String,
  input : String,
) -> Result[Array[@core.Json], JqxError] {
  match tryCompile(filter) {
    Ok(compiled) => runCompiledValues(compiled, input)
    Err(err) => Err(err)
  }
}

///|
/// Convenience lane alias.
pub fn safeRunValues(
  filter : String,
  input : String,
) -> Result[Array[@core.Json], JqxError] {
  runValues(filter, input)
}
