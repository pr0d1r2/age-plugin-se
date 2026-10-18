#!/usr/bin/env bash
# The commit message gate (root T6), the shell form of paradigm's `dev
# commit-msg`: the final paragraph holds a `Paradigm-Stage:` trailer git
# itself parses, naming a stage from paradigm §I.trailer (paradigm/V43,
# V36), and the subject or body cites a T, V or B id (paradigm/V27).
# Comment lines and everything below git's scissors line are not the
# message. Merge, revert, fixup! and squash! subjects are git's and pass.
# Usage: commit-msg.sh MESSAGE_FILE
set -euo pipefail

[ "$#" -eq 1 ] || {
	echo 'commit-msg: usage: commit-msg.sh MESSAGE_FILE' >&2
	exit 2
}

refuse() {
	printf 'commit-msg: %s\n' "$1" >&2
	exit 1
}

scissors='# ------------------------ >8 ------------------------'
kept=$(awk -v cut="$scissors" '$0 == cut { exit } !/^#/' "$1")

case "$kept" in "Merge "* | "Revert "* | "fixup! "* | "squash! "*) exit 0 ;; esac

stage=$(printf '%s\n' "$kept" | git interpret-trailers --parse | sed -n 's/^Paradigm-Stage: *//p' | head -n 1)
[ -n "$stage" ] ||
	refuse "no \`Paradigm-Stage:\` trailer git can parse: put it in the final paragraph, directly above Co-Authored-By, with no blank line between (paradigm/V43)"

case "$stage" in
intent | spec-run | dev-shell | guardrails | gate | release | backprop | propagation) ;;
gap-round-[1-9]* | ck-check-round-[1-9]* | wave-[1-9]* | reconcile-[1-9]*)
	[[ "$stage" =~ ^[a-z-]+-[1-9][0-9]*$ ]] || refuse "\`Paradigm-Stage: $stage\` is not a stage in paradigm §I.trailer"
	;;
*) refuse "\`Paradigm-Stage: $stage\` is not a stage in paradigm §I.trailer" ;;
esac

printf '%s\n' "$kept" | tr -c 'A-Za-z0-9' '\n' | grep -qE '^[TVB][0-9]+[a-z]*$' ||
	refuse 'cite the T, V or B id this commit serves, in the subject or body (paradigm/V27)'
