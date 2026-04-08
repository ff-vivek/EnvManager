#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REMOTE_URL="$(git -C "$ROOT_DIR" config --get remote.origin.url || true)"

if [[ -z "$REMOTE_URL" ]]; then
  echo "Could not determine remote.origin.url" >&2
  exit 1
fi

case "$REMOTE_URL" in
  git@github.com:*)
    REPO="${REMOTE_URL#git@github.com:}"
    ;;
  https://github.com/*)
    REPO="${REMOTE_URL#https://github.com/}"
    ;;
  *)
    echo "Unsupported GitHub remote URL: $REMOTE_URL" >&2
    exit 1
    ;;
esac

REPO="${REPO%.git}"

if [[ "$REPO" != */* ]]; then
  echo "Failed to parse owner/repo from remote URL: $REMOTE_URL" >&2
  exit 1
fi

echo "$REPO"
