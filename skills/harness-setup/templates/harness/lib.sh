# Shared helpers for the harness scripts. Source, don't execute.

# Hash of the full working tree (tracked + untracked, minus ignored files),
# independent of what is staged. Any edit changes it.
harness_fingerprint() {
  local tmp
  tmp=$(mktemp) || return 1
  rm -f "$tmp"
  if git rev-parse --verify -q HEAD >/dev/null; then
    GIT_INDEX_FILE="$tmp" git read-tree HEAD
  fi
  GIT_INDEX_FILE="$tmp" git add -A -- . >/dev/null 2>&1
  GIT_INDEX_FILE="$tmp" git write-tree
  rm -f "$tmp"
}

harness_root() {
  git rev-parse --show-toplevel 2>/dev/null
}
