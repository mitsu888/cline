## Cursor Cloud specific instructions

### Overview

Cline is a VS Code extension (+ standalone CLI) that acts as an autonomous AI coding agent. The codebase has three main parts:

- **Extension** (root): TypeScript, esbuild, Mocha tests
- **Webview UI** (`webview-ui/`): React 18, Vite, Vitest tests
- **CLI** (`cli/`): React Ink terminal UI, Vitest tests

Communication between extension and webview uses gRPC-like protocol over VS Code message passing. Proto files live in `proto/` and must be regenerated after changes with `npm run protos`.

### Key commands

See `CONTRIBUTING.md` for full setup steps. Quick reference:

| Task | Command |
|---|---|
| Install all deps | `npm run install:all` |
| Generate protos | `npm run protos` |
| Lint | `npm run lint` |
| Format | `npm run format:fix` |
| Type check | `npm run check-types` |
| Build extension | `node esbuild.mjs` |
| Build webview | `npm run build:webview` |
| Build CLI | `npm run cli:build` |
| Unit tests (extension) | `npm run test:unit` |
| Webview tests | `cd webview-ui && npm run test` |
| CLI tests | `cd cli && npm run test:run` |
| Dev watch mode | `npm run dev` (protos + esbuild watch) |
| CI build | `npm run ci:build` |

### Non-obvious caveats

- **Proto generation is required before first build.** `npm run protos` must be run at least once. The `npm run dev` script does this automatically.
- **`npm run compile` includes type-checking and linting**, which can be slow. For a fast build during development, use `node esbuild.mjs` directly.
- The extension build output goes to `dist/extension.js`. The webview builds to `webview-ui/build/`.
- **VS Code integration tests require `xvfb-run`** on Linux: `xvfb-run -a npm run test:integration`. System libraries (libgtk-3-0, libnss3, etc.) must be installed — see `CONTRIBUTING.md`.
- **The CLI is an npm workspace** (`cli/`). Its dependencies are installed with the root `npm install`. The webview-ui is NOT a workspace — run `cd webview-ui && npm install` separately (or `npm run install:all`).
- The linter/formatter is **Biome** (not ESLint/Prettier). Config is in `biome.jsonc`.
- CI uses Node.js 22 (matches `.nvmrc` `lts/*`).
- `package.json` uses `lint-staged` with a husky pre-commit hook for auto-formatting.
