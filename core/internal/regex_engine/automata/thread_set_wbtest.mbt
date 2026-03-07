///|
// Source under test: core/internal/regex_engine/automata/thread_set.mbt

///|
test "thread set singleton helpers keep choose and assign_slot invariants" {
  let ctx = Context::new()
  let next = e_mark(ctx~, Mark(7))
  let marks = MarkSlotMap::empty().add_mark(Mark(1))
  let single = ts_exp(marks, e_eps)

  guard single.choose() is Exp(chosen_marks, chosen_expr) else {
    fail("expected singleton exp thread")
  }
  guard chosen_expr == e_eps else {
    fail("expected singleton choose to preserve expr")
  }
  guard chosen_marks.get_slot(Mark(1)) == Slot::unassigned() else {
    fail("expected unassigned slot before propagation")
  }

  let advanced = ts_seq(First, single, next)
  guard advanced.first() is Some(Exp(advanced_marks, expr)) else {
    fail("expected epsilon singleton to collapse into next expr")
  }
  guard expr == next else { fail("expected collapsed expr to equal next") }
  guard advanced_marks.get_slot(Mark(1)) == Slot::unassigned() else {
    fail("expected unassigned slot before assign_slot")
  }

  let assigned = advanced.assign_slot(Slot(3))
  guard assigned.first() is Some(Exp(assigned_marks, assigned_expr)) else {
    fail("expected assigned singleton exp thread")
  }
  guard assigned_expr == next else {
    fail("expected assigned expr to remain unchanged")
  }
  guard assigned_marks.get_slot(Mark(1)) == Slot(3) else {
    fail("expected assign_slot to materialize assigned slot")
  }
}

///|
test "thread set singleton end path stays well-formed" {
  let ctx = Context::new()
  let next = e_mark(ctx~, Mark(9))
  let single_end = ts_end(MarkSlotMap::empty().add_mark(Mark(5)))

  guard single_end.choose() is End(end_marks) else {
    fail("expected singleton end thread")
  }
  guard end_marks.get_slot(Mark(5)) == Slot::unassigned() else {
    fail("expected end thread to start with unassigned slot")
  }

  let seq = ts_seq(First, single_end, next)
  guard seq.first() is Some(Seq(First, first, expr)) else {
    fail("expected singleton end to stay wrapped in seq")
  }
  guard expr == next else { fail("expected seq expr to equal next") }
  guard first.first() is Some(End(seq_marks)) else {
    fail("expected seq first set to preserve end thread")
  }
  guard seq_marks.get_slot(Mark(5)) == Slot::unassigned() else {
    fail("expected preserved end marks to stay unassigned")
  }
}
