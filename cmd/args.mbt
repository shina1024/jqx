///|
struct CliArgs {
  raw : Bool
  raw_input : Bool
  no_input : Bool
  exit_status : Bool
  slurp : Bool
  module_search_paths : Array[String]
  filter : String
  input : String?
}

///|
fn parse_cli_args(args : Array[String]) -> Result[CliArgs, String] {
  if args.length() < 2 {
    return Err("missing filter")
  }
  let mut raw = false
  let mut raw_input = false
  let mut no_input = false
  let mut exit_status = false
  let mut slurp = false
  let module_search_paths = []
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
    if a == "-R" {
      raw_input = true
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
    if a == "-L" {
      idx += 1
      if idx >= args.length() {
        return Err("missing argument for -L")
      }
      module_search_paths.push(args[idx])
      idx += 1
      continue
    }
    if a.length() > 2 && a.has_prefix("-L") {
      module_search_paths.push(a.view(start_offset=2).to_string())
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
    return Ok({
      raw,
      raw_input,
      no_input,
      exit_status,
      slurp,
      module_search_paths,
      filter,
      input: None,
    })
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
  Ok({
    raw,
    raw_input,
    no_input,
    exit_status,
    slurp,
    module_search_paths,
    filter,
    input,
  })
}
