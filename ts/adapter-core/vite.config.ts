import { defineConfig } from "vite-plus";

function isExternalModule(id: string): boolean {
  return !id.startsWith(".") && !id.startsWith("/") && !/^[A-Za-z]:[\\/]/.test(id);
}

export default defineConfig({
  fmt: {},
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
    format: ["esm"],
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
    outputOptions() {
      return {
        chunkFileNames: "chunks/[name]-[hash].js",
        exports: "named",
      };
    },
    outExtensions() {
      return { js: ".js" };
    },
  },
});
