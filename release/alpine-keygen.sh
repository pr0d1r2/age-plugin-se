#!/usr/bin/env bash
# A throwaway, CI-only Alpine signing key (root T23): upstream build.yml's
# `Package (Alpine)` step needs the ALPINE_KEY secret to hold a PEM PKCS#8
# RSA private key, or the macOS 26 build fails. The packages it signs are
# run artifacts, never distributed, so the key is never kept: it is made in
# a shell variable, checked, and sent to `gh secret set` on stdin. No file,
# no argv, no output ever holds it. Idempotent: an existing ALPINE_KEY is
# left alone; --rotate replaces it.
# Usage: alpine-keygen.sh [--rotate]   (inside `nix develop`: OpenSSL 3)
# ALPINE_KEYGEN_REPO names the repository, ALPINE_KEYGEN_BITS the size
# (tests).
set -euo pipefail

# A git hook exports these for some repository; nothing here reads git, and
# nothing it runs should act on that repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_PREFIX

repo=${ALPINE_KEYGEN_REPO:-pr0d1r2/age-plugin-se}
bits=${ALPINE_KEYGEN_BITS:-4096}
fail() {
	printf 'alpine-keygen: %s\n' "$@" >&2
	exit 1
}

rotate=0
case "${1:-}" in
"") ;;
--rotate) rotate=1 ;;
*) fail "usage: alpine-keygen.sh [--rotate]" ;;
esac

command -v gh >/dev/null 2>&1 || fail "needs gh; run it in the dev shell: nix develop -c $0"
gh auth status >/dev/null 2>&1 || fail "gh is not signed in; run \`gh auth login\` first"
openssl version 2>/dev/null | grep -q '^OpenSSL 3' ||
	fail "needs OpenSSL 3 for \`openssl pkey -check\`; run it in the dev shell: nix develop -c $0"

secrets=$(gh secret list -R "$repo") || fail "cannot list the secrets of $repo"
if [ "$rotate" = 0 ] && printf '%s\n' "$secrets" | grep -q '^ALPINE_KEY[[:space:]]'; then
	echo "alpine-keygen: ALPINE_KEY set, nothing done ($repo); --rotate replaces it"
	exit 0
fi

# The PKCS#8 header, split so the repository's no-private-key step does not
# take this script for a key.
header="-----BEGIN PRIVATE"" KEY-----"
key=$(openssl genpkey -algorithm RSA -pkeyopt "rsa_keygen_bits:$bits" 2>/dev/null) ||
	fail "openssl genpkey failed; nothing was set"
[[ "$key" == "$header"* ]] || fail "the new key is not PEM PKCS#8; nothing was set"
printf '%s\n' "$key" | openssl pkey -check -noout >/dev/null 2>&1 ||
	fail "the new key fails \`openssl pkey -check\`; nothing was set"
if ! printf '%s\n' "$key" | gh secret set ALPINE_KEY -R "$repo" >/dev/null; then
	unset key
	fail "gh secret set failed: ALPINE_KEY was not set on $repo; it holds what it held before"
fi
unset key

cat <<EOF
alpine-keygen: ALPINE_KEY set on $repo.

It is a throwaway, CI-only signing key: it lives only in the secret, and
there is nothing to back up or commit. The Alpine packages it signs are
run artifacts, not for distribution. Run \`$0 --rotate\` any time
to replace it.

NEXT: re-run the failed \`build (macos-26)\` job, e.g.
gh run rerun <run-id> --failed -R $repo
EOF
