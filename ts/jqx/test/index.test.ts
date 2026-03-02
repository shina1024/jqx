import * as assert from "node:assert/strict";
import { test } from "node:test";

import {
  createJqx,
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
  type JqxRuntimeError,
  type JqxTypedBackend,
  type QueryAst,
} from "../src/index.js";

test("createJqx delegates runRaw", async () => {
  const backend: JqxBackend = {
    runRaw(filter, input) {
      return { ok: true as const, value: [`${filter}:${input}`] };
    },
  };
  const jqx = createJqx(backend);
  const result = await jqx.runRaw(".", '{"x":1}');
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, ['.:{"x":1}']);
  }
});

test("createJqx run stringifies input and parses outputs", async () => {
  const backend: JqxBackend = {
    runRaw(filter, input) {
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
    runRaw() {
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
    runRaw() {
      return { ok: false as const, error: "boom" as unknown as JqxRuntimeError };
    },
  };
  const jqx = createJqx(backend);
  const rawOut = await jqx.runRaw(".", "{}");
  assert.equal(rawOut.ok, false);
  if (!rawOut.ok) {
    assert.deepEqual(rawOut.error, { kind: "backend_runtime", message: "boom" });
  }
});

test("createJqx typed client supports queryRaw and query", async () => {
  const calls: Array<{ query: QueryAst; input: string }> = [];
  const backend: JqxTypedBackend<QueryAst> = {
    runRaw() {
      return { ok: true as const, value: [] };
    },
    runQueryRaw(query, input) {
      calls.push({ query, input });
      return { ok: true as const, value: ['{"name":"alice"}'] };
    },
  };
  const jqx = createJqx(backend);
  const dslQuery = field("user");
  const queryAst = toAst(dslQuery);

  const rawResult = await jqx.queryRaw(queryAst, '{"user":{"name":"alice"}}');
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
