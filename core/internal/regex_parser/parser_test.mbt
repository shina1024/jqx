///|
// Source under test: core/internal/regex_parser/parser.mbt

///|
fn test_ascii_profile() -> @re.Profile {
  let valid = @re.RecharSet::char_range(0, 0x7F)
  let word = @re.RecharSet::char_range('a', 'z') +
    @re.RecharSet::char_range('A', 'Z') +
    @re.RecharSet::char_range('0', '9') +
    @re.RecharSet::char('_')
  @re.Profile::new(valid~, word~, category=c => {
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '_' {
      @re.Category::word()
    } else if c == '\n' {
      @re.Category::newline()
    } else {
      @re.Category::not_word()
    }
  })
}

///|
fn regex_parse_error_contains(pattern : String, hint : String) -> Bool {
  guard (try? parse(profile=test_ascii_profile(), mode=String, pattern[:]))
    is Err(err) &&
    err.to_string().contains(hint) else {
    return false
  }
  true
}

///|
test "regex parser accepts supported POSIX character classes" {
  guard (try? parse(profile=test_ascii_profile(), mode=String, "[[:digit:]]"[:]))
    is Ok(_) else {
    fail("expected supported POSIX class to parse")
  }
}

///|
test "regex parser reports character class diagnostics" {
  guard regex_parse_error_contains(
    "[[:foo:]]", "Unsupported POSIX character class",
  ) else {
    fail("expected unsupported POSIX class diagnostic")
  }
  guard regex_parse_error_contains("[[:", "Invalid POSIX character class") else {
    fail("expected invalid POSIX class diagnostic")
  }
  guard regex_parse_error_contains(
    "[[a]]", "Unsupported nested character class",
  ) else {
    fail("expected nested character class diagnostic")
  }
  guard regex_parse_error_contains("[z-a]", "Invalid character class range") else {
    fail("expected invalid character range diagnostic")
  }
  guard regex_parse_error_contains(
    "[a-[:digit:]]", "Character class range over sets",
  ) else {
    fail("expected character class range over sets diagnostic")
  }
  guard regex_parse_error_contains(
    "[a--b]", "Unsupported character class set expression",
  ) else {
    fail("expected class set expression diagnostic")
  }
  guard regex_parse_error_contains("[abc", "Unclosed character class") else {
    fail("expected unclosed character class diagnostic")
  }
}
