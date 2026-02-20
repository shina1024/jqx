///|
fn call_require_number(name : String, value : Json) -> Double raise EvalError {
  match value {
    Number(n, _) => n
    _ => raise TypeError(name + "() requires numeric arguments")
  }
}

///|
fn append_range_outputs(
  out : Array[Json],
  start : Double,
  end : Double,
  step : Double,
) -> Unit raise EvalError {
  if step == 0.0 || step != step {
    raise TypeError("range() step cannot be zero")
  }
  let mut current = start
  if step > 0.0 {
    for {
      if current < end {
        out.push(json_number_value(current))
        current += step
        continue
      }
      break
    }
  } else {
    for {
      if current > end {
        out.push(json_number_value(current))
        current += step
        continue
      }
      break
    }
  }
}

///|
fn parse_decimal_digits(s : String, start : Int, count : Int) -> Int? {
  if start < 0 || count < 0 || start + count > s.length() {
    return None
  }
  let mut value = 0
  for i in 0..<count {
    let code = s.unsafe_get(start + i).to_int()
    if code < '0'.to_int() || code > '9'.to_int() {
      return None
    }
    value = value * 10 + (code - '0'.to_int())
  }
  Some(value)
}

///|
fn is_leap_year(year : Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

///|
fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 => 31
    2 => if is_leap_year(year) { 29 } else { 28 }
    3 => 31
    4 => 30
    5 => 31
    6 => 30
    7 => 31
    8 => 31
    9 => 30
    10 => 31
    11 => 30
    12 => 31
    _ => 0
  }
}

///|
fn days_from_civil(year : Int, month : Int, day : Int) -> Int {
  let adjusted_year = if month <= 2 { year - 1 } else { year }
  let era = if adjusted_year >= 0 {
    adjusted_year / 400
  } else {
    (adjusted_year - 399) / 400
  }
  let year_of_era = adjusted_year - era * 400
  let shifted_month = if month > 2 { month - 3 } else { month + 9 }
  let day_of_year = (153 * shifted_month + 2) / 5 + day - 1
  let day_of_era = year_of_era * 365 +
    year_of_era / 4 -
    year_of_era / 100 +
    day_of_year
  era * 146097 + day_of_era - 719468
}

///|
fn parse_rfc3339_utc_seconds(s : String) -> Double? {
  if s.length() != 20 {
    return None
  }
  guard s.unsafe_get(4).to_int().unsafe_to_char() == '-' else { return None }
  guard s.unsafe_get(7).to_int().unsafe_to_char() == '-' else { return None }
  guard s.unsafe_get(10).to_int().unsafe_to_char() == 'T' else { return None }
  guard s.unsafe_get(13).to_int().unsafe_to_char() == ':' else { return None }
  guard s.unsafe_get(16).to_int().unsafe_to_char() == ':' else { return None }
  guard s.unsafe_get(19).to_int().unsafe_to_char() == 'Z' else { return None }

  let year = match parse_decimal_digits(s, 0, 4) {
    Some(v) => v
    None => return None
  }
  let month = match parse_decimal_digits(s, 5, 2) {
    Some(v) => v
    None => return None
  }
  let day = match parse_decimal_digits(s, 8, 2) {
    Some(v) => v
    None => return None
  }
  let hour = match parse_decimal_digits(s, 11, 2) {
    Some(v) => v
    None => return None
  }
  let minute = match parse_decimal_digits(s, 14, 2) {
    Some(v) => v
    None => return None
  }
  let second = match parse_decimal_digits(s, 17, 2) {
    Some(v) => v
    None => return None
  }

  if month < 1 || month > 12 {
    return None
  }
  let max_day = days_in_month(year, month)
  if day < 1 || day > max_day {
    return None
  }
  if hour < 0 || hour > 23 {
    return None
  }
  if minute < 0 || minute > 59 {
    return None
  }
  if second < 0 || second > 59 {
    return None
  }

  let days = days_from_civil(year, month, day).to_double()
  let total = days * 86400.0 +
    hour.to_double() * 3600.0 +
    minute.to_double() * 60.0 +
    second.to_double()
  Some(total)
}

///|
fn floor_div_int(a : Int, b : Int) -> Int {
  if a >= 0 {
    a / b
  } else {
    -((-a + b - 1) / b)
  }
}

///|
fn positive_mod_int(a : Int, m : Int) -> Int {
  let r = a % m
  if r < 0 {
    r + m
  } else {
    r
  }
}

///|
fn civil_from_days(z : Int) -> (Int, Int, Int) {
  let shifted = z + 719468
  let era = if shifted >= 0 {
    shifted / 146097
  } else {
    (shifted - 146096) / 146097
  }
  let day_of_era = shifted - era * 146097
  let year_of_era = (
      day_of_era - day_of_era / 1460 + day_of_era / 36524 - day_of_era / 146096
    ) /
    365
  let year_base = year_of_era + era * 400
  let day_of_year = day_of_era -
    (365 * year_of_era + year_of_era / 4 - year_of_era / 100)
  let month_prime = (5 * day_of_year + 2) / 153
  let day = day_of_year - (153 * month_prime + 2) / 5 + 1
  let month = month_prime + (if month_prime < 10 { 3 } else { -9 })
  let year = year_base + (if month <= 2 { 1 } else { 0 })
  (year, month, day)
}

///|
fn day_of_year_from_date(year : Int, month : Int, day : Int) -> Int {
  days_from_civil(year, month, day) - days_from_civil(year, 1, 1)
}

///|
fn epoch_seconds_to_datetime_components(
  seconds : Double,
) -> (Int, Int, Int, Int, Int, Double, Int, Int) {
  let whole = seconds.floor().to_int()
  let frac = seconds - whole.to_double()
  let days = floor_div_int(whole, 86400)
  let seconds_of_day = whole - days * 86400
  let hour = seconds_of_day / 3600
  let minute = seconds_of_day % 3600 / 60
  let second = (seconds_of_day % 60).to_double() + frac
  let (year, month, day) = civil_from_days(days)
  let day_of_year = day_of_year_from_date(year, month, day)
  let day_of_week = positive_mod_int(days + 4, 7)
  (year, month, day, hour, minute, second, day_of_week, day_of_year)
}

///|
fn datetime_component_number_required(
  a : Array[Json],
  index : Int,
  fn_name : String,
) -> Double raise EvalError {
  if index >= a.length() {
    raise TypeError(fn_name + " requires parsed datetime inputs")
  }
  match a[index] {
    Number(n, _) => n
    _ => raise TypeError(fn_name + " requires parsed datetime inputs")
  }
}

///|
fn datetime_component_number_default(
  a : Array[Json],
  index : Int,
  default_ : Double,
  fn_name : String,
) -> Double raise EvalError {
  if index >= a.length() {
    return default_
  }
  match a[index] {
    Number(n, _) => n
    _ => raise TypeError(fn_name + " requires parsed datetime inputs")
  }
}

///|
fn datetime_component_int_required(
  a : Array[Json],
  index : Int,
  fn_name : String,
) -> Int raise EvalError {
  datetime_component_number_required(a, index, fn_name).floor().to_int()
}

///|
fn datetime_component_int_default(
  a : Array[Json],
  index : Int,
  default_ : Int,
  fn_name : String,
) -> Int raise EvalError {
  datetime_component_number_default(a, index, default_.to_double(), fn_name)
  .floor()
  .to_int()
}

///|
fn parse_datetime_array_input(
  input : Json,
  fn_name : String,
) -> (Int, Int, Int, Int, Int, Double) raise EvalError {
  match input {
    Array(a) => {
      if a.length() < 3 {
        raise TypeError(fn_name + " requires parsed datetime inputs")
      }
      let year = datetime_component_int_required(a, 0, fn_name)
      let month_zero_based = datetime_component_int_required(a, 1, fn_name)
      let day = datetime_component_int_required(a, 2, fn_name)
      let hour = datetime_component_int_default(a, 3, 0, fn_name)
      let minute = datetime_component_int_default(a, 4, 0, fn_name)
      let second = datetime_component_number_default(a, 5, 0.0, fn_name)

      let month = month_zero_based + 1
      if month < 1 || month > 12 {
        raise TypeError(fn_name + " requires parsed datetime inputs")
      }
      let max_day = days_in_month(year, month)
      if day < 1 || day > max_day {
        raise TypeError(fn_name + " requires parsed datetime inputs")
      }
      if hour < 0 || hour > 23 || minute < 0 || minute > 59 {
        raise TypeError(fn_name + " requires parsed datetime inputs")
      }
      if second < 0.0 || second >= 60.0 {
        raise TypeError(fn_name + " requires parsed datetime inputs")
      }

      (year, month, day, hour, minute, second)
    }
    _ => raise TypeError(fn_name + " requires parsed datetime inputs")
  }
}

///|
fn datetime_input_to_format_components(
  input : Json,
  fn_name : String,
) -> (Int, Int, Int, Int, Int, Double, Int, Int) raise EvalError {
  match input {
    Number(seconds, _) => epoch_seconds_to_datetime_components(seconds)
    Array(_) => {
      let (year, month, day, hour, minute, second) = parse_datetime_array_input(
        input, fn_name,
      )
      let days = days_from_civil(year, month, day)
      let day_of_week = positive_mod_int(days + 4, 7)
      let day_of_year = day_of_year_from_date(year, month, day)
      (year, month, day, hour, minute, second, day_of_week, day_of_year)
    }
    _ => raise TypeError(fn_name + " requires parsed datetime inputs")
  }
}

///|
fn datetime_components_to_epoch_seconds(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Double,
) -> Double {
  let days = days_from_civil(year, month, day).to_double()
  days * 86400.0 +
  hour.to_double() * 3600.0 +
  minute.to_double() * 60.0 +
  second
}

///|
fn datetime_components_to_json_array(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Double,
  day_of_week : Int,
  day_of_year : Int,
) -> Json {
  Json::array([
    json_number_value(year.to_double()),
    json_number_value((month - 1).to_double()),
    json_number_value(day.to_double()),
    json_number_value(hour.to_double()),
    json_number_value(minute.to_double()),
    json_number_value(second),
    json_number_value(day_of_week.to_double()),
    json_number_value(day_of_year.to_double()),
  ])
}

///|
fn weekday_name_english(day_of_week : Int) -> String {
  match positive_mod_int(day_of_week, 7) {
    0 => "Sunday"
    1 => "Monday"
    2 => "Tuesday"
    3 => "Wednesday"
    4 => "Thursday"
    5 => "Friday"
    _ => "Saturday"
  }
}

///|
fn month_name_english(month : Int) -> String {
  match month {
    1 => "January"
    2 => "February"
    3 => "March"
    4 => "April"
    5 => "May"
    6 => "June"
    7 => "July"
    8 => "August"
    9 => "September"
    10 => "October"
    11 => "November"
    _ => "December"
  }
}

///|
fn format_two_digits_zero(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn format_two_digits_space(n : Int) -> String {
  if n < 10 {
    " " + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn format_datetime_with_strftime_pattern(
  pattern : String,
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Double,
  day_of_week : Int,
) -> String {
  let sb = StringBuilder::new()
  let second_int = second.floor().to_int()
  let mut i = 0
  for {
    if i >= pattern.length() {
      break
    }
    let ch = pattern.unsafe_get(i).to_int().unsafe_to_char()
    if ch != '%' {
      sb.write_char(ch)
      i += 1
      continue
    }
    if i + 1 >= pattern.length() {
      sb.write_char('%')
      i += 1
      continue
    }
    let token = pattern.unsafe_get(i + 1).to_int().unsafe_to_char()
    match token {
      '%' => sb.write_char('%')
      'Y' => sb.write_string(year.to_string())
      'm' => sb.write_string(format_two_digits_zero(month))
      'd' => sb.write_string(format_two_digits_zero(day))
      'e' => sb.write_string(format_two_digits_space(day))
      'H' => sb.write_string(format_two_digits_zero(hour))
      'M' => sb.write_string(format_two_digits_zero(minute))
      'S' => sb.write_string(format_two_digits_zero(second_int))
      'A' => sb.write_string(weekday_name_english(day_of_week))
      'B' => sb.write_string(month_name_english(month))
      _ => {
        sb.write_char('%')
        sb.write_char(token)
      }
    }
    i += 2
  }
  sb.to_string()
}

///|
fn strptime_utc_fixed_format(
  input : String,
  pattern : String,
) -> (Int, Int, Int, Int, Int, Double, Int, Int)? {
  if pattern != "%Y-%m-%dT%H:%M:%SZ" {
    return None
  }
  match parse_rfc3339_utc_seconds(input) {
    Some(seconds) => Some(epoch_seconds_to_datetime_components(seconds))
    None => None
  }
}

///|
fn gmtime_json(input : Json) -> Json raise EvalError {
  match input {
    Number(seconds, _) => {
      let (year, month, day, hour, minute, second, day_of_week, day_of_year) = epoch_seconds_to_datetime_components(
        seconds,
      )
      datetime_components_to_json_array(
        year, month, day, hour, minute, second, day_of_week, day_of_year,
      )
    }
    _ => raise TypeError("gmtime requires numeric inputs")
  }
}

///|
fn mktime_json(input : Json) -> Json raise EvalError {
  let (year, month, day, hour, minute, second) = parse_datetime_array_input(
    input, "mktime",
  )
  json_number_value(
    datetime_components_to_epoch_seconds(year, month, day, hour, minute, second),
  )
}

///|
fn builtin_call_numeric(
  name : String,
  args : Array[Filter],
  input : Json,
  env : Map[String, Json],
) -> Array[Json]? raise EvalError {
  match name {
    "__neg" =>
      if args.length() != 1 {
        raise UnknownFunction("__neg")
      } else {
        let values = execute_with_env(args[0], input, env)
        let out = []
        for value in values {
          match value {
            Number(n, _) => out.push(json_number_value(-n))
            String(s) =>
              raise TypeError(
                format_filter_string_type_with_preview(s) + " cannot be negated",
              )
            _ =>
              raise TypeError(
                json_type_with_value(value) + " cannot be negated",
              )
          }
        }
        Some(out)
      }
    "pow" =>
      if args.length() != 2 {
        raise UnknownFunction("pow")
      } else {
        let bases = execute_with_env(args[0], input, env)
        let exponents = execute_with_env(args[1], input, env)
        let out = []
        for base_value in bases {
          let base = call_require_number("pow", base_value)
          for exponent_value in exponents {
            let exponent = call_require_number("pow", exponent_value)
            out.push(json_number_value(@math.pow(base, exponent)))
          }
        }
        Some(out)
      }
    "strftime" =>
      if args.length() != 1 {
        raise UnknownFunction("strftime")
      } else {
        let formats = execute_with_env(args[0], input, env)
        let (year, month, day, hour, minute, second, day_of_week, _day_of_year) = datetime_input_to_format_components(
          input, "strftime/1",
        )
        let out = []
        for format_value in formats {
          match format_value {
            String(pattern) =>
              out.push(
                Json::string(
                  format_datetime_with_strftime_pattern(
                    pattern, year, month, day, hour, minute, second, day_of_week,
                  ),
                ),
              )
            _ => raise TypeError("strftime/1 requires a string format")
          }
        }
        Some(out)
      }
    "strflocaltime" =>
      if args.length() != 1 {
        raise UnknownFunction("strflocaltime")
      } else {
        let formats = execute_with_env(args[0], input, env)
        let (year, month, day, hour, minute, second, day_of_week, _day_of_year) = datetime_input_to_format_components(
          input, "strflocaltime/1",
        )
        let out = []
        for format_value in formats {
          match format_value {
            String(pattern) =>
              out.push(
                Json::string(
                  format_datetime_with_strftime_pattern(
                    pattern, year, month, day, hour, minute, second, day_of_week,
                  ),
                ),
              )
            _ => raise TypeError("strflocaltime/1 requires a string format")
          }
        }
        Some(out)
      }
    "strptime" =>
      if args.length() != 1 {
        raise UnknownFunction("strptime")
      } else {
        let input_text = match input {
          String(s) => s
          _ => raise TypeError("strptime/1 requires string inputs")
        }
        let formats = execute_with_env(args[0], input, env)
        let out = []
        for format_value in formats {
          match format_value {
            String(pattern) =>
              match strptime_utc_fixed_format(input_text, pattern) {
                Some(
                  (
                    year,
                    month,
                    day,
                    hour,
                    minute,
                    second,
                    day_of_week,
                    day_of_year,
                  )
                ) =>
                  out.push(
                    datetime_components_to_json_array(
                      year, month, day, hour, minute, second, day_of_week, day_of_year,
                    ),
                  )
                None =>
                  raise TypeError(
                    "strptime/1 requires format \"%Y-%m-%dT%H:%M:%SZ\" and matching input",
                  )
              }
            _ => raise TypeError("strptime/1 requires a string format")
          }
        }
        Some(out)
      }
    "fromdate" =>
      if args.length() != 0 {
        raise UnknownFunction("fromdate")
      } else {
        match input {
          String(s) =>
            match parse_rfc3339_utc_seconds(s) {
              Some(seconds) => Some([json_number_value(seconds)])
              None =>
                raise TypeError(
                  "fromdate input must be RFC3339 UTC (YYYY-MM-DDTHH:MM:SSZ)",
                )
            }
          _ => raise TypeError("fromdate input must be a string")
        }
      }
    "env" =>
      if args.length() != 0 {
        raise UnknownFunction("env")
      } else {
        Some([Json::object(Map::new())])
      }
    "range" =>
      if args.length() == 0 || args.length() > 3 {
        raise UnknownFunction("range")
      } else {
        let starts = if args.length() == 1 {
          [Json::number(0.0)]
        } else {
          execute_with_env(args[0], input, env)
        }
        let ends = if args.length() == 1 {
          execute_with_env(args[0], input, env)
        } else {
          execute_with_env(args[1], input, env)
        }
        let steps = if args.length() >= 3 {
          execute_with_env(args[2], input, env)
        } else {
          [Json::number(1.0)]
        }
        let out = []
        for start_value in starts {
          let start = call_require_number("range", start_value)
          for end_value in ends {
            let end = call_require_number("range", end_value)
            for step_value in steps {
              let step = call_require_number("range", step_value)
              append_range_outputs(out, start, end, step)
            }
          }
        }
        Some(out)
      }
    _ => None
  }
}
