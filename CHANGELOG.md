# Changelog

Each installed harness records its version in `.claude/harness/VERSION`. Audit mode reads it and
applies the **Upgrade** steps of every newer entry below, oldest first, showing a diff for any file
the team has edited.

## 0.4.0

Enforcement fixes. Each one has a test in `tests/run.sh`.

- **PowerShell.** Hooks match `Bash|PowerShell`. On Windows the PowerShell tool used to skip the guard
  and the commit gate.
- **Commits hold exactly what was verified.** Claude commits with `.claude/harness/commit.sh`, which
  stages everything, commits, and undoes the commit if the committed tree is not the verified one.
  Plain `git commit` is blocked. Before, a passing receipt let through a commit of only some of the
  verified files.
- **Worktrees.** `commit.sh` runs in the checkout being committed and reads that checkout's receipt.
  Before, the gate read the receipt of the checkout the session started in.
- **Other ways to commit.** The gate blocks merges, cherry-picks, reverts and pulls that would create
  a commit on their own. Rebase, `git am`, aliases and script files are still not covered.
- **Guard reads only the command.** A blocked phrase in a commit message, a grep pattern or the
  tool-call description no longer blocks, and `git clean -n` is allowed. It now catches
  `rm -rf ./`, `~/`, `*`, `..` and split flags; `+refspec` and `--mirror` pushes; a bare `git push` on
  a protected branch; `git checkout .` and `git restore .`; `git stash clear`; `commit -n`; env files
  such as `.env.local` read with grep, source, cp or `<`; and the PowerShell equivalents.
- **The harness protects itself.** `ask` rules for hooks, harness scripts and settings, a deny rule
  for receipts, and `guard.sh` blocks shell writes to them. The skeptics BLOCK diffs that touch them
  outside the contract.
- **`strict` is enforced.** Verifiers record their verdict with `review.sh`; `commit.sh` refuses
  without a PASS for exactly the tree being committed. `.claude/harness/profile` records the profile.

**Upgrade** from 0.3.0 (write harness files with the Write and Edit tools, so the developer approves):
1. Replace `.claude/harness/lib.sh`, `.claude/hooks/guard.sh` and `.claude/hooks/commit-gate.sh` with
   the templates. Carry local edits to `guard.sh` over by hand (extra patterns, the `protected`
   branch list) and show the diff.
2. Add `.claude/harness/commit.sh` and `.claude/harness/review.sh` (not in `light`).
3. Write the project's profile (`light`, `standard` or `strict`) to `.claude/harness/profile`.
4. In `.claude/settings.json`: change the PreToolUse matcher to `Bash|PowerShell`, and add the `ask`
   rules, the `Edit(./.claude/receipts/**)` deny rule and the `review.sh` allow rule from the template.
5. Refresh `/ship`, `skeptic.md` and `design-skeptic.md` from the templates, keeping local edits. Add
   the `review.sh` line to `implementer.md` and `designer.md`, and the `commit.sh` line to `CLAUDE.md`.
6. Tell the developer: Claude now commits with `commit.sh`, partial commits are refused, the harness
   must be committed for worktrees to have it, and open sessions need a restart to load the new hooks.
7. Write `.claude/harness/VERSION`.

## 0.3.0

- Cloudflare's `security-audit` skill is in the recommended catalog (always offered), replacing the
  built-in `/security-review` as the default security tool.
- The `skeptic` loads the security skill and runs a focused security review of every diff.

**Upgrade** from 0.2.0:
1. Offer to install `security-audit` (see the catalog).
2. In `.claude/agents/skeptic.md`, add the `skills:` block with the security skill and replace the
   "Risk" check with the "Security" and "Risk" checks from the template, keeping local edits.
3. Write `.claude/harness/VERSION`.

## 0.2.0

- Design system with a gallery: UI projects keep every token and component in a gallery people can open
  (Storybook, a `/gallery` route, a debug scene), and the designer and design-skeptic work from it.
- Screenshot tests: every gallery entry has a baseline screenshot checked by `acceptance` or CI.
- CI template: `.github/workflows/harness-verify.yml` runs `verify.sh` on pull requests.
- `.claude/harness/VERSION` records which harness version a project is on.
- Only `impeccable` is recommended for frontend design.

**Upgrade** from 0.1.0:
1. Refresh `.claude/agents/designer.md` and `design-skeptic.md` from the templates, keeping local edits;
   fill `{{GALLERY_LOCATION}}`.
2. If the project has a UI and a gallery, add the screenshot test command to `acceptance` (or to CI if slow).
3. Offer `templates/ci/harness-verify.yml` if the project has no CI job running `verify.sh`.
4. Write `.claude/harness/VERSION`.

## 0.1.0

First version: `CLAUDE.md` index, permissions, guard / format-on-edit / commit-gate hooks, `verify.sh`
receipts, task contracts, `/mock`, `/contract`, `/ship`, `/learn`, role agents and the recommended
skills catalog. Projects set up before `VERSION` existed are 0.1.0.
