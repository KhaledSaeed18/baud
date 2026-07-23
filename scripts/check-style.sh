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

for f in $files; do
  [ -f "$f" ] || continue

  hits=$(LC_ALL=C grep -nP '\xe2\x80\x94|\xe2\x80\x93' "$f" || true)
  if [ -n "$hits" ]; then
    report "em dash or en dash in $f (use a comma, a colon, or rewrite)" "$hits"
  fi

  hits=$(LC_ALL=C grep -nP '\xf0\x9f[\x80-\xbf][\x80-\xbf]|\xe2\x9c[\x80-\xbf]|\xe2\x9d[\x80-\xbf]|\xef\xb8\x8f' "$f" || true)
  if [ -n "$hits" ]; then
    report "emoji in $f" "$hits"
  fi

  hits=$(grep -niE '\b(seamless|robust|comprehensive|cutting-edge|intuitive|innovative|next-level|world-class|leverage|utilize|delve)\b' "$f" || true)
  if [ -n "$hits" ]; then
    report "banned filler word in $f" "$hits"
  fi

  hits=$(grep -nE 'Co-Authored-By|Generated with|Co-authored-by' "$f" || true)
  if [ -n "$hits" ]; then
    report "authorship trailer in $f" "$hits"
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
