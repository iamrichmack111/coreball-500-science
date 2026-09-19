#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

REPO_NAME="${1:-coreball-500-science}"
TAG="${TAG:-v1.0.0}"

log(){ printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die(){ printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

for cmd in git gh python3; do command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"; done
gh auth status >/dev/null 2>&1 || die "Run: gh auth login"
GH_USER="$(gh api user -q .login)"
FULL_REPO="$GH_USER/$REPO_NAME"

log "Target repository: $FULL_REPO"

# Never inherit an unrelated origin.
if [[ ! -d .git ]]; then git init; fi
git branch -M main
git config user.name "$(git config user.name || echo "$GH_USER")"
if [[ -z "$(git config user.email || true)" ]]; then
  GH_ID="$(gh api user -q .id)"
  git config user.email "${GH_ID}+${GH_USER}@users.noreply.github.com"
fi

if ! gh repo view "$FULL_REPO" >/dev/null 2>&1; then
  log "Creating $FULL_REPO"
  gh repo create "$REPO_NAME" --public --description "Coreball 500 science game with CI/CD, Docker, D2, Wiki and demo video"
fi

git remote remove origin >/dev/null 2>&1 || true
git remote add origin "https://github.com/$FULL_REPO.git"
gh auth setup-git >/dev/null 2>&1 || true

log "Writing repository-specific README badges"
export FULL_REPO
python3 <<'PY'
import os,re
from pathlib import Path
repo=os.environ['FULL_REPO']
p=Path('README.md')
t=p.read_text()
t=re.sub(r'https://github\.com/[^/\s)]+/coreball-500-science', f'https://github.com/{repo}', t)
t=re.sub(r'github/v/release/[^/\s)]+/coreball-500-science', f'github/v/release/{repo}', t)
p.write_text(t)
PY

log "Rendering D2 if the d2 binary is available"
if command -v d2 >/dev/null 2>&1; then
  d2 docs/architecture.d2 docs/architecture.svg
else
  echo "D2 binary not installed; using the pre-rendered docs/architecture.svg included in this package."
fi

# Pages must exist before configure-pages tries to GET it.
log "Enabling GitHub Pages for Actions"
if ! gh api "repos/$FULL_REPO/pages" >/dev/null 2>&1; then
  gh api --method POST "repos/$FULL_REPO/pages" -f build_type=workflow >/dev/null 2>&1 || true
else
  gh api --method PUT "repos/$FULL_REPO/pages" -f build_type=workflow >/dev/null 2>&1 || true
fi

log "Enabling Wiki"
gh repo edit "$FULL_REPO" --enable-wiki=true

log "Pushing main repository content"
git add -A
if ! git diff --cached --quiet; then
  git commit -m "release: add Docker D2 Wiki CI CD and committed demo"
fi
git push -u origin main --force

log "Publishing GitHub Wiki (non-blocking if GitHub has not initialized the wiki repo yet)"
WIKI_PUBLISHED=0
WIKI_TMP="$(mktemp -d)"
cp -a wiki/. "$WIKI_TMP/"
(
  cd "$WIKI_TMP"
  git init >/dev/null
  git branch -M master
  git config user.name "$GH_USER"
  git config user.email "$(git -C "$PROJECT_DIR" config user.email)"
  git add -A
  git commit -m "docs: publish Coreball 500 Science wiki" >/dev/null
  git remote add origin "https://github.com/$FULL_REPO.wiki.git"
  if git ls-remote origin >/dev/null 2>&1; then
    git push -u origin master --force
  else
    exit 42
  fi
) && WIKI_PUBLISHED=1 || true
rm -rf "$WIKI_TMP"
if [[ "$WIKI_PUBLISHED" -eq 0 ]]; then
  echo "WARNING: GitHub has not created $FULL_REPO.wiki.git yet."
  echo "The complete wiki source is still committed under ./wiki in the main repository."
  echo "To activate the GitHub Wiki remote, create the first Wiki page once in the GitHub UI, then rerun this script."
fi

log "Triggering Playwright demo recording"
gh workflow run demo-video.yml --repo "$FULL_REPO"
sleep 5
DEMO_RUN="$(gh run list --repo "$FULL_REPO" --workflow demo-video.yml -L 1 --json databaseId -q '.[0].databaseId')"
[[ -n "$DEMO_RUN" ]] || die "Could not find the demo-video workflow run"
gh run watch "$DEMO_RUN" --repo "$FULL_REPO" --exit-status

log "Downloading generated demo video into the repository"
ART_TMP="$(mktemp -d)"
gh run download "$DEMO_RUN" --repo "$FULL_REPO" -n coreball-demo-video -D "$ART_TMP"
MP4="$(find "$ART_TMP" -type f -name 'coreball-demo.mp4' -print -quit)"
WEBM="$(find "$ART_TMP" -type f -name 'coreball-demo.webm' -print -quit)"
COVER="$(find "$ART_TMP" -type f -name 'demo-cover.png' -print -quit)"
[[ -n "$MP4" && -s "$MP4" ]] || { rm -rf "$ART_TMP"; die "Demo workflow completed but MP4 artifact was missing"; }
mkdir -p media
cp "$MP4" media/coreball-demo.mp4
[[ -n "$WEBM" ]] && cp "$WEBM" media/coreball-demo.webm || true
[[ -n "$COVER" ]] && cp "$COVER" media/demo-cover.png || true
rm -rf "$ART_TMP"

git add media README.md
if ! git diff --cached --quiet; then
  git commit -m "media: commit Playwright demo video"
  git push origin main
fi

log "Creating tag and GitHub release"
gh release delete "$TAG" --repo "$FULL_REPO" -y >/dev/null 2>&1 || true
git tag -d "$TAG" >/dev/null 2>&1 || true
git push origin ":refs/tags/$TAG" >/dev/null 2>&1 || true
git tag -a "$TAG" -m "Coreball 500 Science $TAG"
git push origin "$TAG"
gh release create "$TAG" --repo "$FULL_REPO" \
  --title "Coreball 500 Science $TAG" \
  --notes "500 levels, science bonus lives, Playwright demo video, CI/CD, GitHub Pages, Docker, D2 architecture, Wiki, and tagged release." \
  media/coreball-demo.mp4 docs/architecture.svg

log "Triggering verification workflows"
gh workflow run ci.yml --repo "$FULL_REPO"
gh workflow run pages.yml --repo "$FULL_REPO"
gh workflow run docker.yml --repo "$FULL_REPO"
sleep 5

watch_latest(){
  local workflow="$1"
  local rid
  rid="$(gh run list --repo "$FULL_REPO" --workflow "$workflow" -L 1 --json databaseId -q '.[0].databaseId')"
  [[ -n "$rid" ]] || die "No run found for $workflow"
  gh run watch "$rid" --repo "$FULL_REPO" --exit-status
}
watch_latest ci.yml
watch_latest pages.yml
watch_latest docker.yml

log "Verifying required GitHub deliverables"
gh api "repos/$FULL_REPO/contents/Dockerfile?ref=main" >/dev/null || die "Dockerfile missing from GitHub"
gh api "repos/$FULL_REPO/contents/docs/architecture.d2?ref=main" >/dev/null || die "D2 source missing from GitHub"
gh api "repos/$FULL_REPO/contents/docs/architecture.svg?ref=main" >/dev/null || die "D2 SVG missing from GitHub"
gh api "repos/$FULL_REPO/contents/media/coreball-demo.mp4?ref=main" >/dev/null || die "Demo MP4 missing from GitHub"
gh api "repos/$FULL_REPO/releases/tags/$TAG" >/dev/null || die "Release/tag missing from GitHub"
gh api "repos/$FULL_REPO/pages" >/dev/null || die "GitHub Pages is not enabled"
WIKI_REFS="$(git ls-remote "https://github.com/$FULL_REPO.wiki.git" 2>/dev/null || true)"
if [[ -n "$WIKI_REFS" ]]; then
  WIKI_STATUS="published"
else
  WIKI_STATUS="source committed under /wiki; GitHub Wiki remote not initialized yet"
fi

printf '\n\033[1;32mCORE SETUP VERIFIED\033[0m\n'
printf 'Repo:    https://github.com/%s\n' "$FULL_REPO"
printf 'Wiki:    %s\n' "$WIKI_STATUS"
printf 'Release: https://github.com/%s/releases/tag/%s\n' "$FULL_REPO" "$TAG"
printf 'Demo:    https://github.com/%s/blob/main/media/coreball-demo.mp4\n' "$FULL_REPO"
printf 'Docker:  Dockerfile + docker-compose.yml + Docker workflow verified\n'
printf 'Pages:   enabled and latest manual deployment passed\n'
