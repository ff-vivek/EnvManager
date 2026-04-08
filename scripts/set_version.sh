#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/EnvManager.xcodeproj/project.pbxproj"

VERSION=""
BUILD_NUMBER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --build)
      BUILD_NUMBER="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" && -z "$BUILD_NUMBER" ]]; then
  echo "Usage: $0 [--version 1.2.3] [--build 42]" >&2
  exit 1
fi

if [[ -n "$VERSION" && ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Version must look like 1.2 or 1.2.3, got: $VERSION" >&2
  exit 1
fi

if [[ -n "$BUILD_NUMBER" && ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Build number must be numeric, got: $BUILD_NUMBER" >&2
  exit 1
fi

if [[ -n "$VERSION" ]]; then
  VERSION="$VERSION" /usr/bin/perl -0pi -e 's/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $ENV{VERSION};/g' "$PROJECT_FILE"
fi

if [[ -n "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="$BUILD_NUMBER" /usr/bin/perl -0pi -e 's/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $ENV{BUILD_NUMBER};/g' "$PROJECT_FILE"
fi

echo "Updated project version settings in $PROJECT_FILE"
if [[ -n "$VERSION" ]]; then
  echo "  MARKETING_VERSION=$VERSION"
fi
if [[ -n "$BUILD_NUMBER" ]]; then
  echo "  CURRENT_PROJECT_VERSION=$BUILD_NUMBER"
fi
