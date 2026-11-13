# Shared helpers for the harness scripts and hooks. Source, don't execute.

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

# harness_field <key>: the first string value of "key" in the hook JSON on stdin,
# with JSON escapes undone. Prints nothing and returns 1 when the key is absent.
# Plain grep and bash, so hooks need no jq, Node or Python.
harness_field() {
  local raw bs q sl nl ph
  raw=$(LC_ALL=C grep -aoE "\"$1\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" | head -n 1)
  [ -n "$raw" ] || return 1
  raw=${raw#*:}
  raw=${raw#"${raw%%\"*}"}
  raw=${raw#\"}
  raw=${raw%\"}
  # Variables for the backslash and quote keep this identical on bash 3.2 and 5.x.
  bs='\'
  q='"'
  sl='/'
  nl='
'
  ph=$(printf '\001')
  raw=${raw//"$bs$bs"/"$ph"}
  raw=${raw//"${bs}n"/"$nl"}
  raw=${raw//"${bs}t"/" "}
  raw=${raw//"${bs}r"/}
  raw=${raw//"$bs$q"/"$q"}
  raw=${raw//"$bs$sl"/"$sl"}
  raw=${raw//"$ph"/"$bs"}
  printf '%s\n' "$raw"
}

# The command of a Bash or PowerShell tool call, from the hook JSON on stdin.
# Only the command: the tool-call description is never looked at.
# Falls back to the whole payload when there is no "command" field.
harness_command() {
  local input
  input=$(cat)
  printf '%s\n' "$input" | harness_field command || printf '%s\n' "$input"
}

# Splits a command (stdin) into simple commands, one per line, each starting with
# its command word: `cd x && sudo git push` becomes `cd x` and `git push`.
# Hooks match these lines with ^-anchored patterns, so the same words inside a
# quoted string, a grep pattern or an echo do not count.
# Splits on newline ; | & ( ) and backtick, and after `bash -c "`, `eval` and `xargs`.
# Does not split on { } so ${HOME} survives.
# The body of a `$(cat <<'EOF'` heredoc is text (a commit message, a PR description), so
# it is dropped. Heredocs fed to a shell or through a pipe are kept: those lines do run.
harness_segments() {
  local q="[\"']" b='(^|[^[:alnum:]_.-])'
  local heredoc="" line trimmed
  local opens='\$\(cat[[:space:]]*<<-?[[:space:]]*["'"'"']?([A-Za-z_][A-Za-z0-9_]*)["'"'"']?[[:space:]]*$'
  while IFS= read -r line || [ -n "$line" ]; do
    if [ -n "$heredoc" ]; then
      trimmed=${line#"${line%%[![:space:]]*}"}
      [ "$trimmed" = "$heredoc" ] && heredoc=""
      continue
    fi
    printf '%s\n' "$line"
    if [[ $line =~ $opens ]]; then heredoc=${BASH_REMATCH[1]}; fi
  done \
    | LC_ALL=C sed -E \
      -e "s/${b}(bash|sh|zsh|dash|pwsh|powershell)(\.exe)?([[:space:]]+-[^[:space:]]+)*[[:space:]]+-([[:alpha:]]*c|[Cc]ommand)[[:space:]]+${q}?/\1;/g" \
      -e "s/${b}eval[[:space:]]+${q}?/\1;/g" \
      -e "s/${b}xargs([[:space:]]+-[^[:space:]]+)*[[:space:]]+/\1;/g" \
    | LC_ALL=C tr ';|&()`' '\n\n\n\n\n\n' \
    | LC_ALL=C sed -E \
      -e ':a' \
      -e 's/^[[:space:]]+//' \
      -e 's/^(sudo|env|command|exec|time|nohup|then|do|else|elif|if|while|until|!|\{)[[:space:]]+//' \
      -e 'ta' \
      -e 's/^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+//' \
      -e 'ta'
}
