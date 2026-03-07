///|
// Source under test: core/jqx.mbt

///|
test "object_keys_in_order normalizes duplicates and missing keys" {
  let single = { "a": Json::number(1.0) }
  assert_eq(object_keys_in_order(single, []), ["a"])

  let pair = { "a": Json::number(1.0), "b": Json::number(2.0) }
  assert_eq(object_keys_in_order(pair, ["b", "missing", "b"]), ["b", "a"])
}

///|
test "json_equal covers false branches" {
  guard !json_equal(
    Json::array([Json::number(1.0)]),
    Json::array([Json::number(1.0), Json::number(2.0)]),
  ) else {
    fail("expected array length mismatch to be false")
  }
  guard !json_equal(
    Json::array([Json::number(1.0)]),
    Json::array([Json::number(2.0)]),
  ) else {
    fail("expected array element mismatch to be false")
  }
  guard !json_equal(
    Json::object_from_entries([("a", Json::number(1.0))]),
    Json::object_from_entries([
      ("a", Json::number(1.0)),
      ("b", Json::number(2.0)),
    ]),
  ) else {
    fail("expected object length mismatch to be false")
  }
  guard !json_equal(
    Json::object_from_entries([("a", Json::number(1.0))]),
    Json::object_from_entries([("a", Json::number(2.0))]),
  ) else {
    fail("expected object value mismatch to be false")
  }
  guard !json_equal(Json::number(1.0), Json::string("1")) else {
    fail("expected type mismatch to be false")
  }
}

///|
test "decimal_expand_positive_exponent handles valid and invalid inputs" {
  assert_eq(decimal_expand_positive_exponent("12"), None)
  assert_eq(decimal_expand_positive_exponent("1.2e3"), Some("1200"))
  assert_eq(decimal_expand_positive_exponent("1.23e1"), Some("12.3"))
  assert_eq(decimal_expand_positive_exponent("-1.2e3"), Some("-1200"))
  assert_eq(decimal_expand_positive_exponent("+1.2e3"), Some("1200"))
  assert_eq(decimal_expand_positive_exponent("1.2e-1"), None)
  assert_eq(decimal_expand_positive_exponent("1.2.3e1"), None)
  assert_eq(decimal_expand_positive_exponent("1ae2"), None)
  assert_eq(decimal_expand_positive_exponent(".e2"), None)
}
