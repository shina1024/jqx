///|
pub struct CliArgs {
  raw : Bool
  no_input : Bool
  exit_status : Bool
  slurp : Bool
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
  let mut exit_status = false
  let mut slurp = false
  let mut idx = 1
  while idx < args.length() {
    let a = args[idx]
    if a == "--" {
      idx += 1
      break
    }
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
    if a == "-e" {
      exit_status = true
      idx += 1
      continue
    }
    if a == "-s" {
      slurp = true
      idx += 1
      continue
    }
    if a == "-c" {
      idx += 1
      continue
    }
    if a.has_prefix("-") {
      return Err("unknown option: " + a)
    }
    break
  }
  if idx >= args.length() {
    return Err("missing filter")
  }
  let filter = args[idx]
  idx += 1
  if no_input {
    if idx < args.length() {
      return Err("input is not allowed with -n")
    }
    return Ok({ raw, no_input, exit_status, slurp, filter, input: None })
  }
  let input = if idx < args.length() {
    let value = args[idx]
    idx += 1
    if idx < args.length() {
      return Err("too many arguments")
    }
    Some(value)
  } else {
    None
  }
  Ok({ raw, no_input, exit_status, slurp, filter, input })
}
