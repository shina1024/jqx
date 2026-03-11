///|
/// Top-level MoonBit public API.
/// This surface may change before 1.0 while it is reshaped for MoonBit users.

///|
pub fn parse_json(
  input : StringView,
  max_nesting_depth? : Int = 1024,
) -> Json raise JsonParseError {
  let parsed = @core.parse(input, max_nesting_depth~) catch {
    err => raise json_parse_error_from_core(err)
  }
  from_core_value(parsed)
}

///|
pub fn compile(input : StringView) -> CompiledFilter raise CompileError {
  let filter = @core.compile(input) catch {
    err => raise compile_error_from_core(err)
  }
  { filter, }
}

///|
fn CompiledFilter::execute(
  self : CompiledFilter,
  input : Json,
) -> Array[Json] raise RuntimeError {
  let values = @core.execute(self.filter, to_core_value(input)) catch {
    err => raise runtime_error_from_core(err)
  }
  values.map(from_core_value)
}

///|
pub fn is_valid_json(input : StringView) -> Bool {
  @core.valid(input)
}

///|
pub fn run(filter : StringView, input : Json) -> Array[Json] raise JqxError {
  let compiled = compile(filter) catch { err => raise Compile(err) }
  compiled.run(input) catch {
    err => raise Runtime(err)
  }
}

///|
pub fn CompiledFilter::run(
  self : CompiledFilter,
  input : Json,
) -> Array[Json] raise RuntimeError {
  self.execute(input)
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
pub fn run_json_text(
  filter : StringView,
  input : StringView,
  max_nesting_depth? : Int = 1024,
) -> Array[String] raise JqxError {
  let compiled = compile(filter) catch { err => raise Compile(err) }
  compiled.run_json_text(input, max_nesting_depth~)
}

///|
pub fn CompiledFilter::run_json_text(
  self : CompiledFilter,
  input : StringView,
  max_nesting_depth? : Int = 1024,
) -> Array[String] raise JqxError {
  let parsed = parse_json(input, max_nesting_depth~) catch {
    err => raise JsonParse(err)
  }
  let outputs = self.run(parsed) catch { err => raise Runtime(err) }
  json_values_to_strings(outputs)
}
