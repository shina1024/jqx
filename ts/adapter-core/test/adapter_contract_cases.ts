import * as assert from "node:assert/strict";
import { test } from "node:test";

import type { Json, JqxQueryRuntime, JqxRuntime } from "../src/index.js";

type TestResult = { ok: true; value: unknown } | { ok: false; error: unknown };

type FilterOptions = {
  filter: string;
  input: unknown;
  inputSchema: unknown;
  outputSchema: unknown;
};

type QueryOptions = {
  query: { kind: "Q" };
  input: unknown;
  inputSchema: unknown;
  outputSchema: unknown;
};

type InferredOptions = {
  filter: string;
  input: Json;
};

type DynamicAdapterLike = {
  filter(options: FilterOptions): Promise<TestResult>;
  infer(options: InferredOptions): Promise<TestResult>;
};

type QueryAdapterLike = DynamicAdapterLike & {
  query(options: QueryOptions): Promise<TestResult>;
};

type SchemaFactory = {
  userNameInput(this: void): unknown;
  xNumberInput(this: void): unknown;
  stringOutput(this: void): unknown;
  numberOutput(this: void): unknown;
};

type AdapterContractConfig = {
  label: string;
  createDynamicAdapter(this: void, runtime: JqxRuntime): DynamicAdapterLike;
  createQueryAdapter(
    this: void,
    runtime: JqxRuntime & JqxQueryRuntime<{ kind: "Q" }>,
  ): QueryAdapterLike;
  schemas: SchemaFactory;
};

function expectErrorKind(result: TestResult, expected: string): void {
  assert.equal(result.ok, false);
  if (result.ok) {
    return;
  }
  const error = result.error as { kind?: string; message?: string; index?: number };
  assert.equal(error.kind, expected);
}

export function registerAdapterContractCases(config: AdapterContractConfig): void {
  const { label } = config;

  void test(`${label}: adapter.filter validates input and output`, async () => {
    const runtime: JqxRuntime = {
      run(filter, input) {
        assert.equal(filter, ".user.name");
        assert.deepEqual(input, { user: { name: "alice" } });
        return { ok: true, value: ["alice"] };
      },
    };
    const adapter = config.createDynamicAdapter(runtime);
    const result = await adapter.filter({
      filter: ".user.name",
      input: { user: { name: "alice" } },
      inputSchema: config.schemas.userNameInput(),
      outputSchema: config.schemas.stringOutput(),
    });
    assert.equal(result.ok, true);
    if (result.ok) {
      assert.deepEqual(result.value, ["alice"]);
    }
  });

  void test(`${label}: adapter.filter returns input_validation error`, async () => {
    const runtime: JqxRuntime = {
      run() {
        return { ok: true, value: [1] };
      },
    };
    const adapter = config.createDynamicAdapter(runtime);
    const result = await adapter.filter({
      filter: ".",
      input: { x: 1 },
      inputSchema: config.schemas.userNameInput(),
      outputSchema: config.schemas.numberOutput(),
    });
    expectErrorKind(result, "input_validation");
  });

  void test(`${label}: adapter.filter returns runtime error`, async () => {
    const runtime: JqxRuntime = {
      run() {
        return { ok: false, error: { kind: "backend_runtime", message: "boom" } };
      },
    };
    const adapter = config.createDynamicAdapter(runtime);
    const result = await adapter.filter({
      filter: ".",
      input: { x: 1 },
      inputSchema: config.schemas.xNumberInput(),
      outputSchema: config.schemas.numberOutput(),
    });
    expectErrorKind(result, "runtime");
    if (!result.ok) {
      const error = result.error as { message?: string };
      assert.equal(error.message, "boom");
    }
  });

  void test(`${label}: adapter.filter returns output_validation error`, async () => {
    const runtime: JqxRuntime = {
      run() {
        return { ok: true, value: [1] };
      },
    };
    const adapter = config.createDynamicAdapter(runtime);
    const result = await adapter.filter({
      filter: ".",
      input: { x: 1 },
      inputSchema: config.schemas.xNumberInput(),
      outputSchema: config.schemas.stringOutput(),
    });
    expectErrorKind(result, "output_validation");
    if (!result.ok) {
      const error = result.error as { kind?: string; index?: number };
      if (error.kind === "output_validation") {
        assert.equal(error.index, 0);
      }
    }
  });

  void test(`${label}: adapter.query validates through query runtime`, async () => {
    const runtime: JqxRuntime & JqxQueryRuntime<{ kind: "Q" }> = {
      run() {
        return { ok: true, value: [] };
      },
      query(query, input) {
        assert.deepEqual(query, { kind: "Q" });
        assert.deepEqual(input, { x: 7 });
        return { ok: true, value: [7] };
      },
    };
    const adapter = config.createQueryAdapter(runtime);
    const result = await adapter.query({
      query: { kind: "Q" },
      input: { x: 7 },
      inputSchema: config.schemas.xNumberInput(),
      outputSchema: config.schemas.numberOutput(),
    });
    assert.equal(result.ok, true);
    if (result.ok) {
      assert.deepEqual(result.value, [7]);
    }
  });

  void test(`${label}: adapter.infer returns runtime values`, async () => {
    const runtime: JqxRuntime = {
      run(filter, input) {
        assert.equal(filter, ".user.name");
        assert.deepEqual(input, { user: { name: "alice" } });
        return { ok: true, value: ["alice"] };
      },
    };
    const adapter = config.createDynamicAdapter(runtime);
    const result = await adapter.infer({
      filter: ".user.name",
      input: { user: { name: "alice" } },
    });
    assert.equal(result.ok, true);
    if (result.ok) {
      assert.deepEqual(result.value, ["alice"]);
    }
  });

  void test(`${label}: adapter.infer returns runtime error`, async () => {
    const runtime: JqxRuntime = {
      run() {
        return { ok: false, error: { kind: "backend_runtime", message: "boom" } };
      },
    };
    const adapter = config.createDynamicAdapter(runtime);
    const result = await adapter.infer({
      filter: ".",
      input: { x: 1 },
    });
    assert.equal(result.ok, false);
    if (!result.ok) {
      const error = result.error as { kind?: string; message?: string };
      assert.equal(error.kind, "backend_runtime");
      assert.equal(error.message, "boom");
    }
  });
}
