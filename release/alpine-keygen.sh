#!/usr/bin/env bash
# The fork's Alpine signing key (root T23): what abuild-keygen does, run by
# hand, once. An RSA private key in PEM PKCS#8 (what dir2apk.go reads) and
# its public half, named <prefix>-<hex epoch seconds>.rsa and .rsa.pub, in
# DIR, never inside a git work tree. Idempotent: an existing pair is checked
# and reported, never replaced; a new key only with --new. The private key
# is never printed. Needs OpenSSL 3 (the dev shell's): LibreSSL has no
# `pkey -check`.
# Usage: alpine-keygen.sh [--new] [PREFIX [DIR]]  (pr0d1r2, ~/.abuild)
# ALPINE_KEYGEN_BITS sets the size (tests); ALPINE_KEYGEN_GH=0 skips gh.
set -euo pipefail
umask 077

repo=pr0d1r2/age-plugin-se
fail() {
	printf 'alpine-keygen: %s\n' "$@" >&2
	exit 1
}

new=0
if [ "${1:-}" = --new ]; then
	new=1
	shift
fi
[ $# -le 2 ] || fail "usage: alpine-keygen.sh [--new] [PREFIX [DIR]]"
prefix=${1:-pr0d1r2}
dir=${2:-$HOME/.abuild}
bits=${ALPINE_KEYGEN_BITS:-4096}

openssl version 2>/dev/null | grep -q '^OpenSSL 3' ||
	fail "needs OpenSSL 3 for \`openssl pkey -check\`; run it in the dev shell: nix develop -c $0"

# The nearest directory that exists decides whether DIR is in a work tree,
# before anything is created. GIT_DIR and friends, as a git hook exports
# them, would name another repository than DIR's own, so they go.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_PREFIX
probe=$dir
while [ ! -d "$probe" ]; do probe=$(dirname "$probe"); done
if [ "$(git -C "$probe" rev-parse --is-inside-work-tree 2>/dev/null)" = true ] ||
	[ "$(git -C "$probe" rev-parse --is-inside-git-dir 2>/dev/null)" = true ]; then
	fail "$dir is inside a git work tree; a private key there is one \`git add\` from a commit" \
		"pick a directory outside any repository, such as ~/.abuild"
fi

# The PKCS#8 header, split so the repository's no-private-key step does not
# take this script for a key.
header="-----BEGIN PRIVATE"" KEY-----"
check_private() {
	[ "$(head -n 1 "$1")" = "$header" ] ||
		fail "$1 is not a PEM PKCS#8 private key, which dir2apk.go needs; nothing changed"
	openssl pkey -in "$1" -check -noout >/dev/null 2>&1 ||
		fail "$1 fails \`openssl pkey -check\`; nothing changed"
}

next_steps() {
	local key=$1 pub=$2
	cat <<EOF

NEXT STEPS
1. gh secret set ALPINE_KEY -R $repo < $key
2. Back up $key in your secrets store, then delete the loose file
(rm -P on macOS, shred -u elsewhere). Leaked, anyone signs as the fork;
lost, every user must trust a new key.
3. Commit $pub into the fork as release/keys/$(basename "$pub");
users install it into /etc/apk/keys/.
4. Upstream build.yml still writes ALPINE_KEY to upstream's hard-coded key
filename, so \`Package (Alpine)\` mislabels or fails until a fork
packaging script calls \`dir2apk.go --key=$(basename "$key")\`, or an
upstream PR (owner approval) makes the path a variable: root T23.
EOF
	if [ "${ALPINE_KEYGEN_GH:-1}" != 0 ] && command -v gh >/dev/null 2>&1 &&
		gh auth status >/dev/null 2>&1; then
		if gh secret list -R "$repo" 2>/dev/null | grep -q '^ALPINE_KEY[[:space:]]'; then
			printf '\nALPINE_KEY is already set on %s; step 1 replaces it.\n' "$repo"
		else
			printf '\nALPINE_KEY is not set on %s yet.\n' "$repo"
		fi
	fi
}

shopt -s nullglob
keys=("$dir/$prefix"-*.rsa)
pubs=("$dir/$prefix"-*.rsa.pub)
shopt -u nullglob

if [ "$new" = 0 ]; then
	if [ ${#keys[@]} -gt 1 ]; then
		fail "more than one $prefix key in $dir; keep one, or name it in a DIR of its own:" "${keys[@]}"
	fi
	if [ ${#keys[@]} -eq 1 ]; then
		key=${keys[0]}
		pub=$key.pub
		check_private "$key"
		if [ -e "$pub" ]; then
			[ "$(openssl pkey -in "$key" -pubout)" = "$(cat "$pub")" ] ||
				fail "$pub does not match $key; nothing changed"
			echo "alpine-keygen: key exists, nothing created: $key"
		else
			openssl pkey -in "$key" -pubout -out "$pub"
			chmod 644 "$pub"
			echo "alpine-keygen: key exists; derived its missing public half again: $pub"
		fi
		next_steps "$key" "$pub"
		exit 0
	fi
	if [ ${#pubs[@]} -gt 0 ]; then
		fail "the private half is lost: only ${pubs[*]} is in $dir" \
			"restore the private key from your backup; to make a new key on purpose, pass --new"
	fi
fi

key=$dir/$prefix-$(printf '%x' "$(date +%s)").rsa
pub=$key.pub
[ ! -e "$key" ] && [ ! -e "$pub" ] || fail "$key or $pub exists; wait a second and run it again"
mkdir -p "$dir"
openssl genpkey -algorithm RSA -pkeyopt "rsa_keygen_bits:$bits" -out "$key" 2>/dev/null
openssl pkey -in "$key" -pubout -out "$pub"
chmod 644 "$pub"
check_private "$key"
echo "alpine-keygen: made $key and $pub"
next_steps "$key" "$pub"
