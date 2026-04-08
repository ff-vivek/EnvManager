#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERSION="${VERSION:-}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist/release}"
TAG="${TAG:-}"
SKIP_NOTARIZE=0
SKIP_GITHUB_RELEASE=0
SKIP_HOMEBREW=0
ALLOW_DIRTY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --skip-notarize)
      SKIP_NOTARIZE=1
      shift
      ;;
    --skip-github-release)
      SKIP_GITHUB_RELEASE=1
      shift
      ;;
    --skip-homebrew)
      SKIP_HOMEBREW=1
      shift
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  VERSION="$("$ROOT_DIR/scripts/extract_version.sh")"
fi

if [[ -z "$TAG" ]]; then
  TAG="v$VERSION"
fi

PREFLIGHT_ARGS=(--version "$VERSION" --tag "$TAG")

if [[ "$SKIP_NOTARIZE" -eq 1 ]]; then
  PREFLIGHT_ARGS+=(--skip-notarize)
fi

if [[ "$SKIP_GITHUB_RELEASE" -eq 1 ]]; then
  PREFLIGHT_ARGS+=(--skip-github-release)
fi

if [[ "$SKIP_HOMEBREW" -eq 1 ]]; then
  PREFLIGHT_ARGS+=(--skip-homebrew)
fi

if [[ "$ALLOW_DIRTY" -eq 1 ]]; then
  PREFLIGHT_ARGS+=(--allow-dirty)
fi

"$ROOT_DIR/scripts/release_preflight.sh" "${PREFLIGHT_ARGS[@]}"

ARGS=(--version "$VERSION" --output-dir "$OUTPUT_DIR")

if [[ "$SKIP_NOTARIZE" -eq 1 ]]; then
  ARGS+=(--skip-notarize)
fi

if [[ "$ALLOW_DIRTY" -eq 1 ]]; then
  ARGS+=(--allow-dirty)
fi

echo "==> Building, packaging, and notarizing"
"$ROOT_DIR/scripts/release.sh" "${ARGS[@]}"

DMG_PATH="$OUTPUT_DIR/EnvManager-$VERSION.dmg"
CHECKSUM_PATH="$OUTPUT_DIR/EnvManager-$VERSION.sha256"
SHA256="$(awk '{ print $1 }' "$CHECKSUM_PATH")"
REPO="$("$ROOT_DIR/scripts/detect_github_repo.sh")"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/$(basename "$DMG_PATH")"

if [[ "$SKIP_GITHUB_RELEASE" -eq 0 ]]; then
  echo "==> Publishing GitHub Release"
  VERSION="$VERSION" TAG="$TAG" DMG_PATH="$DMG_PATH" CHECKSUM_PATH="$CHECKSUM_PATH" REPO="$REPO" \
    "$ROOT_DIR/scripts/publish_github_release.sh"
else
  echo "==> Skipping GitHub Release publish"
fi

if [[ "$SKIP_HOMEBREW" -eq 0 ]]; then
  echo "==> Publishing Homebrew cask"
  VERSION="$VERSION" SHA256="$SHA256" DOWNLOAD_URL="$DOWNLOAD_URL" \
    "$ROOT_DIR/scripts/publish_homebrew_tap.sh"
else
  echo "==> Skipping Homebrew publish"
fi

echo
echo "Published release:"
echo "  Tag: $TAG"
echo "  DMG: $DMG_PATH"
echo "  SHA: $CHECKSUM_PATH"
