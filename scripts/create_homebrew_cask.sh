#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OUTPUT_FILE="${OUTPUT_FILE:?OUTPUT_FILE is required}"
VERSION="${VERSION:?VERSION is required}"
SHA256="${SHA256:?SHA256 is required}"
DOWNLOAD_URL="${DOWNLOAD_URL:?DOWNLOAD_URL is required}"

CASK_TOKEN="${CASK_TOKEN:-envmanager}"
APP_NAME="${APP_NAME:-EnvManager}"
APP_BUNDLE_NAME="${APP_BUNDLE_NAME:-EnvManager.app}"
DESC="${DESC:-Native macOS app for managing shell environment variables}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-$("$ROOT_DIR/scripts/extract_bundle_identifier.sh")}"
APP_SUPPORT_DIR="${APP_SUPPORT_DIR:-EnvManager}"
HOMEPAGE_URL="${HOMEPAGE_URL:-https://github.com/$("$ROOT_DIR/scripts/detect_github_repo.sh")}"
MIN_MACOS="${MIN_MACOS:-ventura}"

mkdir -p "$(dirname "$OUTPUT_FILE")"

cat > "$OUTPUT_FILE" <<EOF
cask "${CASK_TOKEN}" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "${DOWNLOAD_URL}",
      verified: "github.com/"
  name "${APP_NAME}"
  desc "${DESC}"
  homepage "${HOMEPAGE_URL}"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :${MIN_MACOS}"

  app "${APP_BUNDLE_NAME}"

  zap trash: [
    "~/Library/Application Support/${APP_SUPPORT_DIR}",
    "~/Library/Preferences/${BUNDLE_IDENTIFIER}.plist",
    "~/Library/Saved Application State/${BUNDLE_IDENTIFIER}.savedState",
  ]
end
EOF
