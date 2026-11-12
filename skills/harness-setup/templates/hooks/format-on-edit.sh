#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit): run the configured formatter on the edited file.
# Never blocks: formatting problems surface later in verify.sh.
set -u
input=$(cat)

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
config="$root/.claude/harness/formatters"
[ -f "$config" ] || exit 0

file=$(printf '%s' "$input" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 \
  | sed 's/.*:[[:space:]]*"\(.*\)"/\1/; s/\\\\/\//g')
[ -n "$file" ] && [ -f "$file" ] || exit 0
name=$(basename "$file")

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|'#'*) continue ;; esac
  globs=${line%%[[:space:]]*}
  cmd=$(printf '%s' "${line#"$globs"}" | sed 's/^[[:space:]]*//')
  IFS=, read -r -a patterns <<< "$globs"
  for p in "${patterns[@]}"; do
    # shellcheck disable=SC2254
    case "$name" in
      $p) (cd "$root" && eval "$cmd \"\$file\"") >/dev/null 2>&1; exit 0 ;;
    esac
  done
done < "$config"
exit 0
