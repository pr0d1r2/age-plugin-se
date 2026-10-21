# shellcheck shell=bash
# Sourced by the dev shell on entry (nix/shell.nix). nix's darwin stdenv
# points DEVELOPER_DIR and SDKROOT at its own apple-sdk, which has no Swift 6.2
# and no XCTest, and sets MACOSX_DEPLOYMENT_TARGET to its clang default, not
# this package's `.macOS(.v14)`. So the host Xcode is put back and the other
# two are dropped (decisions 11 and 21), then the
# guard, passed as $1, runs (nix V1). The host Xcode is HOST_DEVELOPER_DIR
# when set: the fork CI pins an Xcode through DEVELOPER_DIR, which the stdenv
# overwrites before this hook runs, so the CI command hands it over under
# this name (root T14). Otherwise it is `xcode-select -p`, which echoes
# DEVELOPER_DIR when set, hence `env -u`. A refusal fails the entry:
# `nix develop` exits and direnv reports the error.
case "${DEVELOPER_DIR:-}" in
"" | /nix/store/*)
	DEVELOPER_DIR=${HOST_DEVELOPER_DIR:-$(/usr/bin/env -u DEVELOPER_DIR /usr/bin/xcode-select -p)}
	;;
esac
export DEVELOPER_DIR
unset SDKROOT MACOSX_DEPLOYMENT_TARGET
"$1" || return 1
