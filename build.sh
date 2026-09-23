#!/bin/zsh
# Builds PortionRecord.app into dist/.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="dist/PortionRecord.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/PortionRecord "$APP/Contents/MacOS/PortionRecord"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc signature keeps the Screen Recording permission grant stable
# across rebuilds.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run it with: open $APP"
