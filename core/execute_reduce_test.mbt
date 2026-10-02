///|
// Source under test: core/execute.mbt (Reduce)
// jq master fix df24981307658868759faaea76b817cc62dd6be0, after jq 1.8.2.
// These intended outputs must remain tested even while the release oracle differs.

///|
test "reduce preserves empty input across multiple initializer outputs" {
  @debug.assert_eq(
    must_run_json_text("[] | reduce .[] as $x (0,1; .)", "null"),
    ["0", "1"],
  )
}

///|
test "reduce preserves nonempty input across multiple initializer outputs" {
  @debug.assert_eq(
    must_run_json_text("[1,2] | reduce .[] as $x (0,1; . + $x)", "null"),
    ["3", "4"],
  )
}
