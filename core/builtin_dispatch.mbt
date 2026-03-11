///|
fn builtin_call(
  name : String,
  args : Array[Filter],
  input : Value,
  env : Map[String, Value],
) -> Array[Value] raise EvalError {
  match builtin_call_path(name, args, input, env) {
    Some(out) => return out
    None => ()
  }
  match builtin_call_string(name, args, input, env) {
    Some(out) => return out
    None => ()
  }
  match builtin_call_collection(name, args, input, env) {
    Some(out) => return out
    None => ()
  }
  match builtin_call_numeric(name, args, input, env) {
    Some(out) => return out
    None => ()
  }
  match builtin_call_stream(name, args, input, env) {
    Some(out) => return out
    None => ()
  }
  raise UnknownFunction(name)
}
