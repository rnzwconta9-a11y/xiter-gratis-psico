#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
command -v xcodebuild >/dev/null || { echo 'Esta compilação exige macOS com Xcode.' >&2; exit 1; }
command -v xcrun >/dev/null

build_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/rnzw-ios-build"
product_root="$build_root/Products"
package_root="$build_root/Package"
mkdir -p "$product_root" "$package_root/Payload"

xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
xcodebuild \
  -project ThreeOneOSFive.xcodeproj \
  -target 3105 \
  -configuration Release \
  -sdk iphoneos \
  -jobs 2 \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  CONFIGURATION_BUILD_DIR="$product_root" \
  build 2>&1 | tee "$build_root/xcodebuild.log"

app="$product_root/3105.app"
test -d "$app"
executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Info.plist")"
test -s "$app/$executable"
xcrun lipo "$app/$executable" -verify_arch arm64
display_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$app/Info.plist")"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")"
test "$display_name" = rnzwstore
test "$bundle_id" = com.apple.mobile.MobileHouseArrest
for resource in 144-fps aimhead-lock reset-guest; do
  test -s "$app/PanelPackages/$resource.3105"
done

# Only replace this script's previously generated staging directory.
if [[ -d "$package_root/Payload/3105.app" ]]; then
  rm -rf "$package_root/Payload/3105.app"
fi
ditto "$app" "$package_root/Payload/3105.app"
(
  cd "$package_root"
  ditto -c -k --keepParent Payload RNZW-unsigned.ipa
  unzip -t RNZW-unsigned.ipa
  shasum -a 256 RNZW-unsigned.ipa > RNZW-unsigned.ipa.sha256
)
printf 'IPA sem assinatura gerado em: %s\n' "$package_root/RNZW-unsigned.ipa"
