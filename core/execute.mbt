///|
/// Minimal jq evaluator (streaming outputs as Array[Json])
///
/// Supported filters:
/// - Identity: .
/// - Pipe: a | b
/// - Comma: a, b
/// - Field: .foo
/// - Index: .[n]
/// - Iter: .[]
/// - Literal JSON values

///|
pub suberror EvalError {
  TypeError(String)
  Thrown(Json)
  UnknownFunction(String)
  UnknownVariable(String)
  Partial(Array[Json], Json, String)
} derive(Eq)

///|
pub impl Show for EvalError with output(self, logger) {
  match self {
    TypeError(msg) => logger.write_string(msg)
    Thrown(value) =>
      match value {
        String(s) => logger.write_string(s)
        _ => logger.write_string(value.to_json_string())
      }
    UnknownFunction(name) => logger.write_string("Unknown function: " + name)
    UnknownVariable(name) => logger.write_string("Unknown variable: $" + name)
    Partial(_, _, message) => logger.write_string(message)
  }
}

///|
fn eval_error_to_message(err : EvalError) -> String {
  match err {
    Partial(_, _, message) => message
    _ => err.to_string()
  }
}

///|
fn eval_error_prefix(err : EvalError) -> Array[Json] {
  match err {
    Partial(values, _, _) => values.copy()
    _ => []
  }
}

///|
fn eval_error_to_catch_input(err : EvalError) -> Json {
  match err {
    Partial(_, catch_input, _) => catch_input
    Thrown(value) => value
    _ => Json::string(eval_error_to_message(err))
  }
}

///|
pub fn eval_error_outputs(err : EvalError) -> Array[Json] {
  eval_error_prefix(err)
}

///|
pub fn eval_error_message(err : EvalError) -> String {
  eval_error_to_message(err)
}

///|
fn append_json_values(out : Array[Json], values : Array[Json]) -> Unit {
  for v in values {
    out.push(v)
  }
}

///|
fn[T] raise_with_prefix(
  prefix : Array[Json],
  err : EvalError,
) -> T raise EvalError {
  if prefix.length() == 0 {
    raise err
  }
  let merged = prefix.copy()
  append_json_values(merged, eval_error_prefix(err))
  raise Partial(
    merged,
    eval_error_to_catch_input(err),
    eval_error_to_message(err),
  )
}

///|
fn eval_error_without_prefix(err : EvalError) -> EvalError {
  match err {
    Partial(_, catch_input, message) => Partial([], catch_input, message)
    _ => err
  }
}

///|
fn append_recurse_values(input : Json, out : Array[Json]) -> Unit {
  out.push(input)
  match input {
    Object(o) =>
      for kv in object_entries_sorted(o) {
        append_recurse_values(kv.1, out)
      }
    Array(a) =>
      for v in a {
        append_recurse_values(v, out)
      }
    _ => ()
  }
}

///|
fn is_ascii_ws(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n'
}

///|
fn trim_ascii_ws(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  for {
    if start < end && is_ascii_ws(s.unsafe_get(start).to_int().unsafe_to_char()) {
      start += 1
    } else {
      break
    }
  }
  for {
    if end > start &&
      is_ascii_ws(s.unsafe_get(end - 1).to_int().unsafe_to_char()) {
      end -= 1
    } else {
      break
    }
  }
  s.view(start_offset=start, end_offset=end).to_string()
}

///|
fn fromjson_fallback_token(s : String) -> Json? {
  let t = ascii_downcase_string(trim_ascii_ws(s))
  match t {
    "nan" | "+nan" | "-nan" =>
      Some(Json::number(@double.infinity - @double.infinity))
    "inf" | "+inf" | "infinity" | "+infinity" =>
      Some(Json::number(@double.infinity))
    "-inf" | "-infinity" => Some(Json::number(@double.neg_infinity))
    _ => None
  }
}

///|
fn parse_fromjson_string(s : String) -> Json raise EvalError {
  try parse(s) catch {
    err =>
      match fromjson_fallback_token(s) {
        Some(v) => v
        None =>
          raise TypeError(err.to_string() + " (while parsing '" + s + "')")
      }
  } noraise {
    j => j
  }
}

///|
pub fn execute(filter : Filter, input : Json) -> Array[Json] raise EvalError {
  let env = Map::new()
  execute_with_env(filter, input, env)
}

///|
pub fn execute_for_cli(filter : Filter, input : Json) -> (Array[Json], String?) {
  try (execute(filter, input), None) catch {
    err => (eval_error_outputs(err), Some(eval_error_message(err)))
  } noraise {
    result => result
  }
}

///|
fn execute_with_env(
  filter : Filter,
  input : Json,
  env : Map[String, Json],
) -> Array[Json] raise EvalError {
  match filter {
    Identity => [input]
    Literal(v) => [v]
    Field(name) =>
      match input {
        Object(o) =>
          match o.get(name) {
            Some(v) => [v]
            None => [Json::null()]
          }
        JNull => [Json::null()]
        _ =>
          raise TypeError(
            "Cannot index " +
            json_type_name(input) +
            " with string \"" +
            name +
            "\"",
          )
      }
    FieldOpt(name) =>
      match input {
        Object(o) =>
          match o.get(name) {
            Some(v) => [v]
            None => [Json::null()]
          }
        JNull => [Json::null()]
        _ => []
      }
    Index(i) =>
      match input {
        Array(a) => {
          let idx = if i < 0 { a.length() + i } else { i }
          if idx >= 0 && idx < a.length() {
            [a[idx]]
          } else {
            [Json::null()]
          }
        }
        JNull => [Json::null()]
        _ =>
          raise TypeError(
            "Cannot index " + json_type_name(input) + " with number",
          )
      }
    IndexOpt(i) =>
      match input {
        Array(a) => {
          let idx = if i < 0 { a.length() + i } else { i }
          if idx >= 0 && idx < a.length() {
            [a[idx]]
          } else {
            [Json::null()]
          }
        }
        JNull => [Json::null()]
        _ => []
      }
    Slice(start, end) => execute_slice(start, end, input, optional=false)
    SliceOpt(start, end) => execute_slice(start, end, input, optional=true)
    Iter =>
      match input {
        Array(a) => a
        Object(o) => {
          let out = []
          for kv in object_entries_sorted(o) {
            out.push(kv.1)
          }
          out
        }
        _ =>
          raise TypeError("Cannot iterate over " + json_type_with_value(input))
      }
    IterOpt =>
      match input {
        Array(a) => a
        Object(o) => {
          let out = []
          for kv in object_entries_sorted(o) {
            out.push(kv.1)
          }
          out
        }
        _ => []
      }
    Recurse => {
      let out = []
      append_recurse_values(input, out)
      out
    }
    Var(name) =>
      match env.get(name) {
        Some(v) => [v]
        None =>
          if name == "ENV" {
            [Json::object(Map::new())]
          } else if name == "__loc__" {
            [
              Json::object_from_entries([
                ("file", Json::string("<top-level>")),
                ("line", Json::number(1.0)),
              ]),
            ]
          } else {
            raise UnknownVariable(name)
          }
      }
    As(value, name, body) => {
      let out = []
      let values = execute_with_env(value, input, env)
      for v in values {
        let next_env = env.copy()
        next_env[name] = v
        for v2 in execute_with_env(body, input, next_env) {
          out.push(v2)
        }
      }
      out
    }
    Try(inner) =>
      try execute_with_env(inner, input, env) catch {
        err =>
          match err {
            Partial(values, _, _) => values
            _ => []
          }
      } noraise {
        values => values
      }
    TryCatch(inner, handler) =>
      try execute_with_env(inner, input, env) catch {
        err => {
          let prefix = eval_error_prefix(err)
          let handled = try
            execute_with_env(handler, eval_error_to_catch_input(err), env)
          catch {
            err2 => raise_with_prefix(prefix, err2)
          } noraise {
            values => values
          }
          append_json_values(prefix, handled)
          prefix
        }
      } noraise {
        values => values
      }
    Reduce(source, name, init, update) => {
      let mut accs = execute_with_env(init, input, env)
      let items = execute_with_env(source, input, env)
      for item in items {
        let next_env = env.copy()
        next_env[name] = item
        let next_accs = []
        for acc in accs {
          for v in execute_with_env(update, acc, next_env) {
            next_accs.push(v)
          }
        }
        accs = next_accs
      }
      accs
    }
    Foreach(source, name, init, update, extract) => {
      let items = execute_with_env(source, input, env)
      let accs = execute_with_env(init, input, env)
      let out = []
      for seed in accs {
        let mut states = [seed]
        for item in items {
          let next_env = env.copy()
          next_env[name] = item
          let next_states = []
          for acc in states {
            for v in execute_with_env(update, acc, next_env) {
              next_states.push(v)
            }
          }
          for acc in next_states {
            for v in execute_with_env(extract, acc, next_env) {
              out.push(v)
            }
          }
          states = next_states
        }
      }
      out
    }
    Pipe(left, right) => {
      let out = []
      let left_values = try execute_with_env(left, input, env) catch {
        err => raise_with_prefix(out, err)
      } noraise {
        values => values
      }
      for v in left_values {
        let right_values = try execute_with_env(right, v, env) catch {
          err => raise_with_prefix(out, err)
        } noraise {
          values => values
        }
        append_json_values(out, right_values)
      }
      out
    }
    Comma(left, right) => {
      let out = []
      let left_values = try execute_with_env(left, input, env) catch {
        err => raise_with_prefix(out, err)
      } noraise {
        values => values
      }
      append_json_values(out, left_values)
      let right_values = try execute_with_env(right, input, env) catch {
        err => raise_with_prefix(out, err)
      } noraise {
        values => values
      }
      append_json_values(out, right_values)
      out
    }
    Array(items) => {
      let out = []
      for f in items {
        let values = try execute_with_env(f, input, env) catch {
          err => raise eval_error_without_prefix(err)
        } noraise {
          values => values
        }
        for v in values {
          out.push(v)
        }
      }
      [Json::array(out)]
    }
    Object(items) => {
      let mut partials = [(Map::new(), [])]
      for kv in items {
        let key = kv.0
        let f = kv.1
        let vals = try execute_with_env(f, input, env) catch {
          err => raise eval_error_without_prefix(err)
        } noraise {
          values => values
        }
        if vals.length() == 0 {
          return []
        }
        let next = []
        for partial in partials {
          let base_map = partial.0
          let base_order = partial.1
          for i in 0..<vals.length() {
            let v = vals[i]
            let m = base_map.copy()
            let order = base_order.copy()
            if !m.contains(key) {
              order.push(key)
            }
            m[key] = v
            next.push((m, order))
          }
        }
        partials = next
      }
      let out = []
      for partial in partials {
        out.push(Json::object_with_order(partial.0, partial.1))
      }
      out
    }
    Builtin(name) => builtin_call0(name, input)
    Call(name, args) => builtin_call(name, args, input, env)
    Eq(left, right) => {
      let l = execute_with_env(left, input, env)
      let r = execute_with_env(right, input, env)
      let out = []
      for j in 0..<r.length() {
        let b = r[j]
        for i in 0..<l.length() {
          let a = l[i]
          out.push(Json::boolean(a == b))
        }
      }
      out
    }
    Neq(left, right) => {
      let l = execute_with_env(left, input, env)
      let r = execute_with_env(right, input, env)
      let out = []
      for j in 0..<r.length() {
        let b = r[j]
        for i in 0..<l.length() {
          let a = l[i]
          out.push(Json::boolean(a != b))
        }
      }
      out
    }
    Lt(left, right) => execute_compare("<", left, right, input, env)
    Lte(left, right) => execute_compare("<=", left, right, input, env)
    Gt(left, right) => execute_compare(">", left, right, input, env)
    Gte(left, right) => execute_compare(">=", left, right, input, env)
    And(left, right) => {
      let out = []
      for l in execute_with_env(left, input, env) {
        if is_truthy(l) {
          for r in execute_with_env(right, input, env) {
            out.push(Json::boolean(is_truthy(r)))
          }
        } else {
          out.push(Json::boolean(false))
        }
      }
      out
    }
    Or(left, right) => {
      let out = []
      for l in execute_with_env(left, input, env) {
        if is_truthy(l) {
          out.push(Json::boolean(true))
        } else {
          for r in execute_with_env(right, input, env) {
            out.push(Json::boolean(is_truthy(r)))
          }
        }
      }
      out
    }
    Not(inner) => {
      let out = []
      for v in execute_with_env(inner, input, env) {
        out.push(Json::boolean(!is_truthy(v)))
      }
      out
    }
    Add(left, right) => execute_add(left, right, input, env)
    Sub(left, right) => execute_arith("-", left, right, input, env)
    Mul(left, right) => execute_arith("*", left, right, input, env)
    Div(left, right) => execute_arith("/", left, right, input, env)
    Mod(left, right) => execute_arith("%", left, right, input, env)
    IfElse(cond, then_branch, else_branch) => {
      let out = []
      for cond_value in execute_with_env(cond, input, env) {
        if is_truthy(cond_value) {
          for v in execute_with_env(then_branch, input, env) {
            out.push(v)
          }
        } else {
          for v in execute_with_env(else_branch, input, env) {
            out.push(v)
          }
        }
      }
      out
    }
    Fallback(left, right) => {
      let l = execute_with_env(left, input, env)
      let truthy_values = []
      for v in l {
        if is_truthy(v) {
          truthy_values.push(v)
        }
      }
      if truthy_values.length() > 0 {
        truthy_values
      } else {
        execute_with_env(right, input, env)
      }
    }
    Empty => []
  }
}

///|
fn execute_with_env_prefix(
  filter : Filter,
  input : Json,
  env : Map[String, Json],
  max_count : Int,
) -> Array[Json] raise EvalError {
  if max_count <= 0 {
    return []
  }

  let out = []
  fn collect(current : Filter, value : Json) -> Unit raise EvalError {
    if out.length() >= max_count {
      return
    }
    match current {
      Comma(left, right) => {
        collect(left, value)
        if out.length() < max_count {
          collect(right, value)
        }
      }
      Pipe(left, right) => {
        let left_values = execute_with_env(left, value, env)
        for next in left_values {
          if out.length() >= max_count {
            break
          }
          collect(right, next)
        }
      }
      _ => {
        let values = execute_with_env(current, value, env)
        for v in values {
          if out.length() >= max_count {
            break
          }
          out.push(v)
        }
      }
    }
  }

  collect(filter, input)
  out
}

///|
fn join_values(a : Array[Json], sep : Json) -> Json raise EvalError {
  let mut acc = Json::string("")
  for i in 0..<a.length() {
    if i > 0 {
      acc = json_add_pair(acc, sep)
    }
    acc = json_add_pair(acc, join_item(a[i]))
  }
  acc
}

///|
fn split_string(s : String, sep : String) -> Array[Json] {
  if s.length() == 0 {
    return []
  }
  if sep.length() == 0 {
    let out = []
    for ch in s {
      out.push(Json::string(char_to_string(ch)))
    }
    return out
  }
  let out = []
  let mut start = 0
  let sep_len = sep.length()
  for {
    let rest = s.view(start_offset=start)
    match rest.find(sep) {
      Some(i) => {
        out.push(
          Json::string(
            s.view(start_offset=start, end_offset=start + i).to_string(),
          ),
        )
        start = start + i + sep_len
        continue
      }
      None => {
        out.push(Json::string(s.view(start_offset=start).to_string()))
        return out
      }
    }
  }
}

///|
priv struct SplitRegexAtom {
  ch : Char
  min_repeat : Int
  max_repeat : Int
}

///|
fn string_to_chars(s : String) -> Array[Char] {
  let out = []
  for ch in s {
    out.push(ch)
  }
  out
}

///|
fn chars_slice_to_string(
  chars : Array[Char],
  start : Int,
  end_ : Int,
) -> String {
  let buf = StringBuilder::new()
  for i in start..<end_ {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
fn ascii_fold_char(ch : Char) -> Char {
  let code = ch.to_int()
  if code >= 'A'.to_int() && code <= 'Z'.to_int() {
    (code + 32).unsafe_to_char()
  } else {
    ch
  }
}

///|
fn split_regex_char_matches(
  input_char : Char,
  pattern_char : Char,
  ignore_case : Bool,
) -> Bool {
  if ignore_case {
    ascii_fold_char(input_char) == ascii_fold_char(pattern_char)
  } else {
    input_char == pattern_char
  }
}

///|
fn split_regex_flag_enabled(flags : String, flag : Char) -> Bool {
  for ch in flags {
    if ch == flag {
      return true
    }
  }
  false
}

///|
fn parse_split_regex_atoms(pattern : String) -> Array[SplitRegexAtom] {
  let chars = string_to_chars(pattern)
  let out = []
  let mut i = 0
  let n = chars.length()
  for {
    if i >= n {
      return out
    }
    let mut ch = chars[i]
    if ch == '\\' && i + 1 < n {
      i = i + 1
      ch = chars[i]
    }

    let mut min_repeat = 1
    let mut max_repeat = 1
    if i + 1 < n {
      match chars[i + 1] {
        '?' => {
          min_repeat = 0
          max_repeat = 1
          i = i + 1
        }
        '*' => {
          min_repeat = 0
          max_repeat = -1
          i = i + 1
        }
        '+' => {
          min_repeat = 1
          max_repeat = -1
          i = i + 1
        }
        _ => ()
      }
    }
    out.push(SplitRegexAtom::{ ch, min_repeat, max_repeat })
    i = i + 1
    continue
  }
}

///|
fn split_regex_match_end(
  chars : Array[Char],
  pos : Int,
  atoms : Array[SplitRegexAtom],
  atom_index : Int,
  ignore_case : Bool,
) -> Int? {
  if atom_index >= atoms.length() {
    return Some(pos)
  }

  let atom = atoms[atom_index]
  let len = chars.length()
  let mut max_repeat = 0
  let mut cursor = pos
  for {
    if cursor < len &&
      (atom.max_repeat < 0 || max_repeat < atom.max_repeat) &&
      split_regex_char_matches(chars[cursor], atom.ch, ignore_case) {
      max_repeat = max_repeat + 1
      cursor = cursor + 1
      continue
    }
    break
  }

  if max_repeat < atom.min_repeat {
    return None
  }

  let mut repeat = max_repeat
  for {
    if repeat >= atom.min_repeat {
      let next_pos = pos + repeat
      match
        split_regex_match_end(
          chars,
          next_pos,
          atoms,
          atom_index + 1,
          ignore_case,
        ) {
        Some(end_pos) => return Some(end_pos)
        None => ()
      }
      repeat = repeat - 1
      continue
    }
    break
  }
  None
}

///|
fn split_regex_find_next(
  chars : Array[Char],
  start : Int,
  atoms : Array[SplitRegexAtom],
  ignore_case : Bool,
  skip_empty_match : Bool,
) -> (Int, Int)? {
  let len = chars.length()
  let mut pos = start
  for {
    if pos > len {
      return None
    }
    match split_regex_match_end(chars, pos, atoms, 0, ignore_case) {
      Some(end_pos) =>
        if skip_empty_match && end_pos == pos {
          pos = pos + 1
          continue
        } else {
          return Some((pos, end_pos))
        }
      None => {
        pos = pos + 1
        continue
      }
    }
  }
}

///|
fn split_string_regex_tokens(
  s : String,
  pattern : String,
  flags : String,
) -> Array[Json] {
  let chars = string_to_chars(s)
  let atoms = parse_split_regex_atoms(pattern)
  let ignore_case = split_regex_flag_enabled(flags, 'i')
  let skip_empty_match = split_regex_flag_enabled(flags, 'n')
  let len = chars.length()
  let out = []
  let mut token_start = 0
  let mut search_start = 0

  for {
    match
      split_regex_find_next(
        chars, search_start, atoms, ignore_case, skip_empty_match,
      ) {
      Some((match_start, match_end)) => {
        out.push(
          Json::string(chars_slice_to_string(chars, token_start, match_start)),
        )
        token_start = match_end
        if match_end > search_start {
          search_start = match_end
        } else if match_start < len {
          search_start = match_start + 1
        } else {
          out.push(Json::string(chars_slice_to_string(chars, token_start, len)))
          return out
        }
        continue
      }
      None => {
        out.push(Json::string(chars_slice_to_string(chars, token_start, len)))
        return out
      }
    }
  }
}

///|
fn regex_has_match(s : String, pattern : String, flags : String) -> Bool {
  let chars = string_to_chars(s)
  let atoms = parse_split_regex_atoms(pattern)
  let ignore_case = split_regex_flag_enabled(flags, 'i')
  let skip_empty_match = split_regex_flag_enabled(flags, 'n')
  match split_regex_find_next(chars, 0, atoms, ignore_case, skip_empty_match) {
    Some(_) => true
    None => false
  }
}

///|
fn regex_scan_strings(
  s : String,
  pattern : String,
  flags : String,
) -> Array[Json] {
  let chars = string_to_chars(s)
  let atoms = parse_split_regex_atoms(pattern)
  let ignore_case = split_regex_flag_enabled(flags, 'i')
  let skip_empty_match = split_regex_flag_enabled(flags, 'n')
  let len = chars.length()
  let out = []
  let mut search_start = 0
  for {
    match
      split_regex_find_next(
        chars, search_start, atoms, ignore_case, skip_empty_match,
      ) {
      Some((match_start, match_end)) => {
        out.push(
          Json::string(chars_slice_to_string(chars, match_start, match_end)),
        )
        if match_end > search_start {
          search_start = match_end
        } else if match_start < len {
          search_start = match_start + 1
        } else {
          return out
        }
        continue
      }
      None => return out
    }
  }
}

///|
fn char_to_string(ch : Char) -> String {
  let buf = StringBuilder::new()
  buf.write_char(ch)
  buf.to_string()
}

///|
fn explode_string(s : String) -> Array[Json] {
  let out = []
  for ch in s {
    out.push(Json::number(ch.to_int().to_double()))
  }
  out
}

///|
fn implode_array(a : Array[Json]) -> String raise EvalError {
  let buf = StringBuilder::new()
  for v in a {
    match v {
      Number(n, _) =>
        if n != n || n == @double.infinity || n == @double.neg_infinity {
          raise TypeError(
            json_type_with_value(v) +
            " can't be imploded, unicode codepoint needs to be numeric",
          )
        } else {
          let code = n.to_int()
          let ch = codepoint_or_replacement(code)
          buf.write_char(ch)
        }
      _ =>
        raise TypeError(
          json_type_with_value(v) +
          " can't be imploded, unicode codepoint needs to be numeric",
        )
    }
  }
  buf.to_string()
}

///|
fn codepoint_or_replacement(code : Int) -> Char {
  if code < 0 || code > 0x10FFFF || (code >= 0xD800 && code <= 0xDFFF) {
    '\u{fffd}'
  } else {
    code.unsafe_to_char()
  }
}

///|
fn ascii_upcase_string(s : String) -> String {
  let buf = StringBuilder::new()
  for ch in s {
    let code = ch.to_int()
    if code >= 'a'.to_int() && code <= 'z'.to_int() {
      buf.write_char((code - 32).unsafe_to_char())
    } else {
      buf.write_char(ch)
    }
  }
  buf.to_string()
}

///|
fn ascii_downcase_string(s : String) -> String {
  let buf = StringBuilder::new()
  for ch in s {
    let code = ch.to_int()
    if code >= 'A'.to_int() && code <= 'Z'.to_int() {
      buf.write_char((code + 32).unsafe_to_char())
    } else {
      buf.write_char(ch)
    }
  }
  buf.to_string()
}

///|
fn join_item(v : Json) -> Json {
  match v {
    String(_) => v
    Number(n, repr) => Json::string(Json::number(n, repr?).to_json_string())
    JTrue => Json::string("true")
    JFalse => Json::string("false")
    JNull => Json::string("")
    _ => v
  }
}

///|
fn clamp_slice_index(i : Int, len : Int) -> Int {
  if i < 0 {
    0
  } else if i > len {
    len
  } else {
    i
  }
}

///|
fn normalize_slice_index(i : Int?, len : Int, default : Int) -> Int {
  match i {
    Some(v) => {
      let idx = if v < 0 { len + v } else { v }
      clamp_slice_index(idx, len)
    }
    None => default
  }
}

///|
fn execute_slice_array(
  a : Array[Json],
  start : Int?,
  end : Int?,
) -> Array[Json] {
  let len = a.length()
  let lo = normalize_slice_index(start, len, 0)
  let hi = normalize_slice_index(end, len, len)
  if hi <= lo {
    []
  } else {
    let out = []
    for i in lo..<hi {
      out.push(a[i])
    }
    out
  }
}

///|
fn set_slice_array(
  a : Array[Json],
  start : Int?,
  end : Int?,
  replacement : Array[Json],
) -> Array[Json] {
  let len = a.length()
  let lo = normalize_slice_index(start, len, 0)
  let hi0 = normalize_slice_index(end, len, len)
  let hi = if hi0 < lo { lo } else { hi0 }
  let out = []
  for i in 0..<lo {
    out.push(a[i])
  }
  for v in replacement {
    out.push(v)
  }
  for i in hi..<len {
    out.push(a[i])
  }
  out
}

///|
fn set_slice_on_input(
  input : Json,
  start : Int?,
  end : Int?,
  value : Json,
) -> Json raise EvalError {
  match input {
    Array(a) => {
      let replacement = match value {
        Array(v) => v
        _ =>
          raise TypeError(
            "A slice of an array can only be assigned another array",
          )
      }
      Json::array(set_slice_array(a, start, end, replacement))
    }
    JNull => {
      let replacement = match value {
        Array(v) => v
        _ =>
          raise TypeError(
            "A slice of an array can only be assigned another array",
          )
      }
      Json::array(set_slice_array([], start, end, replacement))
    }
    String(_) => raise TypeError("Cannot update string slices")
    _ => index_type_error(input, Json::object(Map::new()))
  }
}

///|
fn execute_slice_string(s : String, start : Int?, end : Int?) -> String {
  let len = s.length()
  let lo = normalize_slice_index(start, len, 0)
  let hi = normalize_slice_index(end, len, len)
  if hi <= lo {
    ""
  } else {
    s.view(start_offset=lo, end_offset=hi).to_string()
  }
}

///|
fn execute_slice(
  start : Int?,
  end : Int?,
  input : Json,
  optional~ : Bool,
) -> Array[Json] raise EvalError {
  match input {
    Array(a) => [Json::array(execute_slice_array(a, start, end))]
    String(s) => [Json::string(execute_slice_string(s, start, end))]
    JNull => [Json::null()]
    _ =>
      if optional {
        []
      } else {
        raise TypeError(
          "Cannot index " + json_type_name(input) + " with object",
        )
      }
  }
}
