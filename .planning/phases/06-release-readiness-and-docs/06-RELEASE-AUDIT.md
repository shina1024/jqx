# Phase 6 Release Audit Ledger

Use this ledger to record the proof path for each release-readiness run. CI logs are not enough on their own; maintainers should capture the concrete artifact and smoke evidence here after each dry run.

## npm Dry Run

### Workflow Run

- Workflow: `.github/workflows/release-npm.yml`
- Trigger: `workflow_dispatch`
- Inputs:
  - `tag`: `vX.Y.Z`
  - `dry_run`: `true`
- Current manifest version seed: `0.1.0`
- Audit date:
- Auditor:
- Git commit:
- Workflow run URL:
- Result:

### Mandatory npm Commands

```bash
bash ./scripts/ts_packages.sh verify --frozen-lockfile
pnpm --dir ts/jqx test
pnpm --dir ts/jqx exec node --input-type=module -e "const runtime = await import('@shina1024/jqx'); const bind = await import('@shina1024/jqx/bind'); if (typeof runtime.run !== 'function' || typeof bind.bindRuntime !== 'function') process.exit(1);"
pnpm --dir ts/jqx exec node -e "const runtime = require('@shina1024/jqx'); const bind = require('@shina1024/jqx/bind'); if (typeof runtime.run !== 'function' || typeof bind.bindRuntime !== 'function') process.exit(1);"
```

### Package Audit Table

| Package | Version | Workflow run | `dist/` inspection | Export-map review | Local consumer smoke |
| --- | --- | --- | --- | --- | --- |
| `@shina1024/jqx-adapter-core` | `0.1.0` | pending | pending | pending | pending |
| `@shina1024/jqx-zod-adapter` | `0.1.0` | pending | pending | pending | pending |
| `@shina1024/jqx-yup-adapter` | `0.1.0` | pending | pending | pending | pending |
| `@shina1024/jqx-valibot-adapter` | `0.1.0` | pending | pending | pending | pending |
| `@shina1024/jqx` | `0.1.0` | pending | pending | pending | pending |

### Runtime Entrypoint Checks

- Root runtime package: `@shina1024/jqx`
  - Confirm `exports["."]` points at built `dist/index.js`, `dist/index.cjs`, and `dist/index.d.ts`
  - Confirm the published runtime exposes `parseJson`, `isValidJson`, `compile`, `run`, `runJsonText`, `query`, and `queryJsonText`
- Binding subpath: `@shina1024/jqx/bind`
  - Confirm `exports["./bind"]` points at built `dist/bind.js`, `dist/bind.cjs`, and `dist/bind.d.ts`
  - Confirm the published binding surface exposes `bindRuntime` and `bindQueryRuntime`

### Evidence Notes

- Audit artifact uploaded by workflow:
- Package list from `node ./scripts/ts_packages.mjs list`:
  - `ts/adapter-core`
  - `ts/zod-adapter`
  - `ts/yup-adapter`
  - `ts/valibot-adapter`
  - `ts/jqx`
- `dist/` inventory notes:
- Export-map notes:
- Local consumer smoke notes:
- Follow-up issues:

## CLI Packaging Dry Run

### Workflow Run

- Workflow: `.github/workflows/release-cli.yml`
- Trigger: `workflow_dispatch`
- Inputs:
  - `tag`: `vX.Y.Z`
  - `dry_run`: `true`
  - `prerelease`: `false`
- Audit date:
- Auditor:
- Git commit:
- Workflow run URL:
- Result:

### Expected Artifacts

| Platform | Asset name | Archive contents | Extracted executable name | Smoke result |
| --- | --- | --- | --- | --- |
| Linux | `jqx-vX.Y.Z-linux.tar.gz` | pending | `jqx` | pending |
| macOS | `jqx-vX.Y.Z-macos.tar.gz` | pending | `jqx` | pending |
| Windows | `jqx-vX.Y.Z-windows.zip` | pending | `jqx.exe` | pending |

### Mandatory CLI Smoke Commands

```bash
jqx "." "null"
jqx.exe "." "null"
```

### Packaging Checks

- Confirm Linux packaging copies `_build/native/release/build/cmd/cmd` to `dist/jqx`
- Confirm macOS packaging copies `_build/native/release/build/cmd/cmd` to `dist/jqx`
- Confirm Windows packaging copies `_build/native/release/build/cmd/cmd.exe` to `dist/jqx.exe`
- Confirm `actions/upload-artifact` captures every packaged archive even when `dry_run=true`
- Confirm `Publish GitHub Release` is skipped when `dry_run=true`

### Evidence Notes

- Uploaded artifact names:
- Archive listing notes:
- Extracted executable notes:
- Smoke output notes:
- Follow-up issues:

## MoonBit Package Readiness

### Package Identity

- Package: `shina1024/jqx`
- Current manifest version seed: `0.1.0`
- Manifest: `moon.mod.json`
- Published readme source: `README.mbt.md`

### Mandatory MoonBit Commands

```bash
moon package --list --manifest-path moon.mod.json
moon publish --dry-run --manifest-path moon.mod.json
```

### Readiness Fields

- Audit date:
- Auditor:
- Git commit:
- Package listing artifact:
- `moon package --list --manifest-path moon.mod.json` result:
- Bundle contents notes:
- `moon publish --dry-run --manifest-path moon.mod.json` result:
- Authentication prerequisite (`moon login`) satisfied:
- Public package identity review:
- Follow-up issues:

### Notes

- Record whether packaged contents include only intended public files.
- Record whether MoonBit credentials were available at audit time.
- Record any discrepancy between `moon.mod.json`, `README.mbt.md`, and the intended public package story for `shina1024/jqx`.
