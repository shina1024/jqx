///|
// Source under test: core/builtin_numeric.mbt, core/builtin_range.mbt

///|
test "jq 1.8.2 range zero and NaN steps produce empty streams" {
  @debug.assert_eq(must_run_json_text("[range(0;10;0)]", "null"), ["[]"])
  @debug.assert_eq(must_run_json_text("[range(10;0;-0)]", "null"), ["[]"])
  @debug.assert_eq(must_run_json_text("[range(0;10;nan)]", "null"), ["[]"])
}

///|
test "jq 1.8.2 range numeric bound errors use the released diagnostic" {
  @debug.assert_eq(must_run_json_text("try range(.) catch .", "null"), [
    "\"Range bounds must be numeric\"",
  ])
  @debug.assert_eq(must_run_json_text("try range(0;\"\") catch .", "null"), [
    "\"Range bounds must be numeric\"",
  ])
}

///|
test "jq 1.8.2 range emits a value before an invalid step addition" {
  @debug.assert_eq(must_run_json_text("try range(0;1;[]) catch .", "null"), [
    "0", "\"number (0) and array ([]) cannot be added\"",
  ])
  @debug.assert_eq(must_run_json_text("try [range(0;1;[])] catch .", "null"), [
    "\"number (0) and array ([]) cannot be added\"",
  ])
}

///|
test "jq 1.8.2 range with three arguments uses JSON comparison and addition" {
  @debug.assert_eq(must_run_json_text("[range(null;3;1)]", "null"), [
    "[null,1,2]",
  ])
  @debug.assert_eq(must_run_json_text("[range(0;null;1)]", "null"), ["[]"])
  @debug.assert_eq(must_run_json_text("[range(\"x\";3;1)]", "null"), ["[]"])
  @debug.assert_eq(must_run_json_text("[range(0;0;[])]", "null"), ["[]"])
  @debug.assert_eq(must_run_json_text("[range(0;3;null)]", "null"), ["[]"])
  @debug.assert_eq(must_run_json_text("[range(0;-10;-3)]", "null"), [
    "[0,-3,-6,-9]",
  ])
}

///|
// jq master fix 6aeafff056a988c20672ac1359b2beea13fb9315, after jq 1.8.2.
// Lock intended outputs independently of the narrowly declared oracle exceptions.
test "gmtime floors negative fractional timestamps as fixed upstream does" {
  @debug.assert_eq(must_run_json_text("gmtime", "-1.25"), [
    "[1969,11,31,23,59,58.75,3,364]",
  ])
  @debug.assert_eq(
    must_run_json_text("map(gmtime) | . == sort", "[-1.5,-1,-0.5,0,0.5,1,1.5]"),
    ["true"],
  )
}
