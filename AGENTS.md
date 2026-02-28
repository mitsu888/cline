## Cursor Cloud specific instructions

**Product**: Cline — an AI-powered autonomous coding agent that runs as a VS Code extension and a standalone CLI. The codebase includes: core extension (`src/`), webview UI (`webview-ui/`), CLI (`cli/`), standalone runtime (`standalone/`), and eval/testing platforms.

### Quick reference for common commands

See `package.json` scripts and `CONTRIBUTING.md` for full details. Key commands:

| Task | Command |
|---|---|
| Install all deps | `npm run install:all` |
| Generate protos (required before build) | `npm run protos` |
| Dev mode (protos + watch) | `npm run dev` |
| Compile (type-check + lint + esbuild) | `npm run compile` |
| Lint | `npm run lint` |
| Format fix | `npm run format:fix` |
| Unit tests | `npm run test:unit` |
| Webview tests | `npm run test:webview` |
| CLI tests | `npm run cli:test` |
| Build webview | `npm run build:webview` |
| Build CLI | `npm run cli:build` |
| Run CLI (after build) | `node cli/dist/cli.mjs` |

### Non-obvious caveats

- **Protos must be generated before any build or type-check**. `npm run protos` generates TypeScript types from `.proto` files in `proto/`. Without this step, imports from `src/shared/proto/`, `src/generated/`, and `webview-ui/src/services/grpc-client.ts` will fail. The `dev` and `check-types` scripts already include proto generation.
- **Use `npm run compile` instead of `npm run build`** — this is a VS Code extension, not a standard Node app. There is no `build` script at the root.
- **`npm run test:unit` uses mocha** with `cross-env TS_NODE_PROJECT=./tsconfig.unit-test.json`. The `test:webview` uses vitest (in `webview-ui/`), and `cli:test` also uses vitest (in `cli/`).
- **Linux GUI libs are required for integration tests** (`npm run test:integration`) which launch VS Code via `@vscode/test-electron`. These are already installed in the Cloud VM snapshot (xvfb, libgtk-3-0, etc.). Run integration tests with `xvfb-run` if needed: `xvfb-run npm run test:integration`.
- **The `postprotos` script runs `biome format`** automatically after proto generation. This is expected and not an error.
- **CLI is an npm workspace** at `cli/`. It is automatically installed when running `npm install` at root. No separate install step needed.
- **The `lint-staged` pre-commit hook** runs Biome check and auto-generates `state.proto` if `state-keys.ts` changes. If committing fails on lint, run `npm run format:fix` first.
- **Hot reloading**: `npm run dev` (or `npm run watch`) runs esbuild in watch mode for the extension and tsc in watch mode for type-checking. Webview has its own dev server via `npm run dev:webview`.
