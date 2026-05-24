///|
fn dispatch_builtin_call(
  runtime : RuntimeContext,
  name : String,
  args : Array[Filter],
  input : Value,
  env : Map[String, Value],
) -> Array[Value] raise EvalError {
  match dispatch_path_builtin(runtime, name, args, input, env) {
    Some(out) => return out
    None => ()
  }
  match dispatch_string_builtin(runtime, name, args, input, env) {
    Some(out) => return out
    None => ()
  }
  match dispatch_collection_builtin(runtime, name, args, input, env) {
    Some(out) => return out
    None => ()
  }
  match dispatch_numeric_builtin(runtime, name, args, input, env) {
    Some(out) => return out
    None => ()
  }
  match dispatch_stream_builtin(runtime, name, args, input, env) {
    Some(out) => return out
    None => ()
  }
  raise UnknownFunction(name)
}
