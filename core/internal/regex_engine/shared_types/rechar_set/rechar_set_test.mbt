///|
// Source under test: core/internal/regex_engine/shared_types/rechar_set/rechar_set.mbt

///|
test "trait implementations remain available as RecharSet methods" {
  let left = @rechar_set.RecharSet::char_range(1, 3)
  let right = @rechar_set.RecharSet::char_range(3, 5)
  assert_eq(left.add(right).intervals().to_array(), [(1, 5)])
  assert_eq(left.sub(right).intervals().to_array(), [(1, 2)])
  assert_eq(left.land(right).intervals().to_array(), [(3, 3)])
  assert_eq((left - right).intervals().to_array(), [(1, 2)])
  assert_eq(left.to_repr().to_string(), "[(1, 3)]")
}
