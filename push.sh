#!/usr/bin/env bash
# Run in Git Bash from the project root: ./push.sh "optional commit message"
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -d .git ]; then
  git init
  git branch -M main
fi

git add -A

if git diff --cached --quiet; then
  echo "Nothing to commit."
else
  msg="${1:-Update $(date '+%Y-%m-%d %H:%M')}"
  git commit -m "$msg"
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo ""
  echo "No 'origin' remote set. Create an empty repo on GitHub, then run:"
  echo "  git remote add origin https://github.com/<you>/<repo>.git"
  echo "  ./push.sh"
  exit 1
fi

git push -u origin main
