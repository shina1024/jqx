import * as assert from "node:assert/strict";
import { test } from "node:test";

import {
  compile,
  field,
  isValidJson,
  parseJson,
  query,
  queryJsonText,
  queryRuntime,
  run,
  runCompiled,
  runCompiledJsonText,
  runJsonText,
  runtime,
  toAst,
} from "../src/index.js";

test("runJsonText executes a jq filter on JSON text", () => {
  const result = runJsonText(".foo", '{"foo":1}');
  assert.deepEqual(result, { ok: true, value: ["1"] });
});

test("run stringifies input and parses outputs", () => {
  const result = run(".foo", { foo: 1 });
  assert.deepEqual(result, { ok: true, value: [1] });
});

test("compile returns an opaque compiled filter that runCompiled can execute", () => {
  const compiled = compile(".items[]");
  assert.equal(compiled.ok, true);
  if (!compiled.ok) {
    return;
  }

  const runtimeText = runCompiledJsonText(compiled.value, '{"items":[1,2,3]}');
  assert.deepEqual(runtimeText, { ok: true, value: ["1", "2", "3"] });

  const runtimeValue = runCompiled(compiled.value, { items: [1, 2, 3] });
  assert.deepEqual(runtimeValue, { ok: true, value: [1, 2, 3] });
});

test("parseJson and isValidJson use jqx parser semantics", () => {
  const parsed = parseJson('{"foo":[1,true,null]}');
  assert.deepEqual(parsed, {
    ok: true,
    value: { foo: [1, true, null] },
  });

  assert.equal(isValidJson('{"foo":[1,true,null]}'), true);
  assert.equal(isValidJson("{"), false);

  const invalid = parseJson("{");
  assert.equal(invalid.ok, false);
  if (!invalid.ok) {
    assert.equal(invalid.error.kind, "backend_runtime");
    assert.equal(typeof invalid.error.message, "string");
    assert.equal(typeof invalid.error.details?.code, "string");
  }
});

test("compile surfaces structured backend errors for invalid filters", () => {
  const compiled = compile(".[");
  assert.equal(compiled.ok, false);
  if (!compiled.ok) {
    assert.equal(compiled.error.kind, "backend_runtime");
    assert.equal(typeof compiled.error.details?.code, "string");
  }
});

test("query supports typed DSL and QueryAst inputs", () => {
  const dslQuery = field("user");
  const ast = toAst(dslQuery);

  const textResult = queryJsonText(ast, '{"user":{"name":"alice"}}');
  assert.deepEqual(textResult, {
    ok: true,
    value: ['{"name":"alice"}'],
  });

  const dslResult = query(dslQuery, { user: { name: "alice" } });
  assert.deepEqual(dslResult, {
    ok: true,
    value: [{ name: "alice" }],
  });
});

test("runtime and queryRuntime expose adapter-friendly objects", () => {
  const runResult = runtime.run(".foo", { foo: 1 });
  assert.deepEqual(runResult, { ok: true, value: [1] });

  const queryResult = queryRuntime.query(toAst(field("foo")), { foo: 1 });
  assert.deepEqual(queryResult, { ok: true, value: [1] });
});
