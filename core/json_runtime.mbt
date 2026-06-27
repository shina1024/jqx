///|
pub fn execute_json(
  filter : Filter,
  input : Json,
) -> Array[Json] raise EvalError {
  execute(filter, Value::from_json(input)) |> values_to_json
}

///|
pub fn run_compiled_values(
  filter : Filter,
  input : StringView,
  max_nesting_depth? : Int = 10000,
) -> Array[Value] raise RunError {
  let parsed = parse(input, max_nesting_depth~) catch {
    err => raise Parse(err)
  }
  execute(filter, parsed) catch {
    err => raise Eval(err)
  }
}

///|
pub fn run_json(
  filter : StringView,
  input : Json,
) -> Array[Json] raise RunError {
  let compiled = compile(filter) catch { err => raise Filter(err) }
  execute_json(compiled, input) catch {
    err => raise Eval(err)
  }
}

///|
pub fn run_values(
  filter : StringView,
  input : StringView,
  max_nesting_depth? : Int = 10000,
) -> Array[Value] raise RunError {
  let compiled = compile(filter) catch { err => raise Filter(err) }
  run_compiled_values(compiled, input, max_nesting_depth~)
}

///|
pub fn run_compiled_json_text(
  filter : Filter,
  input : StringView,
  max_nesting_depth? : Int = 10000,
) -> Array[String] raise RunError {
  values_to_json_text(run_compiled_values(filter, input, max_nesting_depth~))
}

///|
pub fn run_json_text(
  filter : StringView,
  input : StringView,
  max_nesting_depth? : Int = 10000,
) -> Array[String] raise RunError {
  let compiled = compile(filter) catch { err => raise Filter(err) }
  run_compiled_json_text(compiled, input, max_nesting_depth~)
}
