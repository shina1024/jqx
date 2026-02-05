///|
pub struct CliArgs {
  raw : Bool
  no_input : Bool
  filter : String
  input : String?
}

///|
pub fn parse_cli_args(args : Array[String]) -> Result[CliArgs, String] {
  if args.length() < 2 {
    return Err("missing filter")
  }
  let mut raw = false
  let mut no_input = false
  let mut idx = 1
  while idx < args.length() {
    let a = args[idx]
    if a == "-r" {
      raw = true
      idx += 1
      continue
    }
    if a == "-n" {
      no_input = true
      idx += 1
      continue
    }
    if a == "-c" {
      idx += 1
      continue
    }
    break
  }
  if idx >= args.length() {
    return Err("missing filter")
  }
  let filter = args[idx]
  idx += 1
  let input = if no_input {
    None
  } else if idx < args.length() {
    Some(args[idx])
  } else {
    None
  }
  Ok({ raw, no_input, filter, input })
}
