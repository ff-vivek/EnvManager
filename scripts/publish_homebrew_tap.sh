#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERSION="${VERSION:?VERSION is required}"
SHA256="${SHA256:?SHA256 is required}"
DOWNLOAD_URL="${DOWNLOAD_URL:?DOWNLOAD_URL is required}"
HOMEBREW_TAP_REPO="${HOMEBREW_TAP_REPO:?HOMEBREW_TAP_REPO is required, for example viveky259259/homebrew-tap}"

CASK_TOKEN="${CASK_TOKEN:-envmanager}"
APP_NAME="${APP_NAME:-EnvManager}"
APP_BUNDLE_NAME="${APP_BUNDLE_NAME:-EnvManager.app}"
HOMEPAGE_URL="${HOMEPAGE_URL:-https://github.com/$("$ROOT_DIR/scripts/detect_github_repo.sh")}"
HOMEBREW_TAP_BRANCH="${HOMEBREW_TAP_BRANCH:-main}"
HOMEBREW_CASK_DIR="${HOMEBREW_CASK_DIR:-Casks}"
MIN_MACOS="${MIN_MACOS:-ventura}"

if [[ -n "${HOMEBREW_TAP_GH_TOKEN:-}" ]]; then
  CLONE_URL="https://x-access-token:${HOMEBREW_TAP_GH_TOKEN}@github.com/${HOMEBREW_TAP_REPO}.git"
else
  CLONE_URL="https://github.com/${HOMEBREW_TAP_REPO}.git"
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

git clone "$CLONE_URL" "$TMP_DIR"
git -C "$TMP_DIR" checkout "$HOMEBREW_TAP_BRANCH"
git -C "$TMP_DIR" config user.name "${GIT_AUTHOR_NAME:-github-actions[bot]}"
git -C "$TMP_DIR" config user.email "${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"

CASK_PATH="$TMP_DIR/$HOMEBREW_CASK_DIR/${CASK_TOKEN}.rb"

OUTPUT_FILE="$CASK_PATH" \
VERSION="$VERSION" \
SHA256="$SHA256" \
DOWNLOAD_URL="$DOWNLOAD_URL" \
CASK_TOKEN="$CASK_TOKEN" \
APP_NAME="$APP_NAME" \
APP_BUNDLE_NAME="$APP_BUNDLE_NAME" \
HOMEPAGE_URL="$HOMEPAGE_URL" \
MIN_MACOS="$MIN_MACOS" \
"$ROOT_DIR/scripts/create_homebrew_cask.sh"

git -C "$TMP_DIR" add "$CASK_PATH"

if git -C "$TMP_DIR" diff --cached --quiet; then
  echo "Homebrew tap already up to date"
  exit 0
fi

git -C "$TMP_DIR" commit -m "${CASK_TOKEN} ${VERSION}"
git -C "$TMP_DIR" push origin "$HOMEBREW_TAP_BRANCH"
