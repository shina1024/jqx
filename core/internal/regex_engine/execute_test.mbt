///|
// Source under test: core/internal/regex_engine/execute.mbt

///|
fn test_ascii_profile() -> Profile {
  let valid = RecharSet::char_range(0, 0x7f)
  let word = RecharSet::char_range('a', 'z') +
    RecharSet::char_range('A', 'Z') +
    RecharSet::char_range('0', '9') +
    RecharSet::char('_')
  Profile::new(valid~, word~, category=c => {
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '_' {
      Category::word()
    } else if c == '\n' {
      Category::newline()
    } else {
      Category::not_word()
    }
  })
}

///|
fn compile_single_ascii_char(ch : Char) -> Regex {
  compile(profile=test_ascii_profile(), char(RecharSet::char(ch.to_int())))
}

///|
test "regex execute returns None for out-of-range lastIndex" {
  let regex = compile_single_ascii_char('a')
  guard regex.execute("abc"[:], -1) is None else {
    fail("expected None for negative lastIndex")
  }
  guard regex.execute("abc"[:], 4) is None else {
    fail("expected None for lastIndex past input length")
  }
}

///|
test "regex execute remains matchable for valid index" {
  let regex = compile_single_ascii_char('a')
  guard regex.execute("ba"[:], 0) is Some(result) else {
    fail("expected match result")
  }
  assert_eq(result.group(0), Some((1, 2)))
}

///|
test "match result group returns None for out-of-range index" {
  let regex = compile_single_ascii_char('a')
  guard regex.execute("a"[:], 0) is Some(result) else {
    fail("expected match result")
  }
  assert_eq(result.group(99), None)
}
