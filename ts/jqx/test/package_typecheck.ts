import { expectTypeOf } from "expect-type";

import {
  compile,
  run,
  type CompiledFilter,
  type Json,
  type JqxResult,
  type JqxRuntimeError,
} from "@shina1024/jqx";
import {
  bindQueryRuntime,
  bindRuntime,
  type JqxJsonTextRuntime,
  type JqxQueryJsonTextRuntime,
} from "@shina1024/jqx/bind";

const directOut = run(".", { user: { name: "a" } });
expectTypeOf(directOut).toMatchTypeOf<JqxResult<Json[], JqxRuntimeError>>();

const compiled = compile(".user.name");
expectTypeOf(compiled).toMatchTypeOf<JqxResult<CompiledFilter<".user.name">, JqxRuntimeError>>();

declare const bindingRuntime: JqxJsonTextRuntime;
const jqx = bindRuntime(bindingRuntime);
expectTypeOf(jqx.run(".", { user: { name: "a" } })).toMatchTypeOf<
  Promise<JqxResult<Json[], JqxRuntimeError>>
>();
// @ts-expect-error `/bind` does not expose compiled filters.
void jqx.compile(".user.name");

declare const bindingQueryRuntime: JqxQueryJsonTextRuntime;
const queryJqx = bindQueryRuntime(bindingQueryRuntime);
expectTypeOf(queryJqx.queryJsonText({ kind: "identity" }, "{}")).toMatchTypeOf<
  Promise<JqxResult<string[], JqxRuntimeError>>
>();
// @ts-expect-error `/bind` does not expose compiled filters.
void queryJqx.compile(".user.name");
