---
name: ship
description: Finish a change - run verify.sh, get an independent review from the contract's verifier, fix what it blocks, and commit with the receipt. Use when the work is done and ready to commit, or the developer types /ship.
---

# Ship

1. **Verify.** Launch the `checker` agent (it runs `bash .claude/harness/verify.sh` and reports only
   failures). On failure, send the failures back to the worker (or fix them yourself for small
   changes) - fix the cause, not the test. Two failed rounds on the same error: stop and report.
2. **Review.** Launch the contract's verifier - `skeptic` for code, `design-skeptic` for visual work;
   `skeptic` when there is no contract. Give it the contract path only. Never pass on the worker's
   report or your own opinion; it must read the code fresh.
3. **Act on findings.** Send every BLOCK back to the worker with the verifier's findings. For a WARN,
   fix it or note why not. Anything changed means back to step 1 - the receipt is stale and commits
   are blocked until it is fresh.
4. **Commit.** Only when verify passed on the final tree. Commit message: what changed and why, then a
   short "Verified:" line listing the acceptance commands, and the verifier's verdict.
   Do not push unless the developer asked.
5. **Close out.** Mark the contract `status: done`. If a verifier blocked, the budget was exceeded or
   anything surprising happened, run `/learn`.

<!-- strict profile only: delete this block in light/standard -->
**Strict:** never commit without a verifier `VERDICT: PASS` on the final tree. If the verifier BLOCKs
twice on the same finding and the worker disagrees, stop and ask the developer to arbitrate.
<!-- end strict -->
