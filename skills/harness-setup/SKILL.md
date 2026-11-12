---
name: harness-setup
description: Set up (or audit) a project-specific Claude Code harness in a repo - CLAUDE.md index, .claude/settings.json permissions and hooks, an acceptance/verify script with change receipts, a commit gate, an adversarial reviewer subagent, task contracts, a learn-from-failure loop, and a curated list of recommended skills. Use when someone asks to "set up a harness", "bootstrap Claude Code for this repo", "configure .claude for this project", "make agents reliable here", or to audit/upgrade an existing harness.
---

# Harness setup

You are installing an engineered environment around Claude Code for **this** project, so that agents
work against explicit contracts, are verified by deterministic commands rather than their own opinion,
and turn failures into durable rules. Sensible defaults first; ask only what you cannot detect.

Background and rationale for every piece lives in `references/practices.md`. Read it once before
the first install so you can explain choices to the developer.

## Modes

- **Install** (default): no `.claude/harness/` folder exists yet.
- **Audit / upgrade**: `.claude/harness/` exists, or the user says "audit". Run the checklist in
  `references/practices.md#audit-checklist`, report pass/fail per item, then offer to fix the gaps
  using the same steps below. Never regenerate files the team has edited without showing a diff.
  Read `.claude/harness/VERSION` (missing means 0.1.0) and compare it with this plugin's version in
  `../../.claude-plugin/plugin.json` (relative to this skill); if older, apply the **Upgrade** steps of each newer entry in
  `../../CHANGELOG.md`, oldest first.

## Step 1 - Inspect the project (no questions yet)

Work out the following from the repo itself, using `references/detection.md`:

1. Root, git status, whether it is a monorepo (workspaces, multiple manifests).
2. Stack(s), package manager, and the real commands for **format, lint, typecheck, test, build**.
   Prefer scripts the project already defines (package.json scripts, Makefile, justfile, Taskfile,
   pyproject, CI workflow steps) over generic guesses. CI config is the best source of truth.
3. Formatter per file type, for the format-on-edit hook.
4. Existing agent config: `CLAUDE.md`, `AGENTS.md`, `.claude/`, `.cursor/rules`, `.github/copilot-instructions.md`.
   Anything here is input to merge, never something to overwrite.
5. Secrets and sensitive paths (`.env*`, `*.pem`, `secrets/`, credential JSON, `*.keystore`).
6. Signals for recommended skills (`references/recommended-skills.md`).

Run the candidate acceptance commands once, in the background if slow, to confirm they work.
A command that fails today on a clean tree must not become an acceptance gate - report it instead.

## Step 2 - Confirm the few real decisions

Use one AskUserQuestion call with at most these questions; skip any you can answer with confidence:

1. **Profile** - `standard` (recommended) / `light` / `strict`. See the table below.
2. **Acceptance commands** - show the detected list; let them trim it (multiSelect).
3. **Recommended skills** - the matches from the catalog (multiSelect, pre-ordered by relevance).

| Piece | light | standard | strict |
|---|---|---|---|
| `CLAUDE.md` index + `.claude/rules/` | yes | yes | yes |
| Permissions (allow detected commands, deny secrets) | yes | yes | yes |
| `guard.sh` (destructive-command hook) | yes | yes | yes |
| `format-on-edit.sh` hook | yes | yes | yes |
| `acceptance` + `verify.sh` receipts | yes | yes | yes |
| `/learn` skill + decisions ledger | yes | yes | yes |
| `/mock` skill (mock-first iteration) | yes | yes | yes |
| Agents: `explorer`, `researcher`, `prototyper`, `checker` | yes | yes | yes |
| `commit-gate.sh` (no receipt, no commit) | - | yes | yes |
| `/contract` + `/ship` skills | - | yes | yes |
| Agents: `architect`, `implementer`, `skeptic` | - | yes | yes |
| Agents: `designer`, `design-skeptic` (only if the project has a UI) | - | yes | yes |
| `/ship` refuses to commit without a verifier PASS | - | - | yes |
| CI job runs `verify.sh` | - | offered | yes |

## Step 3 - Generate files

Copy from `templates/` into the project, filling `{{PLACEHOLDERS}}`. Target layout:

```
CLAUDE.md                        # short index (templates/CLAUDE.md), <= ~80 lines
.claude/
  settings.json                  # templates/settings.json, merged with any existing file
  harness/
    acceptance                   # one command per line, run in order
    formatters                   # glob -> formatter command, used by format-on-edit
    lib.sh  verify.sh
    VERSION                      # harness version this project is on (from plugin.json)
  hooks/
    guard.sh  commit-gate.sh  format-on-edit.sh
  agents/                        # roles, see "Agents" below
    architect.md  explorer.md  researcher.md  prototyper.md
    implementer.md  designer.md  checker.md  skeptic.md  design-skeptic.md
  skills/mock/SKILL.md  skills/contract/SKILL.md  skills/ship/SKILL.md  skills/learn/SKILL.md
  rules/                         # topic rules; start with what you learned in step 1
  mocks/                         # mock notes: decisions and what is faked (committed)
  contracts/TEMPLATE.md          # task contracts (instances are gitignored)
  state/decisions.md             # decision ledger (committed)
  receipts/                      # verify output (gitignored)
.github/workflows/harness-verify.yml   # templates/ci/harness-verify.yml (standard: offered; strict: yes)
```

Rules for generating:

- **Merge, never clobber.** Existing `CLAUDE.md`: keep its content, restructure into the index shape,
  move long sections into `.claude/rules/<topic>.md`, and show the user the before/after. Existing
  `settings.json`: union the `permissions` arrays and append hooks; keep their other keys.
  If `AGENTS.md` exists and other tools use it, make `CLAUDE.md` import it (`@AGENTS.md`) instead of duplicating.
- **Register the plugin.** `settings.json` carries `extraKnownMarketplaces` and `enabledPlugins`
  for `harness`, so every teammate who opens the repo is prompted to install it (and gets
  `/harness-setup` for audits). The plugin repo is private: keep that block only in repos whose
  contributors have access to it, and leave it out of public or open-source repos.
- **Tailor `/mock` to the stack.** In `skills/mock/SKILL.md`, keep only the table rows that apply and
  name the mocking tools the repo already has (MSW, Storybook, a fake provider, a debug scene, a
  feature-flag helper). If it has none, say which existing mechanism hides unfinished work.
- **Agents** (details in `references/practices.md#roles`):
  - Install `designer` and `design-skeptic` only if the project has a UI (web frontend, app screens,
    game UI). Fill `{{DESIGN_SKILL}}` with the design skill chosen from the catalog (e.g.
    `impeccable:impeccable`); if none is installed, delete the `skills:` block. Fill
    `{{DESIGN_SYSTEM_SUMMARY}}` with 2-3 sentences on the existing design system (where tokens and
    components live, themes, its character). If there is none yet, say so. Fill
    `{{GALLERY_LOCATION}}` with how to open the design-system gallery (Storybook command, `/gallery`
    route, debug scene). If the project has no gallery, write "none yet - the first visual task
    creates one" and tell the user (`references/practices.md#1c-a-design-system-you-can-look-at`).
  - Keep the rule that **a verifier never runs on the same model as the worker it checks**
    (implementer `sonnet` -> skeptic `fable`; designer `opus` -> design-skeptic `fable`). If the team
    changes a model, change the pair together.
  - If an agent name clashes with an existing project agent, keep theirs and prefix ours with the
    project name (e.g. `myapp-implementer`), updating references in the skills.
- **Only real commands.** Every command in `CLAUDE.md`, `acceptance`, and `permissions.allow` must be
  one you saw defined or ran successfully. No invented scripts.
- **Allow rules are narrow**: `Bash(npm run test:*)`, not `Bash(npm:*)`. Always include
  `Bash(bash .claude/harness/verify.sh)`.
- **Deny secrets** found in step 1 with `Read(...)` deny rules. Note that `Read(./.env.*)` also hides
  `.env.example`; add an explicit allow for it if the project relies on it.
- Fill `formatters` only with formatters the project already uses. Empty is fine.
- **Screenshot tests.** If the project has a gallery and a screenshot tool (Storybook test runner,
  Playwright, a scene capture script), put its command in `acceptance` when it runs in about a minute,
  otherwise only in CI. If the gallery has no screenshot tests yet, say so and suggest them as the next
  visual task; don't invent a command.
- **CI.** In `strict`, and in `standard` if the developer accepts, write `templates/ci/harness-verify.yml`
  to `.github/workflows/`. Fill `{{DEFAULT_BRANCH}}`, `{{INSTALL_CMD}}`, and `{{SETUP_STEPS}}` with the
  runtime setup the project's existing CI uses (e.g. `actions/setup-node` with its version), or remove
  the placeholder line. If the project already has CI, add a `bash .claude/harness/verify.sh` step to it
  instead. Not on GitHub? Give the developer the same steps for their CI.
- Fill `{{HARNESS_VERSION}}` in `.claude/harness/VERSION` with the `version` from `../../.claude-plugin/plugin.json`.
- Append to `.gitignore`: `.claude/receipts/`, `.claude/contracts/*.md` with `!.claude/contracts/TEMPLATE.md`,
  and `.claude/settings.local.json`.
- Append to `.gitattributes`: `*.sh text eol=lf` and `.claude/harness/* text eol=lf`. Without it, Windows
  checkouts with `core.autocrlf` turn the scripts into CRLF and bash fails on them.
- Seed `.claude/rules/` with 1-3 short files of things you actually learned that are non-obvious
  (e.g. "tests need the DB container: `docker compose up -d db`"). No generic advice.
- `light` profile: skip `commit-gate.sh` and its hook entry, `skills/contract`, `skills/ship`, and the
  `architect`, `implementer`, `designer`, `skeptic` and `design-skeptic` agents.
- `strict` profile: in `skills/ship/SKILL.md` keep the "strict" block; in other profiles delete it.
- Install the chosen recommended skills per the catalog's instructions (plugin install command,
  or copy into `.claude/skills/`). If a skill is only available to the current user, list it in
  `CLAUDE.md` under "Recommended skills" with how to get it, rather than vendoring it.

## Step 4 - Verify the harness itself

Do all of these and report results honestly:

1. `bash .claude/harness/verify.sh` passes and writes `.claude/receipts/latest.md`.
2. Every JSON file you wrote parses.
3. Hooks behave: pipe sample payloads into each script and check exit codes, e.g.
   `printf '{"tool_input":{"command":"git push --force origin main"}}' | bash .claude/hooks/guard.sh; echo $?` -> 2.
   For the commit gate: no receipt -> 2; fresh receipt -> 0; edit a file -> 2 again.
4. `CLAUDE.md` is under ~80 lines and every path it mentions exists.

## Step 5 - Hand over

Tell the developer, briefly:

- What was created or merged (list files), and the profile.
- The day-to-day loop: `/mock` when the feature's shape is uncertain -> `/contract` for multi-file
  work -> work in a worktree -> `/ship`. After any agent mistake: `/learn`.
- That hooks apply only to Claude Code sessions; humans committing directly are not gated.
- Anything you could not set up (failing commands, missing formatter, skills not installable).

Do not commit the harness unless asked. Suggest a commit message if they want one.
