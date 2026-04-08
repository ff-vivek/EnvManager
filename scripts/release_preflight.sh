#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERSION=""
TAG=""
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

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

if [[ -z "$VERSION" ]]; then
  VERSION="$("$ROOT_DIR/scripts/extract_version.sh")"
fi

if [[ -z "$TAG" ]]; then
  TAG="v$VERSION"
fi

if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Release version must look like 1.2 or 1.2.3, got: $VERSION" >&2
  exit 1
fi

if [[ "$TAG" != "v$VERSION" ]]; then
  echo "Release tag must match version. Expected v$VERSION, got $TAG" >&2
  exit 1
fi

require_command git
require_command xcodebuild
require_command xcrun
require_command hdiutil
require_command shasum

if [[ "$ALLOW_DIRTY" -eq 0 ]]; then
  if ! git -C "$ROOT_DIR" diff --quiet || ! git -C "$ROOT_DIR" diff --cached --quiet; then
    echo "Refusing to release from a dirty worktree. Commit or stash changes, or pass --allow-dirty." >&2
    exit 1
  fi
fi

BUNDLE_IDENTIFIER="$("$ROOT_DIR/scripts/extract_bundle_identifier.sh")"
REPO="$("$ROOT_DIR/scripts/detect_github_repo.sh")"

if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
  require_env APPLE_TEAM_ID
  require_env APPLE_ID
  require_env APPLE_APP_SPECIFIC_PASSWORD
  require_command codesign
  require_command spctl
fi

if [[ "$SKIP_GITHUB_RELEASE" -eq 0 ]]; then
  require_command gh
  if [[ -z "${GH_TOKEN:-}" ]] && ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated. Set GH_TOKEN or run gh auth login." >&2
    exit 1
  fi
fi

if [[ "$SKIP_HOMEBREW" -eq 0 ]]; then
  require_env HOMEBREW_TAP_REPO
fi

echo "Preflight OK"
echo "  Version: $VERSION"
echo "  Tag: $TAG"
echo "  Bundle ID: $BUNDLE_IDENTIFIER"
echo "  Repo: $REPO"
echo "  Notarize: $([[ "$SKIP_NOTARIZE" -eq 0 ]] && echo yes || echo no)"
echo "  GitHub release: $([[ "$SKIP_GITHUB_RELEASE" -eq 0 ]] && echo yes || echo no)"
echo "  Homebrew publish: $([[ "$SKIP_HOMEBREW" -eq 0 ]] && echo yes || echo no)"
