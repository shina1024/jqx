///|
pub extend Mark with Eq::{equal, not_equal}

///|
pub extend Mark with Hash::{hash, hash_combine}

///|
pub extend Mark with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend MarkSlotMap with Eq::{equal, not_equal}

///|
pub extend MarkSlotMap with Hash::{hash, hash_combine}

///|
pub extend Slot with Eq::{equal, not_equal}

///|
pub extend Slot with Hash::{hash, hash_combine}

///|
pub extend State with Eq::{equal, not_equal}

///|
pub extend State with Hash::{hash, hash_combine}
