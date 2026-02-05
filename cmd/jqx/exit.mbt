///|
pub fn jqx_exit(code : Int) -> Unit {
  if code != 0 {
    // Use panic to ensure non-zero exit code on all platforms.
    panic()
  }
}
