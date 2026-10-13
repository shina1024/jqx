///|
fn strftime_locale_format(
  pattern : String,
  year : Int32,
  month : Int32,
  day : Int32,
  hour : Int32,
  minute : Int32,
  second : Int32,
  day_of_week : Int32,
  day_of_year : Int32,
) -> String? {
  ignore(
    (pattern, year, month, day, hour, minute, second, day_of_week, day_of_year),
  )
  None
}
