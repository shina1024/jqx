///|
/// Thin wrapper that forwards to the core package.
/// Prefer importing `shina1024/jqx/core` directly for stable APIs.

///|
pub fn parse(
  input : StringView,
  max_nesting_depth? : Int = 1024,
) -> @core.Json raise @core.ParseError {
  @core.parse(input, max_nesting_depth~)
}

///|
pub fn compile(input : StringView) -> @core.Filter raise @core.FilterError {
  @core.compile(input)
}

///|
pub fn parse_filter(input : StringView) -> @core.Filter raise @core.FilterError {
  compile(input)
}

///|
pub fn execute(
  filter : @core.Filter,
  input : @core.Json,
) -> Array[@core.Json] raise @core.EvalError {
  @core.execute(filter, input)
}

///|
pub fn eval(
  filter : @core.Filter,
  input : @core.Json,
) -> Array[@core.Json] raise @core.EvalError {
  execute(filter, input)
}

///|
pub fn valid(input : StringView) -> Bool {
  @core.valid(input)
}
