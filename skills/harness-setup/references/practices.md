# Harness practices

The model is rarely the reason an agent run fails. The environment is: vague goals, no boundary on
what it may touch, no objective definition of done, and the same model grading its own work.
A harness fixes the environment. This file explains each piece so you can justify it to a developer
and adapt it rather than copy it.

## 1. Short index, deep rules

`CLAUDE.md` is loaded into every session, so every line costs context on every turn. Keep it an
index: what the project is, the commands, where things live, the workflow, and pointers.
Topic detail goes in `.claude/rules/*.md` (loaded on demand / by path) or is imported with `@path`.
Rule of thumb: if a line would not change what the agent does, delete it.

## 1b. Mock first when the shape is uncertain

When nobody is sure yet what the feature should look or feel like, a contract written up front is a
guess. `/mock` builds a fast version first - real interfaces, fake behaviour - so the developer can
react to something concrete and iterate in minutes rather than after a full implementation.

What keeps mocks from being throwaway work:
- **Fake the behaviour, keep the seams.** Types, routes, endpoints and parameters are written for real;
  only the data and logic behind them are fake. Implementation swaps what's behind the seam.
- **Fixtures become tests.** Mock data lives in the project's fixtures location and is reused as test data.
- **Mocks are marked and hidden.** Every fake is tagged `HARNESS-MOCK: <slug>` and sits behind a flag,
  dev route, Storybook or debug scene. The contract lists each tag; the skeptic checks none remain.
- **Decisions are written down.** `.claude/mocks/<slug>.md` records what was decided and why, and is the
  input to `/contract`. A mock that ends in "don't build it" is a cheap, useful result.

Skip it for bug fixes and features whose shape is already clear.

## 1c. A design system you can look at

Any project with a UI builds its visuals as a design system - tokens (colour, type, spacing, radius,
motion) and components built only from them - and keeps a **gallery** that renders all of it in one
place a person can open: Storybook, a dev-only `/gallery` route, or a debug scene in a game.

- **Everything visual lands in the gallery.** Each token, and each component in every state and every
  theme. A component that isn't in the gallery isn't done.
- **Screens are built from gallery pieces.** A one-off value in a screen is a missing token or component.
- **Review happens there.** The developer, the designer and the design-skeptic all judge visual work
  in the gallery, so there is always one URL to open instead of clicking through the app.
- **The gallery is also the visual test suite.** Each entry has a baseline screenshot, compared on every
  run: Storybook's test runner or Playwright `toHaveScreenshot` against the stories or `/gallery` route,
  or a scripted capture of the debug scene in a game. A changed screenshot fails until someone looks at
  it and accepts the new baseline, so a visual regression is caught by a command, not by a reviewer's eye.
  Keep it deterministic: fixed viewport, bundled fonts, animations off, and baselines made in the same
  OS image CI uses (usually a container), since font rendering differs between machines.
  If it takes more than a minute or so, run it in CI rather than in `acceptance`.
- **No gallery yet?** The first visual task sets it up, with the existing tokens and components,
  and its screenshot baselines.

## 2. Contract before code

For anything touching more than one or two files, write a task contract first
(`.claude/contracts/<slug>.md`). Four boundaries:

- **Scope** - paths the task may change, and explicit out-of-scope paths.
- **Done** - acceptance commands that must exit 0 (project defaults + task-specific tests).
- **Evidence** - what must exist at the end (new test, receipt, screenshot, migration).
- **Budget** - rough turn / time ceiling. When hit, stop and report instead of thrashing.

A contract turns "fix the login flow" into something a reviewer can check against.

## 3. Isolate the work

Multi-file or risky work runs in a git worktree, not on the developer's live branch. Use Claude
Code's built-in worktree support (ask Claude to work in a worktree, or subagents with worktree
isolation) rather than custom scripts. Benefits: the main checkout stays usable, parallel tasks
don't collide, and discarding a bad attempt is free.

## 4. Deterministic verification - "no receipt, no commit"

Done means the acceptance commands passed **on exactly this tree**. `verify.sh` runs them and writes
`.claude/receipts/latest.md` with a fingerprint of the working tree (a git tree hash of all tracked
and untracked, non-ignored files). `commit-gate.sh` blocks `git commit` from Claude unless the
current tree's fingerprint matches a passing receipt. Any edit after verifying invalidates it.

This is intentionally boring shell + git: no model in the loop, no flakiness from judgment.

## 5. Don't let a model grade its own work

After verification, a separate verifier (`skeptic`, or `design-skeptic` for visual work) reviews the
diff against the contract with a fresh context and read-only tools. It looks for wrong behaviour,
missing tests, scope creep and contract violations, and returns PASS or BLOCK with findings. The worker
fixes BLOCKs, re-verifies, and only then commits.

Two rules make this work:
- **The verifier never runs on the worker's model.** Same model, same blind spots.
- **The verifier gets the contract, never the worker's report.** A report that says "all edge cases
  handled" primes the reviewer to agree. It must read the code fresh.

## Roles

Each role is a subagent with its own model and effort, chosen for the job rather than one model for
everything. Defaults (change freely, but change worker/verifier pairs together):

| Role | Agent | Model · effort | Job |
|---|---|---|---|
| Arbiter | main session | developer's choice | Talks to the developer, hands out work, settles disputes, commits |
| Architect | `architect` | Opus · high | Request or accepted mock -> task contract. No application code |
| Explorer | `explorer` | Haiku · low | Answers "where/how is X done" in this repo, with `path:line` |
| Researcher | `researcher` | Sonnet · medium | Outside facts: docs, APIs, versions, limits. Sourced answers |
| Prototyper | `prototyper` | Sonnet · medium | One round of a mock: real seams, fake behaviour |
| Implementer | `implementer` | Sonnet · medium | Executes one code contract |
| Designer | `designer` | Opus · medium + design skill | Executes one visual contract |
| Checker | `checker` | Haiku · low | Runs `verify.sh`, reports only failures |
| Skeptic | `skeptic` | Fable · high + security skill | Tries to break a finished code diff, security included |
| Design skeptic | `design-skeptic` | Fable · high + design skill | Same for visual work: themes, states, contrast, consistency |
| Gatekeeper | hooks | no model | Guard, format-on-edit and commit gate on every tool call |

Why these defaults:
- Planning and design judgement go to Opus; well-specified execution goes to Sonnet; lookups and
  running checks go to Haiku, so the expensive models are spent where they change the outcome.
- Fable, the strongest model, is spent on attacking work, where missing a flaw costs the most.
- On one real project, Fable's design work was rejected three rounds running on rendered
  detail; with Opus designing and Fable reviewing, it went through. Revisit when models change.
- Workers and verifiers stop every server or process they start: a leftover dev server can lock
  files and break the next agent's install or build.
- Two failed attempts at the same step means stop and report, not a third try.

We deliberately do **not** put a model in front of every Bash call. Permission rules plus a small
deterministic `guard.sh` catch the dangerous cases with zero latency and zero cost. If a team wants a
model-based gate anyway, Claude Code prompt-based hooks are the place for it, scoped to a narrow matcher.

## 6. Guardrails as config, not prose

"Never read .env" in CLAUDE.md is a suggestion. A `Read(./.env)` deny rule is a guarantee. Prefer:
permissions > hooks > rules text. Allow-list the project's real commands narrowly so the agent is not
blocked on prompts for routine work (fewer prompts means developers don't switch to skipping permissions).

## 7. Fast feedback (DevEx)

- One command to know if you're done (`verify.sh`). If it takes > ~2 min, split a fast subset into
  `acceptance` and leave the slow suite to CI.
- Format on edit (`format-on-edit.sh`) so diffs stay clean and lint noise never reaches review.
- Tests must be deterministic. A flaky test in `acceptance` trains everyone to ignore red.
- Same commands locally, in CI, and for the agent. CI can literally run `bash .claude/harness/verify.sh`.
- State on disk, not in the chat: contracts, receipts, and `state/decisions.md` survive context
  compaction and session restarts, and let a second session pick up the work.

## 8. Turn failures into rules

Every agent mistake should happen once. `/learn` turns a failure into the cheapest durable fix, in order
of preference:

1. A test that would have caught it (regression eval).
2. A hook, permission or script that makes it impossible.
3. A one-line rule in `.claude/rules/` (or CLAUDE.md if it applies everywhere).
4. A skill, when the fix is a multi-step procedure.

…and logs the decision in `.claude/state/decisions.md` with date and reason, so rules can be pruned later.

## Audit checklist

Use this in audit mode; report each as pass / fail / n.a. with one line of evidence.

1. `CLAUDE.md` exists, is an index (<= ~80 lines), and every command in it runs.
2. Permissions allow the real dev commands narrowly and deny secrets.
3. Destructive commands are blocked by hook (`guard.sh`).
4. A single verify entry point exists and passes on a clean tree.
5. Commits from agents are gated on a matching passing receipt (standard+).
6. Multi-file work has a contract template and a documented worktree habit (standard+); `/mock` exists
   and no `HARNESS-MOCK` markers are left on the main branch outside a flag/dev-only path.
7. An independent reviewer subagent exists with read-only tools, on a different model from the worker
   it reviews (standard+).
8. Acceptance commands are deterministic (re-run twice; same result).
9. Durable state on disk: decisions ledger present and recently used.
10. Failure loop exists (`/learn`), and `.claude/rules/` has no stale or contradictory rules.
11. Projects with a UI have a design-system gallery that builds and opens, covers the tokens and
    components in use, and has screenshot tests run by `acceptance` or CI (n.a. without a UI).
12. CI runs `verify.sh` (or the same commands) on pull requests (standard: offered; strict: required).
13. `.claude/harness/VERSION` matches the plugin version; if older, list the upgrades from `CHANGELOG.md`.
