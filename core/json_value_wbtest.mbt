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

///|
test "json_equal terminates for cyclic public values" {
  let left_items = [Value::null()]
  let left = Value::array(left_items)
  left_items[0] = left
  let right_items = [Value::null()]
  let right = Value::array(right_items)
  right_items[0] = right
  guard json_equal(left, left) else {
    fail("expected physical identity to compare equal")
  }
  guard !json_equal(left, right) else {
    fail("expected separately constructed cycles to stop at the depth guard")
  }
}
