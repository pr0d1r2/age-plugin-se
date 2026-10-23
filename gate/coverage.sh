#!/usr/bin/env bash
# Coverage ratchet on this host (root V10): `sherd coverage --check`
# against `.coverage`, whose floor was measured on macOS 26, where the
# ML-KEM-768 code and its tests run. Below macOS 26 those tests skip
# (`@available(macOS 26)`), so the floor cannot hold there: this script
# skips with a notice instead, and CI and macOS 26 hosts hold the floor.
# AGE_PLUGIN_SE_MACOS_MAJOR overrides the host's major version (tests).
set -euo pipefail

floor_major=26

refuse() {
	printf 'coverage: %s\n' "$1" >&2
	exit 1
}

[ "$#" -eq 0 ] || refuse 'usage: coverage.sh'

if [ -n "${AGE_PLUGIN_SE_MACOS_MAJOR:-}" ]; then
	major=$AGE_PLUGIN_SE_MACOS_MAJOR
else
	version=$(sw_vers -productVersion) || refuse 'sw_vers could not read the macOS version'
	major=${version%%.*}
fi

[[ "$major" =~ ^[1-9][0-9]*$ ]] || refuse "macOS major version '$major' is not a number"

if [ "$major" -lt "$floor_major" ]; then
	printf 'coverage: macOS %s < %s, post-quantum code cannot run here; CI and macOS %s hosts hold the floor (root V10)\n' \
		"$major" "$floor_major" "$floor_major"
	exit 0
fi

command -v sherd >/dev/null 2>&1 || refuse 'sherd is not on PATH; re-enter the dev shell. A MISSING TOOL, not a finding.'
exec sherd coverage --check
