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

///|
test "upstream strptime defaults missing date fields to January first 1900" {
  // Upstream #3679; jq 1.8.2 defaults to day zero instead.
  @debug.assert_eq(
    must_run_json_text(
      "[(\"2024-06\" | strptime(\"%Y-%m\")), (\"2024\" | strptime(\"%Y\")) | ., todate]",
      "null",
    ),
    [
      "[[2024,5,1,0,0,0,6,152],\"2024-06-01T00:00:00Z\",[2024,0,1,0,0,0,1,0],\"2024-01-01T00:00:00Z\"]",
    ],
  )
  @debug.assert_eq(
    must_run_json_text("\"10:15\" | strptime(\"%H:%M\")", "null"),
    ["[1900,0,1,10,15,0,1,0]"],
  )
  @debug.assert_eq(
    must_run_json_text("strptime(\"%Y-%m-%d\")", "\"1900-02-28\""),
    ["[1900,1,28,0,0,0,3,58]"],
  )
  @debug.assert_eq(
    must_run_json_text(
      "[\"2024-13\",\"2024-\",\"2024-06x\"] | map(try strptime(\"%Y-%m\") catch \"ERR\")",
      "null",
    ),
    ["[\"ERR\",\"ERR\",\"ERR\"]"],
  )
  @debug.assert_eq(
    must_run_json_text(
      "[\"24:15\",\"10:60\"] | map(try strptime(\"%H:%M\") catch \"ERR\")", "null",
    ),
    ["[\"ERR\",\"ERR\"]"],
  )
  @debug.assert_eq(
    must_run_json_text("try strptime(\"%Y-%m\") catch .", "\"2024-13\""),
    ["\"date \\\"2024-13\\\" does not match format \\\"%Y-%m\\\"\""],
  )
}

///|
test "jq 1.8.2 fromdateiso8601 parses UTC dates and normalizes calendar overflow" {
  @debug.assert_eq(
    must_run_json_text("fromdateiso8601", "\"2015-03-05T23:51:47Z\""),
    ["1425599507"],
  )
  @debug.assert_eq(
    must_run_json_text("fromdateiso8601", "\"2015-02-30T00:00:00Z\""),
    ["1425254400"],
  )
  @debug.assert_eq(
    must_run_json_text("fromdateiso8601", "\"2015-03-05T23:51:60Z\""),
    ["1425599520"],
  )
  @debug.assert_eq(
    must_run_json_text("fromdateiso8601", "\"2015-3-5T3:1:7Z\""),
    ["1425524467"],
  )
  @debug.assert_eq(
    must_run_json_text("fromdateiso8601", "\"2015-03-05T23:51:47Z trailing\""),
    ["1425599507"],
  )
  @debug.assert_eq(must_run_json_text("fromdate", "\"2015-02-30T00:00:00Z\""), [
    "1425254400",
  ])
}

///|
test "jq 1.8.2 fromdateiso8601 rejects unsupported inputs with jq errors" {
  @debug.assert_eq(
    must_run_json_text(
      "try fromdateiso8601 catch .", "\"2015-03-05T23:51:47+00:00\"",
    ),
    [
      "\"date \\\"2015-03-05T23:51:47+00:00\\\" does not match format \\\"%Y-%m-%dT%H:%M:%SZ\\\"\"",
    ],
  )
  @debug.assert_eq(must_run_json_text("try fromdateiso8601 catch .", "null"), [
    "\"strptime/1 requires string inputs and arguments\"",
  ])
  @debug.assert_eq(must_run_json_text("try fromdate catch .", "\"bad\""), [
    "\"date \\\"bad\\\" does not match format \\\"%Y-%m-%dT%H:%M:%SZ\\\"\"",
  ])
}

///|
test "upstream fromdateiso8601 rejects surrounding whitespace" {
  @debug.assert_eq(
    must_run_json_text(
      "[(\" 2015-03-05T23:51:47Z\", \"2015-03-05T23:51:47Z \") | try fromdateiso8601 catch \"ERR\"]",
      "null",
    ),
    ["[\"ERR\",\"ERR\"]"],
  )
}

///|
test "upstream strftime reports an oversized formatted result" {
  @debug.assert_eq(
    must_run_json_text("try strftime(\"%Y\" * 50) catch .", "0"),
    ["\"strftime/1: result too long\""],
  )
  @debug.assert_eq(
    must_run_json_text(
      "try strflocaltime(\"%Y\" * 50) catch .", "[2015,2,5,23,51,47,4,63]",
    ),
    ["\"strflocaltime/1: result too long\""],
  )
}

///|
test "jq 1.8.2 todate aliases format timestamps and parsed datetime arrays" {
  @debug.assert_eq(must_run_json_text("todate", "1425599507"), [
    "\"2015-03-05T23:51:47Z\"",
  ])
  @debug.assert_eq(must_run_json_text("todateiso8601", "1425599507.5"), [
    "\"2015-03-05T23:51:47Z\"",
  ])
  @debug.assert_eq(must_run_json_text("todate", "4102444800"), [
    "\"2100-01-01T00:00:00Z\"",
  ])
  @debug.assert_eq(must_run_json_text("todate", "-1"), [
    "\"1969-12-31T23:59:59Z\"",
  ])
  @debug.assert_eq(must_run_json_text("todate", "[2015,2,5,23,51,47,4,63]"), [
    "\"2015-03-05T23:51:47Z\"",
  ])
  @debug.assert_eq(
    must_run_json_text("fromdateiso8601 | todate", "\"2015-06-30T23:59:60Z\""),
    ["\"2015-07-01T00:00:00Z\""],
  )
}

///|
test "jq 1.8.2 todate aliases retain strftime input errors" {
  @debug.assert_eq(must_run_json_text("try todate catch .", "null"), [
    "\"strftime/1 requires parsed datetime inputs\"",
  ])
  @debug.assert_eq(must_run_json_text("try todateiso8601 catch .", "\"x\""), [
    "\"strftime/1 requires parsed datetime inputs\"",
  ])
  @debug.assert_eq(
    must_run_json_text(
      "builtins | map(select(. == \"todate/0\" or . == \"todateiso8601/0\")) | sort",
      "null",
    ),
    ["[\"todate/0\",\"todateiso8601/0\"]"],
  )
}
