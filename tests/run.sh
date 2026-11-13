#!/usr/bin/env bash
# Tests for the harness templates: command parsing, guard, commit gate, commit.sh,
# review.sh, verify.sh and format-on-edit.
# Each case runs against a throwaway git repo with the templates installed as setup would.
# Usage: bash tests/run.sh   (exit 0 when every case passes)
set -u

here=$(cd "$(dirname "$0")" && pwd)
templates="$here/../skills/harness-setup/templates"
pass=0
fail=0

ok()  { pass=$((pass + 1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; }

# expect <name> <expected exit code> <command...>
expect() {
  local name=$1 want=$2; shift 2
  "$@" >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$want" ]; then ok "$name"; else bad "$name (exit $got, want $want)"; fi
}

# check <name> <command...>: passes when the command succeeds
check() {
  local name=$1; shift
  if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi
}

repos=()
trap 'cd /; rm -rf "${repos[@]}"' EXIT

# An empty repo on branch main, shielded from the developer's own git config.
empty_repo() {
  repo=$(mktemp -d)
  repos+=("$repo")
  cd "$repo" || exit 1
  git init -q -b main
  git config user.email test@example.com
  git config user.name test
  git config core.autocrlf false
  git config core.hooksPath .git/hooks
  git config commit.gpgsign false
  git config pull.rebase false
  git config pull.ff true
}

# A fresh repo with the harness installed and committed.
new_repo() {
  empty_repo
  mkdir -p .claude/harness .claude/hooks
  cp "$templates/harness/"*.sh .claude/harness/
  cp "$templates/hooks/"*.sh .claude/hooks/
  printf 'true\n' > .claude/harness/acceptance
  printf '.claude/receipts/\n' > .gitignore
  echo one > file.txt
  git add -A && git commit -qm init
}

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  printf '%s' "$s"
}

# payload <command> [tool] [description] [cwd]: the JSON a PreToolUse hook receives
payload() {
  printf '{"session_id":"t","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":{"command":"%s","description":"%s"}}' \
    "$(json_escape "${4:-}")" "${2:-Bash}" "$(json_escape "$1")" "$(json_escape "${3:-run}")"
}
guard()  { payload "$@" | bash .claude/hooks/guard.sh; }
gate()   { payload "$@" | bash .claude/hooks/commit-gate.sh; }
verify() { bash .claude/harness/verify.sh; }
commit() { bash .claude/harness/commit.sh "$@"; }
review() { bash .claude/harness/review.sh "$@"; }
head_of() { git -C "${1:-.}" rev-parse -q --verify HEAD; }

# --- lib.sh: reading the command out of the hook JSON ----------------------
new_repo
. .claude/harness/lib.sh
got=$(payload 'git commit -m "say \"hi\""' | harness_command)
if [ "$got" = 'git commit -m "say \"hi\""' ]; then ok "command: escaped quotes are undone"; else bad "command: escaped quotes are undone ($got)"; fi
got=$(payload $'cd src\nnpm test' | harness_command)
if [ "$got" = $'cd src\nnpm test' ]; then ok "command: \\n becomes a newline"; else bad "command: \\n becomes a newline ($got)"; fi
got=$(payload 'type C:\dev\x.txt' | harness_command)
if [ "$got" = 'type C:\dev\x.txt' ]; then ok "command: backslashes survive"; else bad "command: backslashes survive ($got)"; fi
got=$(payload 'git status' Bash 'about to git reset --hard' | harness_command)
if [ "$got" = 'git status' ]; then ok "command: the description is left out"; else bad "command: the description is left out ($got)"; fi
got=$(printf 'git reset --hard' | harness_command)
if [ "$got" = 'git reset --hard' ]; then ok "command: falls back to the whole input"; else bad "command: falls back to the whole input ($got)"; fi
got=$(printf '%s\n' 'cd x && sudo FOO=1 git push; echo "git commit" | grep a' | harness_segments | tr '\n' '#')
case "$got" in
  'cd x ##git push#echo "git commit" #grep a#') ok "segments: one simple command per line, prefixes stripped" ;;
  *) bad "segments: one simple command per line, prefixes stripped ($got)" ;;
esac

# --- guard.sh: blocked ----------------------------------------------------
new_repo
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  expect "guard blocks: $cmd" 2 guard "$cmd"
done <<'EOF'
rm -rf /
rm -rf ~
rm -fr .
rm -rf ./
rm -rf ~/
rm -rf *
rm -r -f /
rm -rf $HOME/
rm -rf "$HOME"
rm -rf ${HOME}
rm --recursive --force /
rm -rf ..
rm -rf node_modules .
cd /tmp && sudo rm -rf /
bash -c "rm -rf ~"
git push --force origin feat
git push -f origin feat
git push --force-with-lease
git push origin +main
git push origin +feat
git push --mirror
git push origin main
git push origin HEAD:main
git push
git push origin
git push -u origin HEAD
git -C . push
git reset --hard HEAD~1
git -C . reset --hard
git clean -fd
git clean -xdf
git checkout -- .
git checkout .
git checkout HEAD -- .
git restore .
git restore --staged --worktree .
git restore :/
git stash clear
git commit --no-verify -m x
git commit -n -m x
git commit -nm x
git -c core.hooksPath=/dev/null commit -m x
cat .env
head .env
cat .env.local
cat .env.production
cat config/.env
grep SECRET .env
source .env
. .env
cp .env /tmp/x
base64 < .env
echo forged > .claude/receipts/latest.md
printf 'true\n' > .claude/harness/acceptance
echo x >> ".claude/hooks/guard.sh"
sed -i 's/a/b/' .claude/harness/acceptance
rm .claude/hooks/guard.sh
rm -rf .claude
mv .claude/harness/acceptance /tmp/a
cp /tmp/guard.sh .claude/hooks/guard.sh
tee .claude/settings.json
git rm .claude/hooks/commit-gate.sh
EOF
expect "guard blocks: a later line of a multi-line command" 2 guard $'cd src\ngit push --force'

# --- guard.sh: allowed ----------------------------------------------------
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  expect "guard allows: $cmd" 0 guard "$cmd"
done <<'EOF'
rm -rf node_modules
rm -rf ./build
rm -rf "$tmp"
rm -rf /tmp/foo
rm -f file.txt
git push origin feat/x
git push origin main:feature
git push -n origin feat
git reset --soft HEAD~1
git status
git clean -nfd
git clean --dry-run -fd
git checkout feat
git checkout -- src/a.ts
git restore src/a.ts
git restore --staged .
cat .env.example
cp .env.example .env
grep -rn "\.env" src/
ls -la .env
docker compose --env-file .env up -d
npm test
git commit -m "docs: explain why git reset --hard is blocked"
grep -rn "git push --force" docs/
echo "never run rm -rf / here"
bash .claude/harness/verify.sh
bash .claude/harness/verify.sh > /tmp/out.log 2>&1
cat .claude/receipts/latest.md
sed -n 1,5p .claude/hooks/format-on-edit.sh
cp .claude/harness/acceptance /tmp/backup
echo note > .claude/contracts/foo.md
rm -rf .claude/worktrees/x
git config core.hooksPath .husky
git add .claude/harness
EOF
expect "guard ignores a blocked phrase in the description" 0 \
  guard 'git log --oneline' Bash 'Check history before deciding on git reset --hard'
expect "guard ignores rm -rf / and cat .env in the description" 0 \
  guard 'git status' Bash 'rm -rf / would be bad; cat .env too'
expect "guard ignores a heredoc commit message that starts lines with blocked commands" 0 \
  guard $'bash .claude/harness/commit.sh -m "$(cat <<\'EOF\'\nBlock force pushes\n\ngit push --force is now blocked\nrm -rf / too\nEOF\n)"'
expect "guard still reads the command after a heredoc message" 2 \
  guard $'gh pr create --body "$(cat <<\'EOF\'\nnotes\nEOF\n)"\ngit push --force'
expect "guard reads a heredoc that is piped to a shell" 2 guard $'cat <<EOF | bash\ngit push --force\nEOF'
expect "guard reads a heredoc fed to a shell" 2 guard $'bash <<EOF\nrm -rf /\nEOF'

# After cd into one of the harness's own folders, relative paths are harness files.
expect "guard blocks a redirect after cd into .claude/harness" 2 guard 'cd .claude/harness && echo true > acceptance'
expect "guard blocks sed -i after cd into .claude/harness" 2 guard 'cd .claude/harness && sed -i s/a/b/ acceptance'
expect "guard blocks rm after cd into .claude/hooks" 2 guard 'cd .claude/hooks; rm guard.sh'
expect "guard allows reading after cd into .claude/harness" 0 guard 'cd .claude/harness && cat acceptance 2>&1'
expect "guard allows a redirect to /dev/null after cd into .claude/harness" 0 guard 'cd .claude/harness && bash -n verify.sh > /dev/null'
expect "guard allows a redirect after cd elsewhere" 0 guard 'cd .claude && echo note > notes.txt'

# --- guard.sh: the PowerShell tool ----------------------------------------
expect "guard blocks (PowerShell): Remove-Item -Recurse -Force C:\\" 2 guard 'Remove-Item -Recurse -Force C:\' PowerShell
expect "guard blocks (PowerShell): remove-item -recurse ." 2 guard 'remove-item -recurse .' PowerShell
expect "guard blocks (PowerShell): rm -r -fo ~" 2 guard 'rm -r -fo ~' PowerShell
expect "guard blocks (PowerShell): Get-Content .env" 2 guard 'Get-Content .env' PowerShell
expect "guard blocks (PowerShell): gc .env.local" 2 guard 'gc .env.local' PowerShell
expect "guard blocks (PowerShell): git push --force" 2 guard 'git push --force' PowerShell
expect "guard blocks (PowerShell): git reset --hard" 2 guard 'git reset --hard' PowerShell
expect "guard blocks (PowerShell): Set-Content on acceptance" 2 \
  guard 'Set-Content -Path .claude\harness\acceptance -Value true' PowerShell
expect "guard blocks (PowerShell): Out-File on the receipt (backslash before r, n, t)" 2 \
  guard 'Out-File -FilePath .claude\receipts\latest.md' PowerShell
expect "guard blocks (PowerShell): redirect into .claude\\receipts" 2 guard 'echo x > .claude\receipts\note.txt' PowerShell
expect "guard allows (PowerShell): Get-Content of the receipt" 0 guard 'Get-Content .claude\receipts\latest.md' PowerShell
expect "guard allows (PowerShell): Remove-Item -Recurse node_modules" 0 guard 'Remove-Item -Recurse node_modules' PowerShell
expect "guard allows (PowerShell): git status" 0 guard 'git status' PowerShell

# --- guard.sh: pushing from a protected branch -----------------------------
main=$repo
wt="$repo-wt"; repos+=("$wt")
git worktree add -q "$wt" -b feat/x
expect "guard allows a bare push after cd into a feature worktree" 0 guard "cd $wt && git push"
expect "guard allows git -C <feature worktree> push" 0 guard "git -C $wt push -u origin HEAD"
expect "guard allows a bare push when the payload cwd is a feature worktree" 0 guard 'git push' Bash run "$wt"
expect "guard still blocks a bare push in the main checkout" 2 guard 'git push' Bash run "$main"
git checkout -q -b feat/y
expect "guard allows a bare push on a feature branch" 0 guard 'git push'
expect "guard allows git push -u origin HEAD on a feature branch" 0 guard 'git push -u origin HEAD'

# --- commit-gate.sh -------------------------------------------------------
new_repo
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  expect "gate blocks: $cmd" 2 gate "$cmd"
done <<'EOF'
git commit
git commit -m x
git commit -am x
git -C . commit -m x
git -C ../other-worktree commit -m x
git -c user.name=x commit -m y
cd sub && git commit -am x
/usr/bin/git commit -m x
git.exe commit -m x
bash -c "git commit -m x"
git merge feat
git merge --continue
git cherry-pick abc123
git cherry-pick --continue
git revert HEAD
git revert --no-edit HEAD
git pull
git pull origin main
EOF
expect "gate blocks a commit on a later line" 2 gate $'git add -A\ngit commit -m x'
expect "gate blocks (PowerShell): git commit -m x" 2 gate 'git commit -m x' PowerShell
verify >/dev/null 2>&1
expect "gate blocks plain git commit even with a passing receipt" 2 gate 'git commit -m x'

while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  expect "gate allows: $cmd" 0 gate "$cmd"
done <<'EOF'
git status
git log --grep commit
git commit-graph write
git merge-base main feat
echo "remember to git commit later"
grep -rn "git commit" README.md
bash .claude/harness/commit.sh -m "why git commit is blocked"
git merge --no-commit feat
git merge --ff-only feat
git merge --squash feat
git merge --abort
git cherry-pick -n abc123
git cherry-pick --abort
git revert --no-commit HEAD
git pull --ff-only
git pull --rebase
git rebase main
EOF
expect "gate ignores git commit in the description" 0 gate 'git status' Bash 'Check what would go into the next git commit'
expect "gate ignores git commit inside a heredoc message" 0 \
  gate $'bash .claude/harness/commit.sh -m "$(cat <<\'EOF\'\nExplain the gate\n\ngit commit is blocked now\nEOF\n)"'
git config pull.ff only
expect "gate allows git pull when pull.ff is only" 0 gate 'git pull'

# --- commit.sh ------------------------------------------------------------
new_repo
before=$(head_of)
echo two > file.txt
expect "commit.sh refuses with no receipt" 1 commit -m x
verify >/dev/null 2>&1
echo three > file.txt
expect "commit.sh refuses after an edit" 1 commit -m x
if [ "$(head_of)" = "$before" ]; then ok "refused commits leave HEAD alone"; else bad "refused commits leave HEAD alone"; fi

echo new > untracked.txt
verify >/dev/null 2>&1
expect "commit.sh rejects -n" 1 commit -n -m x
expect "commit.sh rejects -nm" 1 commit -nm x
expect "commit.sh rejects --no-verify" 1 commit --no-verify -m x
expect "commit.sh rejects --no-verify after an attached message" 1 commit -mfixit --no-verify
expect "commit.sh rejects -n after an attached message" 1 commit -mdoc -n
expect "commit.sh rejects the abbreviation --no-verif" 1 commit -m x --no-verif
expect "commit.sh rejects -n after -m and its value" 1 commit -m x -n
expect "commit.sh commits after a passing verify" 0 commit -m "- dash first, not a flag"
if [ "$(git rev-parse 'HEAD^{tree}')" = "$(sed -n 's/^fingerprint: //p' .claude/receipts/latest.md)" ]; then
  ok "the committed tree is the verified tree"
else
  bad "the committed tree is the verified tree"
fi
check "the commit includes the untracked file" git cat-file -e HEAD:untracked.txt
if [ -z "$(git status --porcelain)" ]; then ok "nothing is left uncommitted"; else bad "nothing is left uncommitted"; fi
expect "commit.sh amends a verified tree" 0 commit --amend -m "new message"

# Partial commits: the verified tree needs both files.
echo a > a.txt
echo b > b.txt
verify >/dev/null 2>&1
before=$(head_of)
expect "commit.sh undoes a path-argument commit" 1 commit -m x a.txt
if [ "$(head_of)" = "$before" ]; then ok "the partial commit is gone"; else bad "the partial commit is gone"; fi
if [ "$(cat a.txt)$(cat b.txt)" = ab ]; then ok "files survive the undo"; else bad "files survive the undo"; fi
git reset -q
git add a.txt
expect "commit.sh commits everything even when only one file was staged" 0 commit -m x
check "the other file is in the commit" git cat-file -e HEAD:b.txt

# A git hook that rewrites files makes the commit differ from what was verified.
printf '#!/bin/sh\necho rewritten > file.txt\ngit add file.txt\n' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
echo c > c.txt
verify >/dev/null 2>&1
before=$(head_of)
expect "commit.sh undoes a commit a git hook rewrote" 1 commit -m x
if [ "$(head_of)" = "$before" ]; then ok "the rewritten commit is gone"; else bad "the rewritten commit is gone"; fi
rm .git/hooks/pre-commit

printf 'false\n' > .claude/harness/acceptance
verify >/dev/null 2>&1
expect "commit.sh refuses on a failing receipt" 1 commit -m x

# A repo with no commits yet.
empty_repo
mkdir -p .claude/harness
cp "$templates/harness/"*.sh .claude/harness/
printf 'true\n' > .claude/harness/acceptance
printf '.claude/receipts/\n' > .gitignore
echo one > file.txt
verify >/dev/null 2>&1
expect "commit.sh undoes a partial first commit" 1 commit -m x file.txt
if head_of >/dev/null; then bad "the partial first commit is gone"; else ok "the partial first commit is gone"; fi
expect "commit.sh makes the first commit" 0 commit -m init

# --- worktrees ------------------------------------------------------------
new_repo
main=$repo
wt="$repo-wt"; repos+=("$wt")
git worktree add -q "$wt" -b feat
verify >/dev/null 2>&1                      # the main checkout has a passing receipt
cd "$wt" || exit 1
echo "never verified" > file.txt
before=$(head_of)
expect "a receipt in the main checkout does not unlock a worktree" 1 commit -am x
expect "nor does calling the main checkout's commit.sh from the worktree" 1 bash "$main/.claude/harness/commit.sh" -am x
if [ "$(head_of)" = "$before" ]; then ok "the worktree has no new commit"; else bad "the worktree has no new commit"; fi
verify >/dev/null 2>&1
expect "commit.sh in a worktree uses the worktree's receipt" 0 commit -m x
if [ "$(git log -1 --format=%s feat)" = x ] && [ "$(git -C "$main" log -1 --format=%s main)" = init ]; then
  ok "the commit landed on the worktree's branch only"
else
  bad "the commit landed on the worktree's branch only"
fi

# A worktree cut before the harness was committed has no harness in it.
empty_repo
echo one > file.txt
git add file.txt && git commit -qm init
mkdir -p .claude/harness
cp "$templates/harness/"*.sh .claude/harness/
main=$repo
wt="$repo-wt"; repos+=("$wt")
git worktree add -q "$wt" -b feat
cd "$wt" || exit 1
out=$(bash "$main/.claude/harness/commit.sh" -m x 2>&1)
rc=$?
case "$rc:$out" in
  1:*"no harness"*) ok "commit.sh explains a worktree without the harness" ;;
  *) bad "commit.sh explains a worktree without the harness (exit $rc: $out)" ;;
esac

# --- strict profile: review.sh ---------------------------------------------
new_repo
expect "review.sh rejects an unknown verdict" 2 review MAYBE
printf 'strict\n' > .claude/harness/profile
echo two > file.txt
verify >/dev/null 2>&1
expect "strict: no review, no commit" 1 commit -am x
review BLOCK skeptic >/dev/null 2>&1
expect "strict: a BLOCK does not unlock the commit" 1 commit -am x
review PASS skeptic >/dev/null 2>&1
echo three > file.txt
verify >/dev/null 2>&1
expect "strict: an edit after the review needs a new review" 1 commit -am x
review PASS skeptic >/dev/null 2>&1
expect "strict: commits with a PASS for this tree" 0 commit -am x
printf 'standard\n' > .claude/harness/profile
verify >/dev/null 2>&1
rm -f .claude/receipts/review.md
expect "standard: commits without a recorded review" 0 commit -am x

# --- verify.sh ------------------------------------------------------------
new_repo
printf '# comment\n\ntrue\necho hi\n' > .claude/harness/acceptance
expect "verify passes when every command passes" 0 verify
if grep -q '^status: pass' .claude/receipts/latest.md && grep -q '^fingerprint: ' .claude/receipts/latest.md; then
  ok "verify writes a passing receipt with fingerprint"
else
  bad "verify writes a passing receipt with fingerprint"
fi
printf 'true\nfalse\ntouch should-not-exist\n' > .claude/harness/acceptance
expect "verify fails when a command fails" 1 verify
if grep -q '^fingerprint: ' .claude/receipts/latest.md; then
  bad "failing receipt has no fingerprint"
else
  ok "failing receipt has no fingerprint"
fi
if [ -e should-not-exist ]; then bad "verify stops at the first failure"; else ok "verify stops at the first failure"; fi
rm .claude/harness/acceptance
expect "verify fails without an acceptance file" 1 verify

# --- format-on-edit.sh ----------------------------------------------------
new_repo
printf '*.txt  sh -c '"'"'echo formatted > "$0"'"'"'\n' > .claude/harness/formatters
edit_payload() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1"; }
edit_payload "$repo/file.txt" | bash .claude/hooks/format-on-edit.sh
if [ "$(cat file.txt)" = formatted ]; then ok "format-on-edit runs the matching formatter"; else bad "format-on-edit runs the matching formatter"; fi
echo keep > other.md
edit_payload "$repo/other.md" | bash .claude/hooks/format-on-edit.sh
if [ "$(cat other.md)" = keep ]; then ok "format-on-edit skips unmatched files"; else bad "format-on-edit skips unmatched files"; fi
expect "format-on-edit never blocks on a missing file" 0 sh -c "printf '%s' '{\"tool_input\":{\"file_path\":\"$repo/nope.txt\"}}' | bash .claude/hooks/format-on-edit.sh"

# --- settings template and JSON files --------------------------------------
cd "$here/.."
settings=skills/harness-setup/templates/settings.json
check "hooks cover the PowerShell tool as well as Bash" grep -q '"matcher": "Bash|PowerShell"' "$settings"
for rule in 'Edit(./.claude/hooks/**)' 'Edit(./.claude/harness/**)' 'Edit(./.claude/settings.json)' 'Edit(./.claude/receipts/**)'; do
  check "settings protect the harness: $rule" grep -qF "\"$rule\"" "$settings"
done
for f in .claude-plugin/*.json "$settings"; do
  if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" 2>/dev/null \
     || python -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" 2>/dev/null; then
    ok "valid JSON: $f"
  else
    bad "valid JSON: $f"
  fi
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
