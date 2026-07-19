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
  literal,
  parseQueryAstDocument,
  QUERY_AST_DOCUMENT_FORMAT,
  QUERY_AST_DOCUMENT_VERSION,
  stringifyQueryAstDocument,
  toAst,
  type JqxJsonTextRuntime,
  type JqxQueryJsonTextRuntime,
  type JqxRuntimeError,
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
      return { ok: false as const, error: "boom" as unknown as JqxRuntimeError };
    },
  };
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
