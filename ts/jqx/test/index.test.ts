import * as assert from "node:assert/strict";
import { test } from "node:test";

import {
  bindRuntime,
  createRuntime,
  field,
  RUNTIME_UNSUPPORTED_ERRORS,
  runTypedQuery,
  runTypedQueryAst,
  toAst,
  type JqxRuntimeBinding,
  type QueryAst,
  type JqxTypedRuntime,
} from "../src/index.js";

test("bindRuntime delegates run", async () => {
  const runtime: JqxRuntimeBinding = {
    run(filter, input) {
      return { ok: true as const, value: [`${filter}:${input}`] };
    },
  };
  const jqx = bindRuntime(runtime);
  const result = await jqx.run(".", '{"x":1}');
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, ['.:{"x":1}']);
  }
});

test("runCompat falls back to run", async () => {
  const runtime: JqxRuntimeBinding = {
    run() {
      return { ok: true as const, value: ["fallback"] };
    },
  };
  const jqx = createRuntime(runtime);
  const result = await jqx.runCompat(".", "1");
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, ["fallback"]);
  }
});

test("runValues returns unsupported error when runtime does not provide it", async () => {
  const runtime: JqxRuntimeBinding = {
    run() {
      return { ok: true as const, value: ["1"] };
    },
  };
  const jqx = bindRuntime(runtime);
  const result = await jqx.runValues(".", "1");
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error, RUNTIME_UNSUPPORTED_ERRORS.runValues);
  }
});

test("runTypedQuery forwards QueryAst to runtime.runQuery", async () => {
  const calls: Array<{ query: QueryAst; input: string }> = [];
  const runtime: JqxTypedRuntime<QueryAst> = {
    runQuery(query, input) {
      calls.push({ query, input });
      return { ok: true as const, value: ["typed"] };
    },
  };
  const query = field("user");
  const input = '{"user":"alice"}';
  const result = await runTypedQuery(runtime, query, input);
  assert.equal(result.ok, true);
  assert.deepEqual(calls, [{ query: toAst(query), input }]);
});

test("runTypedQueryAst forwards ast as-is", async () => {
  const calls: Array<{ query: QueryAst; input: string }> = [];
  const runtime: JqxTypedRuntime<QueryAst> = {
    runQuery(query, input) {
      calls.push({ query, input });
      return { ok: true as const, value: ["typed-ast"] };
    },
  };
  const queryAst: QueryAst = { kind: "identity" };
  const input = "1";
  const result = await runTypedQueryAst(runtime, queryAst, input);
  assert.equal(result.ok, true);
  assert.deepEqual(calls, [{ query: queryAst, input }]);
});
