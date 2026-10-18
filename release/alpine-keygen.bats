#!/usr/bin/env bats
# release/alpine-keygen.sh (root T23): every key here is a throwaway made in
# a temp dir outside git, at 1024 bits so the tests stay quick; the default
# size is checked once. gh is off, so the tests stay offline.

setup() {
	keygen="$BATS_TEST_DIRNAME/alpine-keygen.sh"
	out="$BATS_TEST_TMPDIR/keys"
	export ALPINE_KEYGEN_BITS=1024 ALPINE_KEYGEN_GH=0
	cd "$BATS_TEST_TMPDIR"
}

# The one key pair in $out, as $key and $pub.
pair() {
	key=$(ls "$out"/test-*.rsa)
	pub="$key.pub"
}

fingerprint() {
	for f in "$@"; do
		printf '%s %s\n' "$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")" "$(shasum -a 256 <"$f")"
	done
}

@test "makes a PKCS#8 RSA pair named prefix-hex-epoch, private half 0600" {
	run "$keygen" test "$out"
	[ "$status" -eq 0 ]
	pair
	[[ "$(basename "$key")" =~ ^test-[0-9a-f]+\.rsa$ ]]
	# The PKCS#8 header, split so the no-private-key step does not see one.
	[ "$(head -1 "$key")" = "-----BEGIN PRIVATE"" KEY-----" ]
	openssl pkey -in "$key" -check -noout
	[ "$(openssl pkey -in "$key" -pubout)" = "$(cat "$pub")" ]
	[ "$(stat -c %a "$key" 2>/dev/null || stat -f %Lp "$key")" = 600 ]
}

@test "the default key is 4096 bits" {
	unset ALPINE_KEYGEN_BITS
	run "$keygen" test "$out"
	[ "$status" -eq 0 ]
	pair
	openssl pkey -in "$key" -noout -text | grep -q 'Private-Key: (4096 bit'
}

@test "prints the next steps naming the files, never the private key" {
	run "$keygen" test "$out"
	[ "$status" -eq 0 ]
	pair
	[[ "$output" == *"gh secret set ALPINE_KEY -R pr0d1r2/age-plugin-se < $key"* ]]
	[[ "$output" == *"release/keys/$(basename "$pub")"* ]]
	[[ "$output" == *"T23"* ]]
	[[ "$output" != *"PRIVATE KEY"* ]]
	[[ "$output" != *"$(sed -n 2p "$key")"* ]]
}

@test "refuses an output dir inside a git work tree and writes nothing" {
	git init -q repo
	run "$keygen" test repo/keys
	[ "$status" -eq 1 ]
	[[ "$output" == *"git work tree"* ]]
	[ ! -e repo/keys ]
}

@test "a second run creates nothing and leaves the pair byte for byte" {
	"$keygen" test "$out"
	pair
	before=$(fingerprint "$key" "$pub")
	sleep 1
	run "$keygen" test "$out"
	[ "$status" -eq 0 ]
	[[ "$output" == *"key exists, nothing created"* ]]
	[[ "$output" == *"< $key"* ]]
	[ "$(fingerprint "$key" "$pub")" = "$before" ]
	[ "$(ls "$out" | wc -l | tr -d ' ')" -eq 2 ]
}

@test "a missing public half is derived again from the private key" {
	"$keygen" test "$out"
	pair
	want=$(cat "$pub")
	rm "$pub"
	run "$keygen" test "$out"
	[ "$status" -eq 0 ]
	[ "$(cat "$pub")" = "$want" ]
	[ "$(ls "$out" | wc -l | tr -d ' ')" -eq 2 ]
}

@test "a missing private half fails and makes no new key" {
	"$keygen" test "$out"
	pair
	rm "$key"
	run "$keygen" test "$out"
	[ "$status" -eq 1 ]
	[[ "$output" == *"private half is lost"* ]]
	[[ "$output" == *"--new"* ]]
	[ "$(ls "$out")" = "$(basename "$pub")" ]
}

@test "more than one key fails and lists them" {
	"$keygen" test "$out"
	sleep 1
	"$keygen" --new test "$out"
	run "$keygen" test "$out"
	[ "$status" -eq 1 ]
	[[ "$output" == *"more than one"* ]]
	for k in "$out"/test-*.rsa; do [[ "$output" == *"$k"* ]]; done
}

@test "a mismatched pair fails and changes nothing" {
	"$keygen" test "$out"
	pair
	openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:1024 2>/dev/null | openssl pkey -pubout >"$pub"
	before=$(fingerprint "$key" "$pub")
	run "$keygen" test "$out"
	[ "$status" -eq 1 ]
	[[ "$output" == *"does not match"* ]]
	[ "$(fingerprint "$key" "$pub")" = "$before" ]
}

@test "a private key that is not PKCS#8 fails and changes nothing" {
	mkdir -p "$out"
	openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:1024 2>/dev/null | openssl pkey -traditional >"$out/test-1.rsa"
	before=$(fingerprint "$out/test-1.rsa")
	run "$keygen" test "$out"
	[ "$status" -eq 1 ]
	[[ "$output" == *"PKCS#8"* ]]
	[ "$(fingerprint "$out/test-1.rsa")" = "$before" ]
	[ ! -e "$out/test-1.rsa.pub" ]
}

@test "--new makes a second key on purpose" {
	"$keygen" test "$out"
	sleep 1
	run "$keygen" --new test "$out"
	[ "$status" -eq 0 ]
	[ "$(ls "$out"/test-*.rsa | wc -l | tr -d ' ')" -eq 2 ]
	[ "$(ls "$out"/test-*.rsa.pub | wc -l | tr -d ' ')" -eq 2 ]
}
