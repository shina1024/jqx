///|
test "compute exit status" {
  assert_eq(compute_exit_status([]), 4)
  assert_eq(compute_exit_status([@lib.Json::null()]), 1)
  assert_eq(compute_exit_status([@lib.Json::boolean(false)]), 1)
  assert_eq(compute_exit_status([@lib.Json::boolean(true)]), 0)
  assert_eq(compute_exit_status([@lib.Json::number(1.0)]), 0)
  assert_eq(
    compute_exit_status([@lib.Json::number(1.0), @lib.Json::boolean(false)]),
    1,
  )
}
