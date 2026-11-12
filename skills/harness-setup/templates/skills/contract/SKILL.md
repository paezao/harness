---
name: contract
description: Write a task contract (scope, acceptance commands, evidence, budget, roles) and run it with the right agents. Use when a task touches more than ~2 files, changes behaviour users rely on, or the developer types /contract.
---

# Task contract

You (the main session) are the arbiter: you talk to the developer, hand work to agents, and settle
disputes. You do not write the contract or the code yourself.

1. **Contract.** Launch the `architect` agent with the request (and the mock notes path, if an
   accepted mock exists in `.claude/mocks/`). It writes `.claude/contracts/<yyyy-mm-dd>-<slug>.md`.
   If you need facts about the code or the outside world first, use `explorer` or `researcher`.
2. **Agree it.** Read the contract. Ask the developer any open questions it lists, have the architect
   amend it, then show the developer the goal and scope in a few lines and wait for an OK.
3. **Isolate.** For anything large, or when the developer has uncommitted work, use a git worktree.
4. **Build.** Launch the contract's worker (`implementer`, or `designer` for visual work) with the
   contract path only (and the worktree path, if any). Do not paraphrase the spec; the contract is the brief.
5. **Finish** with `/ship`.

Splitting: a task that is both code and visual is two contracts, run one after the other or in
separate worktrees if their scopes don't overlap.

If a worker reports it needs a path outside Scope, decide with the developer, have the architect amend
the contract, and relaunch. Never let scope grow silently.

Small changes (one or two files you can see whole) skip this and go straight to editing and `/ship`.
