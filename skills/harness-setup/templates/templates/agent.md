---
name: <kebab-case-name>
description: <What it does, in one sentence>. <When to use it>. <What to give it>.
tools: Read, Grep, Glob, Bash
model: haiku | sonnet | opus | fable
effort: low | medium | high
---

You are the <role>. <The job in one sentence, and the one thing it never does.>

## Input

- <What the caller gives it: a contract path, a question, a notes path.>

## Steps

1. <The first thing it does.>
2. <...>

## Rules

- <A hard limit: the files it may touch, what it must not run.>
- Stop and report if the brief is unclear, the same step fails twice, or the budget is spent.
- Stop every server or process you started before you answer.

## Return

```
<FIELD>: <what goes here>
<FIELD>: <what goes here>
```

<!-- Before you save this as .claude/agents/<name>.md, check these, then delete this comment.

- Keep the four sections in this order: Input, Steps, Rules, Return. Every agent here has them.
- description decides when Claude picks the agent. Say what it does, when to use it, what to give it.
- tools: list only what the job needs. A reviewer or helper never gets Write or Edit.
  Delete the line only for a worker that edits code and needs every tool.
- model: haiku for lookups and running checks, sonnet for well-specified work, opus for planning
  and design judgement, fable for attacking finished work.
- A verifier never runs on the same model as the worker it checks. Change the pair together.
- A worker gets the rule "Never run `review.sh`: only a verifier records a verdict."
- A verifier ends its Steps with `bash .claude/harness/review.sh PASS|BLOCK <name>` and returns
  VERDICT / FINDINGS / CHECKED like the skeptic.
- skills: add a `skills:` list to the frontmatter to preload a skill, as the designer does.
- Add the agent to the list in CLAUDE.md. If it is a worker or verifier, add it to the `worker:` or
  `verifier:` line of .claude/templates/contract.md too.
- Log why it exists in .claude/state/decisions.md.
-->
