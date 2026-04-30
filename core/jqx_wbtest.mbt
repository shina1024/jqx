///|
// Source under test: core/jqx.mbt

///|
test "object_keys_in_order normalizes duplicates and missing keys" {
  let single = { "a": Value::number(1.0) }
  assert_eq(object_keys_in_order(single, []), ["a"])

  let pair = { "a": Value::number(1.0), "b": Value::number(2.0) }
  assert_eq(object_keys_in_order(pair, ["b", "missing", "b"]), ["b", "a"])
}

///|
test "json_equal covers false branches" {
  guard !json_equal(
    Value::array([Value::number(1.0)]),
    Value::array([Value::number(1.0), Value::number(2.0)]),
  ) else {
    fail("expected array length mismatch to be false")
  }
  guard !json_equal(
    Value::array([Value::number(1.0)]),
    Value::array([Value::number(2.0)]),
  ) else {
    fail("expected array element mismatch to be false")
  }
  guard !json_equal(
    Value::object_from_entries([("a", Value::number(1.0))]),
    Value::object_from_entries([
      ("a", Value::number(1.0)),
      ("b", Value::number(2.0)),
    ]),
  ) else {
    fail("expected object length mismatch to be false")
  }
  guard !json_equal(
    Value::object_from_entries([("a", Value::number(1.0))]),
    Value::object_from_entries([("a", Value::number(2.0))]),
  ) else {
    fail("expected object value mismatch to be false")
  }
  guard !json_equal(Value::number(1.0), Value::string("1")) else {
    fail("expected type mismatch to be false")
  }
}

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
