#!/usr/bin/env bash
# Blocks commits containing style violations from docs/CONVENTIONS.md section 1.
# Bypass with --no-verify only if you are certain. Do not make a habit of it.

set -uo pipefail

fail=0
files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(swift|md|json|txt)$' || true)

if [ -z "$files" ]; then
  exit 0
fi

report() {
  echo "style: $1"
  echo "$2"
  fail=1
}

# The rulebook files define the banned words and authorship trailers by listing
# them, so they are exempt from those two content checks. Every other check
# still applies to them.
is_rulebook() {
  case "$1" in
    CLAUDE.md|docs/CONVENTIONS.md) return 0 ;;
    *) return 1 ;;
  esac
}

for f in $files; do
  [ -f "$f" ] || continue

  # perl matches the raw UTF-8 bytes so the check runs on BSD (macOS) userland,
  # where grep has no -P. em dash is E2 80 94, en dash is E2 80 93.
  hits=$(perl -ne 'print "$.:$_" if /\xe2\x80\x94|\xe2\x80\x93/' "$f" || true)
  if [ -n "$hits" ]; then
    report "em dash or en dash in $f (use a comma, a colon, or rewrite)" "$hits"
  fi

  hits=$(perl -ne 'print "$.:$_" if /\xf0\x9f[\x80-\xbf][\x80-\xbf]|\xe2\x9c[\x80-\xbf]|\xe2\x9d[\x80-\xbf]|\xef\xb8\x8f/' "$f" || true)
  if [ -n "$hits" ]; then
    report "emoji in $f" "$hits"
  fi

  if ! is_rulebook "$f"; then
    hits=$(grep -niE '\b(seamless|robust|comprehensive|cutting-edge|intuitive|innovative|next-level|world-class|leverage|utilize|delve)\b' "$f" || true)
    if [ -n "$hits" ]; then
      report "banned filler word in $f" "$hits"
    fi

    hits=$(grep -nE 'Co-Authored-By|Generated with|Co-authored-by' "$f" || true)
    if [ -n "$hits" ]; then
      report "authorship trailer in $f" "$hits"
    fi
  fi

  # Exclamation marks only inside Swift string literals, where UI copy lives.
  if [[ "$f" == *.swift ]]; then
    hits=$(grep -nE '"[^"]*![^"]*"' "$f" || true)
    if [ -n "$hits" ]; then
      report "exclamation mark in a string literal in $f (UI copy stays calm)" "$hits"
    fi
  fi
done

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Commit blocked. Fix the above or run with --no-verify if you are sure."
  exit 1
fi
exit 0
