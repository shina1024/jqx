///|
priv struct ModuleFileSource {
  source : String
  directory : String
}

///|
fn module_path_is_separator(ch : Char) -> Bool {
  ch == '/' || ch == '\\'
}

///|
fn module_path_is_drive_letter(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
}

///|
fn module_path_is_absolute(path : String) -> Bool {
  if path.length() == 0 {
    return false
  }
  let first = path.unsafe_get(0).to_int().unsafe_to_char()
  if module_path_is_separator(first) {
    return true
  }
  if path.length() >= 2 &&
    module_path_is_drive_letter(first) &&
    path.unsafe_get(1).to_int().unsafe_to_char() == ':' {
    return true
  }
  false
}

///|
fn module_path_last_separator(path : String) -> Int {
  let mut out = -1
  for i in 0..<path.length() {
    let ch = path.unsafe_get(i).to_int().unsafe_to_char()
    if module_path_is_separator(ch) {
      out = i
    }
  }
  out
}

///|
fn module_path_basename(path : String) -> String {
  let idx = module_path_last_separator(path)
  if idx < 0 {
    path
  } else if idx + 1 >= path.length() {
    ""
  } else {
    path.view(start_offset=idx + 1).to_owned()
  }
}

///|
fn module_path_parent(path : String) -> String {
  let idx = module_path_last_separator(path)
  if idx < 0 {
    "."
  } else if idx == 0 {
    path.view(start_offset=0, end_offset=1).to_owned()
  } else {
    path.view(start_offset=0, end_offset=idx).to_owned()
  }
}

///|
fn module_join_path(base : String, rel : String) -> String {
  if base.length() == 0 || base == "." {
    return rel
  }
  let last = base.unsafe_get(base.length() - 1).to_int().unsafe_to_char()
  if module_path_is_separator(last) {
    base + rel
  } else {
    base + "/" + rel
  }
}

///|
fn append_module_candidate_once(out : Array[String], path : String) -> Unit {
  if !out.contains(path) {
    out.push(path)
  }
}

///|
fn module_candidate_relative_paths(module_name : String) -> Array[String] {
  let out = []
  append_module_candidate_once(out, module_name)
  let has_jq_suffix = module_name.has_suffix(".jq")
  if !has_jq_suffix {
    append_module_candidate_once(out, module_name + ".jq")
    let base = module_path_basename(module_name)
    if base.length() > 0 {
      append_module_candidate_once(out, module_name + "/" + base + ".jq")
    }
  }
  out
}

///|
fn module_candidate_paths(
  module_name : String,
  search_dirs : Array[String],
) -> Array[String] {
  let out = []
  let rel_paths = module_candidate_relative_paths(module_name)
  if module_path_is_absolute(module_name) {
    for rel in rel_paths {
      append_module_candidate_once(out, rel)
    }
    return out
  }
  for dir in search_dirs {
    for rel in rel_paths {
      append_module_candidate_once(out, module_join_path(dir, rel))
    }
  }
  out
}

///|
fn load_module_source_from_filesystem(
  module_name : String,
  search_dirs : Array[String],
) -> ModuleFileSource? {
  let candidates = module_candidate_paths(module_name, search_dirs)
  for path in candidates {
    match module_source_read_file(path) {
      Some(source) =>
        return Some({ source, directory: module_path_parent(path) })
      None => ()
    }
  }
  None
}
