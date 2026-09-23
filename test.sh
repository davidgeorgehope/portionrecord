#!/bin/zsh
# Runs the unit tests.
set -euo pipefail
cd "$(dirname "$0")"

# With only the Command Line Tools installed, SwiftPM doesn't add the search
# paths Swift Testing lives in, so pass them explicitly.
if [[ "$(xcode-select -p)" == /Library/Developer/CommandLineTools ]]; then
  dev=/Library/Developer/CommandLineTools/Library/Developer
  swift test -Xswiftc -F -Xswiftc "$dev/Frameworks" \
    -Xlinker -rpath -Xlinker "$dev/Frameworks" \
    -Xlinker -rpath -Xlinker "$dev/usr/lib" "$@"
else
  swift test "$@"
fi
