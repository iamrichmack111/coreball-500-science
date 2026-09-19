#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

REPO_NAME="${1:-coreball-500-science}"
TAG="${TAG:-v1.0.0}"

log(){ printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn(){ printf '\n\033[1;33mWARNING: %s\033[0m\n' "$*"; }
die(){ printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git is required."
command -v gh >/dev/null 2>&1 || die "GitHub CLI (gh) is required. Install it, then run: gh auth login"
command -v python3 >/dev/null 2>&1 || die "python3 is required."

gh auth status >/dev/null 2>&1 || die "GitHub CLI is not logged in. Run: gh auth login"

GH_USER="$(gh api user -q .login)"

# If this folder already points to a GitHub repo, keep that repo.
if git remote get-url origin >/dev/null 2>&1; then
  ORIGIN_URL="$(git remote get-url origin)"
  EXISTING_REPO="$(printf '%s' "$ORIGIN_URL" | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
  if [[ "$EXISTING_REPO" == */* ]]; then
    FULL_REPO="$EXISTING_REPO"
    REPO_NAME="${FULL_REPO#*/}"
  else
    FULL_REPO="$GH_USER/$REPO_NAME"
  fi
else
  FULL_REPO="$GH_USER/$REPO_NAME"
fi

log "Writing clean GitHub Actions workflows"
mkdir -p .github/workflows docs media/screenshots
rm -f .github/workflows/ci.yml .github/workflows/pages.yml .github/workflows/demo-video.yml

python3 <<'PY'
from pathlib import Path

Path('.github/workflows/ci.yml').write_text('''name: CI

on:
  push:
    branches:
      - main
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 22

      - name: Install dependencies
        run: npm install

      - name: Install Chromium
        run: npx playwright install --with-deps chromium

      - name: Run Playwright tests
        run: npm test

      - name: Generate screenshots
        run: npm run screenshots

      - name: Upload screenshots
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coreball-screenshots
          path: media/screenshots
          if-no-files-found: ignore
''')

Path('.github/workflows/pages.yml').write_text('''name: Deploy Pages

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}

    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure Pages
        uses: actions/configure-pages@v5

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: .

      - name: Deploy Pages
        id: deployment
        uses: actions/deploy-pages@v4
''')

Path('.github/workflows/demo-video.yml').write_text('''name: Demo Video

on:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  demo:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 22

      - name: Install dependencies
        run: npm install

      - name: Install Chromium
        run: npx playwright install --with-deps chromium

      - name: Start game server
        run: |
          python3 -m http.server 4173 --bind 127.0.0.1 > /tmp/coreball-server.log 2>&1 &
          sleep 2

      - name: Record Playwright demo
        run: npm run demo

      - name: Install FFmpeg
        run: sudo apt-get update && sudo apt-get install -y ffmpeg

      - name: Convert demo to MP4
        run: |
          ffmpeg -y -i media/coreball-demo.webm \
            -c:v libx264 -preset medium -crf 21 \
            -pix_fmt yuv420p -movflags +faststart \
            media/coreball-demo.mp4

      - name: Upload demo video
        uses: actions/upload-artifact@v4
        with:
          name: coreball-demo-video
          path: |
            media/coreball-demo.mp4
            media/coreball-demo.webm
            media/demo-cover.png
''')

Path('docs/architecture.d2').write_text('''direction: right

player: Player {
  shape: person
}

game: Coreball 500 {
  canvas: HTML5 Canvas
  levels: 500 Levels
  collision: Pin Collision Engine
  lives: Heart System
  slow: Slow Motion
  science: Science Bonus Life
}

testing: Playwright {
  smoke: Smoke Tests
  screenshots: Screenshots
  video: Demo Video
}

github: GitHub {
  actions: CI/CD
  pages: GitHub Pages
  wiki: Wiki
  release: Releases
}

player -> game.canvas: Fire pin
game.canvas -> game.collision
game.collision -> game.lives: Collision
game.lives -> game.science: Lose heart
game.science -> game.lives: Correct answer +1 heart
game.levels -> game.canvas
game.slow -> game.canvas

testing -> game: Browser automation
github.actions -> testing
github.actions -> github.pages
github.wiki -> game
github.release -> game
''')
PY

log "Validating workflow YAML structure"
python3 - <<'PY'
from pathlib import Path
for name in ['ci.yml','pages.yml','demo-video.yml']:
    p=Path('.github/workflows')/name
    t=p.read_text()
    required=['name:', 'on:', 'jobs:', 'uses: actions/checkout@v4']
    missing=[x for x in required if x not in t]
    if missing:
        raise SystemExit(f'{p}: missing {missing}')
    if 'EOF' in t:
        raise SystemExit(f'{p}: stray EOF found')
    print('OK', p)
PY

log "Rendering D2 architecture diagram"
if ! command -v d2 >/dev/null 2>&1; then
  warn "D2 is not installed. Attempting the official installer."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://d2lang.com/install.sh | sh -s -- || true
    export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
  fi
fi

if command -v d2 >/dev/null 2>&1; then
  d2 docs/architecture.d2 docs/architecture.svg
else
  warn "D2 install was unavailable. Keeping docs/architecture.d2; CI/push can still proceed."
fi

log "Ensuring Git repository and GitHub remote"
if [[ ! -d .git ]]; then
  git init
fi
git branch -M main

# Configure a usable Git identity if one is not already set.
if ! git config user.name >/dev/null 2>&1 || [[ -z "$(git config user.name || true)" ]]; then
  git config user.name "$GH_USER"
fi
if ! git config user.email >/dev/null 2>&1 || [[ -z "$(git config user.email || true)" ]]; then
  GH_ID="$(gh api user -q .id)"
  git config user.email "${GH_ID}+${GH_USER}@users.noreply.github.com"
fi

if ! gh repo view "$FULL_REPO" >/dev/null 2>&1; then
  log "Creating GitHub repository $FULL_REPO"
  gh repo create "$REPO_NAME" --public --description "Coreball 500 science game with Playwright CI/CD"
  FULL_REPO="$GH_USER/$REPO_NAME"
fi

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "https://github.com/$FULL_REPO.git"
else
  git remote add origin "https://github.com/$FULL_REPO.git"
fi

log "Updating README badges and architecture section"
export FULL_REPO
python3 <<'PY'
import os
from pathlib import Path
repo=os.environ['FULL_REPO']
p=Path('README.md')
text=p.read_text() if p.exists() else '# Coreball 500 Science\n'

badges=f'''\n[![CI](https://github.com/{repo}/actions/workflows/ci.yml/badge.svg)](https://github.com/{repo}/actions/workflows/ci.yml)\n[![Pages](https://github.com/{repo}/actions/workflows/pages.yml/badge.svg)](https://github.com/{repo}/actions/workflows/pages.yml)\n[![Release](https://img.shields.io/github/v/release/{repo})](https://github.com/{repo}/releases)\n'''

if '[![CI]' not in text:
    lines=text.splitlines()
    if lines and lines[0].startswith('#'):
        text='\n'.join([lines[0], badges, *lines[1:]])+'\n'
    else:
        text=badges+'\n'+text

section='''\n## Architecture\n\n![Coreball Architecture](docs/architecture.svg)\n\nThe project uses a lightweight HTML5 Canvas game engine with deterministic levels, rotating-pin collision mechanics, hearts, slow-motion power-ups, science bonus-life questions, Playwright browser testing, GitHub Actions CI/CD, and GitHub Pages deployment.\n\n## Project Automation\n\n- 500 game levels\n- Playwright smoke tests\n- Automated screenshots\n- Demo-video workflow\n- GitHub Actions CI\n- GitHub Pages deployment\n- D2 architecture documentation\n- GitHub Wiki\n- Tagged GitHub releases\n'''
if '## Architecture' not in text:
    text += section
p.write_text(text)
PY

log "Installing Node dependencies locally if needed"
if [[ -f package.json ]]; then
  npm install --ignore-scripts || warn "npm install failed locally; GitHub Actions will try again."
fi

log "Committing and pushing main"
git add -A
if ! git diff --cached --quiet; then
  git commit -m "ci: add CI CD Pages D2 Wiki and demo workflow"
else
  log "No new main-repo changes to commit"
fi

git push -u origin main --force

log "Enabling GitHub Wiki and creating documentation"
gh repo edit "$FULL_REPO" --enable-wiki=true || true
WIKI_DIR="$(mktemp -d)"
WIKI_URL="https://github.com/$FULL_REPO.wiki.git"

# GitHub may take a moment to make the wiki repository available.
WIKI_READY=0
for attempt in 1 2 3 4 5; do
  if git clone "$WIKI_URL" "$WIKI_DIR/wiki" >/dev/null 2>&1; then
    WIKI_READY=1
    break
  fi
  rm -rf "$WIKI_DIR/wiki"
  sleep 2
done

if [[ "$WIKI_READY" -eq 1 ]]; then
  cd "$WIKI_DIR/wiki"
  cat > Home.md <<'EOF'
# Coreball 500 Science

A browser-based rotating-pin timing game with 500 levels, hearts, slow-motion power-ups, and science bonus-life questions.

## Wiki

- [Gameplay](Gameplay)
- [Science Bonus System](Science-Bonus-System)
- [Architecture](Architecture)
- [Development](Development)
- [CI CD](CI-CD)
EOF

  cat > Gameplay.md <<'EOF'
# Gameplay

Attach every queued pin to the rotating core without touching an already attached pin.

## Difficulty

- Pre-attached pins
- Smaller safe gaps
- Faster rotation
- Direction reversals
- Larger shot queues

## Hearts

Players can use 3, 5, or 7 hearts. A collision removes one heart.
EOF

  cat > Science-Bonus-System.md <<'EOF'
# Science Bonus System

After a collision removes a heart, the player receives a multiple-choice science question.

- Correct answer: restore the lost heart.
- Incorrect answer: the heart remains lost.

Questions cover biology, physics, chemistry, Earth science, and astronomy.
EOF

  cat > Architecture.md <<'EOF'
# Architecture

The game is a lightweight HTML5 Canvas application.

## Main components

- Canvas renderer
- 500-level generator
- Rotating pin engine
- Collision detection
- Heart/life system
- Slow-motion power-ups
- Science question system
- Playwright browser automation
- GitHub Actions CI/CD
- GitHub Pages deployment
EOF

  cat > Development.md <<'EOF'
# Development

## Start

```bash
./start.sh
```

## Test

```bash
npm install
npx playwright install chromium
npm test
```

## Screenshots

```bash
npm run screenshots
```

## Demo Video

```bash
npm run demo
```
EOF

  cat > CI-CD.md <<'EOF'
# CI CD

The repository contains three GitHub Actions workflows.

## CI

Runs Playwright browser tests and generates screenshots.

## Deploy Pages

Deploys the static browser game to GitHub Pages.

## Demo Video

Runs Playwright, records a browser demo, converts it to MP4 with FFmpeg, and uploads it as a workflow artifact.
EOF

  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "docs: add project wiki"
  fi
  git push origin HEAD:master --force
  cd "$PROJECT_DIR"
else
  warn "Wiki repo was not available yet. Main repo setup will continue. Run this script again later to retry Wiki creation."
fi
rm -rf "$WIKI_DIR"

log "Enabling GitHub Pages"
gh api --method POST "repos/$FULL_REPO/pages" -f build_type=workflow >/dev/null 2>&1 || \
  gh api --method PUT "repos/$FULL_REPO/pages" -f build_type=workflow >/dev/null 2>&1 || true

log "Creating/updating release tag $TAG"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  git tag -d "$TAG" >/dev/null 2>&1 || true
fi
git push origin ":refs/tags/$TAG" >/dev/null 2>&1 || true
git tag -a "$TAG" -m "Coreball 500 Science $TAG"
git push origin "$TAG"

gh release delete "$TAG" -y >/dev/null 2>&1 || true
gh release create "$TAG" \
  --title "Coreball 500 Science $TAG" \
  --notes "500 levels, science bonus lives, slow motion, Playwright tests and screenshots, demo-video workflow, CI/CD, GitHub Pages, D2 architecture documentation, Wiki, and tagged release."

log "Triggering workflows"
gh workflow run ci.yml --repo "$FULL_REPO" || true
gh workflow run pages.yml --repo "$FULL_REPO" || true
gh workflow run demo-video.yml --repo "$FULL_REPO" || true

log "Final verification"
printf 'Repository: https://github.com/%s\n' "$FULL_REPO"
printf 'Release:    https://github.com/%s/releases/tag/%s\n' "$FULL_REPO" "$TAG"
printf 'Wiki:       https://github.com/%s/wiki\n' "$FULL_REPO"
printf '\nRecent workflow runs:\n'
gh run list --repo "$FULL_REPO" -L 10 || true
printf '\nGit status:\n'
git status --short --branch

printf '\n\033[1;32mSETUP COMPLETE\033[0m\n'
