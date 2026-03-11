///|
/// Top-level MoonBit public API.
/// This surface may change before 1.0 while it is reshaped for MoonBit users.

///|
pub fn parse(
  input : StringView,
  max_nesting_depth? : Int = 1024,
) -> Json raise ParseError {
  let parsed = @core.parse(input, max_nesting_depth~) catch {
    err => raise parse_error_from_core(err)
  }
  from_core_value(parsed)
}

///|
pub fn compile(input : StringView) -> CompiledFilter raise FilterError {
  let filter = @core.compile(input) catch {
    err => raise filter_error_from_core(err)
  }
  { filter, }
}

///|
fn execute_compiled(
  filter : CompiledFilter,
  input : Json,
) -> Array[Json] raise EvalError {
  let values = @core.execute(filter.filter, to_core_value(input)) catch {
    err => raise eval_error_from_core(err)
  }
  values.map(from_core_value)
}

///|
pub fn valid(input : StringView) -> Bool {
  @core.valid(input)
}

///|
pub fn run(filter : StringView, input : Json) -> Array[Json] raise JqxError {
  let compiled = compile(filter) catch { err => raise Filter(err) }
  run_compiled(compiled, input) catch {
    err => raise Eval(err)
  }
}

///|
pub fn run_compiled(
  filter : CompiledFilter,
  input : Json,
) -> Array[Json] raise EvalError {
  execute_compiled(filter, input)
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
  let outputs = run_compiled(filter, parsed) catch { err => raise Eval(err) }
  json_values_to_strings(outputs)
}
