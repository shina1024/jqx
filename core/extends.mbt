///|
pub extend EvalError with Eq::{equal, not_equal}

///|
pub extend EvalError with @debug.Debug::{to_repr}

///|
pub extend EvalError with Show::{to_string, output}

///|
pub extend Filter with Eq::{equal, not_equal}

///|
pub extend Filter with @debug.Debug::{to_repr}

///|
pub extend Filter with Show::{to_string, output}

///|
pub extend Position with Eq::{equal, not_equal}

///|
pub extend Position with @debug.Debug::{to_repr}

///|
pub extend ParseError with Eq::{equal, not_equal}

///|
pub extend ParseError with @debug.Debug::{to_repr}

///|
pub extend ParseError with Show::{to_string, output}

///|
pub extend RunError with Eq::{equal, not_equal}

///|
pub extend RunError with @debug.Debug::{to_repr}

///|
pub extend RunError with Show::{to_string, output}

///|
pub extend Value with Show::{to_string, output}

///|
pub extend Value with @debug.Debug::{to_repr}

///|
pub extend JsonObject with @debug.Debug::{to_repr}

///|
pub extend Value with Eq::{equal, not_equal}

///|
pub extend FilterError with Eq::{equal, not_equal}

///|
pub extend FilterError with @debug.Debug::{to_repr}

///|
pub extend FilterError with Show::{to_string, output}
