---
name: mock
description: Build a fast, throwaway-friendly mock of a feature so the developer can see it, react, and iterate before the real implementation. Use when the shape of a feature is still uncertain (UX, API, data model, game feel), when the developer says "mock it up", "prototype", "let me see it first", or types /mock.
---

# Mock first

Goal: get the developer something they can click, call, or play in minutes, iterate on it with them
cheaply, and end with decisions concrete enough to write a contract. Speed beats polish; the seams
must be real so the work is not thrown away.

## 1. Agree the mock's purpose (one message)

State in 2-3 lines: what question the mock answers ("does this flow make sense?", "is this API shape
easy to consume?", "does the jump feel right?"), what will be faked, and what will be real.
Skip asking if the request already makes this clear.

## 2. Build at the seams that survive

Fake the behaviour, not the interfaces. Whatever the real feature will need anyway, write for real now:

| Project type | Real now | Faked |
|---|---|---|
| Frontend | Components, routes, props/types | Data: fixtures behind the same client/hook the real one will use (MSW / Storybook / a fake provider, whatever the repo already has) |
| API / backend | Schema or OpenAPI, request/response types, handler signature | Handler body returns fixtures; no persistence or side effects |
| Game | Scene, input mapping, tuning parameters exposed in one place | Greybox meshes, placeholder art/audio, stubbed backend calls |
| CLI / library | Command names, flags, public function signatures, help text | Output from fixtures |

Rules:
- Put fixture data in the project's fixtures/test-data location. It becomes test data later.
- Mark every faked piece with a `HARNESS-MOCK: <slug>` comment so it can be found and replaced.
- Keep mocks behind something the real app already uses to hide unfinished work (feature flag,
  dev-only route, Storybook, debug scene). Never wire a mock into a production path.
- Work in a worktree or a `mock/<slug>` branch when the developer has other changes in flight.
- Mocks still pass lint and typecheck; skip new tests unless they are free.

## 3. Iterate with the developer

You (the main session) stay with the developer; the `prototyper` agent does the building. Each round:
give it the notes path and the change requested, then show the developer the result (run it,
screenshot it, or give the exact command/URL) and ask what to change. Keep rounds small and fast.
Use `researcher` if a round depends on how an external API or library actually behaves.
Record each decision as you go in `.claude/mocks/<slug>.md` (create it before the first round):

```
# Mock: <slug>
question: <what the mock is answering>
status: iterating | accepted | dropped
## Decisions
- YYYY-MM-DD - <decision> - <why / feedback>
## Interfaces settled
- <types, endpoints, events, params now considered final>
## Faked (HARNESS-MOCK: <slug>)
- <path> - <what is fake> - <what real implementation needs>
## Open questions
```

## 4. Hand off

When the developer accepts it, set `status: accepted` and offer `/contract`, which hands these notes
to the `architect` (in projects without it,
list the `HARNESS-MOCK` locations and settled interfaces as the plan for implementation). The contract should be
written from this file: settled interfaces become scope, fixtures become test data, and every
`HARNESS-MOCK: <slug>` location becomes something the implementation must replace.
If the mock answered "no, don't build this", set `status: dropped`, remove the mock code, and keep the
notes - that answer is worth keeping.
