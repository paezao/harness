# Detecting the stack and its commands

Priority of sources, highest first:

1. CI workflow steps (`.github/workflows/*.yml`, `.gitlab-ci.yml`, `azure-pipelines.yml`, `bitbucket-pipelines.yml`).
   What CI runs is what "green" means for this team.
2. Task runners: `Makefile`, `justfile`, `Taskfile.yml`, `package.json` scripts, `pyproject.toml` `[tool.*]`/scripts, `Cargo.toml` aliases.
3. README / CONTRIBUTING "development" sections.
4. Ecosystem defaults below - only if the tool is actually configured in the repo.

## Signals -> typical commands

| Signal | Package manager / runner | Format | Lint | Typecheck | Test |
|---|---|---|---|---|---|
| `package.json` + `pnpm-lock.yaml` | `pnpm` | prettier / biome (if configured) | `pnpm lint` | `pnpm typecheck` or `pnpm exec tsc --noEmit` | `pnpm test` |
| `package.json` + `yarn.lock` | `yarn` | same | `yarn lint` | same | `yarn test` |
| `package.json` + `package-lock.json` | `npm` | same | `npm run lint` | same | `npm test` |
| `bun.lockb` / `bun.lock` | `bun` | same | `bun run lint` | same | `bun test` |
| `pyproject.toml` + `uv.lock` | `uv run` | `ruff format` | `ruff check` | `mypy` / `pyright` (if configured) | `pytest` |
| `poetry.lock` | `poetry run` | same | same | same | same |
| `go.mod` | `go` | `gofmt -w` | `go vet ./...` / `golangci-lint run` | (compiler) | `go test ./...` |
| `Cargo.toml` | `cargo` | `cargo fmt` | `cargo clippy -- -D warnings` | (compiler) | `cargo test` |
| `*.csproj` / `*.sln` | `dotnet` | `dotnet format` | (analyzers) | `dotnet build` | `dotnet test` |
| `Gemfile` | `bundle exec` | `rubocop -a` | `rubocop` | `srb tc` (if sorbet) | `rspec` / `rails test` |
| `project.godot` | Godot | `gdformat` (if gdtoolkit) | `gdlint` | - | GUT / gdUnit CLI if present |
| `ProjectSettings/ProjectVersion.txt` | Unity | `dotnet format` on asmdef projects if used | - | - | Unity `-runTests -batchmode` if a CLI path is known |
| `*.uproject` | Unreal | clang-format if `.clang-format` | - | - | Automation tests via `UnrealEditor-Cmd` if scripted |
| `default.project.json` / `rokit.toml` / `aftman.toml` | Rojo (Roblox) | `stylua` | `selene` | `luau-lsp analyze` if configured | TestEZ / Jest-Lua runner if present |

Monorepos: prefer the root task runner (`turbo run test`, `nx affected -t test`, `pnpm -r test`).
If only per-package commands exist, put the affected-package form in `acceptance` and note the full
suite in `CLAUDE.md`.

## Formatter lines for `.claude/harness/formatters`

Format: `<comma-separated globs> <command>`; the edited file path is appended as the last argument.

```
*.ts,*.tsx,*.js,*.jsx,*.json,*.css,*.md   npx --no-install prettier --write
*.py                                      uv run ruff format
*.go                                      gofmt -w
*.rs                                      rustfmt
*.cs                                      dotnet format whitespace --include
*.gd                                      gdformat
*.lua,*.luau                              stylua
```

Use `npx --no-install` (or the project's runner) so the hook never downloads packages.

## Secrets to deny

Look for and deny reads of: `.env`, `.env.*` (allow `.env.example` if used), `*.pem`, `*.key`, `*.p12`,
`*.keystore`, `secrets/**`, `**/credentials*.json`, `**/service-account*.json`, `*.tfstate`.
Only add rules for patterns that exist or plausibly will (e.g. `.env` in `.gitignore`).

## Worth recording as rules

While detecting, note anything a newcomer would trip on and that the agent can't infer quickly:
required services (DB, Redis, emulators), env setup, generated code that must not be hand-edited,
slow test suites and their fast subsets, unusual directory conventions. These seed `.claude/rules/`.
