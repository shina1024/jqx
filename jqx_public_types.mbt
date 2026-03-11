///|
pub type ParseError = @core.ParseError

///|
pub type FilterError = @core.FilterError

///|
pub type EvalError = @core.EvalError

///|
pub struct CompiledFilter {
  filter : @core.Filter
}

///|
pub suberror JqxError {
  Parse(ParseError)
  Filter(FilterError)
  Eval(EvalError)
} derive(Eq)

///|
pub impl Show for JqxError with output(self, logger) {
  match self {
    Parse(err) => Show::output(err, logger)
    Filter(err) => Show::output(err, logger)
    Eval(err) => Show::output(err, logger)
  }
}
