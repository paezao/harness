# {{PROJECT_NAME}}

{{ONE_LINE_DESCRIPTION}}

## Commands

- Install: `{{INSTALL_CMD}}`
- Dev: `{{DEV_CMD}}`
- Test: `{{TEST_CMD}}`  (single test: `{{SINGLE_TEST_CMD}}`)
- Lint / typecheck: `{{LINT_CMD}}` / `{{TYPECHECK_CMD}}`
- **Done check:** `bash .claude/harness/verify.sh` - must pass before any commit.

## Layout

{{LAYOUT_BULLETS}}

## Workflow

0. Feature shape unclear (UX, API, game feel)? `/mock` first and iterate with the developer.
1. More than ~2 files or any risky change: `/contract` first, then work in a git worktree.
2. Stay inside the contract's scope. Need to go outside it? Stop and ask.
3. Finish with `/ship` (verify -> independent review -> commit). Commit with
   `bash .claude/harness/commit.sh`, never plain `git commit`: it commits only what `verify.sh` checked.
4. When something goes wrong or the developer corrects you: `/learn`.

The main session is the arbiter; work goes to agents in `.claude/agents/`: `architect` (contracts),
`implementer` / `designer` (build), `checker` (runs checks), `skeptic` / `design-skeptic` (review),
`explorer` (questions about this repo), `researcher` (docs and APIs), `prototyper` (mocks).
A verifier never sees the worker's report, only the contract.

## Rules

Topic rules live in `.claude/rules/`. Decisions and their reasons: `.claude/state/decisions.md`.
{{RULE_POINTERS}}

## Recommended skills

{{RECOMMENDED_SKILLS}}
