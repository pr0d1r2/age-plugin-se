#!/usr/bin/env bash
# SwiftPM inside a nix build (nix/package.nix, nix/checks.nix): put the host
# Xcode back over the stdenv's apple-sdk, run the guard (nix V1), point each
# Package.resolved pin at its vendored checkout, then run swift with the
# remaining arguments. Usage: swift.sh <guard> <mirrors> <swift args...>,
# where <mirrors> holds one "<original url> <mirror url>" pair per line.
set -euo pipefail

guard=$1
mirrors=$2
shift 2

export HOME=${TMPDIR:-/tmp}
DEVELOPER_DIR=$(/usr/bin/env -u DEVELOPER_DIR /usr/bin/xcode-select -p)
export DEVELOPER_DIR
unset SDKROOT MACOSX_DEPLOYMENT_TARGET
export PATH="$PATH:/usr/bin"

"$guard" >&2

# SwiftPM's user-level state defaults to the build user's home, which a nix
# build cannot write.
state="$HOME/swiftpm"
paths=(--cache-path "$state/cache" --config-path "$state/config" --security-path "$state/security")

while read -r original mirror; do
	[ -n "$original" ] || continue
	swift package "${paths[@]}" config set-mirror --original "$original" --mirror "$mirror" >&2
done <"$mirrors"

exec swift "$@" "${paths[@]}"
