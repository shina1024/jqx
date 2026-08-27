// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
priv struct TranslateContext {
  ctx : @automata.Context
  pref : Preference
  groups : Array[String?]
  symbol_table : &@symbol_map.Table
}

///|
fn TranslateContext::new(
  ctx : @automata.Context,
  symbol_table : &@symbol_map.Table,
) -> TranslateContext {
  { ctx, pref: First, groups: [], symbol_table, }
}

///|
fn translate(
  tc : TranslateContext,
  ast : Pattern,
) -> (@automata.Expr, Preference) {
  let { ctx, pref, groups, symbol_table, } = tc
  match ast.desc {
    Char(c) => (@automata.e_cset(ctx~, symbol_table.map_set(c)), pref)
    Sequence(exprs) => (transl_seq(tc, exprs), pref)
    Alternation(exprs) => {
      let merged_exprs = merge_alternation_sequences(exprs)
      let alts = []
      for expr in merged_exprs {
        let (cr, pref2) = translate(tc, expr)
        alts.push(enforce_pref(ctx, pref, pref2, cr))
      }
      (@automata.e_alt(ctx~, alts), pref)
    }
    Quantifier(q, expr) => {
      let (cr, pref2) = translate(tc, expr)
      let rem = match q.max {
        None => @automata.e_rep(ctx~, q.mode, pref2, cr)
        Some(max) => {
          let repeater = match q.mode {
            Greedy =>
              rem => {
                @automata.e_alt(ctx~, [
                  @automata.e_seq(ctx~, pref2, @automata.e_copy(ctx~, cr), rem),
                  @automata.e_eps,
                ])
              }
            NonGreedy =>
              rem => {
                @automata.e_alt(ctx~, [
                  @automata.e_eps,
                  @automata.e_seq(ctx~, pref2, @automata.e_copy(ctx~, cr), rem),
                ])
              }
          }
          iter(max - q.min, repeater, @automata.e_eps)
        }
      }
      let result = iter(
        q.min,
        rem => @automata.e_seq(ctx~, pref2, @automata.e_copy(ctx~, cr), rem),
        rem,
      )
      (result, pref)
    }
    Preference(pref2, expr) => {
      let (cr, pref3) = translate({ ..tc, pref: pref2, }, expr)
      (enforce_pref(ctx, pref2, pref3, cr), pref2)
    }
    Capture(name~, expr) => {
      let group_index = groups.length()
      groups.push(name)
      let (cr, pref2) = translate(tc, expr)
      (
        @automata.e_seq(
          ctx~,
          First,
          @automata.e_mark(ctx~, Mark(group_index * 2)),
          @automata.e_seq(
            ctx~,
            First,
            cr,
            @automata.e_mark(ctx~, Mark(group_index * 2 + 1)),
          ),
        ),
        pref2,
      )
    }
    Assertion(asrt) => (transl_asrt(ctx, asrt), pref)
  }
}

///|
fn split_char_head(expr : Pattern) -> (RecharSet, Pattern)? {
  match expr.desc {
    Char(head) => Some((head, epsilon))
    Sequence(parts) =>
      if parts.length() == 0 {
        None
      } else {
        match parts[0].desc {
          Char(head) => {
            let tails = []
            for i in 1..<parts.length() {
              tails.push(parts[i])
            }
            Some((head, seq(ReadOnlyArray::from_array(tails))))
          }
          _ => None
        }
      }
    _ => None
  }
}

///|
fn rechar_set_equal(a : RecharSet, b : RecharSet) -> Bool {
  a.is_subset(b) && b.is_subset(a)
}

///|
/// Merge alternation branches that share the same leading `Char`.
/// This only merges contiguous branches to preserve left-to-right priority.
fn merge_alternation_sequences(
  exprs : ReadOnlyArray[Pattern],
) -> Array[Pattern] {
  let merged = []
  let mut i = 0
  while i < exprs.length() {
    let current = exprs[i]
    match split_char_head(current) {
      Some((head, tail)) => {
        let tails = [tail]
        let mut j = i + 1
        while j < exprs.length() {
          match split_char_head(exprs[j]) {
            Some((head2, tail2)) if rechar_set_equal(head2, head) => {
              tails.push(tail2)
              j += 1
            }
            _ => break
          }
        }
        if tails.length() > 1 {
          merged.push(seq([char(head), alt(ReadOnlyArray::from_array(tails))]))
        } else {
          merged.push(current)
        }
        i = j
      }
      None => {
        merged.push(current)
        i += 1
      }
    }
  }
  merged
}

///|
fn transl_asrt(ctx : @automata.Context, asrt : Assertion) -> @automata.Expr {
  match asrt {
    StartOfLine => @automata.e_after(ctx~, Category::inexistant_or_newline())
    EndOfLine => @automata.e_before(ctx~, Category::inexistant_or_newline())
    StartOfWord =>
      @automata.e_seq(
        ctx~,
        First,
        @automata.e_after(ctx~, Category::inexistant_or_non_word()),
        @automata.e_before(ctx~, Category::word()),
      )
    EndOfWord =>
      @automata.e_seq(
        ctx~,
        First,
        @automata.e_after(ctx~, Category::word()),
        @automata.e_before(ctx~, Category::inexistant_or_non_word()),
      )
    NotWordBoundary =>
      @automata.e_alt(ctx~, [
        @automata.e_seq(
          ctx~,
          First,
          @automata.e_after(ctx~, Category::word()),
          @automata.e_before(ctx~, Category::word()),
        ),
        @automata.e_seq(
          ctx~,
          First,
          @automata.e_after(ctx~, Category::inexistant_or_non_word()),
          @automata.e_before(ctx~, Category::inexistant_or_non_word()),
        ),
      ])
    StartOfInput => @automata.e_after(ctx~, Category::inexistant())
    EndOfInput => @automata.e_before(ctx~, Category::inexistant())
  }
}

///|
fn transl_seq(
  tc : TranslateContext,
  exprs : ReadOnlyArray[Pattern],
) -> @automata.Expr {
  let n = exprs.length()
  if n == 0 {
    return @automata.e_eps
  }
  // Translate left-to-right to preserve capture group numbering side effects.
  let crs : Array[@automata.Expr] = []
  let prefs : Array[Preference] = []
  for i in 0..<n {
    let (cr, pref2) = translate(tc, exprs[i])
    crs.push(cr)
    prefs.push(pref2)
  }
  // Combine right-to-left iteratively (replaces recursive go(i+1)).
  let mut acc = enforce_pref(tc.ctx, tc.pref, prefs[n - 1], crs[n - 1])
  let mut i = n - 2
  while i >= 0 {
    let cr = crs[i]
    let pref2 = prefs[i]
    acc = if @automata.is_eps(acc) {
      cr
    } else if @automata.is_eps(cr) {
      acc
    } else {
      @automata.e_seq(ctx=tc.ctx, pref2, cr, acc)
    }
    i = i - 1
  }
  acc
}

///|
fn enforce_pref(
  ctx : @automata.Context,
  pref : Preference,
  pref2 : Preference,
  cr : @automata.Expr,
) -> @automata.Expr {
  match (pref, pref2) {
    (First, First) => cr
    (First, k) => @automata.e_seq(ctx~, k, cr, @automata.e_eps)
    _ => cr
  }
}

///|
fn[T] iter(n : Int, f : (T) -> T, init : T) -> T {
  let mut acc = init
  let mut i = 0
  while i < n {
    acc = f(acc)
    i = i + 1
  }
  acc
}
