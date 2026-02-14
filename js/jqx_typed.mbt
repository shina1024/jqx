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
/// Additional typed-lane combinators (still Json -> Json focused).
/// These keep typed DSL authoring practical without exposing raw AST builders.

///|
pub fn literal(value : @core.Json) -> Query[@core.Json, @core.Json] {
  query_of_filter(@core.Filter::literal(value))
}

///|
pub fn iter() -> Query[@core.Json, @core.Json] {
  query_of_filter(@core.Filter::iter())
}

///|
pub fn comma(
  left : Query[@core.Json, @core.Json],
  right : Query[@core.Json, @core.Json],
) -> Query[@core.Json, @core.Json] {
  query_of_filter(@core.Filter::comma(left.filter, right.filter))
}

///|
pub fn call(
  name : String,
  args : Array[Query[@core.Json, @core.Json]],
) -> Query[@core.Json, @core.Json] {
  query_of_filter(@core.Filter::call(name, args.map(q => q.filter)))
}

///|
pub fn select(
  pred : Query[@core.Json, @core.Json],
) -> Query[@core.Json, @core.Json] {
  call("select", [pred])
}

///|
pub fn eq(
  left : Query[@core.Json, @core.Json],
  right : Query[@core.Json, @core.Json],
) -> Query[@core.Json, @core.Json] {
  query_of_filter(@core.Filter::eq(left.filter, right.filter))
}

///|
pub fn add(
  left : Query[@core.Json, @core.Json],
  right : Query[@core.Json, @core.Json],
) -> Query[@core.Json, @core.Json] {
  query_of_filter(@core.Filter::add(left.filter, right.filter))
}

///|
pub fn fallback(
  left : Query[@core.Json, @core.Json],
  right : Query[@core.Json, @core.Json],
) -> Query[@core.Json, @core.Json] {
  query_of_filter(@core.Filter::fallback(left.filter, right.filter))
}

///|
pub fn try_catch(
  inner : Query[@core.Json, @core.Json],
  handler : Query[@core.Json, @core.Json],
) -> Query[@core.Json, @core.Json] {
  query_of_filter(@core.Filter::try_catch(inner.filter, handler.filter))
}

///|
pub fn executeQuery(
  query : Query[@core.Json, @core.Json],
  input : @core.Json,
) -> Result[Array[@core.Json], String] {
  Ok(@core.execute(query.filter, input)) catch {
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
    let values = @core.execute(query.filter, json)
    let out = []
    for v in values {
      out.push(v.to_json_string())
    }
    Ok(out)
  } catch {
    err => Err(err.to_string())
  }
}
