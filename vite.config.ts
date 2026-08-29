import { defineConfig } from "vite-plus";

export default defineConfig({
  fmt: {},
  staged: {
    "*": () => ["moon info", "moon fmt"],
    "ts/jqx/**": () => ["pnpm --dir ts/jqx format", "pnpm --dir ts/jqx lint"],
    "ts/adapter-core/**": () => [
      "pnpm --dir ts/adapter-core format",
      "pnpm --dir ts/adapter-core lint",
    ],
    "ts/yup-adapter/**": () => [
      "pnpm --dir ts/yup-adapter format",
      "pnpm --dir ts/yup-adapter lint",
    ],
    "ts/valibot-adapter/**": () => [
      "pnpm --dir ts/valibot-adapter format",
      "pnpm --dir ts/valibot-adapter lint",
    ],
    "ts/zod-adapter/**": () => [
      "pnpm --dir ts/zod-adapter format",
      "pnpm --dir ts/zod-adapter lint",
    ],
  },
});
