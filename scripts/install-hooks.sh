#!/usr/bin/env bash
# Installs the style hook into .git/hooks. Run once after cloning.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
ln -sf ../../scripts/check-style.sh "$root/.git/hooks/pre-commit"
chmod +x "$root/scripts/check-style.sh"
echo "pre-commit hook installed"
