///|
// Source under test: core/json_format.mbt

///|
test "decimal_expand_positive_exponent handles valid and invalid inputs" {
  guard decimal_expand_positive_exponent("12") is None else {
    fail("expected decimal_expand_positive_exponent(\"12\") to return None")
  }
  guard decimal_expand_positive_exponent("1.2e3") is Some("1200") else {
    fail(
      "expected decimal_expand_positive_exponent(\"1.2e3\") to return Some(\"1200\")",
    )
  }
  guard decimal_expand_positive_exponent("1.23e1") is Some("12.3") else {
    fail(
      "expected decimal_expand_positive_exponent(\"1.23e1\") to return Some(\"12.3\")",
    )
  }
  guard decimal_expand_positive_exponent("-1.2e3") is Some("-1200") else {
    fail(
      "expected decimal_expand_positive_exponent(\"-1.2e3\") to return Some(\"-1200\")",
    )
  }
  guard decimal_expand_positive_exponent("+1.2e3") is Some("1200") else {
    fail(
      "expected decimal_expand_positive_exponent(\"+1.2e3\") to return Some(\"1200\")",
    )
  }
  guard decimal_expand_positive_exponent("1.2e-1") is None else {
    fail("expected decimal_expand_positive_exponent(\"1.2e-1\") to return None")
  }
  guard decimal_expand_positive_exponent("1.2.3e1") is None else {
    fail(
      "expected decimal_expand_positive_exponent(\"1.2.3e1\") to return None",
    )
  }
  guard decimal_expand_positive_exponent("1ae2") is None else {
    fail("expected decimal_expand_positive_exponent(\"1ae2\") to return None")
  }
  guard decimal_expand_positive_exponent(".e2") is None else {
    fail("expected decimal_expand_positive_exponent(\".e2\") to return None")
  }
}
