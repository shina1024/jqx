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
