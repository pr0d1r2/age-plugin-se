#!/usr/bin/env bash
# Universal binary check (root T30, V6): a release `age-plugin-se` built
# for arm64 and for x86_64, joined by `lipo`, must hold exactly those two
# slices, each with `minos` 14.0, so one binary runs on an Apple silicon
# Mac and on an Intel Mac from macOS 14 on. Adapted from a fork's
# `verify-macos-deployment` Makefile target (docs/THIRD-PARTY-NOTICES.md).
# Either Mac can run it: each slice is built by `--arch`, never the host's
# default, and Xcode cross-builds the slice the host is not.
# Usage: universal.sh [BINARY]  checks BINARY instead of building one.
# UNIVERSAL_MINOS overrides the expected minos (a planted failure).
set -euo pipefail

minos=${UNIVERSAL_MINOS:-14.0}
archs="arm64 x86_64"

refuse() {
	printf 'universal: %s\n' "$1" >&2
	exit 1
}

[ "$#" -le 1 ] || refuse 'usage: universal.sh [BINARY]'

if [ "$#" -eq 1 ]; then
	binary=$1
else
	work=.build/tmp-universal
	rm -rf "$work"
	mkdir -p "$work"
	slices=()
	for arch in $archs; do
		swift build -c release -j 2 --arch "$arch" >&2
		bin=$(swift build -c release -j 2 --arch "$arch" --show-bin-path)
		cp "$bin/age-plugin-se" "$work/age-plugin-se-$arch"
		slices+=("$work/age-plugin-se-$arch")
	done
	binary=$work/age-plugin-se
	lipo -create "${slices[@]}" -output "$binary"
fi

[ -f "$binary" ] || refuse "no binary at $binary"

found=$(lipo -archs "$binary" | tr ' ' '\n' | sed '/^$/d' | sort | tr '\n' ' ')
[ "$found" = "$archs " ] || refuse "$binary holds [${found% }], expected [$archs]"

for arch in $archs; do
	got=$(vtool -arch "$arch" -show-build "$binary" | awk '/minos/ { print $2; exit }')
	[ "$got" = "$minos" ] || refuse "$binary $arch slice has minos ${got:-none}, expected $minos (root V6)"
done

printf 'universal: %s holds %s, each minos %s\n' "$binary" "$archs" "$minos"
