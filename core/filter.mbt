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
  FieldOpt(String)
  Index(Int)
  IndexOpt(Int)
  Iter
  IterOpt
  Literal(Json)
  Array(Array[Filter])
  Object(Array[(String, Filter)])
  Builtin(String)
  Call(String, Array[Filter])
  Var(String)
  As(Filter, String, Filter)
  Try(Filter)
  TryCatch(Filter, Filter)
  Reduce(Filter, String, Filter, Filter)
  Foreach(Filter, String, Filter, Filter, Filter)
  Eq(Filter, Filter)
  Neq(Filter, Filter)
  Lt(Filter, Filter)
  Lte(Filter, Filter)
  Gt(Filter, Filter)
  Gte(Filter, Filter)
  And(Filter, Filter)
  Or(Filter, Filter)
  Not(Filter)
  Add(Filter, Filter)
  Sub(Filter, Filter)
  Mul(Filter, Filter)
  Div(Filter, Filter)
  IfElse(Filter, Filter, Filter)
  Fallback(Filter, Filter)
  Empty
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
pub fn Filter::field_opt(name : String) -> Filter {
  FieldOpt(name)
}

///|
pub fn Filter::index(i : Int) -> Filter {
  Index(i)
}

///|
pub fn Filter::index_opt(i : Int) -> Filter {
  IndexOpt(i)
}

///|
pub fn Filter::iter() -> Filter {
  Iter
}

///|
pub fn Filter::iter_opt() -> Filter {
  IterOpt
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

///|
pub fn Filter::builtin(name : String) -> Filter {
  Builtin(name)
}

///|
pub fn Filter::call(name : String, args : Array[Filter]) -> Filter {
  Call(name, args)
}

///|
pub fn Filter::var_(name : String) -> Filter {
  Var(name)
}

///|
pub fn Filter::as_(value : Filter, name : String, body : Filter) -> Filter {
  As(value, name, body)
}

///|
pub fn Filter::try_(inner : Filter) -> Filter {
  Try(inner)
}

///|
pub fn Filter::try_catch(inner : Filter, handler : Filter) -> Filter {
  TryCatch(inner, handler)
}

///|
pub fn Filter::reduce(
  source : Filter,
  name : String,
  init : Filter,
  update : Filter,
) -> Filter {
  Reduce(source, name, init, update)
}

///|
pub fn Filter::foreach(
  source : Filter,
  name : String,
  init : Filter,
  update : Filter,
  extract : Filter,
) -> Filter {
  Foreach(source, name, init, update, extract)
}

///|
pub fn Filter::eq(left : Filter, right : Filter) -> Filter {
  Eq(left, right)
}

///|
pub fn Filter::neq(left : Filter, right : Filter) -> Filter {
  Neq(left, right)
}

///|
pub fn Filter::lt(left : Filter, right : Filter) -> Filter {
  Lt(left, right)
}

///|
pub fn Filter::lte(left : Filter, right : Filter) -> Filter {
  Lte(left, right)
}

///|
pub fn Filter::gt(left : Filter, right : Filter) -> Filter {
  Gt(left, right)
}

///|
pub fn Filter::gte(left : Filter, right : Filter) -> Filter {
  Gte(left, right)
}

///|
pub fn Filter::and_(left : Filter, right : Filter) -> Filter {
  And(left, right)
}

///|
pub fn Filter::or_(left : Filter, right : Filter) -> Filter {
  Or(left, right)
}

///|
pub fn Filter::not(inner : Filter) -> Filter {
  Not(inner)
}

///|
pub fn Filter::add(left : Filter, right : Filter) -> Filter {
  Add(left, right)
}

///|
pub fn Filter::sub(left : Filter, right : Filter) -> Filter {
  Sub(left, right)
}

///|
pub fn Filter::mul(left : Filter, right : Filter) -> Filter {
  Mul(left, right)
}

///|
pub fn Filter::div(left : Filter, right : Filter) -> Filter {
  Div(left, right)
}

///|
pub fn Filter::if_else(
  cond : Filter,
  then_branch : Filter,
  else_branch : Filter,
) -> Filter {
  IfElse(cond, then_branch, else_branch)
}

///|
pub fn Filter::fallback(left : Filter, right : Filter) -> Filter {
  Fallback(left, right)
}

///|
pub fn Filter::empty() -> Filter {
  Empty
}
