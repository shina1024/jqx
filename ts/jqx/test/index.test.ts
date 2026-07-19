import * as assert from "node:assert/strict";
import { test } from "vite-plus/test";

import {
  bindRuntime,
  bindQueryRuntime,
  comma,
  exportQueryAstDocument,
  exportTypedQueryDocument,
  field,
  importQueryAstDocument,
  isJqxError,
  isJqxRuntimeError,
  literal,
  parseQueryAstDocument,
  QUERY_AST_DOCUMENT_FORMAT,
  QUERY_AST_DOCUMENT_VERSION,
  runtimeErrorToMessage,
  stringifyQueryAstDocument,
  toJqxRuntimeError,
  toAst,
  type JqxJsonTextRuntime,
  type JqxQueryJsonTextRuntime,
  type Json,
  type QueryAst,
} from "../src/bind.js";

async function collectStream<T, E>(
  stream: AsyncIterable<{ ok: true; value: T } | { ok: false; error: E }>,
) {
  const items: Array<{ ok: true; value: T } | { ok: false; error: E }> = [];
  for await (const item of stream) {
    items.push(item);
  }
  return items;
}

test("bindRuntime delegates runJsonText", async () => {
  const runtime: JqxJsonTextRuntime = {
    runJsonText(filter, input) {
      return { ok: true as const, value: [`${filter}:${input}`] };
    },
  };
  const jqx = bindRuntime(runtime);
  const result = await jqx.runJsonText(".", '{"x":1}');
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, ['.:{"x":1}']);
  }
});

test("bindRuntime run stringifies input and parses outputs", async () => {
  const runtime: JqxJsonTextRuntime = {
    runJsonText(filter, input) {
      assert.equal(filter, ".x");
      assert.equal(input, '{"x":1}');
      return { ok: true as const, value: ['{"x":1}'] };
    },
  };
  const jqx = bindRuntime(runtime);
  const result = await jqx.run(".x", { x: 1 });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, [{ x: 1 }]);
  }
});

test("bindRuntime run returns input_stringify for unserializable value-lane input", async () => {
  const runtime: JqxJsonTextRuntime = {
    runJsonText() {
      assert.fail("runJsonText should not be called when input stringification fails");
    },
  };
  const jqx = bindRuntime(runtime);
  const cyclic: Record<string, unknown> = {};
  cyclic.self = cyclic;

  const result = await jqx.run(".", cyclic as Json);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "input_stringify");
    assert.equal(typeof result.error.message, "string");
  }
});

test("bindRuntime contains hostile input failures across run and runStream", async () => {
  const runtime: JqxJsonTextRuntime = {
    runJsonText() {
      assert.fail("backend should not receive hostile value-lane input");
    },
  };
  const jqx = bindRuntime(runtime);
  const hostile = new Proxy(
    {},
    {
      ownKeys() {
        throw new Error("inspection failed");
      },
    },
  ) as Json;

  const result = await jqx.run(".", hostile);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "input_stringify");
  }
  const streamed = await collectStream(jqx.runStream(".", hostile));
  assert.equal(streamed.length, 1);
  assert.equal(streamed[0]?.ok, false);
});

test("bindRuntime serializes descriptor values without invoking Proxy getters", async () => {
  let getterCalls = 0;
  const encodedInputs: string[] = [];
  const runtime: JqxJsonTextRuntime = {
    runJsonText(_filter, input) {
      encodedInputs.push(input);
      return { ok: true, value: [input] };
    },
  };
  const input = new Proxy(
    { x: 1, items: [2] },
    {
      get(target, property, receiver) {
        getterCalls += 1;
        if (property === "x") return Number.POSITIVE_INFINITY;
        return Reflect.get(target, property, receiver);
      },
    },
  );
  const result = await bindRuntime(runtime).run(".", input);
  assert.equal(result.ok, true);
  const arrayInput = new Proxy([2], {
    get(target, property, receiver) {
      getterCalls += 1;
      if (property === "length") return 100;
      if (property === "0") return Number.POSITIVE_INFINITY;
      return Reflect.get(target, property, receiver);
    },
  });
  const arrayResult = await bindRuntime(runtime).run(".", arrayInput);
  assert.equal(arrayResult.ok, true);
  assert.deepEqual(encodedInputs, ['{"x":1,"items":[2]}', "[2]"]);
  assert.equal(getterCalls, 0);
});

test("bindRuntime run rejects non-finite numbers in the value lane", async () => {
  const runtime: JqxJsonTextRuntime = {
    runJsonText() {
      assert.fail("runJsonText should not be called when value-lane validation fails");
    },
  };
  const jqx = bindRuntime(runtime);
  const result = await jqx.run(".", { nested: [Number.POSITIVE_INFINITY] } as Json);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "input_value");
    if (result.error.kind === "input_value") {
      assert.equal(result.error.path, "$.nested[0]");
    }
  }
});

test("bindRuntime run returns parse error for invalid raw JSON", async () => {
  const runtime: JqxJsonTextRuntime = {
    runJsonText() {
      return { ok: true as const, value: ["not-json"] };
    },
  };
  const jqx = bindRuntime(runtime);
  const result = await jqx.run(".", 1);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "output_parse");
    if (result.error.kind === "output_parse") {
      assert.equal(result.error.index, 0);
    }
  }
});

test("bindRuntime run returns output_value for jq-compatible raw outputs outside the value lane", async () => {
  const runtime: JqxJsonTextRuntime = {
    runJsonText() {
      return { ok: true as const, value: ['{"value":[1e309]}'] };
    },
  };
  const jqx = bindRuntime(runtime);
  const result = await jqx.run(".", null);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "output_value");
    if (result.error.kind === "output_value") {
      assert.equal(result.error.index, 0);
      assert.equal(result.error.path, "$.value[0]");
    }
  }
});

test("bindRuntime normalizes legacy backend string errors", async () => {
  const runtime: JqxJsonTextRuntime = {
    runJsonText() {
      return { ok: false, error: { kind: "backend_runtime", message: "placeholder" } };
    },
  };
  Object.defineProperty(runtime, "runJsonText", {
    value() {
      return { ok: false, error: "boom" };
    },
  });
  const jqx = bindRuntime(runtime);
  const rawOut = await jqx.runJsonText(".", "{}");
  assert.equal(rawOut.ok, false);
  if (!rawOut.ok) {
    assert.deepEqual(rawOut.error, { kind: "backend_runtime", message: "boom" });
  }
});

test("bindRuntime runJsonTextStream falls back to runJsonText", async () => {
  const runtime: JqxJsonTextRuntime = {
    runJsonText(filter, input) {
      assert.equal(filter, ".");
      assert.equal(input, '{"x":1}');
      return { ok: true as const, value: ['{"x":1}', '{"x":2}'] };
    },
  };
  const jqx = bindRuntime(runtime);
  const items = await collectStream(jqx.runJsonTextStream(".", '{"x":1}'));
  assert.deepEqual(items, [
    { ok: true, value: '{"x":1}' },
    { ok: true, value: '{"x":2}' },
  ]);
});

test("bindRuntime runJsonTextStream prefers runtime streaming lane", async () => {
  const runtime: JqxJsonTextRuntime & {
    runJsonTextStream(
      filter: string,
      input: string,
    ): {
      ok: true;
      value: AsyncIterable<string>;
    };
  } = {
    runJsonText() {
      assert.fail("runJsonText should not be called when runJsonTextStream exists");
    },
    runJsonTextStream(filter, input) {
      assert.equal(filter, ".");
      assert.equal(input, '{"x":1}');
      return {
        ok: true as const,
        value: (async function* () {
          yield '{"x":1}';
          yield '{"x":2}';
        })(),
      };
    },
  };
  const jqx = bindRuntime(runtime);
  const items = await collectStream(jqx.runJsonTextStream(".", '{"x":1}'));
  assert.deepEqual(items, [
    { ok: true, value: '{"x":1}' },
    { ok: true, value: '{"x":2}' },
  ]);
});

test("bindRuntime runJsonTextStream yields backend_runtime on stream iteration failure", async () => {
  const runtime: JqxJsonTextRuntime & {
    runJsonTextStream(
      filter: string,
      input: string,
    ): {
      ok: true;
      value: AsyncIterable<string>;
    };
  } = {
    runJsonText() {
      assert.fail("runJsonText should not be called when runJsonTextStream exists");
    },
    runJsonTextStream(filter, input) {
      assert.equal(filter, ".");
      assert.equal(input, '{"x":1}');
      return {
        ok: true as const,
        value: (async function* () {
          yield '{"x":1}';
          throw new Error("stream boom");
        })(),
      };
    },
  };
  const jqx = bindRuntime(runtime);
  const items = await collectStream(jqx.runJsonTextStream(".", '{"x":1}'));
  assert.equal(items.length, 2);
  assert.deepEqual(items[0], { ok: true, value: '{"x":1}' });
  assert.equal(items[1]?.ok, false);
  if (!items[1]?.ok) {
    assert.deepEqual(items[1].error, {
      kind: "backend_runtime",
      message: "stream boom",
    });
  }
});

test("bindRuntime runStream parses each streamed json value", async () => {
  const runtime: JqxJsonTextRuntime & {
    runJsonTextStream(
      filter: string,
      input: string,
    ): {
      ok: true;
      value: AsyncIterable<string>;
    };
  } = {
    runJsonText() {
      return { ok: true as const, value: [] };
    },
    runJsonTextStream(filter, input) {
      assert.equal(filter, ".x");
      assert.equal(input, '{"x":1}');
      return {
        ok: true as const,
        value: (async function* () {
          yield "1";
          yield "2";
        })(),
      };
    },
  };
  const jqx = bindRuntime(runtime);
  const items = await collectStream(jqx.runStream(".x", { x: 1 }));
  assert.deepEqual(items, [
    { ok: true, value: 1 },
    { ok: true, value: 2 },
  ]);
});

test("bindRuntime runStream returns parse error with index", async () => {
  const runtime: JqxJsonTextRuntime & {
    runJsonTextStream(
      filter: string,
      input: string,
    ): {
      ok: true;
      value: AsyncIterable<string>;
    };
  } = {
    runJsonText() {
      return { ok: true as const, value: [] };
    },
    runJsonTextStream(filter, input) {
      assert.equal(filter, ".x");
      assert.equal(input, '{"x":1}');
      return {
        ok: true as const,
        value: (async function* () {
          yield "1";
          yield "not-json";
          yield "3";
        })(),
      };
    },
  };
  const jqx = bindRuntime(runtime);
  const items = await collectStream(jqx.runStream(".x", { x: 1 }));
  assert.equal(items.length, 2);
  assert.deepEqual(items[0], { ok: true, value: 1 });
  assert.equal(items[1]?.ok, false);
  if (!items[1]?.ok) {
    assert.equal(items[1].error.kind, "output_parse");
    if (items[1].error.kind === "output_parse") {
      assert.equal(items[1].error.index, 1);
    }
  }
});

test("bindRuntime runStream returns output_value with index for jq-compatible streamed outputs outside the value lane", async () => {
  const runtime: JqxJsonTextRuntime & {
    runJsonTextStream(
      filter: string,
      input: string,
    ): {
      ok: true;
      value: AsyncIterable<string>;
    };
  } = {
    runJsonText() {
      return { ok: true as const, value: [] };
    },
    runJsonTextStream(filter, input) {
      assert.equal(filter, ".x");
      assert.equal(input, '{"x":1}');
      return {
        ok: true as const,
        value: (async function* () {
          yield "1";
          yield '{"value":[1e309]}';
          yield "3";
        })(),
      };
    },
  };
  const jqx = bindRuntime(runtime);
  const items = await collectStream(jqx.runStream(".x", { x: 1 }));
  assert.equal(items.length, 2);
  assert.deepEqual(items[0], { ok: true, value: 1 });
  assert.equal(items[1]?.ok, false);
  if (!items[1]?.ok) {
    assert.equal(items[1].error.kind, "output_value");
    if (items[1].error.kind === "output_value") {
      assert.equal(items[1].error.index, 1);
      assert.equal(items[1].error.path, "$.value[0]");
    }
  }
});

test("bindQueryRuntime supports queryJsonText and query", async () => {
  const calls: Array<{ query: QueryAst; input: string }> = [];
  const runtime: JqxQueryJsonTextRuntime<QueryAst> = {
    runJsonText() {
      return { ok: true as const, value: [] };
    },
    runQueryJsonText(query, input) {
      calls.push({ query, input });
      return { ok: true as const, value: ['{"name":"alice"}'] };
    },
  };
  const jqx = bindQueryRuntime(runtime);
  const dslQuery = field("user");
  const queryAst = toAst(dslQuery);

  const rawResult = await jqx.queryJsonText(queryAst, '{"user":{"name":"alice"}}');
  assert.equal(rawResult.ok, true);

  const result = await jqx.query(dslQuery, { user: { name: "alice" } });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, [{ name: "alice" }]);
  }
  assert.deepEqual(calls, [
    { query: queryAst, input: '{"user":{"name":"alice"}}' },
    { query: queryAst, input: '{"user":{"name":"alice"}}' },
  ]);
});

test("bindQueryRuntime queryJsonTextStream falls back to runQueryJsonText", async () => {
  const runtime: JqxQueryJsonTextRuntime<QueryAst> = {
    runJsonText() {
      return { ok: true as const, value: [] };
    },
    runQueryJsonText(query, input) {
      assert.deepEqual(query, toAst(field("user")));
      assert.equal(input, '{"user":{"name":"alice"}}');
      return { ok: true as const, value: ['{"name":"alice"}'] };
    },
  };
  const jqx = bindQueryRuntime(runtime);
  const items = await collectStream(
    jqx.queryJsonTextStream(field("user"), '{"user":{"name":"alice"}}'),
  );
  assert.deepEqual(items, [{ ok: true, value: '{"name":"alice"}' }]);
});

test("bindQueryRuntime queryStream uses query streaming lane and normalizes DSL query", async () => {
  const calls: QueryAst[] = [];
  const runtime: JqxQueryJsonTextRuntime<QueryAst> & {
    runQueryJsonTextStream(
      query: QueryAst,
      input: string,
    ): {
      ok: true;
      value: AsyncIterable<string>;
    };
  } = {
    runJsonText() {
      return { ok: true as const, value: [] };
    },
    runQueryJsonText() {
      assert.fail("runQueryJsonText should not be called when runQueryJsonTextStream exists");
    },
    runQueryJsonTextStream(query, input) {
      calls.push(query);
      assert.equal(input, '{"user":{"name":"alice"}}');
      return {
        ok: true as const,
        value: (async function* () {
          yield '{"name":"alice"}';
        })(),
      };
    },
  };
  const jqx = bindQueryRuntime(runtime);
  const dslQuery = field("user");
  const items = await collectStream(jqx.queryStream(dslQuery, { user: { name: "alice" } }));
  assert.deepEqual(items, [{ ok: true, value: { name: "alice" } }]);
  assert.deepEqual(calls, [toAst(dslQuery)]);
});

test("bindQueryRuntime supports custom query lane without DSL normalization", async () => {
  const calls: Array<{ query: { kind: "custom"; key: string }; input: string }> = [];
  const runtime = {
    runJsonText() {
      return { ok: true as const, value: [] };
    },
    runQueryJsonText(query: { kind: "custom"; key: string }, input: string) {
      calls.push({ query, input });
      return { ok: true as const, value: ['{"name":"alice"}'] };
    },
  };
  const jqx = bindQueryRuntime(runtime);
  const result = await jqx.query({ kind: "custom", key: "user" }, { user: { name: "alice" } });
  assert.equal(result.ok, true);
  assert.deepEqual(calls, [
    { query: { kind: "custom", key: "user" }, input: '{"user":{"name":"alice"}}' },
  ]);
});

test("QueryAst document export/import supports v1 envelope", () => {
  const query = field("user");
  const ast = toAst(query);
  const document = exportTypedQueryDocument(query);
  assert.deepEqual(document, {
    format: QUERY_AST_DOCUMENT_FORMAT,
    version: QUERY_AST_DOCUMENT_VERSION,
    ast,
  });

  const imported = importQueryAstDocument(document);
  assert.equal(imported.ok, true);
  if (imported.ok) {
    assert.deepEqual(imported.value, ast);
  }
});

test("QueryAst export/import accepts shared query and literal references", () => {
  const sharedQuery = field("user");
  const repeatedQuery = exportTypedQueryDocument(comma(sharedQuery, sharedQuery));
  assert.equal(importQueryAstDocument(repeatedQuery).ok, true);

  const sharedValue = { name: "alice" };
  const repeatedValue = exportTypedQueryDocument(
    literal({ first: sharedValue, second: sharedValue }),
  );
  assert.equal(importQueryAstDocument(repeatedValue).ok, true);
});

test("QueryAst import returns invalid_document for hostile objects", () => {
  const hostile = new Proxy(
    {},
    {
      has() {
        throw new Error("inspection failed");
      },
    },
  );

  const result = importQueryAstDocument(hostile);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "invalid_document");
  }

  const getterDocument = Object.create(null) as Record<string, unknown>;
  Object.defineProperties(getterDocument, {
    format: {
      enumerable: true,
      get() {
        throw new Error("inspection failed");
      },
    },
    version: { enumerable: true, value: QUERY_AST_DOCUMENT_VERSION },
    ast: { enumerable: true, value: { kind: "identity" } },
  });
  assert.equal(importQueryAstDocument(getterDocument).ok, false);
});

test("QueryAst import returns a detached validated snapshot", () => {
  const ast = { kind: "field" as const, name: "before" };
  const imported = importQueryAstDocument({
    format: QUERY_AST_DOCUMENT_FORMAT,
    version: QUERY_AST_DOCUMENT_VERSION,
    ast,
  });
  ast.name = "after";
  assert.equal(imported.ok, true);
  if (imported.ok && imported.value.kind === "field") {
    assert.equal(imported.value.name, "before");
  }
});

test("QueryAst import snapshots array length without invoking Proxy getters", () => {
  let getterCalls = 0;
  const args = new Proxy<QueryAst[]>([{ kind: "identity" }], {
    get(target, property, receiver) {
      getterCalls += 1;
      return property === "length" ? 100 : Reflect.get(target, property, receiver);
    },
  });
  const imported = importQueryAstDocument({
    format: QUERY_AST_DOCUMENT_FORMAT,
    version: QUERY_AST_DOCUMENT_VERSION,
    ast: { kind: "call", name: "empty", args },
  });
  assert.equal(imported.ok, true);
  assert.equal(getterCalls, 0);
  if (imported.ok && imported.value.kind === "call") {
    assert.equal(imported.value.args.length, 1);
  }
});

test("QueryAst import rejects bare ast", () => {
  const ast = toAst(field("name"));
  const imported = importQueryAstDocument(ast);
  assert.equal(imported.ok, false);
  if (!imported.ok) {
    assert.equal(imported.error.kind, "invalid_document");
  }
});

test("QueryAst import rejects unsupported document version", () => {
  const ast = toAst(field("name"));
  const imported = importQueryAstDocument({
    format: QUERY_AST_DOCUMENT_FORMAT,
    version: 999,
    ast,
  });
  assert.equal(imported.ok, false);
  if (!imported.ok) {
    assert.equal(imported.error.kind, "unsupported_version");
  }
});

test("QueryAst parse handles json text", () => {
  const ast = toAst(field("name"));
  const text = stringifyQueryAstDocument(exportQueryAstDocument(ast).ast);
  const parsed = parseQueryAstDocument(text);
  assert.equal(parsed.ok, true);
  if (parsed.ok) {
    assert.deepEqual(parsed.value, ast);
  }

  const invalid = parseQueryAstDocument("{");
  assert.equal(invalid.ok, false);
  if (!invalid.ok) {
    assert.equal(invalid.error.kind, "invalid_json");
  }
});

test("bindRuntime returns backend_runtime when backend throws synchronously", async () => {
  // Given
  const runtime: JqxJsonTextRuntime = {
    runJsonText() {
      throw new Error("sync down");
    },
  };
  const jqx = bindRuntime(runtime);

  // When
  const result = await jqx.runJsonText(".", "null");

  // Then
  assert.deepEqual(result, {
    ok: false,
    error: { kind: "backend_runtime", message: "sync down" },
  });
});

test("bindRuntime contains runtime errors whose own reflection traps throw", async () => {
  const hostileError = new Proxy(
    {},
    {
      getPrototypeOf() {
        throw new Error("prototype inspection failed");
      },
    },
  );
  const runtime: JqxJsonTextRuntime = {
    runJsonText() {
      throw hostileError;
    },
  };
  const result = await bindRuntime(runtime).runJsonText(".", "null");
  assert.deepEqual(result, {
    ok: false,
    error: { kind: "backend_runtime", message: "Runtime call failed" },
  });
});

test("bindRuntime contains hostile successful result payloads across every lane", async () => {
  const runtime: JqxJsonTextRuntime = {
    runJsonText() {
      return { ok: true, value: [] };
    },
  };
  Object.defineProperty(runtime, "runJsonText", {
    value() {
      return {
        ok: true,
        get value() {
          throw new Error("hostile successful payload");
        },
      };
    },
  });
  const jqx = bindRuntime(runtime);
  assert.equal((await jqx.runJsonText(".", "null")).ok, false);
  assert.equal((await jqx.run(".", null)).ok, false);
  assert.equal((await collectStream(jqx.runJsonTextStream(".", "null")))[0]?.ok, false);
  assert.equal((await collectStream(jqx.runStream(".", null)))[0]?.ok, false);
});

test("bindQueryRuntime contains hostile successful result payloads across every lane", async () => {
  const runtime: JqxQueryJsonTextRuntime = {
    runJsonText() {
      return { ok: true, value: [] };
    },
    runQueryJsonText() {
      return { ok: true, value: [] };
    },
  };
  Object.defineProperty(runtime, "runQueryJsonText", {
    value() {
      return {
        ok: true,
        get value() {
          throw new Error("hostile successful query payload");
        },
      };
    },
  });
  const jqx = bindQueryRuntime(runtime);
  const query: QueryAst = { kind: "identity" };
  assert.equal((await jqx.queryJsonText(query, "null")).ok, false);
  assert.equal((await jqx.query(query, null)).ok, false);
  assert.equal((await collectStream(jqx.queryJsonTextStream(query, "null")))[0]?.ok, false);
  assert.equal((await collectStream(jqx.queryStream(query, null)))[0]?.ok, false);
});

test("bindRuntime contains hostile successful array iteration", async () => {
  const runtime: JqxJsonTextRuntime = {
    runJsonText() {
      return { ok: true, value: [] };
    },
  };
  const values = new Proxy<string[]>(["null"], {
    get(target, property, receiver) {
      if (property === Symbol.iterator || property === "entries") {
        throw new Error("hostile array iteration");
      }
      return Reflect.get(target, property, receiver);
    },
  });
  Object.defineProperty(runtime, "runJsonText", {
    value() {
      return { ok: true, value: values };
    },
  });
  const jqx = bindRuntime(runtime);
  assert.deepEqual(await jqx.run(".", null), { ok: true, value: [null] });
  assert.deepEqual(await collectStream(jqx.runJsonTextStream(".", "null")), [
    { ok: true, value: "null" },
  ]);
});

test("bindRuntime rejects non-string streaming backend values", async () => {
  const runtime: JqxJsonTextRuntime = {
    runJsonText() {
      return { ok: true, value: [] };
    },
  };
  Object.defineProperty(runtime, "runJsonTextStream", {
    value() {
      return {
        ok: true,
        value: (async function* () {
          yield 123;
        })(),
      };
    },
  });
  const jqx = bindRuntime(runtime);
  const expected = [
    {
      ok: false,
      error: {
        kind: "backend_runtime",
        message: "Runtime output stream must contain strings",
      },
    },
  ];
  assert.deepEqual(await collectStream(jqx.runJsonTextStream(".", "null")), expected);
  assert.deepEqual(await collectStream(jqx.runStream(".", null)), expected);
});

test("public runtime error helpers contain revoked Proxy values", () => {
  const revocable = Proxy.revocable({}, {});
  revocable.revoke();
  assert.equal(isJqxError(revocable.proxy), false);
  assert.equal(isJqxRuntimeError(revocable.proxy), false);
  assert.deepEqual(toJqxRuntimeError(revocable.proxy), {
    kind: "backend_runtime",
    message: "Unknown runtime error",
  });
  assert.equal(runtimeErrorToMessage(revocable.proxy), "Unknown runtime error");
});

test("bindRuntime contains throwing streaming capability getters", async () => {
  const runtime: JqxJsonTextRuntime = {
    runJsonText() {
      return { ok: true, value: [] };
    },
  };
  Object.defineProperty(runtime, "runJsonTextStream", {
    get() {
      throw new Error("capability inspection failed");
    },
  });
  const items = await collectStream(bindRuntime(runtime).runJsonTextStream(".", "null"));
  assert.equal(items.length, 1);
  assert.equal(items[0]?.ok, false);
});

test("bindQueryRuntime contains hostile typed-query inspection", async () => {
  const runtime: JqxQueryJsonTextRuntime = {
    runJsonText() {
      return { ok: true, value: [] };
    },
    runQueryJsonText() {
      assert.fail("backend should not receive a hostile query");
    },
  };
  const query = new Proxy<QueryAst>(
    { kind: "identity" },
    {
      ownKeys() {
        throw new Error("query inspection failed");
      },
    },
  );
  const jqx = bindQueryRuntime(runtime);
  const textResult = await jqx.queryJsonText(query, "null");
  const valueResult = await jqx.query(query, null);
  assert.equal(textResult.ok, false);
  assert.equal(valueResult.ok, false);
  const textStream = await collectStream(jqx.queryJsonTextStream(query, "null"));
  const valueStream = await collectStream(jqx.queryStream(query, null));
  assert.equal(textStream.length, 1);
  assert.equal(textStream[0]?.ok, false);
  assert.equal(valueStream.length, 1);
  assert.equal(valueStream[0]?.ok, false);
});

test("bindQueryRuntime contains throwing query-stream capability getters", async () => {
  const runtime: JqxQueryJsonTextRuntime = {
    runJsonText() {
      return { ok: true, value: [] };
    },
    runQueryJsonText() {
      return { ok: true, value: [] };
    },
  };
  Object.defineProperty(runtime, "runQueryJsonTextStream", {
    get() {
      throw new Error("query capability inspection failed");
    },
  });
  const query: QueryAst = { kind: "identity" };
  const items = await collectStream(bindQueryRuntime(runtime).queryJsonTextStream(query, "null"));
  assert.equal(items.length, 1);
  assert.equal(items[0]?.ok, false);
});

test("bindRuntime returns backend_runtime when backend promise rejects", async () => {
  // Given
  const runtime: JqxJsonTextRuntime = {
    runJsonText() {
      return Promise.reject(new Error("async down"));
    },
  };
  const jqx = bindRuntime(runtime);

  // When
  const result = await jqx.run(".", null);

  // Then
  assert.deepEqual(result, {
    ok: false,
    error: { kind: "backend_runtime", message: "async down" },
  });
});

test("bindRuntime stream returns backend_runtime when backend throws before streaming", async () => {
  // Given
  const runtime: JqxJsonTextRuntime & {
    runJsonTextStream(): { ok: true; value: AsyncIterable<string> };
  } = {
    runJsonText() {
      return { ok: true, value: [] };
    },
    runJsonTextStream() {
      throw new Error("stream setup down");
    },
  };
  const jqx = bindRuntime(runtime);

  // When
  const items = await collectStream(jqx.runJsonTextStream(".", "null"));

  // Then
  assert.deepEqual(items, [
    {
      ok: false,
      error: { kind: "backend_runtime", message: "stream setup down" },
    },
  ]);
});

test("bindQueryRuntime preserves custom query objects with an ast field", async () => {
  // Given
  type CustomQuery = { readonly ast: string };
  const seen: CustomQuery[] = [];
  const runtime: JqxQueryJsonTextRuntime<CustomQuery> = {
    runJsonText() {
      return { ok: true, value: [] };
    },
    runQueryJsonText(query) {
      seen.push(query);
      return { ok: true, value: ["null"] };
    },
  };
  const jqx = bindQueryRuntime(runtime);
  const query = { ast: "CUSTOM" };

  // When
  const result = await jqx.queryJsonText(query, "null");

  // Then
  assert.equal(result.ok, true);
  assert.deepEqual(seen, [query]);
});

test("QueryAst import rejects non-JSON literal values", () => {
  // Given
  const documents: unknown[] = [
    {
      format: QUERY_AST_DOCUMENT_FORMAT,
      version: QUERY_AST_DOCUMENT_VERSION,
      ast: { kind: "literal", value: Number.NaN },
    },
    {
      format: QUERY_AST_DOCUMENT_FORMAT,
      version: QUERY_AST_DOCUMENT_VERSION,
      ast: { kind: "literal", value: new Date(0) },
    },
  ];

  for (const document of documents) {
    // When
    const result = importQueryAstDocument(document);

    // Then
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.kind, "invalid_ast");
    }
  }
});

test("QueryAst import rejects cyclic literal values without throwing", () => {
  // Given
  const cyclic: Record<string, unknown> = { kind: "literal" };
  cyclic.value = cyclic;
  const document = {
    format: QUERY_AST_DOCUMENT_FORMAT,
    version: QUERY_AST_DOCUMENT_VERSION,
    ast: cyclic,
  };

  // When
  const result = importQueryAstDocument(document);

  // Then
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "invalid_ast");
  }
});
