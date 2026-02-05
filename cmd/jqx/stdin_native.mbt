///|
fn read_stdin_all_internal() -> String {
  let buf = StringBuilder::new()
  loop getchar() {
    -1 => buf.to_string()
    c => {
      buf.write_char(c.unsafe_to_char())
      continue getchar()
    }
  }
}

///|
extern "c" fn getchar() -> Int = "getchar"
