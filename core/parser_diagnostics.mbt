///|
priv enum CompileDiagnostic {
  UnknownVariable(String)
  UndefinedLabel(String)
}

///|
priv struct CompileDiagnosticFrame {
  filter : Filter
  vars : Array[String]
  labels : Array[String]
}

///|
priv struct UnresolvedCallFrame {
  filter : Filter
  visible_signatures : Array[(String, Int)]
  all_signatures : Array[(String, Int)]
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
  let stack : Array[CompileDiagnosticFrame] = [{ filter, vars, labels }]
  while stack.length() > 0 {
    match stack.pop() {
      None => ()
      Some(frame) =>
        match frame.filter {
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
          | Builtin(_) => ()
          Var(name) =>
            if frame.vars.contains(name) || is_compile_special_variable(name) {
              ()
            } else {
              return Some(UnknownVariable(name))
            }
          Break(name) =>
            if frame.labels.contains(name) {
              ()
            } else {
              return Some(UndefinedLabel(name))
            }
          Scope(defs, body) => {
            stack.push({ filter: body, vars: frame.vars, labels: frame.labels })
            let def_frames : Array[CompileDiagnosticFrame] = []
            for def_ in defs {
              let def_vars = frame.vars.copy()
              for param in def_.1 {
                def_vars.push(normalize_compile_param_name(param))
              }
              def_frames.push({
                filter: def_.2,
                vars: def_vars,
                labels: frame.labels,
              })
            }
            for i = def_frames.length() - 1; i >= 0; i = i - 1 {
              stack.push(def_frames[i])
            }
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
          | Fallback(left, right) => {
            stack.push({ filter: right, vars: frame.vars, labels: frame.labels })
            stack.push({ filter: left, vars: frame.vars, labels: frame.labels })
          }
          Array(items) =>
            for i = items.length() - 1; i >= 0; i = i - 1 {
              stack.push({
                filter: items[i],
                vars: frame.vars,
                labels: frame.labels,
              })
            }
          Object(items) =>
            for i = items.length() - 1; i >= 0; i = i - 1 {
              stack.push({
                filter: items[i].1,
                vars: frame.vars,
                labels: frame.labels,
              })
            }
          Call(_, args) =>
            for i = args.length() - 1; i >= 0; i = i - 1 {
              stack.push({
                filter: args[i],
                vars: frame.vars,
                labels: frame.labels,
              })
            }
          As(value, name, body) => {
            let body_vars = frame.vars.copy()
            body_vars.push(name)
            stack.push({ filter: body, vars: body_vars, labels: frame.labels })
            stack.push({ filter: value, vars: frame.vars, labels: frame.labels })
          }
          Label(name, body) => {
            let body_labels = frame.labels.copy()
            body_labels.push(name)
            stack.push({ filter: body, vars: frame.vars, labels: body_labels })
          }
          Try(inner) =>
            stack.push({ filter: inner, vars: frame.vars, labels: frame.labels })
          TryCatch(inner, handler) => {
            stack.push({
              filter: handler,
              vars: frame.vars,
              labels: frame.labels,
            })
            stack.push({ filter: inner, vars: frame.vars, labels: frame.labels })
          }
          Reduce(source, name, init, update) => {
            let update_vars = frame.vars.copy()
            update_vars.push(name)
            stack.push({
              filter: update,
              vars: update_vars,
              labels: frame.labels,
            })
            stack.push({ filter: init, vars: frame.vars, labels: frame.labels })
            stack.push({
              filter: source,
              vars: frame.vars,
              labels: frame.labels,
            })
          }
          Foreach(source, name, init, update, extract) => {
            let update_vars = frame.vars.copy()
            update_vars.push(name)
            stack.push({
              filter: extract,
              vars: update_vars,
              labels: frame.labels,
            })
            stack.push({
              filter: update,
              vars: update_vars,
              labels: frame.labels,
            })
            stack.push({ filter: init, vars: frame.vars, labels: frame.labels })
            stack.push({
              filter: source,
              vars: frame.vars,
              labels: frame.labels,
            })
          }
          Not(inner) =>
            stack.push({ filter: inner, vars: frame.vars, labels: frame.labels })
          IfElse(cond, then_branch, else_branch) => {
            stack.push({
              filter: else_branch,
              vars: frame.vars,
              labels: frame.labels,
            })
            stack.push({
              filter: then_branch,
              vars: frame.vars,
              labels: frame.labels,
            })
            stack.push({ filter: cond, vars: frame.vars, labels: frame.labels })
          }
        }
    }
  }
  None
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
  let stack : Array[UnresolvedCallFrame] = [
    { filter, visible_signatures, all_signatures },
  ]
  while stack.length() > 0 {
    match stack.pop() {
      None => ()
      Some(frame) =>
        match frame.filter {
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
          | Break(_) => ()
          Builtin(name) =>
            if compile_has_signature(frame.all_signatures, name, 0) &&
              !compile_has_signature(frame.visible_signatures, name, 0) {
              return Some((name, 0))
            }
          Call(name, args) => {
            let arity = args.length()
            if compile_has_signature(frame.all_signatures, name, arity) &&
              !compile_has_signature(frame.visible_signatures, name, arity) {
              return Some((name, arity))
            }
            for i = args.length() - 1; i >= 0; i = i - 1 {
              stack.push({
                filter: args[i],
                visible_signatures: frame.visible_signatures,
                all_signatures: frame.all_signatures,
              })
            }
          }
          Scope(defs, body) => {
            let local_signatures = compile_scope_signatures(defs)
            let combined_all = frame.all_signatures.copy()
            for sig in local_signatures {
              combined_all.push(sig)
            }
            let local_visible = frame.visible_signatures.copy()
            let def_frames : Array[UnresolvedCallFrame] = []
            for i in 0..<defs.length() {
              let def_ = defs[i]
              let visible_for_body = local_visible.copy()
              visible_for_body.push(local_signatures[i])
              def_frames.push({
                filter: def_.2,
                visible_signatures: visible_for_body,
                all_signatures: combined_all,
              })
              local_visible.push(local_signatures[i])
            }
            stack.push({
              filter: body,
              visible_signatures: local_visible,
              all_signatures: combined_all,
            })
            for i = def_frames.length() - 1; i >= 0; i = i - 1 {
              stack.push(def_frames[i])
            }
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
          | Fallback(left, right) => {
            stack.push({
              filter: right,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
            stack.push({
              filter: left,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
          }
          Array(items) =>
            for i = items.length() - 1; i >= 0; i = i - 1 {
              stack.push({
                filter: items[i],
                visible_signatures: frame.visible_signatures,
                all_signatures: frame.all_signatures,
              })
            }
          Object(items) =>
            for i = items.length() - 1; i >= 0; i = i - 1 {
              stack.push({
                filter: items[i].1,
                visible_signatures: frame.visible_signatures,
                all_signatures: frame.all_signatures,
              })
            }
          As(value, _, body) => {
            stack.push({
              filter: body,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
            stack.push({
              filter: value,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
          }
          Label(_, body) =>
            stack.push({
              filter: body,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
          Try(inner) | Not(inner) =>
            stack.push({
              filter: inner,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
          TryCatch(inner, handler) => {
            stack.push({
              filter: handler,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
            stack.push({
              filter: inner,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
          }
          Reduce(source, _, init, update) => {
            stack.push({
              filter: update,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
            stack.push({
              filter: init,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
            stack.push({
              filter: source,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
          }
          Foreach(source, _, init, update, extract) => {
            stack.push({
              filter: extract,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
            stack.push({
              filter: update,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
            stack.push({
              filter: init,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
            stack.push({
              filter: source,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
          }
          IfElse(cond, then_branch, else_branch) => {
            stack.push({
              filter: else_branch,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
            stack.push({
              filter: then_branch,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
            stack.push({
              filter: cond,
              visible_signatures: frame.visible_signatures,
              all_signatures: frame.all_signatures,
            })
          }
        }
    }
  }
  None
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
