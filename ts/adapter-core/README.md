# @shina1024/jqx-adapter-core

Shared support package for jqx TypeScript runtime and adapter packages.

Most users should install `@shina1024/jqx` and one of the validator adapters directly.
Use this package when you are building a custom jqx adapter or integrating with the shared runtime/result/query types used by:

- `@shina1024/jqx-zod-adapter`
- `@shina1024/jqx-yup-adapter`
- `@shina1024/jqx-valibot-adapter`

The package is published because the public adapter packages depend on these shared contracts, but it is not the main end-user entrypoint.

## Scripts

```bash
pnpm build
pnpm format
pnpm format:check
pnpm lint
pnpm lint:typeaware
pnpm typecheck
```

`pnpm build` bundles ESM/CJS with `tsdown` and emits declarations with `tsgo`. `pnpm typecheck` uses `tsgo`.
The workspace pins `@typescript/native-preview` for `tsgo` and type-aware linting, so adapter package verification follows the checked-in native-preview toolchain rather than a separately installed stock `typescript`.
