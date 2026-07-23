#!/usr/bin/env bash
# Builds, signs, notarises, and staples a distributable Baud.app, then zips it.
#
# Requires a Developer ID Application certificate in your keychain and a notary
# credential profile. Fill scripts/notarize.env first (see notarize.env.example).
# This script is not run in CI here; it is the documented release path.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

env_file="scripts/notarize.env"
if [ ! -f "$env_file" ]; then
  echo "missing $env_file (copy scripts/notarize.env.example and fill it in)"
  exit 1
fi
# shellcheck disable=SC1090
source "$env_file"
: "${DEVELOPER_ID:?set DEVELOPER_ID in $env_file}"
: "${NOTARY_PROFILE:?set NOTARY_PROFILE in $env_file}"

build_dir="$root/build"
derived="$build_dir/DerivedData"
zip="$build_dir/Baud.zip"
rm -rf "$build_dir"
mkdir -p "$build_dir"

echo "Building Release, signed and hardened..."
xcodebuild \
  -project Baud.xcodeproj \
  -scheme Baud \
  -configuration Release \
  -derivedDataPath "$derived" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build

app="$derived/Build/Products/Release/Baud.app"

echo "Verifying signature..."
codesign --verify --strict --verbose=2 "$app"

echo "Zipping for notarisation..."
ditto -c -k --keepParent "$app" "$zip"

echo "Submitting to the notary service (this can take a few minutes)..."
xcrun notarytool submit "$zip" --keychain-profile "$NOTARY_PROFILE" --wait

echo "Stapling the ticket..."
xcrun stapler staple "$app"

echo "Re-zipping the stapled app..."
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"

echo ""
echo "Done. Upload this to a GitHub release:"
echo "  $zip"
echo "Cask sha256:"
shasum -a 256 "$zip"
