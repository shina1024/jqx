declare module "../../../target/js/release/build/js/js.js" {
  const runtime: Record<string, unknown> & {
    default?: Record<string, unknown>;
  };

  export = runtime;
}
