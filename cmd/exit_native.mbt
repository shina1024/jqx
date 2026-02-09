///|
fn jqx_exit_internal(code : Int) -> Unit {
  c_exit(code)
}

///|
extern "C" fn c_exit(code : Int) = "exit"
