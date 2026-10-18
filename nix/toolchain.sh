#!/usr/bin/env bash
# Host-toolchain guard (nix V1, root V6). Swift, the macOS SDK and XCTest come
# from the host Xcode (decisions 11 and 21), so nix cannot promise them; this
# refuses before any build, test or shell instead of letting `--pq` quietly
# become `pqUnavailable` (Swift < 6.2) or `swift test` fail on a missing
# `XCTest` module. It reads `swift` and `xcrun` from PATH and honours
# DEVELOPER_DIR as they do.
set -euo pipefail

min_major=6
min_minor=2

refuse() {
	printf 'toolchain: %s\n' "$1" >&2
	printf 'toolchain: install Xcode machine-wide and point DEVELOPER_DIR (or xcode-select) at it (decision 21)\n' >&2
	exit 1
}

command -v swift >/dev/null 2>&1 || refuse "no swift on PATH; Swift ${min_major}.${min_minor} or newer is needed"

version_line=$(swift --version 2>&1 | grep -m1 'Swift version' || true)
version=$(printf '%s\n' "$version_line" | sed -n 's/.*Swift version \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')
[ -n "$version" ] || refuse "cannot read the Swift version from \`swift --version\`"

major=${version%%.*}
minor=${version#*.}
if [ "$major" -lt "$min_major" ] || { [ "$major" -eq "$min_major" ] && [ "$minor" -lt "$min_minor" ]; }; then
	refuse "Swift $version is older than ${min_major}.${min_minor}, so \`--pq\` would build as \`pqUnavailable\` (root V6)"
fi

xcrun --find xctest >/dev/null 2>&1 ||
	refuse "XCTest is missing (\`xcrun --find xctest\` failed, DEVELOPER_DIR=${DEVELOPER_DIR:-unset}); Command Line Tools ship no XCTest"

printf 'toolchain: Swift %s, XCTest found\n' "$version"
