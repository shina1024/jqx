///|
extern "c" fn exit_native(code : Int) -> Unit = "exit"

///|
fn exit_internal(code : Int) -> Unit {
  exit_native(code)
}
