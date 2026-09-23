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

# macOS ties the Screen Recording grant to the signature. An ad-hoc signature
# is just the build's hash, so every rebuild loses the grant; a certificate
# keeps it. Uses SIGN_IDENTITY, else the keychain's first code-signing identity.
identity=${SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
  | awk 'NR == 1 && $2 ~ /^[0-9A-F]+$/ && length($2) == 40 { print $2 }')}
if [[ -z $identity ]]; then
  echo "No code-signing identity found: signing ad-hoc, so macOS will ask for"
  echo "Screen Recording permission again after every rebuild."
fi
codesign --force --sign "${identity:--}" "$APP"

echo "Built $APP"
echo "Run it with: open $APP"
