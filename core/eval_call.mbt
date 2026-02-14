///|
fn eval_call(
  name : String,
  args : Array[Filter],
  input : Json,
  env : Map[String, Json],
) -> Array[Json] raise EvalError {
  match eval_call_path_builtin(name, args, input, env) {
    Some(out) => return out
    None => ()
  }
  match eval_call_string_builtin(name, args, input, env) {
    Some(out) => return out
    None => ()
  }
  match eval_call_collection_builtin(name, args, input, env) {
    Some(out) => return out
    None => ()
  }
  match eval_call_numeric_builtin(name, args, input, env) {
    Some(out) => return out
    None => ()
  }
  match eval_call_stream_builtin(name, args, input, env) {
    Some(out) => return out
    None => ()
  }
  raise UnknownFunction(name)
}
