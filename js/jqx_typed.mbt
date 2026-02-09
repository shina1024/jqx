///|
/// Minimal typed DSL scaffold for the JS/TS Typed lane.
/// This keeps type parameters at the API boundary while reusing the core AST.

///|
pub struct Query[I, O] {
  filter : @core.Filter
  _input : I?
  _output : O?
}

///|
fn[I, O] query_of_filter(filter : @core.Filter) -> Query[I, O] {
  { filter, _input: None, _output: None }
}

///|
pub fn[I, O] Query::toFilter(query : Query[I, O]) -> @core.Filter {
  query.filter
}

///|
pub fn identity() -> Query[@core.Json, @core.Json] {
  query_of_filter(@core.Filter::identity())
}

///|
pub fn field(name : String) -> Query[@core.Json, @core.Json] {
  query_of_filter(
    @core.Filter::pipe(@core.Filter::identity(), @core.Filter::field(name)),
  )
}

///|
pub fn index(i : Int) -> Query[@core.Json, @core.Json] {
  query_of_filter(
    @core.Filter::pipe(@core.Filter::identity(), @core.Filter::index(i)),
  )
}

///|
pub fn pipe(
  left : Query[@core.Json, @core.Json],
  right : Query[@core.Json, @core.Json],
) -> Query[@core.Json, @core.Json] {
  query_of_filter(@core.Filter::pipe(left.filter, right.filter))
}

///|
pub fn map(
  inner : Query[@core.Json, @core.Json],
) -> Query[@core.Json, @core.Json] {
  query_of_filter(@core.Filter::call("map", [inner.filter]))
}

///|
pub fn evalQuery(
  query : Query[@core.Json, @core.Json],
  input : @core.Json,
) -> Result[Array[@core.Json], String] {
  Ok(@core.eval(query.filter, input)) catch {
    err => Err(err.to_string())
  }
}

///|
pub fn runQuery(
  query : Query[@core.Json, @core.Json],
  input : String,
) -> Result[Array[String], String] {
  try {
    let json = @core.parse(input)
    let values = @core.eval(query.filter, json)
    let out = []
    for v in values {
      out.push(v.to_json_string())
    }
    Ok(out)
  } catch {
    err => Err(err.to_string())
  }
}
