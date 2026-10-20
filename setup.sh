#!/bin/zsh
# Generates Blocker.xcodeproj from project.yml and opens it.
#   ./setup.sh          generate + open Xcode
#   ./setup.sh check    generate + compile iOS and macOS without signing (logs in build-logs/)
#   ./setup.sh test     run the BlockerCore unit tests
set -e
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  if [ -x tools/.bin/xcodegen/bin/xcodegen ]; then
    export PATH="$PWD/tools/.bin/xcodegen/bin:$PATH"
  elif command -v brew >/dev/null 2>&1; then
    echo "Installing XcodeGen with Homebrew…"
    brew install xcodegen
  else
    echo "Downloading XcodeGen…"
    mkdir -p tools/.bin
    curl -fsSL -o tools/.bin/xcodegen.zip https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip
    unzip -oq tools/.bin/xcodegen.zip -d tools/.bin
    export PATH="$PWD/tools/.bin/xcodegen/bin:$PATH"
  fi
fi

xcodegen generate

# Free "Personal Team" accounts can't use iCloud. `./setup.sh free` removes the iCloud
# entitlement so the app can be signed and run; sync stays off until you join the
# paid Apple Developer Program (then just run ./setup.sh again).
if [ "$1" = "free" ]; then
  for f in Config/App-iOS.entitlements Config/App-macOS.entitlements; do
    /usr/libexec/PlistBuddy -c "Delete :com.apple.developer.ubiquity-kvstore-identifier" "$f" 2>/dev/null || true
  done
  echo "Free-team mode: iCloud sync switched off for this build."
fi

case "$1" in
  check)
    mkdir -p build-logs
    echo "Building macOS…"
    xcodebuild -project Blocker.xcodeproj -scheme Blocker-macOS -destination 'generic/platform=macOS' \
      -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build > build-logs/macos.log 2>&1 \
      && echo "macOS: BUILD SUCCEEDED" || echo "macOS: BUILD FAILED (see build-logs/macos.log)"
    echo "Building iOS…"
    xcodebuild -project Blocker.xcodeproj -scheme Blocker-iOS -destination 'generic/platform=iOS' \
      -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build > build-logs/ios.log 2>&1 \
      && echo "iOS: BUILD SUCCEEDED" || echo "iOS: BUILD FAILED (see build-logs/ios.log)"
    grep -E "error:|warning:" build-logs/*.log | grep -v "/build/dd/" | sort -u > build-logs/summary.txt || true
    echo "Done. Errors/warnings: build-logs/summary.txt"
    ;;
  test)
    mkdir -p build-logs
    (cd Packages/BlockerCore && swift test) > build-logs/core-tests.log 2>&1 \
      && echo "Core tests: PASSED" || echo "Core tests: FAILED (see build-logs/core-tests.log)"
    ;;
  *)
    open Blocker.xcodeproj
    ;;
esac
