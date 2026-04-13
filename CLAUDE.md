@.clinerules/general.md
@.clinerules/network.md
@.clinerules/cli.md

# Cline — Comprehensive Development Guide

## What Is This Project?

Cline is a VS Code extension (and CLI) that provides an autonomous AI coding agent. It supports 40+ AI providers (Anthropic, OpenAI, Bedrock, Gemini, Ollama, etc.), executes tools (file ops, terminal, browser), and communicates between a TypeScript backend and a React webview via gRPC-over-postMessage.

**This is a VS Code extension** — use `npm run compile` to verify builds, not `npm run build`.

## Repository Layout

```
cline/
├── src/                    # Extension backend (TypeScript)
│   ├── extension.ts        # VS Code activation entry point
│   ├── common.ts           # Platform-agnostic initialization
│   ├── config.ts           # Configuration management
│   ├── core/               # Core business logic
│   │   ├── api/            # API handler abstraction (40+ providers)
│   │   ├── controller/     # Message routing, state management, orchestrator
│   │   ├── task/           # Task execution engine (API calls, tool execution)
│   │   ├── webview/        # Webview lifecycle management
│   │   ├── context/        # Context tracking (files, environment, instructions)
│   │   ├── storage/        # Local state persistence
│   │   ├── prompts/        # System prompts (modular: components + variants + templates)
│   │   ├── slash-commands/  # Slash command definitions
│   │   ├── hooks/          # Pre/post-task hook system
│   │   ├── permissions/    # Command permission control
│   │   ├── mentions/       # @-mention parsing
│   │   ├── workspace/      # Workspace detection
│   │   └── ignore/         # .clineignore handling
│   ├── shared/             # Platform-agnostic shared code
│   │   ├── api.ts          # ApiProvider union type, model definitions
│   │   ├── ExtensionMessage.ts  # ClineAsk, ClineSay, message types
│   │   ├── tools.ts        # ClineDefaultTool enum
│   │   ├── proto/          # Generated protobuf type definitions
│   │   ├── proto-conversions/   # TS <-> proto mapping functions
│   │   ├── storage/        # State key type definitions
│   │   ├── providers/      # providers.json for UI dropdown
│   │   └── net.ts          # Proxy-aware fetch/axios (MUST use for all network calls)
│   ├── generated/          # Auto-generated code (DO NOT edit)
│   │   ├── grpc-js/        # gRPC JavaScript bindings
│   │   ├── nice-grpc/      # Promise-based gRPC clients
│   │   └── hosts/          # Host-specific generated code
│   ├── hosts/              # Platform-specific implementations
│   │   ├── host-provider.ts     # Singleton for dependency injection
│   │   └── vscode/         # VS Code-specific (terminal, diff, webview)
│   ├── integrations/       # Feature integrations (editor, terminal, checkpoints, browser)
│   ├── services/           # Cross-cutting services (auth, MCP, telemetry, search, browser)
│   ├── utils/              # Utility functions (path, fs, model-utils)
│   ├── exports/            # Public API surface for external extensions
│   └── standalone/         # Standalone (non-VS Code) mode
├── webview-ui/             # React frontend (Vite + React 18 + Tailwind + HeroUI)
│   └── src/
│       ├── App.tsx         # View router (Chat, Settings, History, MCP, Account, etc.)
│       ├── components/     # UI components organized by feature
│       ├── context/        # React contexts (ExtensionStateContext, Auth, Platform)
│       ├── services/       # Generated gRPC clients for backend communication
│       └── hooks/          # Custom React hooks
├── cli/                    # Terminal UI (React Ink)
│   └── src/
│       ├── index.ts        # CLI entry point (Commander.js)
│       ├── components/     # Ink React components (ChatView, ConfigView, etc.)
│       ├── agent/          # ClineAgent — core stateless agent logic
│       ├── acp/            # Agent Client Protocol (stdio mode)
│       └── context/        # TaskContext, StdinContext
├── proto/                  # Protocol Buffer definitions (22 .proto files)
│   ├── cline/             # Extension services (task, ui, state, models, etc.)
│   └── host/              # Host bridge services (diff, env, window, workspace)
├── scripts/               # Build, test, and deployment scripts (30+)
├── .clinerules/           # Tribal knowledge and development guides
│   ├── general.md         # Core development patterns and gotchas
│   ├── network.md         # Network/proxy requirements
│   ├── cli.md             # CLI development guide
│   ├── cline-overview.md  # Full architecture overview with diagrams
│   ├── protobuf-development.md  # 4-step gRPC endpoint guide
│   ├── workflows/         # Release, PR review, and documentation workflows
│   └── hooks/             # Hook lifecycle examples
├── esbuild.mjs            # Build configuration (aliases, multiple targets)
├── biome.jsonc            # Linter + formatter (tabs, no semicolons, 130-char lines)
├── tsconfig.json          # TypeScript config (ES2022, strict, path aliases)
└── package.json           # Scripts, dependencies, workspace config
```

## Architecture Flow

```
extension.ts (activate)
  → setupHostProvider()           # Platform-specific factory injection
  → initialize(context)           # Services, state, hooks
  → WebviewProvider               # Manages webview lifecycle
    → Controller                  # Orchestrates messages <-> tasks, manages state
      → Task                      # Executes API calls + tool operations in a loop
        → ApiHandler              # Calls AI provider (Anthropic, OpenAI, etc.)
        → ToolExecutor            # Runs tools (file edit, terminal, browser, etc.)
```

**Communication:** Extension ↔ Webview uses gRPC-like protocol serialized as protobuf over `postMessage`. The CLI uses event emitters and direct callbacks.

## Key Scripts

| Command | Purpose |
|---------|---------|
| `npm run compile` | Type-check + lint + build extension |
| `npm run dev` | Build protos + watch mode (esbuild + tsc) |
| `npm run protos` | Regenerate TypeScript from .proto files |
| `npm run check-types` | Type-check extension + webview + CLI |
| `npm run lint` | Biome lint + proto lint |
| `npm run format:fix` | Auto-fix formatting (changed files only) |
| `npm run test:unit` | Mocha unit tests (`src/**/__tests__/*.ts`) |
| `npm run test:integration` | VS Code extension integration tests |
| `npm run test:e2e` | Playwright end-to-end tests |
| `npm run dev:webview` | Webview dev server with HMR |
| `npm run build:webview` | Production webview build |
| `npm run cli:build` | Build CLI |
| `npm run cli:dev` | CLI dev mode |
| `npm run changeset` | Create a changelog entry (always patch) |
| `UPDATE_SNAPSHOTS=true npm run test:unit` | Regenerate system prompt snapshots |

## Path Aliases

Configured in `tsconfig.json` and resolved by esbuild:

| Alias | Maps to |
|-------|---------|
| `@/*` | `src/*` |
| `@core/*` | `src/core/*` |
| `@shared/*` | `src/shared/*` |
| `@services/*` | `src/services/*` |
| `@integrations/*` | `src/integrations/*` |
| `@hosts/*` | `src/hosts/*` |
| `@utils/*` | `src/utils/*` |
| `@generated/*` | `src/generated/*` |

## Code Style

- **Formatter/Linter:** Biome (`biome.jsonc`)
- **Indentation:** Tabs (width 4)
- **Semicolons:** None
- **Line width:** 130 characters
- **Trailing commas:** All
- **Arrow parens:** Always
- **Line endings:** LF
- **Quotes:** Double quotes (JS/TS)

## Critical Development Patterns

### gRPC/Protobuf Communication

Proto files live in `proto/` — one per feature domain. After any `.proto` change, run `npm run protos`.

**4-step workflow for new RPCs:**
1. Define RPC in the appropriate `.proto` file
2. Run `npm run protos` to regenerate types
3. Implement handler in `src/core/controller/<domain>/`
4. Call from webview: `ServiceClient.methodName(Request.create({ ... }))`

For simple data, use shared types from `proto/cline/common.proto` (`StringRequest`, `Empty`, `Int64Request`, `KeyValuePair`). For complex data, define custom messages in the feature's `.proto` file.

### Adding a New API Provider

**Three proto conversion files MUST be updated** or the provider silently resets to Anthropic:

1. `proto/cline/models.proto` — add to `ApiProvider` enum
2. `convertApiProviderToProto()` in `src/shared/proto-conversions/models/api-configuration-conversion.ts`
3. `convertProtoToApiProvider()` in the same file

**Other required files:**
- `src/shared/api.ts` — `ApiProvider` union type and model definitions
- `src/shared/providers/providers.json` — dropdown list
- `src/core/api/index.ts` — register in `createHandlerForProvider()`
- `webview-ui/src/components/settings/utils/providerUtils.ts` — `getModelsForProvider()` + `normalizeApiConfiguration()`
- `webview-ui/src/utils/validate.ts` — validation case
- `webview-ui/src/components/settings/ApiOptions.tsx` — render component
- `cli/src/components/ModelPicker.tsx` — CLI provider registration

### Responses API Providers (OpenAI Codex, OpenAI Native)

For providers using OpenAI's Responses API:
1. Add provider to `isNextGenModelProvider()` in `src/utils/model-utils.ts`
2. Set `apiFormat: ApiFormat.OPENAI_RESPONSES` on models in `src/shared/api.ts`
3. Variant matcher and task runner handle the rest automatically

### Adding Tools to System Prompt

1. Add to `ClineDefaultTool` enum in `src/shared/tools.ts`
2. Define variants in `src/core/prompts/system-prompt/tools/` (export at minimum `[GENERIC]`)
3. Register in `src/core/prompts/system-prompt/tools/init.ts`
4. Add to variant configs in `src/core/prompts/system-prompt/variants/*/config.ts`
5. Create handler in `src/core/task/tools/handlers/`
6. Wire in `ToolExecutor.ts` and assistant message parser if needed
7. After changes: `UPDATE_SNAPSHOTS=true npm run test:unit`

**Variant tiers for system prompt modifications:**
- **Next-gen** (Claude 4, GPT-5, Gemini 2.5): `next-gen/`, `native-next-gen/`, `native-gpt-5/`, `gpt-5/`, `gemini-3/`
- **Standard** (default fallback): `generic/`
- **Small/local models**: `xs/`, `hermes/`, `glm/`

### Adding Global State Keys

1. Type definition in `src/shared/storage/state-keys.ts`
2. Read in `src/core/storage/utils/state-helpers.ts` — add both `context.globalState.get()` call AND return value
3. For settings toggleable from UI, wire BOTH update paths:
   - `src/core/controller/state/updateSettings.ts` (webview)
   - `src/core/controller/state/updateSettingsCli.ts` (CLI/ACP)
4. For webview round-trip: add to `UpdateSettingsRequest` in `proto/cline/state.proto`, run `npm run protos`, include in `getStateToPostToWebview()`, and update `ExtensionState` + webview defaults

### Networking

**All extension-side network calls MUST use the proxy-aware wrappers** from `@/shared/net`:
- Use `import { fetch } from '@/shared/net'` instead of global `fetch`
- Use `getAxiosSettings()` spread into axios config
- Pass custom `fetch` to third-party clients (OpenAI, etc.)
- Webview code CAN use global `fetch` (browser handles proxies)

### Modifying Slash Commands

Three files need updates:
- `src/core/slash-commands/index.ts` — command definitions
- `src/core/prompts/commands.ts` — system prompt integration
- `webview-ui/src/utils/slash-commands.ts` — webview autocomplete

### ChatRow Cancelled/Interrupted States

When a ChatRow shows a loading state, detect cancellation with:
```tsx
const wasCancelled =
    info.status === "generating" &&
    (!isLast ||
        lastModifiedMessage?.ask === "resume_task" ||
        lastModifiedMessage?.ask === "resume_completed_task")
```
Both `!isLast` (message is stale) and `resume_task` check (just cancelled) are needed.

### StateManager Cache vs Direct globalState

Use `controller.stateManager.setGlobalState()`/`getGlobalStateKey()` for normal state access. Exception: state needed at startup before cache is ready — read directly from `context.globalState.get()` in `common.ts`.

## Testing

- **Unit tests:** `src/**/__tests__/*.ts` (Mocha + ts-node)
- **Integration tests:** `src/test/*.test.ts` (vscode-test)
- **E2E tests:** `src/test/e2e/` (Playwright)
- **Webview tests:** `cd webview-ui && npm run test`
- **CLI tests:** `cd cli && npm run test`
- **System prompt snapshots:** Live in `src/core/prompts/system-prompt/__tests__/__snapshots__/`. Regenerate with `UPDATE_SNAPSHOTS=true npm run test:unit`

## Feature Flags

See PR https://github.com/cline/cline/pull/7566 as reference for adding new feature flags.

## Changesets

For user-facing, significant changes: `npm run changeset` and create a **patch** changeset. Never create minor or major bumps. Skip changesets for trivial fixes, internal refactors, or minor UI tweaks.
