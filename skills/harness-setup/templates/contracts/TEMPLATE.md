# Contract: <title>

date: YYYY-MM-DD
status: draft | agreed | done | abandoned
worker: implementer | designer
verifier: skeptic | design-skeptic

## Goal
<one sentence: the outcome, not the implementation>

## Spec
<what to build, interfaces it must keep, edge cases that matter, lessons from .claude/rules/.
The worker reads only this contract.>

## From mock
<none, or `.claude/mocks/<slug>.md`. Every `HARNESS-MOCK: <slug>` location below must be replaced.>
- <path> - <real behaviour needed>

## Scope
In:
- <path or glob>
Out:
- <path or area explicitly not to touch>

## Acceptance (all must exit 0)
- `bash .claude/harness/verify.sh`
- <task-specific command, e.g. a single test file>

## Evidence
- <new/changed test>
- `.claude/receipts/latest.md` (passing, matches final tree)

## Budget
<e.g. ~40 turns / 1 hour. When hit: stop, summarise state and blockers.>

## Open questions
- <none / list - resolve before starting>
