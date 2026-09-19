#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Installing Playwright dependencies"
npm install
npx playwright install chromium

echo "==> Retaking V20 screenshots"
npm run screenshots

echo "==> Generated screenshots"
find media/screenshots -maxdepth 1 -type f -name '*.png' -printf '%f\n' | sort

COUNT=$(find media/screenshots -maxdepth 1 -type f -name '*.png' | wc -l)
if [ "$COUNT" -lt 16 ]; then
  echo "ERROR: expected at least 16 screenshots, found $COUNT"
  exit 1
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add media/screenshots tests/screenshots.spec.js .github/workflows/retake-screenshots.yml
  if ! git diff --cached --quiet; then
    git commit -m "docs: retake V20 theme and gameplay screenshots"
    git push origin main
  else
    echo "Screenshots are already current."
  fi
fi

echo "DONE: $COUNT screenshots retaken."
