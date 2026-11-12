#!/usr/bin/env bash
# Tests for the harness templates: guard, commit gate, format-on-edit and verify.
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

repos=()
trap 'rm -rf "${repos[@]}"' EXIT

# A fresh repo with the harness installed and one commit.
new_repo() {
  repo=$(mktemp -d)
  repos+=("$repo")
  cd "$repo" || exit 1
  git init -q
  git config user.email test@example.com
  git config user.name test
  git config core.autocrlf false
  mkdir -p .claude/harness .claude/hooks
  cp "$templates/harness/lib.sh" "$templates/harness/verify.sh" .claude/harness/
  cp "$templates/hooks/"*.sh .claude/hooks/
  printf 'true\n' > .claude/harness/acceptance
  printf '.claude/receipts/\n' > .gitignore
  echo one > file.txt
  git add -A && git commit -qm init
}

bash_payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }
guard()  { bash_payload "$1" | bash .claude/hooks/guard.sh; }
gate()   { bash_payload "$1" | bash .claude/hooks/commit-gate.sh; }
verify() { bash .claude/harness/verify.sh; }

# --- guard.sh -------------------------------------------------------------
new_repo
for cmd in 'rm -rf /' 'rm -rf ~' 'rm -fr .' 'git push --force origin feat' 'git push -f origin feat' \
           'git push --force-with-lease' 'git push origin main' 'git reset --hard HEAD~1' \
           'git clean -fd' 'git commit --no-verify -m x' 'cat .env' 'head .env'; do
  expect "guard blocks: $cmd" 2 guard "$cmd"
done
for cmd in 'rm -rf node_modules' 'git push origin feat/x' 'git reset --soft HEAD~1' \
           'git status' 'cat .env.example' 'npm test'; do
  expect "guard allows: $cmd" 0 guard "$cmd"
done

# --- commit-gate.sh -------------------------------------------------------
new_repo
expect "gate ignores non-commit commands" 0 gate 'git status'
expect "gate blocks commit with no receipt" 2 gate 'git commit -m x'
verify >/dev/null 2>&1
expect "gate allows commit after passing verify" 0 gate 'git commit -m x'
echo two > file.txt
expect "gate blocks commit after an edit" 2 gate 'git commit -m x'
expect "gate also catches git -C dir commit" 2 gate 'git -C . commit -m x'
echo new > untracked.txt
verify >/dev/null 2>&1
expect "gate allows commit after re-verify" 0 gate 'git commit -am x'
printf 'false\n' > .claude/harness/acceptance
verify >/dev/null 2>&1
expect "gate blocks commit on failing receipt" 2 gate 'git commit -m x'

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

# --- JSON files parse -----------------------------------------------------
cd "$here/.."
for f in .claude-plugin/*.json skills/harness-setup/templates/settings.json; do
  if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" 2>/dev/null \
     || python -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" 2>/dev/null; then
    ok "valid JSON: $f"
  else
    bad "valid JSON: $f"
  fi
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
