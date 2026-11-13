---
name: learn
description: Turn an agent mistake, a developer correction, or a surprising failure into a durable fix (test, hook, rule or skill) so it does not happen again. Use after something went wrong, when the developer says "remember this" / "don't do that again", or types /learn.
---

# Learn

1. **State the failure** in one sentence: what happened, what should have happened, and why it was
   not caught. Confirm with the developer if it is not obvious.
2. **Pick the cheapest durable fix**, preferring the earlier options:
   1. A test that would have failed (add it, and to `.claude/harness/acceptance` if it is a new suite).
   2. A guardrail that makes it impossible: a permission rule in `.claude/settings.json`, a pattern in
      `.claude/hooks/guard.sh`, or a script. Change these with the Edit tool, which asks the developer
      to approve; `guard.sh` blocks shell writes to the harness's own files.
   3. A rule: one or two lines in the matching `.claude/rules/<topic>.md` (create the topic if needed).
      Only add to `CLAUDE.md` itself if it applies to every task.
   4. A skill in `.claude/skills/`, when the fix is a multi-step procedure.
3. **Check for conflicts.** Search `.claude/rules/` and `CLAUDE.md` for rules this contradicts or
   duplicates; merge or replace instead of appending.
4. **Log it** in `.claude/state/decisions.md`:
   `- YYYY-MM-DD - <rule or change> - because <failure> - <file changed>`
5. Show the developer the diff of what you added.

Keep rules specific and testable ("run `pnpm db:migrate` before integration tests"),
never vague ("be careful with the database").
