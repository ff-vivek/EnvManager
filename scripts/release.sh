#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SCHEME="${SCHEME:-EnvManager}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist/release}"
VERSION="${VERSION:-}"
SKIP_NOTARIZE=0
ALLOW_DIRTY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
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

PREFLIGHT_ARGS=(--version "$VERSION" --skip-github-release --skip-homebrew)

if [[ "$SKIP_NOTARIZE" -eq 1 ]]; then
  PREFLIGHT_ARGS+=(--skip-notarize)
fi

if [[ "$ALLOW_DIRTY" -eq 1 ]]; then
  PREFLIGHT_ARGS+=(--allow-dirty)
fi

"$ROOT_DIR/scripts/release_preflight.sh" "${PREFLIGHT_ARGS[@]}"

ARCHIVE_PATH="$OUTPUT_DIR/$SCHEME.xcarchive"
EXPORT_DIR="$OUTPUT_DIR/export"
APP_PATH="$EXPORT_DIR/$SCHEME.app"
DMG_PATH="$OUTPUT_DIR/${SCHEME}-${VERSION}.dmg"
CHECKSUM_PATH="$OUTPUT_DIR/${SCHEME}-${VERSION}.sha256"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "==> Archiving $SCHEME"
ARCHIVE_PATH="$ARCHIVE_PATH" "$ROOT_DIR/scripts/archive_app.sh"

echo "==> Exporting Developer ID app"
ARCHIVE_PATH="$ARCHIVE_PATH" EXPORT_DIR="$EXPORT_DIR" SCHEME="$SCHEME" "$ROOT_DIR/scripts/export_developer_id.sh"

echo "==> Verifying exported app bundle"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl -a -vv -t exec "$APP_PATH"

echo "==> Creating DMG"
APP_PATH="$APP_PATH" OUTPUT_DMG="$DMG_PATH" VOLUME_NAME="$SCHEME" "$ROOT_DIR/scripts/create_dmg.sh"

if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
  echo "==> Notarizing and stapling DMG"
  DMG_PATH="$DMG_PATH" "$ROOT_DIR/scripts/notarize_dmg.sh"
else
  echo "==> Skipping notarization"
fi

echo "==> Writing SHA256 checksum"
(cd "$OUTPUT_DIR" && shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$CHECKSUM_PATH")")

echo
echo "Release artifacts:"
echo "  DMG: $DMG_PATH"
echo "  SHA: $CHECKSUM_PATH"
