///|
// Source under test: core/internal/regex_parser/parser.mbt

///|
fn test_ascii_profile_wb() -> @re.Profile {
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
test "hex2i decodes mixed-case digits" {
  assert_eq(hex2i("1Af"[:]), 431)
}

///|
test "class_atom returns well-formed atoms without hitting fallback panic" {
  let string_ctx = ParserContext::new(
    profile=test_ascii_profile_wb(),
    base=0,
    mode=String,
  )
  guard Parser::class_atom("\\u0041"[:], ctx=string_ctx) is ([], Char(c)) else {
    fail("expected unicode escape atom")
  }
  assert_eq(c, 'A'.to_int())

  let bytes_ctx = ParserContext::new(
    profile=test_ascii_profile_wb(),
    base=0,
    mode=Bytes,
  )
  guard Parser::class_atom("\\x41"[:], ctx=bytes_ctx) is ([], Char(b)) else {
    fail("expected byte escape atom")
  }
  assert_eq(b, 'A'.to_int())

  guard Parser::class_atom("[:digit:]"[:], ctx=string_ctx) is ([], Class(cs)) else {
    fail("expected POSIX digit class atom")
  }
  assert_eq(cs.contains('0'.to_int()), true)
  assert_eq(cs.contains('9'.to_int()), true)
}

///|
test "character_class consumes closing bracket and negation safely" {
  let ctx = ParserContext::new(
    profile=test_ascii_profile_wb(),
    base=0,
    mode=String,
  )

  guard Parser::character_class("[a]"[:], ctx~) is ([], plain) else {
    fail("expected simple character class")
  }
  assert_eq(plain.contains('a'.to_int()), true)
  assert_eq(plain.contains('b'.to_int()), false)

  let ctx = ParserContext::new(
    profile=test_ascii_profile_wb(),
    base=0,
    mode=String,
  )
  guard Parser::character_class("[^a]"[:], ctx~) is ([], negated) else {
    fail("expected negated character class")
  }
  assert_eq(negated.contains('a'.to_int()), false)
  assert_eq(negated.contains('b'.to_int()), true)
}
