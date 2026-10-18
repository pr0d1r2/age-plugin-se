#!/usr/bin/env bats
# gate/names.sh (paradigm/V37): the planted names here are made up.

setup() {
	names="$BATS_TEST_DIRNAME/names.sh"
	cd "$BATS_TEST_TMPDIR"
	printf '# a comment, not an entry\n\nzorblax\n  Quuxcorp  \n' >denylist
	export NAMES_DENYLIST="$BATS_TEST_TMPDIR/denylist"
}

@test "clean files pass" {
	printf 'nothing to see\n' >clean.txt
	run "$names" clean.txt
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "a listed name is refused by entry number, never by name" {
	printf 'line one\nwe ship to quuxcorp now\n' >leak.txt
	run "$names" leak.txt
	[ "$status" -eq 1 ]
	[ "$output" = "names: leak.txt:2: private name (denylist entry 2)" ]
	[[ "$output" != *[Qq]uuxcorp* ]]
}

@test "names match case-insensitively and every hit is listed" {
	printf 'ZORBLAX\nzorBlax again\n' >a.txt
	printf 'Quuxcorp\n' >b.txt
	run "$names" a.txt b.txt
	[ "$status" -eq 1 ]
	[ "${#lines[@]}" -eq 3 ]
	[ "${lines[0]}" = "names: a.txt:1: private name (denylist entry 1)" ]
	[ "${lines[1]}" = "names: a.txt:2: private name (denylist entry 1)" ]
	[ "${lines[2]}" = "names: b.txt:1: private name (denylist entry 2)" ]
}

@test "a file that is gone or binary is skipped" {
	printf 'zorblax\0binary\n' >blob.bin
	run "$names" gone.txt blob.bin
	[ "$status" -eq 0 ]
}

@test "without a denylist it says so and passes" {
	export NAMES_DENYLIST="$BATS_TEST_TMPDIR/absent"
	printf 'zorblax\n' >leak.txt
	run "$names" leak.txt
	[ "$status" -eq 0 ]
	[[ "$output" == *"no private name was checked"* ]]
}
