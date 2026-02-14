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
fn builtin_call_numeric(
  name : String,
  args : Array[Filter],
  input : Json,
  env : Map[String, Json],
) -> Array[Json]? raise EvalError {
  match name {
    "pow" =>
      if args.length() != 2 {
        raise UnknownFunction("pow")
      } else {
        let bases = eval_with_env(args[0], input, env)
        let exponents = eval_with_env(args[1], input, env)
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
          eval_with_env(args[0], input, env)
        }
        let ends = if args.length() == 1 {
          eval_with_env(args[0], input, env)
        } else {
          eval_with_env(args[1], input, env)
        }
        let steps = if args.length() >= 3 {
          eval_with_env(args[2], input, env)
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
