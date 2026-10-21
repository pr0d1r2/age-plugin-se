#!/usr/bin/env bash
# The one test command (nix V2): checks.<system>.tests and the gate's
# pre-push `test` step (root T6) both run this, so they cannot drift. The
# arguments are the swift to run: plain `swift` in the dev shell, whose
# entry put the host Xcode on PATH (nix V1), or nix/swift.sh's wrapper
# inside a nix build. `--disable-sandbox` because SwiftPM's sandbox cannot
# nest in a nix build; the pins are Package.resolved's and only those.
set -euo pipefail

[ "$#" -gt 0 ] || {
	echo 'test.sh: usage: test.sh <swift command...>' >&2
	exit 2
}
exec "$@" test --disable-sandbox --only-use-versions-from-resolved-file
