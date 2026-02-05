///|
/// Minimal JS/TS-facing API.
/// Keep this surface area small for stability.

///|
pub fn parseJson(input : String) -> @core.Json raise @core.ParseError {
  @core.parse(input)
}

///|
pub fn parseFilter(input : String) -> @core.Filter raise @core.FilterError {
  @core.parse_filter(input)
}

///|
pub fn eval(
  filter : @core.Filter,
  input : @core.Json,
) -> Array[@core.Json] raise @core.EvalError {
  @core.eval(filter, input)
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
