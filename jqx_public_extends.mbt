///|
pub extend Position with Eq::{equal, not_equal}

///|
pub extend Position with Show::{to_string, output}

///|
pub extend JsonParseError with Eq::{equal, not_equal}

///|
pub extend JsonParseError with Show::{to_string, output}

///|
pub extend CompileError with Eq::{equal, not_equal}

///|
pub extend CompileError with Show::{to_string, output}

///|
pub extend RuntimeError with Eq::{equal, not_equal}

///|
pub extend RuntimeError with Show::{to_string, output}

///|
pub extend RunError with Eq::{equal, not_equal}

///|
pub extend RunError with Show::{to_string, output}

///|
pub extend JsonTextRunError with Eq::{equal, not_equal}

///|
pub extend JsonTextRunError with Show::{to_string, output}

///|
pub extend CompiledJsonTextRunError with Eq::{equal, not_equal}

///|
pub extend CompiledJsonTextRunError with Show::{to_string, output}
