///|
// Source under test: core/json_value.mbt

///|
test "object_keys_in_order normalizes duplicates and missing keys" {
  let single = { "a": Value::number(1.0) }
  @debug.assert_eq(object_keys_in_order(single, []), ["a"])

  let pair = { "a": Value::number(1.0), "b": Value::number(2.0) }
  @debug.assert_eq(object_keys_in_order(pair, ["b", "missing", "b"]), ["b", "a"])
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
