#!/usr/bin/env bash
# Local build script (run on macOS).
# Requirements: Xcode 15+, Homebrew, XcodeGen (`brew install xcodegen`).

set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen not found. Install with: brew install xcodegen"
  exit 1
fi

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Building for iOS Simulator (unsigned)..."
xcodebuild \
  -project MuleHazardMap.xcodeproj \
  -scheme MuleHazardMap \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "==> Build finished. Open Xcode with:"
echo "    open MuleHazardMap.xcodeproj"
