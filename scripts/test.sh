#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# With a full Xcode install, plain `swift test` works as-is. With only the
# Apple Command Line Tools, Swift Testing ships as a framework the compiler
# does not search by default, and the _Testing_Foundation cross-import
# overlay ships without Swift module interfaces, so the paths are passed
# explicitly and cross-import overlays are disabled.

CLT_DIR="/Library/Developer/CommandLineTools"
CLT_FRAMEWORKS="$CLT_DIR/Library/Developer/Frameworks"
CLT_TESTING_PLUGIN="$CLT_DIR/usr/lib/swift/host/plugins/testing"

if [[ "$(xcode-select -p 2>/dev/null)" == "$CLT_DIR" && -d "$CLT_FRAMEWORKS/Testing.framework" ]]; then
    exec swift test \
        -Xswiftc -F -Xswiftc "$CLT_FRAMEWORKS" \
        -Xswiftc -plugin-path -Xswiftc "$CLT_TESTING_PLUGIN" \
        -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
        -Xlinker -F -Xlinker "$CLT_FRAMEWORKS" \
        -Xlinker -rpath -Xlinker "$CLT_FRAMEWORKS" \
        "$@"
fi

exec swift test "$@"
