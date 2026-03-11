///|
/// Top-level MoonBit public API.
/// This surface may change before 1.0 while it is reshaped for MoonBit users.

///|
pub fn parse(
  input : StringView,
  max_nesting_depth? : Int = 1024,
) -> Json raise ParseError {
  from_core_value(@core.parse(input, max_nesting_depth~))
}

///|
pub fn compile(input : StringView) -> CompiledFilter raise FilterError {
  { filter: @core.compile(input) }
}

///|
pub fn parse_filter(input : StringView) -> CompiledFilter raise FilterError {
  compile(input)
}

///|
pub fn execute(
  filter : CompiledFilter,
  input : Json,
) -> Array[Json] raise EvalError {
  @core.execute(filter.filter, to_core_value(input)).map(from_core_value)
}

///|
pub fn eval(
  filter : CompiledFilter,
  input : Json,
) -> Array[Json] raise EvalError {
  execute(filter, input)
}

///|
pub fn valid(input : StringView) -> Bool {
  @core.valid(input)
}

///|
pub fn run(filter : StringView, input : Json) -> Array[Json] raise JqxError {
  let compiled = compile(filter) catch { err => raise Filter(err) }
  execute(compiled, input) catch {
    err => raise Eval(err)
  }
}

///|
pub fn run_compiled(
  filter : CompiledFilter,
  input : Json,
) -> Array[Json] raise EvalError {
  execute(filter, input)
}

///|
fn json_values_to_strings(values : Array[Json]) -> Array[String] {
  let out = []
  for value in values {
    out.push(value.stringify())
  }
  out
}

///|
pub fn run_text(
  filter : StringView,
  input : StringView,
  max_nesting_depth? : Int = 1024,
) -> Array[String] raise JqxError {
  let compiled = compile(filter) catch { err => raise Filter(err) }
  run_compiled_text(compiled, input, max_nesting_depth~)
}

///|
pub fn run_compiled_text(
  filter : CompiledFilter,
  input : StringView,
  max_nesting_depth? : Int = 1024,
) -> Array[String] raise JqxError {
  let parsed = parse(input, max_nesting_depth~) catch {
    err => raise Parse(err)
  }
  let outputs = execute(filter, parsed) catch { err => raise Eval(err) }
  json_values_to_strings(outputs)
}
