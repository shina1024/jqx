///|
/// jq filter AST (minimal core)
///
/// Start from core jq features:
/// - Identity: .
/// - Pipe: a | b
/// - Comma: a, b
/// - Field: .foo
/// - Index: .[n]
/// - Iter: .[]
/// - Literal JSON values
///
/// This is intentionally small and can be extended later.

///|
pub enum Filter {
  Identity
  Pipe(Filter, Filter)
  Comma(Filter, Filter)
  Field(String)
  Index(Int)
  Iter
  Literal(Json)
  Array(Filter)
  Object(Array[(String, Filter)])
} derive(Eq, Show)

///|
pub fn Filter::identity() -> Filter {
  Identity
}

///|
pub fn Filter::field(name : String) -> Filter {
  Field(name)
}

///|
pub fn Filter::index(i : Int) -> Filter {
  Index(i)
}

///|
pub fn Filter::iter() -> Filter {
  Iter
}

///|
pub fn Filter::literal(value : Json) -> Filter {
  Literal(value)
}

///|
pub fn Filter::pipe(left : Filter, right : Filter) -> Filter {
  Pipe(left, right)
}

///|
pub fn Filter::comma(left : Filter, right : Filter) -> Filter {
  Comma(left, right)
}
