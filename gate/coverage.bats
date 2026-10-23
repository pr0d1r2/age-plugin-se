#!/usr/bin/env bats
# gate/coverage.sh (root V10), on fake `sherd` and `sw_vers`: below
# macOS 26 the ratchet skips with a notice; on 26 and later it runs
# `sherd coverage --check` and passes on its verdict.

setup() {
	check="$BATS_TEST_DIRNAME/coverage.sh"
	bin="$BATS_TEST_TMPDIR/bin"
	mkdir -p "$bin"
	PATH="$bin:$PATH"
	unset AGE_PLUGIN_SE_MACOS_MAJOR
	sherd 0
	sw_vers 26.6.2
}

sherd() { # sherd <exit status>: records its arguments, exits with it
	printf '#!/bin/sh\necho "sherd $*"\nexit %s\n' "$1" >"$bin/sherd"
	chmod +x "$bin/sherd"
}

sw_vers() { # sw_vers <productVersion>
	printf '#!/bin/sh\n[ "$1" = -productVersion ] || exit 2\necho "%s"\n' "$1" >"$bin/sw_vers"
	chmod +x "$bin/sw_vers"
}

@test "macOS 26 runs sherd coverage --check" {
	run "$check"
	[ "$status" -eq 0 ]
	[ "$output" = "sherd coverage --check" ]
}

@test "macOS 26 fails when sherd finds coverage below the floor" {
	sherd 1
	run "$check"
	[ "$status" -eq 1 ]
	[ "$output" = "sherd coverage --check" ]
}

@test "a later macOS still runs the ratchet" {
	sw_vers 27.0
	run "$check"
	[ "$status" -eq 0 ]
	[ "$output" = "sherd coverage --check" ]
}

@test "macOS 15 skips with the notice and never runs sherd" {
	sherd 1
	sw_vers 15.6.1
	run "$check"
	[ "$status" -eq 0 ]
	[ "$output" = "coverage: macOS 15 < 26, post-quantum code cannot run here; CI and macOS 26 hosts hold the floor (root V10)" ]
}

@test "a version with no minor part is read as its major" {
	sherd 1
	sw_vers 14
	run "$check"
	[ "$status" -eq 0 ]
	[[ "$output" == "coverage: macOS 14 < 26"* ]]
}

@test "AGE_PLUGIN_SE_MACOS_MAJOR overrides the host" {
	sherd 1
	AGE_PLUGIN_SE_MACOS_MAJOR=15 run "$check"
	[ "$status" -eq 0 ]
	[[ "$output" == "coverage: macOS 15 < 26"* ]]
}

@test "AGE_PLUGIN_SE_MACOS_MAJOR=26 runs the ratchet on an older host" {
	sw_vers 15.6.1
	AGE_PLUGIN_SE_MACOS_MAJOR=26 run "$check"
	[ "$status" -eq 0 ]
	[ "$output" = "sherd coverage --check" ]
}

@test "a version that is not a number is refused" {
	AGE_PLUGIN_SE_MACOS_MAJOR=x run "$check"
	[ "$status" -eq 1 ]
	[[ "$output" == *"macOS major version 'x' is not a number"* ]]
}

@test "an unreadable version is refused, never skipped" {
	printf '#!/bin/sh\nexit 1\n' >"$bin/sw_vers"
	run "$check"
	[ "$status" -eq 1 ]
	[[ "$output" == *"sw_vers could not read the macOS version"* ]]
}

@test "macOS 26 with no sherd on PATH is a missing tool" {
	rm "$bin/sherd"
	PATH="$bin:/usr/bin:/bin" run "$check"
	[ "$status" -eq 1 ]
	[[ "$output" == *"sherd is not on PATH"* ]]
}

@test "macOS 15 needs no sherd" {
	rm "$bin/sherd"
	sw_vers 15.6.1
	PATH="$bin:/usr/bin:/bin" run "$check"
	[ "$status" -eq 0 ]
	[[ "$output" == "coverage: macOS 15 < 26"* ]]
}

@test "an argument is refused" {
	run "$check" extra
	[ "$status" -eq 1 ]
	[[ "$output" == *"usage: coverage.sh"* ]]
}
