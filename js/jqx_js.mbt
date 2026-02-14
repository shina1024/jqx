///|
/// Minimal JS/TS-facing API.
/// Keep this surface area small for stability.

///|
pub fn parseJson(input : String) -> @core.Json raise @core.ParseError {
  @core.parse(input)
}

///|
pub fn tryParseJson(input : String) -> Result[@core.Json, String] {
  Ok(@core.parse(input)) catch {
    err => Err(err.to_string())
  }
}

///|
pub fn safeParseJson(input : String) -> Result[@core.Json, String] {
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
pub fn tryCompile(input : String) -> Result[@core.Filter, String] {
  Ok(@core.compile(input)) catch {
    err => Err(err.to_string())
  }
}

///|
pub fn tryParseFilter(input : String) -> Result[@core.Filter, String] {
  tryCompile(input)
}

///|
pub fn safeCompile(input : String) -> Result[@core.Filter, String] {
  tryCompile(input)
}

///|
pub fn safeParseFilter(input : String) -> Result[@core.Filter, String] {
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
) -> Result[Array[@core.Json], String] {
  Ok(@core.execute(filter, input)) catch {
    err => Err(err.to_string())
  }
}

///|
pub fn safeExecute(
  filter : @core.Filter,
  input : @core.Json,
) -> Result[Array[@core.Json], String] {
  tryExecute(filter, input)
}

///|
/// Compatibility lane:
/// returns JSON text so large numbers and repr are preserved.
pub fn executeToJsonStrings(
  filter : String,
  input : String,
) -> Result[Array[String], String] {
  try {
    let f = @core.compile(filter)
    let j = @core.parse(input)
    let out = @core.execute(f, j)
    let strings = []
    for v in out {
      strings.push(v.to_json_string())
    }
    Ok(strings)
  } catch {
    err => Err(err.to_string())
  }
}

///|
/// Compatibility lane alias.
pub fn run(filter : String, input : String) -> Result[Array[String], String] {
  executeToJsonStrings(filter, input)
}

///|
/// Compatibility lane explicit entrypoint.
pub fn runCompat(
  filter : String,
  input : String,
) -> Result[Array[String], String] {
  executeToJsonStrings(filter, input)
}

///|
/// Convenience lane:
/// returns core Json values (Number uses Double semantics internally).
pub fn runValues(
  filter : String,
  input : String,
) -> Result[Array[@core.Json], String] {
  try {
    let f = @core.compile(filter)
    let j = @core.parse(input)
    Ok(@core.execute(f, j))
  } catch {
    err => Err(err.to_string())
  }
}

///|
/// Convenience lane alias.
pub fn safeRunValues(
  filter : String,
  input : String,
) -> Result[Array[@core.Json], String] {
  runValues(filter, input)
}
