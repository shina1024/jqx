///|
pub extend Category with Eq::{equal, not_equal}

///|
pub extend Category with Hash::{hash, hash_combine}

///|
pub extend Category with Add::{add}

///|
pub extend Preference with Eq::{equal, not_equal}

///|
pub extend Preference with Hash::{hash, hash_combine}

///|
pub extend Preference with @debug.Debug::{to_repr}

///|
pub extend QuantifierMode with @debug.Debug::{to_repr}
