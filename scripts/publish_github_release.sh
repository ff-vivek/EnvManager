#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERSION="${VERSION:?VERSION is required}"
DMG_PATH="${DMG_PATH:?DMG_PATH is required}"
CHECKSUM_PATH="${CHECKSUM_PATH:?CHECKSUM_PATH is required}"
TAG="${TAG:-v$VERSION}"
REPO="${REPO:-$("$ROOT_DIR/scripts/detect_github_repo.sh")}"
TITLE="${TITLE:-$TAG}"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found at $DMG_PATH" >&2
  exit 1
fi

if [[ ! -f "$CHECKSUM_PATH" ]]; then
  echo "Checksum file not found at $CHECKSUM_PATH" >&2
  exit 1
fi

if ! git -C "$ROOT_DIR" rev-parse "$TAG" >/dev/null 2>&1; then
  git -C "$ROOT_DIR" config user.name "${GIT_AUTHOR_NAME:-github-actions[bot]}"
  git -C "$ROOT_DIR" config user.email "${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
  git -C "$ROOT_DIR" tag -a "$TAG" -m "Release $TAG"
fi

if ! git -C "$ROOT_DIR" ls-remote --tags origin "refs/tags/$TAG" | grep -q "$TAG"; then
  git -C "$ROOT_DIR" push origin "$TAG"
fi

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" "$DMG_PATH" "$CHECKSUM_PATH" --repo "$REPO" --clobber
  gh release edit "$TAG" --repo "$REPO" --latest
else
  gh release create "$TAG" "$DMG_PATH" "$CHECKSUM_PATH" \
    --repo "$REPO" \
    --title "$TITLE" \
    --verify-tag \
    --generate-notes \
    --latest
fi
