#!/usr/bin/env bash
# Planted runs for the toolchain guard (nix T1): the host toolchain passes,
# and an old Swift, a missing XCTest and a missing swift are each refused
# with a message naming the piece and decision 21. Fakes are put first on
# PATH; the real `swift` and `xcrun` are used for everything else.
set -euo pipefail

guard="${1:-$(cd "$(dirname "$0")" && pwd)/toolchain.sh}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fake() { # fake <dir> <name> <body>
	mkdir -p "$1"
	printf '#!/bin/sh\n%s\n' "$3" >"$1/$2"
	chmod +x "$1/$2"
}

expect_refusal() { # expect_refusal <label> <needle> <PATH>
	local out
	if out=$(PATH="$3" "$BASH" "$guard" 2>&1); then
		printf 'toolchain-test: %s: guard passed, expected a refusal\n' "$1" >&2
		exit 1
	fi
	case "$out" in *"$2"*) ;; *)
		printf 'toolchain-test: %s: refusal does not name %s:\n%s\n' "$1" "$2" "$out" >&2
		exit 1
		;;
	esac
	case "$out" in *"decision 21"*) ;; *)
		printf 'toolchain-test: %s: refusal does not name decision 21:\n%s\n' "$1" "$out" >&2
		exit 1
		;;
	esac
	printf 'toolchain-test: %s: refused\n' "$1"
}

"$guard" >/dev/null
printf 'toolchain-test: host toolchain: passed\n'

fake "$work/old" swift 'echo "Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2 clang-1700.0.13.5)"'
expect_refusal "Swift 6.1" "older than 6.2" "$work/old:$PATH"

fake "$work/noxct" xcrun 'exit 1'
expect_refusal "no XCTest" "XCTest is missing" "$work/noxct:$PATH"

mkdir -p "$work/empty"
expect_refusal "no swift" "no swift on PATH" "$work/empty"
