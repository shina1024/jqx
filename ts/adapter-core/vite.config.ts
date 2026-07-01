import { defineConfig } from "vite-plus";

function isExternalModule(id: string): boolean {
  return !id.startsWith(".") && !id.startsWith("/") && !/^[A-Za-z]:[\\/]/.test(id);
}

export default defineConfig({
  lint: {
    options: {
      typeAware: true,
      typeCheck: true,
    },
  },
  test: {
    include: ["test/**/*.test.ts"],
  },
  pack: {
    entry: {
      index: "src/index.ts",
    },
    format: ["esm", "cjs"],
    deps: {
      neverBundle: isExternalModule,
    },
    platform: "node",
    outDir: "dist",
    clean: true,
    report: false,
    dts: {
      oxc: true,
      entry: ["src/index.ts", "src/typed_query.ts"],
      tsconfig: "tsconfig.build.json",
    },
    outputOptions(_, format) {
      return {
        chunkFileNames: format === "cjs" ? "chunks/[name]-[hash].cjs" : "chunks/[name]-[hash].js",
        exports: "named",
      };
    },
    outExtensions({ format }) {
      return { js: format === "cjs" ? ".cjs" : ".js" };
    },
  },
});
