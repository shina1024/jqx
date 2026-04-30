///|
priv enum CompileDiagnostic {
  UnknownVariable(String)
  UndefinedLabel(String)
}

///|
fn is_compile_special_variable(name : String) -> Bool {
  name == "ENV" || name == "__loc__"
}

///|
fn normalize_compile_param_name(param : String) -> String {
  if param.has_prefix("$") {
    param.view(start_offset=1).to_owned()
  } else {
    param
  }
}

///|
fn compile_first_diagnostic(
  filter : Filter,
  vars : Array[String],
  labels : Array[String],
) -> CompileDiagnostic? {
  fn with_var(name : String) -> Array[String] {
    let next = vars.copy()
    next.push(name)
    next
  }

  fn with_label(name : String) -> Array[String] {
    let next = labels.copy()
    next.push(name)
    next
  }

  fn first_in(items : Array[Filter]) -> CompileDiagnostic? {
    for item in items {
      match compile_first_diagnostic(item, vars, labels) {
        Some(diag) => return Some(diag)
        None => ()
      }
    }
    None
  }

  match filter {
    Identity
    | Iter
    | IterOpt
    | Recurse
    | Empty
    | Literal(_)
    | Field(_)
    | FieldOpt(_)
    | Index(_)
    | IndexOpt(_)
    | Slice(_, _)
    | SliceOpt(_, _)
    | Builtin(_) => None
    Var(name) =>
      if vars.contains(name) || is_compile_special_variable(name) {
        None
      } else {
        Some(UnknownVariable(name))
      }
    Break(name) =>
      if labels.contains(name) {
        None
      } else {
        Some(UndefinedLabel(name))
      }
    Scope(defs, body) => {
      for def_ in defs {
        let def_vars = vars.copy()
        for param in def_.1 {
          def_vars.push(normalize_compile_param_name(param))
        }
        match compile_first_diagnostic(def_.2, def_vars, labels) {
          Some(diag) => return Some(diag)
          None => ()
        }
      }
      compile_first_diagnostic(body, vars, labels)
    }
    Pipe(left, right)
    | Comma(left, right)
    | Eq(left, right)
    | Neq(left, right)
    | Lt(left, right)
    | Lte(left, right)
    | Gt(left, right)
    | Gte(left, right)
    | And(left, right)
    | Or(left, right)
    | Add(left, right)
    | Sub(left, right)
    | Mul(left, right)
    | Div(left, right)
    | Mod(left, right)
    | Fallback(left, right) =>
      match compile_first_diagnostic(left, vars, labels) {
        Some(diag) => Some(diag)
        None => compile_first_diagnostic(right, vars, labels)
      }
    Array(items) => first_in(items)
    Object(items) => {
      for kv in items {
        match compile_first_diagnostic(kv.1, vars, labels) {
          Some(diag) => return Some(diag)
          None => ()
        }
      }
      None
    }
    Call(_, args) => first_in(args)
    As(value, name, body) =>
      match compile_first_diagnostic(value, vars, labels) {
        Some(diag) => Some(diag)
        None => compile_first_diagnostic(body, with_var(name), labels)
      }
    Label(name, body) => compile_first_diagnostic(body, vars, with_label(name))
    Try(inner) => compile_first_diagnostic(inner, vars, labels)
    TryCatch(inner, handler) =>
      match compile_first_diagnostic(inner, vars, labels) {
        Some(diag) => Some(diag)
        None => compile_first_diagnostic(handler, vars, labels)
      }
    Reduce(source, name, init, update) =>
      match compile_first_diagnostic(source, vars, labels) {
        Some(diag) => Some(diag)
        None =>
          match compile_first_diagnostic(init, vars, labels) {
            Some(diag) => Some(diag)
            None => compile_first_diagnostic(update, with_var(name), labels)
          }
      }
    Foreach(source, name, init, update, extract) =>
      match compile_first_diagnostic(source, vars, labels) {
        Some(diag) => Some(diag)
        None =>
          match compile_first_diagnostic(init, vars, labels) {
            Some(diag) => Some(diag)
            None =>
              match compile_first_diagnostic(update, with_var(name), labels) {
                Some(diag) => Some(diag)
                None =>
                  compile_first_diagnostic(extract, with_var(name), labels)
              }
          }
      }
    Not(inner) => compile_first_diagnostic(inner, vars, labels)
    IfElse(cond, then_branch, else_branch) =>
      match compile_first_diagnostic(cond, vars, labels) {
        Some(diag) => Some(diag)
        None =>
          match compile_first_diagnostic(then_branch, vars, labels) {
            Some(diag) => Some(diag)
            None => compile_first_diagnostic(else_branch, vars, labels)
          }
      }
  }
}

///|
fn compile_find_token_offset(input : StringView, token : String) -> Int? {
  input.to_owned().find(token)
}

///|
fn compile_has_signature(
  signatures : Array[(String, Int)],
  name : String,
  arity : Int,
) -> Bool {
  for sig in signatures {
    if sig.0 == name && sig.1 == arity {
      return true
    }
  }
  false
}

///|
fn compile_scope_signatures(
  defs : Array[(String, Array[String], Filter)],
) -> Array[(String, Int)] {
  let out = []
  for def_ in defs {
    out.push((def_.0, def_.1.length()))
  }
  out
}

///|
fn compile_first_unresolved_local_call(
  filter : Filter,
  visible_signatures : Array[(String, Int)],
  all_signatures : Array[(String, Int)],
) -> (String, Int)? {
  fn first_in(items : Array[Filter]) -> (String, Int)? {
    for item in items {
      match
        compile_first_unresolved_local_call(
          item, visible_signatures, all_signatures,
        ) {
        Some(hit) => return Some(hit)
        None => ()
      }
    }
    None
  }

  match filter {
    Identity
    | Iter
    | IterOpt
    | Recurse
    | Empty
    | Literal(_)
    | Field(_)
    | FieldOpt(_)
    | Index(_)
    | IndexOpt(_)
    | Slice(_, _)
    | SliceOpt(_, _)
    | Var(_)
    | Break(_) => None
    Builtin(name) =>
      if compile_has_signature(all_signatures, name, 0) &&
        !compile_has_signature(visible_signatures, name, 0) {
        Some((name, 0))
      } else {
        None
      }
    Call(name, args) => {
      let arity = args.length()
      if compile_has_signature(all_signatures, name, arity) &&
        !compile_has_signature(visible_signatures, name, arity) {
        Some((name, arity))
      } else {
        first_in(args)
      }
    }
    Scope(defs, body) => {
      let combined_all = all_signatures.copy()
      let local_signatures = compile_scope_signatures(defs)
      for sig in local_signatures {
        combined_all.push(sig)
      }
      let local_visible = visible_signatures.copy()
      for def_ in defs {
        let visible_for_body = local_visible.copy()
        visible_for_body.push((def_.0, def_.1.length()))
        match
          compile_first_unresolved_local_call(
            def_.2,
            visible_for_body,
            combined_all,
          ) {
          Some(hit) => return Some(hit)
          None => ()
        }
        local_visible.push((def_.0, def_.1.length()))
      }
      compile_first_unresolved_local_call(body, local_visible, combined_all)
    }
    Pipe(left, right)
    | Comma(left, right)
    | Eq(left, right)
    | Neq(left, right)
    | Lt(left, right)
    | Lte(left, right)
    | Gt(left, right)
    | Gte(left, right)
    | And(left, right)
    | Or(left, right)
    | Add(left, right)
    | Sub(left, right)
    | Mul(left, right)
    | Div(left, right)
    | Mod(left, right)
    | Fallback(left, right) =>
      match
        compile_first_unresolved_local_call(
          left, visible_signatures, all_signatures,
        ) {
        Some(hit) => Some(hit)
        None =>
          compile_first_unresolved_local_call(
            right, visible_signatures, all_signatures,
          )
      }
    Array(items) => first_in(items)
    Object(items) => {
      for kv in items {
        match
          compile_first_unresolved_local_call(
            kv.1,
            visible_signatures,
            all_signatures,
          ) {
          Some(hit) => return Some(hit)
          None => ()
        }
      }
      None
    }
    As(value, _, body) =>
      match
        compile_first_unresolved_local_call(
          value, visible_signatures, all_signatures,
        ) {
        Some(hit) => Some(hit)
        None =>
          compile_first_unresolved_local_call(
            body, visible_signatures, all_signatures,
          )
      }
    Label(_, body) =>
      compile_first_unresolved_local_call(
        body, visible_signatures, all_signatures,
      )
    Try(inner) =>
      compile_first_unresolved_local_call(
        inner, visible_signatures, all_signatures,
      )
    TryCatch(inner, handler) =>
      match
        compile_first_unresolved_local_call(
          inner, visible_signatures, all_signatures,
        ) {
        Some(hit) => Some(hit)
        None =>
          compile_first_unresolved_local_call(
            handler, visible_signatures, all_signatures,
          )
      }
    Reduce(source, _, init, update) =>
      match
        compile_first_unresolved_local_call(
          source, visible_signatures, all_signatures,
        ) {
        Some(hit) => Some(hit)
        None =>
          match
            compile_first_unresolved_local_call(
              init, visible_signatures, all_signatures,
            ) {
            Some(hit) => Some(hit)
            None =>
              compile_first_unresolved_local_call(
                update, visible_signatures, all_signatures,
              )
          }
      }
    Foreach(source, _, init, update, extract) =>
      match
        compile_first_unresolved_local_call(
          source, visible_signatures, all_signatures,
        ) {
        Some(hit) => Some(hit)
        None =>
          match
            compile_first_unresolved_local_call(
              init, visible_signatures, all_signatures,
            ) {
            Some(hit) => Some(hit)
            None =>
              match
                compile_first_unresolved_local_call(
                  update, visible_signatures, all_signatures,
                ) {
                Some(hit) => Some(hit)
                None =>
                  compile_first_unresolved_local_call(
                    extract, visible_signatures, all_signatures,
                  )
              }
          }
      }
    Not(inner) =>
      compile_first_unresolved_local_call(
        inner, visible_signatures, all_signatures,
      )
    IfElse(cond, then_branch, else_branch) =>
      match
        compile_first_unresolved_local_call(
          cond, visible_signatures, all_signatures,
        ) {
        Some(hit) => Some(hit)
        None =>
          match
            compile_first_unresolved_local_call(
              then_branch, visible_signatures, all_signatures,
            ) {
            Some(hit) => Some(hit)
            None =>
              compile_first_unresolved_local_call(
                else_branch, visible_signatures, all_signatures,
              )
          }
      }
  }
}

///|
fn compile_first_forward_ref_in_scope(
  defs : Array[(String, Array[String], Filter)],
) -> (String, Int)? {
  let all_signatures = compile_scope_signatures(defs)
  let visible_signatures = []
  for def_ in defs {
    let visible_for_body = visible_signatures.copy()
    visible_for_body.push((def_.0, def_.1.length()))
    match
      compile_first_unresolved_local_call(
        def_.2,
        visible_for_body,
        all_signatures,
      ) {
      Some(hit) => return Some(hit)
      None => ()
    }
    visible_signatures.push((def_.0, def_.1.length()))
  }
  None
}

///|
pub fn validate_filter_compile_diagnostics(
  filter : Filter,
  input : StringView,
) -> Unit raise FilterError {
  match filter {
    Scope(defs, _) =>
      match compile_first_forward_ref_in_scope(defs) {
        Some((name, arity)) => {
          let token = if arity == 0 { name } else { name + "(" }
          let offset = match compile_find_token_offset(input, token) {
            Some(i) => i
            None => 0
          }
          raise Diagnostics([
            name +
            "/" +
            arity.to_string() +
            " is not defined " +
            filter_position_suffix(input, offset),
          ])
        }
        None => ()
      }
    _ => ()
  }
  match compile_first_diagnostic(filter, [], []) {
    Some(UnknownVariable(name)) => {
      let token = "$" + name
      let offset = match compile_find_token_offset(input, token) {
        Some(i) => i
        None => 0
      }
      raise Diagnostics([
        "$" + name + " is not defined " + filter_position_suffix(input, offset),
      ])
    }
    Some(UndefinedLabel(name)) => {
      let token = "break $" + name
      let offset = match compile_find_token_offset(input, token) {
        Some(i) => i
        None => 0
      }
      raise Diagnostics([
        "$*label-" +
        name +
        " is not defined " +
        filter_position_suffix(input, offset),
      ])
    }
    None => ()
  }
}
