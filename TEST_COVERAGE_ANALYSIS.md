# Test Coverage Analysis

A snapshot of the current automated-test landscape in this repository and a prioritized list of areas worth investing in. Intended for contributors picking up testing work.

## Testing Setup

- **Unit tests:** Mocha + NYC, discovered under `src/**/__tests__/*.ts` (config: `.mocharc.json`, `.nycrc.unit.json`). Run with `npm run test:unit` / `npm run test:coverage`.
- **Webview tests:** Vitest in `webview-ui/`.
- **E2E:** Playwright (`playwright.config.ts`, `src/test/e2e/`).
- **CLI:** Tests colocated under `cli/src/`.

## Coverage at a Glance

| Area          | Source files | Test files | Ratio |
| ------------- | -----------: | ---------: | ----: |
| `src/`        |          765 |        111 | 14.5% |
| `webview-ui/` |          302 |         18 |    6% |
| `cli/`        |           49 |         11 |   22% |

Counts are file-level only — they do not reflect line coverage and overstate effective coverage where a single test file exercises many source files (and vice versa).

## Highest-Risk Gaps

### 1. API providers — 36 of 42 untested

`src/core/api/providers/` ships tests for only `bedrock`, `claude-code`, `litellm`, `ollama`, `sapaicore`, `vercel-ai-gateway`. The most-used providers — `anthropic`, `openai`, `openai-native`, `gemini`, `openrouter`, `vertex`, `xai`, `deepseek`, `mistral`, `groq`, `qwen`, `cline` — have no dedicated unit tests. Regressions in request/response shaping, streaming, tool-call parsing, or auth headers ship silently.

**Suggested first targets:** `anthropic`, `openai-native`, `gemini`, `openrouter`, `cline` — likely >80% of active users.

### 2. Controller gRPC handlers — ~3.7% covered

`src/core/controller/` is 190 files / 7 tests. Worst sub-areas:

- `state/` — 28 files, 0 tests. Settings round-trip bugs are exactly the class `CLAUDE.md` calls out as silent failures.
- `models/` — 26 files, 0 tests (`refreshGroqModels`, `getAihubmixModels`, etc.).
- `task/` — 17 files, 0 tests (task routing).
- `mcp/` — 13 files, 0 tests (MCP server lifecycle).
- `account/` — 14 files, 0 tests (auth flows).

### 3. Proto-conversion round-trips

`src/shared/proto-conversions/models/api-configuration-conversion.ts` is the locus of the documented "provider silently resets to Anthropic" bug. A focused round-trip suite (`string → proto enum → string` for every `ApiProvider`) would prevent recurrence and act as a forcing function when new providers are added.

### 4. Webview UI components — ~3% covered

Only `chat/` and `settings/` have any Vitest coverage in `webview-ui/src/components/`. Zero tests in: `account/`, `browser/`, `cline-rules/`, `common/`, `history/`, `mcp/`, `menu/`, `onboarding/`, `ui/`, `welcome/`.

Given the `ChatRow` cancellation pattern documented in `CLAUDE.md` (status stuck on `"generating"` after cancel — requires both `!isLast` and `lastModifiedMessage?.ask === "resume_task"` checks), the chat-row state-derivation logic is a strong candidate for unit tests.

### 5. Tool handlers

`src/core/task/tools/handlers/` is the agent's contract with the world. Coverage is thin; each handler has well-defined inputs/outputs, making them a natural fit for unit tests with fakes. Start with the most-invoked tools: `read_file`, `write_to_file`, `replace_in_file`, `execute_command`.

### 6. Settings update dual-path

Per `CLAUDE.md`, settings keys must round-trip through both `src/core/controller/state/updateSettings.ts` (webview path) and `src/core/controller/state/updateSettingsCli.ts` (CLI/ACP path). A contract test asserting every settings key is handled on both paths would catch the documented "toggle appears stuck" bug class.

### 7. System-prompt variants

`src/core/prompts/system-prompt/__tests__/` has snapshot tests, but coverage across the 10+ variants (`next-gen`, `native-gpt-5`, `native-gpt-5-1`, `gemini-3`, `glm`, `hermes`, `xs`, …) is uneven. Worth auditing which variants have only snapshot coverage vs. behavior tests for `componentOverrides`.

## Recommended Priority Order

The goal is "broken-prone × user-facing" — concentrate effort where bugs are most likely and most visible.

1. **Top-5 provider request/response tests:** `anthropic`, `openai-native`, `gemini`, `openrouter`, `cline`.
2. **Proto-conversion round-trip tests** for `ApiProvider` and `Settings`.
3. **Settings dual-path tests** covering both `updateSettings` and `updateSettingsCli`.
4. **`ChatRow` cancelled/interrupted state-derivation tests.**
5. **Tool handler unit tests** for `read_file`, `write_to_file`, `replace_in_file`, `execute_command`.
6. **Webview tests** for `account/`, `mcp/`, and `onboarding/`.

Each item targets either a documented foot-gun in `CLAUDE.md` or a hot-path module. The intent is not uniform file-level coverage — it is to spend testing effort where regressions are most likely to ship and to hurt.

## Notes & Caveats

- File-ratio numbers are a starting point, not a substitute for `npm run test:coverage` line-coverage data. A follow-up pass to publish line/branch coverage per directory would refine prioritization.
- The `src/test/` integration and E2E suites cover primary chat/auth/diff/editor flows; secondary features are largely unexercised end-to-end.
- Adding tests to high-churn areas (providers, controllers) yields more value than to stable utility code.
