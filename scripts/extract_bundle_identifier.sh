#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/EnvManager.xcodeproj/project.pbxproj"

BUNDLE_IDENTIFIER="$(
  awk '
    /PRODUCT_BUNDLE_IDENTIFIER = / {
      gsub(";", "", $3)
      print $3
      exit
    }
  ' "$PROJECT_FILE"
)"

if [[ -z "$BUNDLE_IDENTIFIER" ]]; then
  echo "Failed to extract PRODUCT_BUNDLE_IDENTIFIER from $PROJECT_FILE" >&2
  exit 1
fi

echo "$BUNDLE_IDENTIFIER"
