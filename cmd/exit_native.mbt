///|
fn jqx_exit_internal(code : Int32) -> Unit {
  c_exit(code)
}

///|
extern "C" fn c_exit(code : Int32) = "exit"
