import * as assert from "node:assert/strict";
import { test } from "node:test";

import type { Json, JqxRuntime, JqxTypedRuntime } from "../src/index.js";

type TestResult = { ok: true; value: unknown } | { ok: false; error: unknown };

type FilterOptions<Schema> = {
  filter: string;
  input: unknown;
  inputSchema: Schema;
  outputSchema: Schema;
};

type QueryOptions<Schema> = {
  query: { kind: "Q" };
  input: unknown;
  inputSchema: Schema;
  outputSchema: Schema;
};

type InferredOptions = {
  filter: string;
  input: Json;
};

type DynamicAdapterLike<Schema> = {
  filter(options: FilterOptions<Schema>): Promise<TestResult>;
  inferred(options: InferredOptions): Promise<TestResult>;
};

type TypedAdapterLike<Schema> = DynamicAdapterLike<Schema> & {
  query(options: QueryOptions<Schema>): Promise<TestResult>;
};

type SchemaFactory<Schema> = {
  userNameInput(): Schema;
  xNumberInput(): Schema;
  stringOutput(): Schema;
  numberOutput(): Schema;
};

type AdapterContractConfig<Schema> = {
  label: string;
  createDynamicAdapter(runtime: JqxRuntime): DynamicAdapterLike<Schema>;
  createTypedAdapter(
    runtime: JqxRuntime & JqxTypedRuntime<{ kind: "Q" }>,
  ): TypedAdapterLike<Schema>;
  schemas: SchemaFactory<Schema>;
};

function expectErrorKind(result: TestResult, expected: string): void {
  assert.equal(result.ok, false);
  if (result.ok) {
    return;
  }
  const error = result.error as { kind?: string; message?: string; index?: number };
  assert.equal(error.kind, expected);
}

export function registerAdapterContractCases<Schema>(config: AdapterContractConfig<Schema>): void {
  const { label, createDynamicAdapter, createTypedAdapter, schemas } = config;

  test(`${label}: adapter.filter validates input and output`, async () => {
    const runtime: JqxRuntime = {
      run(filter, input) {
        assert.equal(filter, ".user.name");
        assert.deepEqual(input, { user: { name: "alice" } });
        return { ok: true, value: ["alice"] };
      },
    };
    const adapter = createDynamicAdapter(runtime);
    const result = await adapter.filter({
      filter: ".user.name",
      input: { user: { name: "alice" } },
      inputSchema: schemas.userNameInput(),
      outputSchema: schemas.stringOutput(),
    });
    assert.equal(result.ok, true);
    if (result.ok) {
      assert.deepEqual(result.value, ["alice"]);
    }
  });

  test(`${label}: adapter.filter returns input_validation error`, async () => {
    const runtime: JqxRuntime = {
      run() {
        return { ok: true, value: [1] };
      },
    };
    const adapter = createDynamicAdapter(runtime);
    const result = await adapter.filter({
      filter: ".",
      input: { x: 1 },
      inputSchema: schemas.userNameInput(),
      outputSchema: schemas.numberOutput(),
    });
    expectErrorKind(result, "input_validation");
  });

  test(`${label}: adapter.filter returns runtime error`, async () => {
    const runtime: JqxRuntime = {
      run() {
        return { ok: false, error: { kind: "backend_runtime", message: "boom" } };
      },
    };
    const adapter = createDynamicAdapter(runtime);
    const result = await adapter.filter({
      filter: ".",
      input: { x: 1 },
      inputSchema: schemas.xNumberInput(),
      outputSchema: schemas.numberOutput(),
    });
    expectErrorKind(result, "runtime");
    if (!result.ok) {
      const error = result.error as { message?: string };
      assert.equal(error.message, "boom");
    }
  });

  test(`${label}: adapter.filter returns output_validation error`, async () => {
    const runtime: JqxRuntime = {
      run() {
        return { ok: true, value: [1] };
      },
    };
    const adapter = createDynamicAdapter(runtime);
    const result = await adapter.filter({
      filter: ".",
      input: { x: 1 },
      inputSchema: schemas.xNumberInput(),
      outputSchema: schemas.stringOutput(),
    });
    expectErrorKind(result, "output_validation");
    if (!result.ok) {
      const error = result.error as { kind?: string; index?: number };
      if (error.kind === "output_validation") {
        assert.equal(error.index, 0);
      }
    }
  });

  test(`${label}: adapter.query validates through typed runtime`, async () => {
    const runtime: JqxRuntime & JqxTypedRuntime<{ kind: "Q" }> = {
      run() {
        return { ok: true, value: [] };
      },
      query(query, input) {
        assert.deepEqual(query, { kind: "Q" });
        assert.deepEqual(input, { x: 7 });
        return { ok: true, value: [7] };
      },
    };
    const adapter = createTypedAdapter(runtime);
    const result = await adapter.query({
      query: { kind: "Q" },
      input: { x: 7 },
      inputSchema: schemas.xNumberInput(),
      outputSchema: schemas.numberOutput(),
    });
    assert.equal(result.ok, true);
    if (result.ok) {
      assert.deepEqual(result.value, [7]);
    }
  });

  test(`${label}: adapter.inferred returns runtime values`, async () => {
    const runtime: JqxRuntime = {
      run(filter, input) {
        assert.equal(filter, ".user.name");
        assert.deepEqual(input, { user: { name: "alice" } });
        return { ok: true, value: ["alice"] };
      },
    };
    const adapter = createDynamicAdapter(runtime);
    const result = await adapter.inferred({
      filter: ".user.name",
      input: { user: { name: "alice" } },
    });
    assert.equal(result.ok, true);
    if (result.ok) {
      assert.deepEqual(result.value, ["alice"]);
    }
  });

  test(`${label}: adapter.inferred returns runtime error`, async () => {
    const runtime: JqxRuntime = {
      run() {
        return { ok: false, error: { kind: "backend_runtime", message: "boom" } };
      },
    };
    const adapter = createDynamicAdapter(runtime);
    const result = await adapter.inferred({
      filter: ".",
      input: { x: 1 },
    });
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error, "boom");
    }
  });
}
