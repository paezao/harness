# <Topic>

<One line: which part of the project these rules cover.>

- <A rule, specific and testable>. Why: <the failure it prevents>.
- <...>

<!-- Before you save this as .claude/rules/<topic>.md, check these, then delete this comment.

- One topic per file. Every file in .claude/rules/ is loaded into the session, so keep it short.
- Specific and testable: "run `pnpm db:migrate` before integration tests", never "be careful with
  the database".
- Every rule says why. A rule nobody can explain gets deleted at the next clean-up.
- To load the file only for some paths, put this at the very top:
    ---
    paths:
      - "src/api/**"
    ---
- Log the rule in .claude/state/decisions.md.
-->
