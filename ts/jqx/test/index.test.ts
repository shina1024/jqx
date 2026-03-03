import * as assert from "node:assert/strict";
import { test } from "node:test";

import {
  createJqx,
  createQueryJqx,
  exportQueryAstDocument,
  exportTypedQueryDocument,
  field,
  importQueryAstDocument,
  parseQueryAstDocument,
  QUERY_AST_DOCUMENT_FORMAT,
  QUERY_AST_DOCUMENT_VERSION,
  stringifyQueryAstDocument,
  toAst,
  type JqxBackend,
  type JqxQueryBackend,
  type JqxRuntimeError,
  type QueryAst,
} from "../src/index.js";

async function collectStream<T, E>(stream: AsyncIterable<{ ok: true; value: T } | { ok: false; error: E }>) {
  const items: Array<{ ok: true; value: T } | { ok: false; error: E }> = [];
  for await (const item of stream) {
    items.push(item);
  }
  return items;
}

test("createJqx delegates runJsonText", async () => {
  const backend: JqxBackend = {
    runJsonText(filter, input) {
      return { ok: true as const, value: [`${filter}:${input}`] };
    },
  };
  const jqx = createJqx(backend);
  const result = await jqx.runJsonText(".", '{"x":1}');
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, ['.:{"x":1}']);
  }
});

test("createJqx run stringifies input and parses outputs", async () => {
  const backend: JqxBackend = {
    runJsonText(filter, input) {
      assert.equal(filter, ".x");
      assert.equal(input, '{"x":1}');
      return { ok: true as const, value: ['{"x":1}'] };
    },
  };
  const jqx = createJqx(backend);
  const result = await jqx.run(".x", { x: 1 });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, [{ x: 1 }]);
  }
});

test("createJqx run returns parse error for invalid raw JSON", async () => {
  const backend: JqxBackend = {
    runJsonText() {
      return { ok: true as const, value: ["not-json"] };
    },
  };
  const jqx = createJqx(backend);
  const result = await jqx.run(".", 1);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "output_parse");
    if (result.error.kind === "output_parse") {
      assert.equal(result.error.index, 0);
    }
  }
});

test("createJqx normalizes legacy backend string errors", async () => {
  const backend: JqxBackend = {
    runJsonText() {
      return { ok: false as const, error: "boom" as unknown as JqxRuntimeError };
    },
  };
  const jqx = createJqx(backend);
  const rawOut = await jqx.runJsonText(".", "{}");
  assert.equal(rawOut.ok, false);
  if (!rawOut.ok) {
    assert.deepEqual(rawOut.error, { kind: "backend_runtime", message: "boom" });
  }
});

test("createJqx runJsonTextStream falls back to runJsonText", async () => {
  const backend: JqxBackend = {
    runJsonText(filter, input) {
      assert.equal(filter, ".");
      assert.equal(input, '{"x":1}');
      return { ok: true as const, value: ['{"x":1}', '{"x":2}'] };
    },
  };
  const jqx = createJqx(backend);
  const items = await collectStream(jqx.runJsonTextStream(".", '{"x":1}'));
  assert.deepEqual(items, [
    { ok: true, value: '{"x":1}' },
    { ok: true, value: '{"x":2}' },
  ]);
});

test("createJqx runJsonTextStream prefers backend streaming lane", async () => {
  const backend: JqxBackend & {
    runJsonTextStream(filter: string, input: string): {
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
  const jqx = createJqx(backend);
  const items = await collectStream(jqx.runJsonTextStream(".", '{"x":1}'));
  assert.deepEqual(items, [
    { ok: true, value: '{"x":1}' },
    { ok: true, value: '{"x":2}' },
  ]);
});

test("createJqx runJsonTextStream yields backend_runtime on stream iteration failure", async () => {
  const backend: JqxBackend & {
    runJsonTextStream(filter: string, input: string): {
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
  const jqx = createJqx(backend);
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

test("createJqx runStream parses each streamed json value", async () => {
  const backend: JqxBackend & {
    runJsonTextStream(filter: string, input: string): {
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
  const jqx = createJqx(backend);
  const items = await collectStream(jqx.runStream(".x", { x: 1 }));
  assert.deepEqual(items, [
    { ok: true, value: 1 },
    { ok: true, value: 2 },
  ]);
});

test("createJqx runStream returns parse error with index", async () => {
  const backend: JqxBackend & {
    runJsonTextStream(filter: string, input: string): {
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
  const jqx = createJqx(backend);
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

test("createQueryJqx supports queryJsonText and query", async () => {
  const calls: Array<{ query: QueryAst; input: string }> = [];
  const backend: JqxQueryBackend<QueryAst> = {
    runJsonText() {
      return { ok: true as const, value: [] };
    },
    runQueryJsonText(query, input) {
      calls.push({ query, input });
      return { ok: true as const, value: ['{"name":"alice"}'] };
    },
  };
  const jqx = createQueryJqx(backend);
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

test("createQueryJqx queryJsonTextStream falls back to runQueryJsonText", async () => {
  const backend: JqxQueryBackend<QueryAst> = {
    runJsonText() {
      return { ok: true as const, value: [] };
    },
    runQueryJsonText(query, input) {
      assert.deepEqual(query, toAst(field("user")));
      assert.equal(input, '{"user":{"name":"alice"}}');
      return { ok: true as const, value: ['{"name":"alice"}'] };
    },
  };
  const jqx = createQueryJqx(backend);
  const items = await collectStream(jqx.queryJsonTextStream(field("user"), '{"user":{"name":"alice"}}'));
  assert.deepEqual(items, [{ ok: true, value: '{"name":"alice"}' }]);
});

test("createQueryJqx queryStream uses query streaming lane and normalizes DSL query", async () => {
  const calls: QueryAst[] = [];
  const backend: JqxQueryBackend<QueryAst> & {
    runQueryJsonTextStream(query: QueryAst, input: string): {
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
  const jqx = createQueryJqx(backend);
  const dslQuery = field("user");
  const items = await collectStream(jqx.queryStream(dslQuery, { user: { name: "alice" } }));
  assert.deepEqual(items, [{ ok: true, value: { name: "alice" } }]);
  assert.deepEqual(calls, [toAst(dslQuery)]);
});

test("createQueryJqx supports custom query lane without DSL normalization", async () => {
  const calls: Array<{ query: { kind: "custom"; key: string }; input: string }> = [];
  const backend = {
    runJsonText() {
      return { ok: true as const, value: [] };
    },
    runQueryJsonText(query: { kind: "custom"; key: string }, input: string) {
      calls.push({ query, input });
      return { ok: true as const, value: ['{"name":"alice"}'] };
    },
  };
  const jqx = createQueryJqx(backend);
  const result = await jqx.query(
    { kind: "custom", key: "user" },
    { user: { name: "alice" } },
  );
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
