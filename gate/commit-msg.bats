#!/usr/bin/env bats
# gate/commit-msg.sh (paradigm/V27, V36, V43).

setup() {
	check="$BATS_TEST_DIRNAME/commit-msg.sh"
	msg="$BATS_TEST_TMPDIR/msg"
}

@test "a cited id and a parsed stage trailer pass" {
	printf 'ci(x): add x (T6)\n\nWhy.\n\nParadigm-Stage: guardrails\nCo-Authored-By: A <a@example.com>\n' >"$msg"
	run "$check" "$msg"
	[ "$status" -eq 0 ]
}

@test "ids cited as node:id or paradigm/id count" {
	printf 'docs: x\n\nServes nix:V2 and paradigm/V43.\n\nParadigm-Stage: wave-2\n' >"$msg"
	run "$check" "$msg"
	[ "$status" -eq 0 ]
}

@test "a stage line split off by a blank line is no trailer" {
	printf 'ci(x): add x (T6)\n\nParadigm-Stage: guardrails\n\nCo-Authored-By: A <a@example.com>\n' >"$msg"
	run "$check" "$msg"
	[ "$status" -eq 1 ]
	[[ "$output" == *"no \`Paradigm-Stage:\` trailer git can parse"* ]]
}

@test "a stage outside the vocabulary is refused" {
	printf 'ci(x): add x (T6)\n\nParadigm-Stage: polishing\n' >"$msg"
	run "$check" "$msg"
	[ "$status" -eq 1 ]
	[[ "$output" == *"is not a stage"* ]]
	printf 'ci(x): add x (T6)\n\nParadigm-Stage: wave-x\n' >"$msg"
	run "$check" "$msg"
	[ "$status" -eq 1 ]
}

@test "a message citing no id is refused, and comments do not count" {
	printf 'ci(x): add x\n\nNo id here.\n# T6 only in a comment\n\nParadigm-Stage: guardrails\n' >"$msg"
	run "$check" "$msg"
	[ "$status" -eq 1 ]
	[[ "$output" == *"cite the T, V or B id"* ]]
}

@test "the diff below the scissors line is not the message" {
	printf 'ci(x): add x\n\nParadigm-Stage: guardrails\n# ------------------------ >8 ------------------------\n+T6 in the diff\n' >"$msg"
	run "$check" "$msg"
	[ "$status" -eq 1 ]
}

@test "git's own merge subjects pass" {
	printf 'Merge pull request #9 from x/y\n' >"$msg"
	run "$check" "$msg"
	[ "$status" -eq 0 ]
}
