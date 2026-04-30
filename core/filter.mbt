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
  Scope(Array[(String, Array[String], Filter)], Filter)
  Pipe(Filter, Filter)
  Comma(Filter, Filter)
  Field(String)
  FieldOpt(String)
  Index(Int)
  IndexOpt(Int)
  Slice(Int?, Int?)
  SliceOpt(Int?, Int?)
  Iter
  IterOpt
  Recurse
  Literal(Value)
  Array(Array[Filter])
  Object(Array[(String, Filter)])
  Builtin(String)
  Call(String, Array[Filter])
  Var(String)
  As(Filter, String, Filter)
  Label(String, Filter)
  Break(String)
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
  Mod(Filter, Filter)
  IfElse(Filter, Filter, Filter)
  Fallback(Filter, Filter)
  Empty
} derive(Eq)

///|
fn show_named_variant0(name : String, logger : &Logger) -> Unit {
  logger.write_string(name)
}

///|
fn[T : Show] show_named_variant1(
  name : String,
  arg : T,
  logger : &Logger,
) -> Unit {
  logger.write_string(name)
  logger.write_char('(')
  Show::output(arg, logger)
  logger.write_char(')')
}

///|
fn[T1 : Show, T2 : Show] show_named_variant2(
  name : String,
  arg1 : T1,
  arg2 : T2,
  logger : &Logger,
) -> Unit {
  logger.write_string(name)
  logger.write_char('(')
  Show::output(arg1, logger)
  logger.write_string(", ")
  Show::output(arg2, logger)
  logger.write_char(')')
}

///|
fn[T1 : Show, T2 : Show, T3 : Show] show_named_variant3(
  name : String,
  arg1 : T1,
  arg2 : T2,
  arg3 : T3,
  logger : &Logger,
) -> Unit {
  logger.write_string(name)
  logger.write_char('(')
  Show::output(arg1, logger)
  logger.write_string(", ")
  Show::output(arg2, logger)
  logger.write_string(", ")
  Show::output(arg3, logger)
  logger.write_char(')')
}

///|
fn[T1 : Show, T2 : Show, T3 : Show, T4 : Show] show_named_variant4(
  name : String,
  arg1 : T1,
  arg2 : T2,
  arg3 : T3,
  arg4 : T4,
  logger : &Logger,
) -> Unit {
  logger.write_string(name)
  logger.write_char('(')
  Show::output(arg1, logger)
  logger.write_string(", ")
  Show::output(arg2, logger)
  logger.write_string(", ")
  Show::output(arg3, logger)
  logger.write_string(", ")
  Show::output(arg4, logger)
  logger.write_char(')')
}

///|
fn[T1 : Show, T2 : Show, T3 : Show, T4 : Show, T5 : Show] show_named_variant5(
  name : String,
  arg1 : T1,
  arg2 : T2,
  arg3 : T3,
  arg4 : T4,
  arg5 : T5,
  logger : &Logger,
) -> Unit {
  logger.write_string(name)
  logger.write_char('(')
  Show::output(arg1, logger)
  logger.write_string(", ")
  Show::output(arg2, logger)
  logger.write_string(", ")
  Show::output(arg3, logger)
  logger.write_string(", ")
  Show::output(arg4, logger)
  logger.write_string(", ")
  Show::output(arg5, logger)
  logger.write_char(')')
}

///|
fn show_int_option(arg : Int?, logger : &Logger) -> Unit {
  match arg {
    Some(value) => {
      logger.write_string("Some(")
      Show::output(value, logger)
      logger.write_char(')')
    }
    None => logger.write_string("None")
  }
}

///|
pub impl Show for Filter with output(self, logger) {
  match self {
    Identity => show_named_variant0("Identity", logger)
    Scope(defs, body) => show_named_variant2("Scope", defs, body, logger)
    Pipe(left, right) => show_named_variant2("Pipe", left, right, logger)
    Comma(left, right) => show_named_variant2("Comma", left, right, logger)
    Field(name) => show_named_variant1("Field", name, logger)
    FieldOpt(name) => show_named_variant1("FieldOpt", name, logger)
    Index(i) => show_named_variant1("Index", i, logger)
    IndexOpt(i) => show_named_variant1("IndexOpt", i, logger)
    Slice(start, end) => {
      logger.write_string("Slice(")
      show_int_option(start, logger)
      logger.write_string(", ")
      show_int_option(end, logger)
      logger.write_char(')')
    }
    SliceOpt(start, end) => {
      logger.write_string("SliceOpt(")
      show_int_option(start, logger)
      logger.write_string(", ")
      show_int_option(end, logger)
      logger.write_char(')')
    }
    Iter => show_named_variant0("Iter", logger)
    IterOpt => show_named_variant0("IterOpt", logger)
    Recurse => show_named_variant0("Recurse", logger)
    Literal(value) => show_named_variant1("Literal", value, logger)
    Array(items) => show_named_variant1("Array", items, logger)
    Object(entries) => show_named_variant1("Object", entries, logger)
    Builtin(name) => show_named_variant1("Builtin", name, logger)
    Call(name, args) => show_named_variant2("Call", name, args, logger)
    Var(name) => show_named_variant1("Var", name, logger)
    As(value, name, body) =>
      show_named_variant3("As", value, name, body, logger)
    Label(name, body) => show_named_variant2("Label", name, body, logger)
    Break(name) => show_named_variant1("Break", name, logger)
    Try(inner) => show_named_variant1("Try", inner, logger)
    TryCatch(inner, handler) =>
      show_named_variant2("TryCatch", inner, handler, logger)
    Reduce(source, name, init, update) =>
      show_named_variant4("Reduce", source, name, init, update, logger)
    Foreach(source, name, init, update, extract) =>
      show_named_variant5(
        "Foreach", source, name, init, update, extract, logger,
      )
    Eq(left, right) => show_named_variant2("Eq", left, right, logger)
    Neq(left, right) => show_named_variant2("Neq", left, right, logger)
    Lt(left, right) => show_named_variant2("Lt", left, right, logger)
    Lte(left, right) => show_named_variant2("Lte", left, right, logger)
    Gt(left, right) => show_named_variant2("Gt", left, right, logger)
    Gte(left, right) => show_named_variant2("Gte", left, right, logger)
    And(left, right) => show_named_variant2("And", left, right, logger)
    Or(left, right) => show_named_variant2("Or", left, right, logger)
    Not(inner) => show_named_variant1("Not", inner, logger)
    Add(left, right) => show_named_variant2("Add", left, right, logger)
    Sub(left, right) => show_named_variant2("Sub", left, right, logger)
    Mul(left, right) => show_named_variant2("Mul", left, right, logger)
    Div(left, right) => show_named_variant2("Div", left, right, logger)
    Mod(left, right) => show_named_variant2("Mod", left, right, logger)
    IfElse(cond, then_branch, else_branch) =>
      show_named_variant3("IfElse", cond, then_branch, else_branch, logger)
    Fallback(left, right) =>
      show_named_variant2("Fallback", left, right, logger)
    Empty => show_named_variant0("Empty", logger)
  }
}

///|
pub fn Filter::identity() -> Filter {
  Identity
}

///|
pub fn Filter::scope(
  defs : Array[(String, Array[String], Filter)],
  body : Filter,
) -> Filter {
  Scope(defs, body)
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
pub fn Filter::slice(start : Int?, end : Int?) -> Filter {
  Slice(start, end)
}

///|
pub fn Filter::slice_opt(start : Int?, end : Int?) -> Filter {
  SliceOpt(start, end)
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
pub fn Filter::recurse() -> Filter {
  Recurse
}

///|
pub fn Filter::literal(value : Value) -> Filter {
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
pub fn Filter::label(name : String, body : Filter) -> Filter {
  Label(name, body)
}

///|
pub fn Filter::break_(name : String) -> Filter {
  Break(name)
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
pub fn Filter::mod_(left : Filter, right : Filter) -> Filter {
  Mod(left, right)
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
