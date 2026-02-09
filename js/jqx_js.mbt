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
pub fn parseFilter(input : String) -> @core.Filter raise @core.FilterError {
  @core.parse_filter(input)
}

///|
pub fn tryParseFilter(input : String) -> Result[@core.Filter, String] {
  Ok(@core.parse_filter(input)) catch {
    err => Err(err.to_string())
  }
}

///|
pub fn safeParseFilter(input : String) -> Result[@core.Filter, String] {
  tryParseFilter(input)
}

///|
pub fn eval(
  filter : @core.Filter,
  input : @core.Json,
) -> Array[@core.Json] raise @core.EvalError {
  @core.eval(filter, input)
}

///|
pub fn execute(
  filter : @core.Filter,
  input : @core.Json,
) -> Array[@core.Json] raise @core.EvalError {
  eval(filter, input)
}

///|
pub fn tryEval(
  filter : @core.Filter,
  input : @core.Json,
) -> Result[Array[@core.Json], String] {
  Ok(@core.eval(filter, input)) catch {
    err => Err(err.to_string())
  }
}

///|
pub fn safeExecute(
  filter : @core.Filter,
  input : @core.Json,
) -> Result[Array[@core.Json], String] {
  tryEval(filter, input)
}

///|
pub fn evalToJsonStrings(
  filter : String,
  input : String,
) -> Result[Array[String], String] {
  try {
    let f = @core.parse_filter(filter)
    let j = @core.parse(input)
    let out = @core.eval(f, j)
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
pub fn run(filter : String, input : String) -> Result[Array[String], String] {
  evalToJsonStrings(filter, input)
}
