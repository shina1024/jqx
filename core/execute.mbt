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
  BreakSignal(String, Array[Json])
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
    BreakSignal(name, _) => logger.write_string("break $" + name)
    Partial(_, _, message) => logger.write_string(message)
  }
}

///|
fn eval_error_to_message(err : EvalError) -> String {
  match err {
    BreakSignal(name, _) => "break $" + name
    Partial(_, _, message) => message
    _ => err.to_string()
  }
}

///|
fn eval_error_prefix(err : EvalError) -> Array[Json] {
  match err {
    BreakSignal(_, values) => values.copy()
    Partial(values, _, _) => values.copy()
    _ => []
  }
}

///|
fn eval_error_to_catch_input(err : EvalError) -> Json {
  match err {
    BreakSignal(name, _) => Json::string("break $" + name)
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
  match err {
    BreakSignal(name, values) => {
      let merged = prefix.copy()
      append_json_values(merged, values)
      raise BreakSignal(name, merged)
    }
    _ => ()
  }
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
    BreakSignal(name, _) => BreakSignal(name, [])
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
    Label(name, body) =>
      try execute_with_env(body, input, env) catch {
        err =>
          match err {
            BreakSignal(target, values) =>
              if target == name {
                values
              } else {
                raise err
              }
            _ => raise err
          }
      } noraise {
        values => values
      }
    Break(name) => raise BreakSignal(name, [])
    Try(inner) =>
      try execute_with_env(inner, input, env) catch {
        err =>
          match err {
            BreakSignal(_, _) => raise err
            Partial(values, _, _) => values
            _ => []
          }
      } noraise {
        values => values
      }
    TryCatch(inner, handler) =>
      try execute_with_env(inner, input, env) catch {
        err =>
          match err {
            BreakSignal(_, _) => raise err
            _ => {
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
            let update_values = try
              execute_with_env(update, acc, next_env)
            catch {
              err => raise_with_prefix(out, err)
            } noraise {
              values => values
            }
            for v in update_values {
              next_states.push(v)
            }
          }
          for acc in next_states {
            let extract_values = try
              execute_with_env(extract, acc, next_env)
            catch {
              err => raise_with_prefix(out, err)
            } noraise {
              values => values
            }
            append_json_values(out, extract_values)
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
priv struct SplitRegexPattern {
  atoms : Array[SplitRegexAtom]
  anchor_start : Bool
  anchor_end : Bool
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
fn split_regex_char_is_escaped(
  chars : Array[Char],
  index : Int,
  start : Int,
) -> Bool {
  let mut backslashes = 0
  let mut i = index - 1
  for {
    if i >= start && chars[i] == '\\' {
      backslashes = backslashes + 1
      i = i - 1
      continue
    }
    break
  }
  backslashes % 2 == 1
}

///|
fn parse_split_regex_pattern(pattern : String) -> SplitRegexPattern {
  let chars = string_to_chars(pattern)
  let n = chars.length()
  let mut start = 0
  let mut end_ = n
  let anchor_start = n > 0 && chars[0] == '^'
  if anchor_start {
    start = 1
  }
  let anchor_end = end_ > start &&
    chars[end_ - 1] == '$' &&
    !split_regex_char_is_escaped(chars, end_ - 1, start)
  if anchor_end {
    end_ = end_ - 1
  }
  let out = []
  let mut i = start
  for {
    if i >= end_ {
      return SplitRegexPattern::{ atoms: out, anchor_start, anchor_end }
    }
    let mut ch = chars[i]
    if ch == '\\' && i + 1 < end_ {
      i = i + 1
      ch = chars[i]
    }

    let mut min_repeat = 1
    let mut max_repeat = 1
    if i + 1 < end_ {
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
  anchor_start : Bool,
  anchor_end : Bool,
) -> (Int, Int)? {
  let len = chars.length()
  if anchor_start && start > 0 {
    return None
  }
  let mut pos = if anchor_start { 0 } else { start }
  for {
    if pos > len {
      return None
    }
    match split_regex_match_end(chars, pos, atoms, 0, ignore_case) {
      Some(end_pos) =>
        if anchor_end && end_pos != len {
          if anchor_start {
            return None
          } else {
            pos = pos + 1
            continue
          }
        } else if skip_empty_match && end_pos == pos {
          if anchor_start {
            return None
          } else {
            pos = pos + 1
            continue
          }
        } else {
          return Some((pos, end_pos))
        }
      None =>
        if anchor_start {
          return None
        } else {
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
  let parsed = parse_split_regex_pattern(pattern)
  let atoms = parsed.atoms
  let anchor_start = parsed.anchor_start
  let anchor_end = parsed.anchor_end
  let ignore_case = split_regex_flag_enabled(flags, 'i')
  let skip_empty_match = split_regex_flag_enabled(flags, 'n')
  let len = chars.length()
  let out = []
  let mut token_start = 0
  let mut search_start = 0

  for {
    match
      split_regex_find_next(
        chars, search_start, atoms, ignore_case, skip_empty_match, anchor_start,
        anchor_end,
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
let regex_combining_mark_lo = 0x0300

///|
let regex_combining_mark_hi = 0x036F

///|
fn regex_is_word_char(ch : Char) -> Bool {
  match ch {
    'a'..='z' | 'A'..='Z' | '0'..='9' | '_' | '\u{0300}'..='\u{036F}' => true
    _ => false
  }
}

///|
let regex_unicode_profile : @regex_engine.Profile = @regex_engine.Profile::new(
  valid=@regex_engine.RecharSet::char_range(0, 0x10FFFF),
  word=@regex_engine.RecharSet::char_range('a', 'z') +
    @regex_engine.RecharSet::char_range('A', 'Z') +
    @regex_engine.RecharSet::char_range('0', '9') +
    @regex_engine.RecharSet::char('_') +
    @regex_engine.RecharSet::char_range(
      regex_combining_mark_lo, regex_combining_mark_hi,
    ),
  category=c => {
    let ch = c.unsafe_to_char()
    if regex_is_word_char(ch) {
      @regex_engine.Category::word()
    } else if ch == '\n' {
      @regex_engine.Category::newline()
    } else {
      @regex_engine.Category::not_word()
    }
  },
)

///|
priv enum CompiledRegexMatcher {
  Native(@regex_engine.Regex)
  TopLevelPositiveLookahead(@regex_engine.Regex)
}

///|
priv struct CompiledRegexPattern {
  matcher : CompiledRegexMatcher
  group_names : ReadOnlyArray[String?]
  skip_empty_match : Bool
}

///|
priv struct RegexMatchData {
  start : Int
  end_ : Int
  result : @regex_engine.MatchResult
}

///|
fn regex_is_extended_ws(ch : Char) -> Bool {
  is_ascii_ws(ch) || ch == '\f' || ch == '\u{0b}'
}

///|
fn regex_expand_shorthand_classes(pattern : String) -> String {
  let chars = string_to_chars(pattern)
  let len = chars.length()
  let buf = StringBuilder::new()
  let mut i = 0
  for {
    if i >= len {
      return buf.to_string()
    }
    let ch = chars[i]
    if ch == '\\' && i + 1 < len {
      match chars[i + 1] {
        'd' => buf.write_string("[[:digit:]]")
        'D' => buf.write_string("[^[:digit:]]")
        's' => buf.write_string("[[:space:]]")
        'S' => buf.write_string("[^[:space:]]")
        'w' => buf.write_string("[[:word:]]")
        'W' => buf.write_string("[^[:word:]]")
        c => {
          buf.write_char('\\')
          buf.write_char(c)
        }
      }
      i += 2
      continue
    }
    buf.write_char(ch)
    i += 1
    continue
  }
}

///|
fn regex_apply_extended_mode(pattern : String) -> String {
  let chars = string_to_chars(pattern)
  let len = chars.length()
  let buf = StringBuilder::new()
  let mut in_char_class = false
  let mut i = 0
  for {
    if i >= len {
      return buf.to_string()
    }
    let ch = chars[i]
    if ch == '\\' {
      buf.write_char(ch)
      if i + 1 < len {
        i += 1
        buf.write_char(chars[i])
      }
      i += 1
      continue
    }
    if !in_char_class && ch == '[' {
      in_char_class = true
      buf.write_char(ch)
      i += 1
      continue
    }
    if in_char_class && ch == ']' {
      in_char_class = false
      buf.write_char(ch)
      i += 1
      continue
    }
    if !in_char_class && ch == '#' {
      i += 1
      for {
        if i >= len {
          return buf.to_string()
        }
        let c = chars[i]
        if c == '\n' || c == '\r' {
          break
        }
        i += 1
        continue
      }
      continue
    }
    if !in_char_class && regex_is_extended_ws(ch) {
      i += 1
      continue
    }
    buf.write_char(ch)
    i += 1
    continue
  }
}

///|
fn regex_rewrite_multiline(
  pattern : @regex_engine.Pattern,
) -> @regex_engine.Pattern {
  match pattern.desc {
    Char(_) => pattern
    Sequence(parts) =>
      @regex_engine.seq(parts.map(part => regex_rewrite_multiline(part)))
    Alternation(parts) =>
      @regex_engine.alt(parts.map(part => regex_rewrite_multiline(part)))
    Quantifier(q, part) =>
      @regex_engine.quantifier(regex_rewrite_multiline(part), q)
    Preference(pref, part) =>
      @regex_engine.preference(pref, regex_rewrite_multiline(part))
    Capture(name~, part) =>
      @regex_engine.capture(name?, regex_rewrite_multiline(part))
    Assertion(assertion) =>
      match assertion {
        StartOfInput => @regex_engine.start_of_line
        EndOfInput => @regex_engine.end_of_line
        _ => pattern
      }
  }
}

///|
fn regex_extract_top_level_positive_lookahead(pattern : String) -> String? {
  let chars = string_to_chars(pattern)
  let len = chars.length()
  if len < 4 {
    return None
  }
  if chars[0] != '(' ||
    chars[1] != '?' ||
    chars[2] != '=' ||
    chars[len - 1] != ')' {
    return None
  }
  let mut escaped = false
  let mut in_char_class = false
  let mut depth = 0
  for i in 0..<len {
    let ch = chars[i]
    if escaped {
      escaped = false
      continue
    }
    if ch == '\\' {
      escaped = true
      continue
    }
    if in_char_class {
      if ch == ']' {
        in_char_class = false
      }
      continue
    }
    if ch == '[' {
      in_char_class = true
      continue
    }
    if ch == '(' {
      depth += 1
      continue
    }
    if ch == ')' {
      depth -= 1
      if depth < 0 {
        return None
      }
      if depth == 0 && i != len - 1 {
        return None
      }
      continue
    }
  }
  if escaped || in_char_class || depth != 0 {
    return None
  }
  Some(chars_slice_to_string(chars, 3, len - 1))
}

///|
fn regex_parse_pattern(
  pattern : String,
  flags : String,
) -> @regex_engine.Pattern raise EvalError {
  let mut source = pattern
  if split_regex_flag_enabled(flags, 'i') {
    source = "(?i:" + source + ")"
  }
  let parsed = try
    @regex_parser.parse(
      profile=regex_unicode_profile,
      mode=@regex_parser.Mode::String,
      source[:],
    )
  catch {
    err => raise TypeError("Regex failure: " + err.to_string())
  } noraise {
    value => value
  }
  if split_regex_flag_enabled(flags, 'm') ||
    split_regex_flag_enabled(flags, 'p') {
    regex_rewrite_multiline(parsed)
  } else {
    parsed
  }
}

///|
fn regex_compile_engine_pattern(
  pattern : String,
  flags : String,
) -> @regex_engine.Regex raise EvalError {
  let parsed = regex_parse_pattern(pattern, flags)
  @regex_engine.compile(profile=regex_unicode_profile, parsed)
}

///|
fn regex_compile_pattern(
  pattern : String,
  flags : String,
) -> CompiledRegexPattern raise EvalError {
  let mut normalized = regex_expand_shorthand_classes(pattern)
  if split_regex_flag_enabled(flags, 'x') {
    normalized = regex_apply_extended_mode(normalized)
  }
  let skip_empty_match = split_regex_flag_enabled(flags, 'n')
  if regex_extract_top_level_positive_lookahead(normalized)
    is Some(lookahead_inner) {
    let lookahead_regex = regex_compile_engine_pattern(lookahead_inner, flags)
    CompiledRegexPattern::{
      matcher: TopLevelPositiveLookahead(lookahead_regex),
      group_names: lookahead_regex.group_names(),
      skip_empty_match,
    }
  } else {
    let regex = regex_compile_engine_pattern(normalized, flags)
    CompiledRegexPattern::{
      matcher: Native(regex),
      group_names: regex.group_names(),
      skip_empty_match,
    }
  }
}

///|
fn regex_slice_string(s : String, start : Int, end_ : Int) -> String {
  s.view(start_offset=start, end_offset=end_).to_string()
}

///|
fn regex_find_native_next_match(
  regex : @regex_engine.Regex,
  input : String,
  search_start : Int,
) -> RegexMatchData? {
  match regex.execute(input[:], search_start) {
    None => None
    Some(result) =>
      match result.group(0) {
        None => None
        Some((start, end_)) => Some(RegexMatchData::{ start, end_, result })
      }
  }
}

///|
fn regex_find_top_level_lookahead_match(
  regex : @regex_engine.Regex,
  input : String,
  search_start : Int,
) -> RegexMatchData? {
  let len = input.length()
  let mut current_start = search_start
  for {
    if current_start > len {
      return None
    }
    match regex.execute(input[:], current_start) {
      None => return None
      Some(result) =>
        match result.group(0) {
          None => return None
          Some((inner_start, _)) =>
            if inner_start == current_start {
              return Some(RegexMatchData::{
                start: current_start,
                end_: current_start,
                result,
              })
            } else if inner_start > current_start {
              current_start = inner_start
              continue
            } else if current_start < len {
              current_start += 1
              continue
            } else {
              return None
            }
        }
    }
  }
}

///|
fn regex_find_next_match(
  compiled : CompiledRegexPattern,
  input : String,
  search_start : Int,
) -> RegexMatchData? {
  let len = input.length()
  let mut current_start = search_start
  for {
    if current_start > len {
      return None
    }
    let found = match compiled.matcher {
      Native(regex) => regex_find_native_next_match(regex, input, current_start)
      TopLevelPositiveLookahead(regex) =>
        regex_find_top_level_lookahead_match(regex, input, current_start)
    }
    match found {
      None => return None
      Some(result) =>
        if compiled.skip_empty_match && result.start == result.end_ {
          if result.start < len {
            current_start = result.start + 1
            continue
          } else {
            return None
          }
        } else {
          return Some(result)
        }
    }
  }
}

///|
fn regex_group_value_or_null(
  s : String,
  result : @regex_engine.MatchResult,
  index : Int,
) -> Json {
  match result.group(index) {
    Some((start, end_)) => Json::string(regex_slice_string(s, start, end_))
    None => Json::null()
  }
}

///|
fn regex_capture_entry(
  s : String,
  result : @regex_engine.MatchResult,
  group_names : ReadOnlyArray[String?],
  index : Int,
) -> Json {
  let name_json = match group_names.get(index) {
    Some(Some(name)) => Json::string(name)
    _ => Json::null()
  }
  match result.group(index) {
    Some((start, end_)) =>
      if start == end_ {
        Json::object_from_entries([
          ("offset", Json::number(start.to_double())),
          ("string", Json::string("")),
          ("length", Json::number(0.0)),
          ("name", name_json),
        ])
      } else {
        Json::object_from_entries([
          ("offset", Json::number(start.to_double())),
          ("length", Json::number((end_ - start).to_double())),
          ("string", Json::string(regex_slice_string(s, start, end_))),
          ("name", name_json),
        ])
      }
    None =>
      Json::object_from_entries([
        ("offset", Json::number(-1.0)),
        ("string", Json::null()),
        ("length", Json::number(0.0)),
        ("name", name_json),
      ])
  }
}

///|
fn regex_named_capture_object(
  s : String,
  result : @regex_engine.MatchResult,
  group_names : ReadOnlyArray[String?],
) -> Json {
  let out = Map::new()
  for i in 1..<group_names.length() {
    match group_names[i] {
      Some(name) => out[name] = regex_group_value_or_null(s, result, i)
      None => ()
    }
  }
  Json::object(out)
}

///|
fn regex_next_search_start(
  current_start : Int,
  match_start : Int,
  match_end : Int,
  input_len : Int,
) -> Int? {
  if match_start == match_end {
    if match_start < input_len {
      Some(match_start + 1)
    } else {
      None
    }
  } else if match_end > current_start {
    Some(match_end)
  } else if match_start < input_len {
    Some(match_start + 1)
  } else {
    None
  }
}

///|
fn regex_has_match(
  s : String,
  pattern : String,
  flags : String,
) -> Bool raise EvalError {
  let compiled = regex_compile_pattern(pattern, flags)
  regex_find_next_match(compiled, s, 0) is Some(_)
}

///|
fn regex_scan_values(
  s : String,
  pattern : String,
  flags : String,
) -> Array[Json] raise EvalError {
  let compiled = regex_compile_pattern(pattern, flags)
  let mut search_start = 0
  let len = s.length()
  let has_captures = compiled.group_names.length() > 1
  let out = []
  for {
    match regex_find_next_match(compiled, s, search_start) {
      Some(found) => {
        if has_captures {
          let groups = []
          for i in 1..<compiled.group_names.length() {
            groups.push(regex_group_value_or_null(s, found.result, i))
          }
          out.push(Json::array(groups))
        } else {
          out.push(Json::string(regex_slice_string(s, found.start, found.end_)))
        }
        match
          regex_next_search_start(search_start, found.start, found.end_, len) {
          Some(next_start) => {
            search_start = next_start
            continue
          }
          None => return out
        }
      }
      None => return out
    }
  }
}

///|
fn regex_match_objects(
  s : String,
  pattern : String,
  flags : String,
) -> Array[Json] raise EvalError {
  let compiled = regex_compile_pattern(pattern, flags)
  let global = split_regex_flag_enabled(flags, 'g')
  let mut search_start = 0
  let len = s.length()
  let out = []
  for {
    match regex_find_next_match(compiled, s, search_start) {
      Some(found) => {
        let captures = []
        for i in 1..<compiled.group_names.length() {
          captures.push(
            regex_capture_entry(s, found.result, compiled.group_names, i),
          )
        }
        out.push(
          Json::object_from_entries([
            ("offset", Json::number(found.start.to_double())),
            ("length", Json::number((found.end_ - found.start).to_double())),
            (
              "string",
              Json::string(regex_slice_string(s, found.start, found.end_)),
            ),
            ("captures", Json::array(captures)),
          ]),
        )
        if !global {
          return out
        }
        match
          regex_next_search_start(search_start, found.start, found.end_, len) {
          Some(next_start) => {
            search_start = next_start
            continue
          }
          None => return out
        }
      }
      None => return out
    }
  }
}

///|
fn regex_capture_objects(
  s : String,
  pattern : String,
  flags : String,
) -> Array[Json] raise EvalError {
  let compiled = regex_compile_pattern(pattern, flags)
  let global = split_regex_flag_enabled(flags, 'g')
  let mut search_start = 0
  let len = s.length()
  let out = []
  for {
    match regex_find_next_match(compiled, s, search_start) {
      Some(found) => {
        out.push(
          regex_named_capture_object(s, found.result, compiled.group_names),
        )
        if !global {
          return out
        }
        match
          regex_next_search_start(search_start, found.start, found.end_, len) {
          Some(next_start) => {
            search_start = next_start
            continue
          }
          None => return out
        }
      }
      None => return out
    }
  }
}

///|
fn regex_apply_replacement_variants(
  variants : Array[String],
  replacements : Array[String],
  matched : String,
) -> Array[String] {
  if replacements.length() == 0 {
    let out = []
    for variant in variants {
      out.push(variant + matched)
    }
    return out
  }
  if variants.length() == 1 && replacements.length() > 1 {
    let out = []
    let base = variants[0]
    for replacement in replacements {
      out.push(base + replacement)
    }
    return out
  }
  let out = []
  for i in 0..<variants.length() {
    let replacement = if i < replacements.length() {
      replacements[i]
    } else {
      ""
    }
    out.push(variants[i] + replacement)
  }
  out
}

///|
fn regex_substitute_values(
  s : String,
  pattern : String,
  replacement_filter : Filter,
  flags : String,
  env : Map[String, Json],
  global~ : Bool,
  replacement_error : String,
) -> Array[String] raise EvalError {
  let compiled = regex_compile_pattern(pattern, flags)
  let len = s.length()
  let mut search_start = 0
  let mut token_start = 0
  let mut variants = [""]
  for {
    match regex_find_next_match(compiled, s, search_start) {
      Some(found) => {
        let prefix = regex_slice_string(s, token_start, found.start)
        for i in 0..<variants.length() {
          variants[i] = variants[i] + prefix
        }
        let replacement_input = regex_named_capture_object(
          s,
          found.result,
          compiled.group_names,
        )
        let replacement_values_json = execute_with_env(
          replacement_filter, replacement_input, env,
        )
        let replacement_values = []
        for value in replacement_values_json {
          match value {
            String(text) => replacement_values.push(text)
            _ => raise TypeError(replacement_error)
          }
        }
        let matched = regex_slice_string(s, found.start, found.end_)
        variants = regex_apply_replacement_variants(
          variants, replacement_values, matched,
        )
        token_start = found.end_
        if !global {
          let suffix = regex_slice_string(s, token_start, len)
          for i in 0..<variants.length() {
            variants[i] = variants[i] + suffix
          }
          return variants
        }
        match
          regex_next_search_start(search_start, found.start, found.end_, len) {
          Some(next_start) => {
            search_start = next_start
            continue
          }
          None => {
            let suffix = regex_slice_string(s, token_start, len)
            for i in 0..<variants.length() {
              variants[i] = variants[i] + suffix
            }
            return variants
          }
        }
      }
      None => {
        let suffix = regex_slice_string(s, token_start, len)
        for i in 0..<variants.length() {
          variants[i] = variants[i] + suffix
        }
        return variants
      }
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
