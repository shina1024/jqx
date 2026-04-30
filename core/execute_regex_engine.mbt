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
priv struct RegexCompileCacheState {
  entries : Map[String, CompiledRegexPattern]
}

///|
let regex_compile_cache_state : RegexCompileCacheState = { entries: Map::new() }

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
  while i < len {
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
  }
  buf.to_string()
}

///|
fn regex_apply_extended_mode(pattern : String) -> String {
  let chars = string_to_chars(pattern)
  let len = chars.length()
  let buf = StringBuilder::new()
  let mut in_char_class = false
  let mut i = 0
  while i < len {
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
      while i < len {
        let c = chars[i]
        if c == '\n' || c == '\r' {
          break
        }
        i += 1
      }
      continue
    }
    if !in_char_class && regex_is_extended_ws(ch) {
      i += 1
      continue
    }
    buf.write_char(ch)
    i += 1
  }
  buf.to_string()
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
fn regex_compile_pattern_uncached(
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
fn regex_compile_cache_key(pattern : String, flags : String) -> String {
  flags + "\u{0000}" + pattern
}

///|
fn regex_compile_pattern(
  pattern : String,
  flags : String,
) -> CompiledRegexPattern raise EvalError {
  let key = regex_compile_cache_key(pattern, flags)
  match regex_compile_cache_state.entries.get(key) {
    Some(compiled) => compiled
    None => {
      let compiled = regex_compile_pattern_uncached(pattern, flags)
      regex_compile_cache_state.entries[key] = compiled
      compiled
    }
  }
}

///|
fn regex_slice_string(s : String, start : Int, end_ : Int) -> String {
  s.view(start_offset=start, end_offset=end_).to_owned()
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
  while current_start <= len {
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
  None
}

///|
fn regex_find_next_match(
  compiled : CompiledRegexPattern,
  input : String,
  search_start : Int,
) -> RegexMatchData? {
  let len = input.length()
  let mut current_start = search_start
  while current_start <= len {
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
  None
}

///|
fn regex_group_value_or_null(
  s : String,
  result : @regex_engine.MatchResult,
  index : Int,
) -> Value {
  match result.group(index) {
    Some((start, end_)) => Value::string(regex_slice_string(s, start, end_))
    None => Value::null()
  }
}

///|
fn regex_capture_entry(
  s : String,
  result : @regex_engine.MatchResult,
  group_names : ReadOnlyArray[String?],
  index : Int,
) -> Value {
  let name_json = match group_names.get(index) {
    Some(Some(name)) => Value::string(name)
    _ => Value::null()
  }
  match result.group(index) {
    Some((start, end_)) =>
      if start == end_ {
        Value::object_from_entries([
          ("offset", Value::number(start.to_double())),
          ("string", Value::string("")),
          ("length", Value::number(0.0)),
          ("name", name_json),
        ])
      } else {
        Value::object_from_entries([
          ("offset", Value::number(start.to_double())),
          ("length", Value::number((end_ - start).to_double())),
          ("string", Value::string(regex_slice_string(s, start, end_))),
          ("name", name_json),
        ])
      }
    None =>
      Value::object_from_entries([
        ("offset", Value::number(-1.0)),
        ("string", Value::null()),
        ("length", Value::number(0.0)),
        ("name", name_json),
      ])
  }
}

///|
fn regex_named_capture_object(
  s : String,
  result : @regex_engine.MatchResult,
  group_names : ReadOnlyArray[String?],
) -> Value {
  let out = Map::new()
  for i in 1..<group_names.length() {
    match group_names[i] {
      Some(name) => out[name] = regex_group_value_or_null(s, result, i)
      None => ()
    }
  }
  Value::object(out)
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
) -> Array[Value] raise EvalError {
  let compiled = regex_compile_pattern(pattern, flags)
  let mut search_start = 0
  let len = s.length()
  let has_captures = compiled.group_names.length() > 1
  let out = []
  while search_start <= len {
    match regex_find_next_match(compiled, s, search_start) {
      Some(found) => {
        if has_captures {
          let groups = []
          for i in 1..<compiled.group_names.length() {
            groups.push(regex_group_value_or_null(s, found.result, i))
          }
          out.push(Value::array(groups))
        } else {
          out.push(
            Value::string(regex_slice_string(s, found.start, found.end_)),
          )
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
  out
}

///|
fn regex_match_objects(
  s : String,
  pattern : String,
  flags : String,
) -> Array[Value] raise EvalError {
  let compiled = regex_compile_pattern(pattern, flags)
  let global = split_regex_flag_enabled(flags, 'g')
  let mut search_start = 0
  let len = s.length()
  let out = []
  while search_start <= len {
    match regex_find_next_match(compiled, s, search_start) {
      Some(found) => {
        let captures = []
        for i in 1..<compiled.group_names.length() {
          captures.push(
            regex_capture_entry(s, found.result, compiled.group_names, i),
          )
        }
        out.push(
          Value::object_from_entries([
            ("offset", Value::number(found.start.to_double())),
            ("length", Value::number((found.end_ - found.start).to_double())),
            (
              "string",
              Value::string(regex_slice_string(s, found.start, found.end_)),
            ),
            ("captures", Value::array(captures)),
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
  out
}

///|
fn regex_capture_objects(
  s : String,
  pattern : String,
  flags : String,
) -> Array[Value] raise EvalError {
  let compiled = regex_compile_pattern(pattern, flags)
  let global = split_regex_flag_enabled(flags, 'g')
  let mut search_start = 0
  let len = s.length()
  let out = []
  while search_start <= len {
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
  out
}

///|
fn regex_apply_replacement_chunks(
  variants : Array[Array[String]],
  replacements : Array[String],
  matched : String,
) -> Array[Array[String]] {
  if replacements.length() == 0 {
    if matched.length() == 0 {
      return variants
    }
    for variant in variants {
      variant.push(matched)
    }
    return variants
  }
  if variants.length() == 1 && replacements.length() > 1 {
    let base_chunks = variants[0]
    let out : Array[Array[String]] = []
    for replacement in replacements {
      let next_chunks = base_chunks.copy()
      if replacement.length() > 0 {
        next_chunks.push(replacement)
      }
      out.push(next_chunks)
    }
    return out
  }
  let out : Array[Array[String]] = []
  for i in 0..<variants.length() {
    let next_chunks = variants[i].copy()
    if i < replacements.length() && replacements[i].length() > 0 {
      next_chunks.push(replacements[i])
    }
    out.push(next_chunks)
  }
  out
}

///|
fn regex_join_chunks(chunks : Array[String]) -> String {
  let buf = StringBuilder::new()
  for chunk in chunks {
    buf.write_string(chunk)
  }
  buf.to_string()
}

///|
fn regex_substitute_values(
  s : String,
  pattern : String,
  replacement_filter : Filter,
  flags : String,
  env : Map[String, Value],
  global~ : Bool,
  replacement_error : String,
) -> Array[String] raise EvalError {
  let compiled = regex_compile_pattern(pattern, flags)
  let len = s.length()
  let mut search_start = 0
  let mut token_start = 0
  let mut variants : Array[Array[String]] = [[]]
  while search_start <= len {
    match regex_find_next_match(compiled, s, search_start) {
      Some(found) => {
        let prefix = regex_slice_string(s, token_start, found.start)
        if prefix.length() > 0 {
          for variant in variants {
            variant.push(prefix)
          }
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
        variants = regex_apply_replacement_chunks(
          variants, replacement_values, matched,
        )
        token_start = found.end_
        if !global {
          let suffix = regex_slice_string(s, token_start, len)
          if suffix.length() > 0 {
            for variant in variants {
              variant.push(suffix)
            }
          }
          let out = []
          for chunks in variants {
            out.push(regex_join_chunks(chunks))
          }
          return out
        }
        match
          regex_next_search_start(search_start, found.start, found.end_, len) {
          Some(next_start) => {
            search_start = next_start
            continue
          }
          None => {
            let suffix = regex_slice_string(s, token_start, len)
            if suffix.length() > 0 {
              for variant in variants {
                variant.push(suffix)
              }
            }
            let out = []
            for chunks in variants {
              out.push(regex_join_chunks(chunks))
            }
            return out
          }
        }
      }
      None => {
        let suffix = regex_slice_string(s, token_start, len)
        if suffix.length() > 0 {
          for variant in variants {
            variant.push(suffix)
          }
        }
        let out = []
        for chunks in variants {
          out.push(regex_join_chunks(chunks))
        }
        return out
      }
    }
  }
  let suffix = regex_slice_string(s, token_start, len)
  if suffix.length() > 0 {
    for variant in variants {
      variant.push(suffix)
    }
  }
  let out = []
  for chunks in variants {
    out.push(regex_join_chunks(chunks))
  }
  out
}
