#!/usr/bin/env bash
# "No receipt, no commit": commits exactly the tree verify.sh checked.
# Takes the same arguments as `git commit`. Run it from the checkout you are
# committing in; a worktree uses its own receipt.
#
# It stages everything, commits, then compares the tree that was really committed
# with the receipt's fingerprint and undoes the commit if they differ. That catches
# path arguments, --only and git hooks that rewrite files.
set -u

fail() {
  echo "commit: $1" >&2
  exit 1
}

root=$(git rev-parse --show-toplevel 2>/dev/null) || fail "not inside a git repository."
cd "$root" || exit 1
if [ ! -f .claude/harness/lib.sh ]; then
  fail "this checkout has no harness ($root/.claude/harness is missing). Commit the harness so worktrees include it."
fi
. .claude/harness/lib.sh

# Refuse --no-verify / -n: the project's own git hooks stay on.
skip=0
for arg in "$@"; do
  if [ "$skip" -eq 1 ]; then skip=0; continue; fi
  case "$arg" in
    # git accepts unique abbreviations of long options, so --no-verif counts too.
    --no-veri*) fail "--no-verify is not allowed: git hooks stay on." ;;
    --message|--file|--author|--date|--reuse-message|--reedit-message|--fixup|--squash|--template|--cleanup|--trailer|--pathspec-from-file)
      skip=1 ;;
    --) break ;;
    --*) ;;
    -?*)
      # A cluster of short flags. m F C c t take a value: the rest of the same argument
      # is that value (-mfix), and only when nothing follows is it the next argument (-m fix).
      flags=${arg%%[mFCct]*}
      case "$flags" in *n*) fail "-n (--no-verify) is not allowed: git hooks stay on." ;; esac
      rest=${arg#"$flags"}
      [ "${#rest}" -eq 1 ] && skip=1
      ;;
  esac
done

receipt=.claude/receipts/latest.md
[ -f "$receipt" ] \
  || fail "no change receipt. Run \`bash .claude/harness/verify.sh\` first (or /ship)."
grep -q '^status: pass' "$receipt" \
  || fail "the latest receipt is failing. Fix the failures, then run verify.sh again."
expected=$(sed -n 's/^fingerprint: //p' "$receipt")
actual=$(harness_fingerprint)
[ -n "$expected" ] && [ "$expected" = "$actual" ] \
  || fail "files changed since the last passing verify. Run \`bash .claude/harness/verify.sh\` again."

# strict profile: an independent reviewer must have recorded a PASS for this exact tree.
profile=""
[ -f .claude/harness/profile ] && profile=$(tr -d '[:space:]' < .claude/harness/profile)
if [ "$profile" = strict ]; then
  review=.claude/receipts/review.md
  [ -f "$review" ] \
    || fail "strict profile: no review recorded. Run the skeptic (or design-skeptic); it records its verdict."
  grep -q '^verdict: PASS' "$review" \
    || fail "strict profile: the last review is not a PASS. Fix the findings, verify, and have it reviewed again."
  reviewed=$(sed -n 's/^fingerprint: //p' "$review")
  [ "$reviewed" = "$expected" ] \
    || fail "strict profile: files changed since the review. Have this tree reviewed again."
fi

git add -A || fail "git add -A failed."
staged=$(git write-tree) || fail "git write-tree failed."
[ "$staged" = "$expected" ] \
  || fail "staging everything did not produce the verified tree (a force-added ignored file, or skip-worktree/assume-unchanged bits). Everything is staged now; sort that out and run verify.sh again."

old=$(git rev-parse -q --verify HEAD) || old=""
git commit "$@"
rc=$?
[ "$rc" -eq 0 ] || exit "$rc"

new=$(git rev-parse -q --verify HEAD) || new=""
# Nothing was committed (for example --dry-run).
[ "$new" != "$old" ] || exit 0

committed=$(git rev-parse 'HEAD^{tree}')
if [ "$committed" != "$expected" ]; then
  if [ -n "$old" ]; then
    git reset -q --soft "$old"
  else
    git update-ref -d HEAD
  fi
  fail "the commit did not contain exactly the verified files, so it was undone (your files are untouched). Cause: a path argument, --only, or a git hook that rewrote files. Commit everything; to leave files out, stash them and run verify.sh again."
fi
exit 0
