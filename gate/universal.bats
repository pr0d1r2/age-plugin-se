#!/usr/bin/env bats
# gate/universal.sh (root T30, V6), on fake `lipo` and `vtool`: the
# verdict on a given binary, not the build.

setup() {
	check="$BATS_TEST_DIRNAME/universal.sh"
	bin="$BATS_TEST_TMPDIR/bin"
	mkdir -p "$bin"
	binary="$BATS_TEST_TMPDIR/age-plugin-se"
	touch "$binary"
	PATH="$bin:$PATH"
}

fake() { # fake <archs> <arm64 minos> <x86_64 minos>
	printf '#!/bin/sh\necho "%s"\n' "$1" >"$bin/lipo"
	printf '#!/bin/sh\ncase "$2" in arm64) m=%s ;; *) m=%s ;; esac\nprintf "    minos %%s\\n      sdk 27.0\\n" "$m"\n' "$2" "$3" >"$bin/vtool"
	chmod +x "$bin/lipo" "$bin/vtool"
}

@test "two slices, each minos 14.0, pass" {
	fake "x86_64 arm64" 14.0 14.0
	run "$check" "$binary"
	[ "$status" -eq 0 ]
	[[ "$output" == *"holds arm64 x86_64, each minos 14.0"* ]]
}

@test "a missing x86_64 slice is refused" {
	fake "arm64" 14.0 14.0
	run "$check" "$binary"
	[ "$status" -eq 1 ]
	[[ "$output" == *"holds [arm64], expected [arm64 x86_64]"* ]]
}

@test "a third slice is refused" {
	fake "arm64 arm64e x86_64" 14.0 14.0
	run "$check" "$binary"
	[ "$status" -eq 1 ]
}

@test "a slice built for macOS 26 is refused" {
	fake "arm64 x86_64" 14.0 26.0
	run "$check" "$binary"
	[ "$status" -eq 1 ]
	[[ "$output" == *"x86_64 slice has minos 26.0, expected 14.0"* ]]
}

@test "UNIVERSAL_MINOS sets the expected minos" {
	fake "arm64 x86_64" 14.0 14.0
	UNIVERSAL_MINOS=26.0 run "$check" "$binary"
	[ "$status" -eq 1 ]
	[[ "$output" == *"arm64 slice has minos 14.0, expected 26.0"* ]]
}

@test "a missing binary is refused" {
	run "$check" "$BATS_TEST_TMPDIR/none"
	[ "$status" -eq 1 ]
	[[ "$output" == *"no binary at"* ]]
}
