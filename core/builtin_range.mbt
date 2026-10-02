///|
fn range_bound_number(value : Value) -> Double raise EvalError {
  match value {
    Number(n, _) => n
    _ => raise TypeError("Range bounds must be numeric")
  }
}

///|
fn range_less_than(left : Value, right : Value) -> Bool raise EvalError {
  match (left, right) {
    (Number(x, rx), Number(y, ry)) =>
      match (rx, ry) {
        (Some(a), Some(b)) =>
          match decimal_compare_repr(a, b) {
            Some(cmp) => cmp < 0
            None => x < y
          }
        _ => x < y
      }
    _ => compare_json(left, right) < 0
  }
}

///|
// jq 1.8.2 implements range/3 with while/comparison/addition in builtin.jq,
// unlike its numeric-bound-checked range/1-2. Keep the emitted error prefix.
fn append_stepped_range_outputs(
  out : Array[Value],
  start : Value,
  end : Value,
  step : Value,
) -> Unit raise EvalError {
  let zero = Value::number(0.0)
  let ascending = range_less_than(zero, step)
  let descending = range_less_than(step, zero)
  if !ascending && !descending {
    return
  }
  let mut current = start
  while (if ascending {
          range_less_than(current, end)
        } else {
          range_less_than(end, current)
        }) {
    out.push(current)
    current = try json_add_pair(current, step) catch {
      err => raise_with_prefix(out, err)
    } noraise {
      value => value
    }
  }
}
