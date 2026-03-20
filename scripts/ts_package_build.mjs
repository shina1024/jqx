#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { cpSync, existsSync, readdirSync } from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import { pathToFileURL } from "node:url";

const entryPoints = process.argv.slice(2);

if (entryPoints.length === 0) {
  console.error("Usage: node ../../scripts/ts_package_build.mjs <entry> [entry...]");
  process.exit(2);
}

const packageDir = process.cwd();
const distDir = path.join(packageDir, "dist");
const binExt = process.platform === "win32" ? ".cmd" : "";
let repairedInstall = false;
const packageRequire = createRequire(path.join(packageDir, "package.json"));

function repairInstall() {
  if (repairedInstall) {
    return;
  }
  repairedInstall = true;
  console.warn(
    "[ts-package-build] Missing local package tools; running pnpm install --frozen-lockfile to repair package dependencies.",
  );
  run("pnpm", ["install", "--frozen-lockfile"]);
}

function binPath(name) {
  const candidate = path.join(packageDir, "node_modules", ".bin", `${name}${binExt}`);
  if (!existsSync(candidate) && !repairedInstall) {
    repairInstall();
  }
  if (!existsSync(candidate)) {
    throw new Error(
      `Missing ${path.basename(candidate)}. Reinstall package dependencies for this checkout before building package artifacts.`,
    );
  }
  return candidate;
}

function run(command, args) {
  console.log(`$ ${path.basename(command)} ${args.join(" ")}`);
  const sharedOptions = {
    cwd: packageDir,
    env: {
      ...process.env,
      CI: process.env.CI ?? "true",
    },
    stdio: "inherit",
  };
  const result =
    process.platform === "win32"
      ? spawnSync(process.env.ComSpec ?? "cmd.exe", [
          "/d",
          "/s",
          "/c",
          `${command} ${args.join(" ")}`,
        ], sharedOptions)
      : spawnSync(command, args, sharedOptions);

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(`Command failed: ${path.basename(command)} ${args.join(" ")}`);
  }
}

async function importPackageLocal(specifier) {
  let resolved;
  try {
    resolved = packageRequire.resolve(specifier);
  } catch {
    repairInstall();
    try {
      resolved = packageRequire.resolve(specifier);
    } catch {
      throw new Error(
        `Missing package dependency "${specifier}". Reinstall package dependencies for this checkout before building package artifacts.`,
      );
    }
  }
  return import(pathToFileURL(resolved).href);
}

function isExternalModule(id) {
  return !id.startsWith(".") && !path.isAbsolute(id);
}

function syncDcts(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      syncDcts(fullPath);
      continue;
    }
    if (!entry.name.endsWith(".d.ts")) {
      continue;
    }
    cpSync(fullPath, fullPath.slice(0, -".d.ts".length) + ".d.cts");
  }
}

try {
  const { build } = await importPackageLocal("tsdown");
  const entries = Object.fromEntries(
    entryPoints.map((entryPoint) => [
      path.basename(entryPoint, path.extname(entryPoint)),
      entryPoint,
    ]),
  );

  await build({
    cwd: packageDir,
    entry: entries,
    format: ["es", "cjs"],
    deps: {
      neverBundle: isExternalModule,
    },
    platform: "node",
    outDir: distDir,
    clean: true,
    report: false,
    dts: false,
    outputOptions(_, format) {
      return {
        chunkFileNames:
          format === "cjs" ? "chunks/[name]-[hash].cjs" : "chunks/[name]-[hash].js",
        exports: "named",
      };
    },
    outExtensions({ format }) {
      return { js: format === "cjs" ? ".cjs" : ".js" };
    },
  });

  run(binPath("tsgo"), [
    "-p",
    "tsconfig.build.json",
    "--emitDeclarationOnly",
    "--declaration",
    "--rootDir",
    "src",
    "--declarationDir",
    "dist",
  ]);

  syncDcts(distDir);
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[ts-package-build] ${message}`);
  process.exit(1);
}
