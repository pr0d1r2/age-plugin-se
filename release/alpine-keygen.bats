#!/usr/bin/env bats
# release/alpine-keygen.sh (root T23): a throwaway CI-only Alpine signing
# key, straight into the ALPINE_KEY secret. Offline: a fake gh first on
# PATH logs its args and keeps the secret's state; it never stores the key,
# only its public half and a checksum. A logging openssl wraps the real one.
# Keys are 1024 bits here; the default 4096 is checked once.

setup() {
	keygen="$BATS_TEST_DIRNAME/alpine-keygen.sh"
	state="$BATS_TEST_TMPDIR/state"
	bin="$BATS_TEST_TMPDIR/bin"
	work="$BATS_TEST_TMPDIR/work"
	mkdir -p "$state" "$bin" "$work"
	# A git hook (pre-push) exports these for the repository under test;
	# left set, `git init` below would act on that repository.
	unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_PREFIX
	export ALPINE_KEYGEN_BITS=1024 ALPINE_KEYGEN_REPO=test/repo GH_FAKE_STATE="$state"
	real_openssl=$(command -v openssl)
	cat >"$bin/openssl" <<WRAP
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$state/openssl.log"
exec "$real_openssl" "\$@"
WRAP
	cat >"$bin/gh" <<'FAKE'
#!/usr/bin/env bash
s=$GH_FAKE_STATE
printf '%s\n' "$*" >>"$s/log"
case "$1 $2" in
"auth status") [ ! -e "$s/unauth" ] || { echo "not logged in" >&2; exit 1; } ;;
"secret list") [ ! -e "$s/secret" ] || printf 'ALPINE_KEY\t2026-10-18T00:00:00Z\n' ;;
"secret set")
	[ "$3 $4 $5" = "ALPINE_KEY -R test/repo" ] && [ $# -eq 5 ] || { echo "fake gh: unexpected $*" >&2; exit 2; }
	[ ! -e "$s/fail-set" ] || { echo "HTTP 403" >&2; exit 1; }
	in=$(cat)
	printf '%s\n' "$in" | openssl pkey -check -noout >/dev/null 2>&1 || { echo "fake gh: not a key" >&2; exit 3; }
	printf '%s\n' "$in" | head -n 1 >"$s/secret.head"
	printf '%s\n' "$in" | openssl pkey -pubout >"$s/secret.pub"
	printf '%s\n' "$in" | shasum -a 256 >"$s/secret"
	;;
*) echo "fake gh: unexpected $*" >&2; exit 2 ;;
esac
FAKE
	chmod +x "$bin/openssl" "$bin/gh"
	export PATH="$bin:$PATH"
	cd "$work"
}

# The PKCS#8 header, split so the no-private-key step does not see one.
header="-----BEGIN PRIVATE"" KEY-----"

@test "the first run sets ALPINE_KEY through gh's stdin, PKCS#8, and says what it is" {
	run "$keygen"
	[ "$status" -eq 0 ]
	grep -qx 'secret set ALPINE_KEY -R test/repo' "$state/log"
	[ "$(cat "$state/secret.head")" = "$header" ]
	[[ "$output" == *"throwaway"* ]]
	[[ "$output" == *"--rotate"* ]]
	[[ "$output" == *"build (macos-26)"* ]]
}

@test "no private key in any file, argv or output; the script writes no file" {
	run "$keygen"
	[ "$status" -eq 0 ]
	[ -z "$(ls -A "$work")" ]
	! grep -rqF "BEGIN PRIVATE" "$BATS_TEST_TMPDIR"
	! grep -qF "PRIVATE" "$state/log" "$state/openssl.log"
	[[ "$output" != *"PRIVATE"* ]]
	pub=$(sed -n 2p "$state/secret.pub")
	[[ "$output" != *"$pub"* ]]
}

@test "a second run does nothing" {
	"$keygen"
	before=$(cat "$state/secret")
	run "$keygen"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ALPINE_KEY set, nothing done"* ]]
	[ "$(grep -c '^secret set' "$state/log")" -eq 1 ]
	[ "$(grep -c '^genpkey' "$state/openssl.log")" -eq 1 ]
	[ "$(cat "$state/secret")" = "$before" ]
}

@test "--rotate sets a new key" {
	"$keygen"
	before=$(cat "$state/secret")
	run "$keygen" --rotate
	[ "$status" -eq 0 ]
	[ "$(grep -c '^secret set' "$state/log")" -eq 2 ]
	[ "$(cat "$state/secret")" != "$before" ]
}

@test "an unauthenticated gh fails before any key is made" {
	touch "$state/unauth"
	run "$keygen"
	[ "$status" -eq 1 ]
	[[ "$output" == *"gh auth login"* ]]
	[ ! -e "$state/openssl.log" ] || ! grep -q '^genpkey' "$state/openssl.log"
	! grep -q '^secret set' "$state/log"
}

@test "a failed gh secret set is reported, nothing written" {
	touch "$state/fail-set"
	run "$keygen"
	[ "$status" -eq 1 ]
	[[ "$output" == *"ALPINE_KEY was not set"* ]]
	[ -z "$(ls -A "$work")" ]
	[ ! -e "$state/secret" ]
}

@test "a hook's GIT_DIR and GIT_WORK_TREE change nothing" {
	git init -q "$BATS_TEST_TMPDIR/other"
	GIT_DIR="$BATS_TEST_TMPDIR/other/.git" GIT_WORK_TREE="$BATS_TEST_TMPDIR/other" run "$keygen"
	[ "$status" -eq 0 ]
	grep -qx 'secret set ALPINE_KEY -R test/repo' "$state/log"
	! git -C "$BATS_TEST_TMPDIR/other" config --local --get core.worktree
}

@test "the default key is 4096 bits" {
	unset ALPINE_KEYGEN_BITS
	run "$keygen"
	[ "$status" -eq 0 ]
	openssl pkey -pubin -in "$state/secret.pub" -noout -text | grep -q 'Public-Key: (4096 bit'
}
