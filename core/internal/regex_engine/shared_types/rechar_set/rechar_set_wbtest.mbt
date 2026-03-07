///|
// Source under test: core/internal/regex_engine/shared_types/rechar_set/{tree,rechar_set}.mbt

///|
test "bal preserves interval order for heavy left and right trees" {
  let right = build([(20, 20), (30, 30), (40, 40)][:], 0, 2)
  let right_balanced = RecharSet(bal(Empty, 10, 10, right))
  assert_eq(right_balanced.intervals().to_array(), [
    (10, 10),
    (20, 20),
    (30, 30),
    (40, 40),
  ])

  let left = build([(10, 10), (20, 20), (30, 30)][:], 0, 2)
  let left_balanced = RecharSet(bal(left, 40, 40, Empty))
  assert_eq(left_balanced.intervals().to_array(), [
    (10, 10),
    (20, 20),
    (30, 30),
    (40, 40),
  ])
}

///|
test "cat union and intersection maintain tree invariants" {
  let left = build([(0, 0), (2, 2)][:], 0, 1)
  let right = build([(5, 5), (7, 7)][:], 0, 1)
  let concatenated = RecharSet(cat(left, right))
  assert_eq(concatenated.intervals().to_array(), [
    (0, 0),
    (2, 2),
    (5, 5),
    (7, 7),
  ])

  let merged = RecharSet::from_sorted_array([(0, 0), (10, 10)][:]) +
    RecharSet::from_sorted_array([(1, 9)][:])
  assert_eq(merged.intervals().to_array(), [(0, 10)])

  let overlap = RecharSet::from_sorted_array([(0, 2), (8, 10)][:]) &
    RecharSet::from_sorted_array([(1, 9)][:])
  assert_eq(overlap.intervals().to_array(), [(1, 2), (8, 9)])
}
