# Format-freeze fixtures

These files are the bytes the fork's format tests compare against (root
V1, V2): identities, recipients and recorded plugin sessions, made once by
the upstream plugin at two revisions. Every file here is append-only
(fixtures V2): it is never regenerated or edited. A new upstream revision
gets a new directory.

The keys are throwaway keys made for this corpus only, with
`--access-control none`, so no Touch ID or passcode guards them and they
guard nothing. A Secure Enclave identity file works only on the Mac that
made it, so publishing these is safe; they are still never reused.

## How they were made

- Date: 2026-10-18.
- Mac: `MacBookPro18,3`, macOS 26.6.2 (25G83), with a Secure Enclave.
- Toolchain: Xcode 27.1, Apple Swift 6.4 (`/usr/bin/swift`, outside the
  nix shell, with `DEVELOPER_DIR` and `SDKROOT` unset).
- age client: age v1.3.2 from this flake's nixpkgs (`26f4107e`),
  `nix shell --inputs-from . nixpkgs#age`.
- Producers: upstream tag `v0.2.1` (`a229872`) and upstream commit
  `57ccea1`, both in this repository's history. Each was exported with
  `git archive <rev>` into an empty directory and built there unchanged
  with `swift build -c release -j 2`. Both binaries print `v0.2.1` for
  `--version`.

For each revision, in an empty `fixtures/<rev>/`, with `P` the release
binary of that revision:

```sh
P keygen --access-control none --recipient-type se -o se-classic.identity
P recipients --recipient-type se -i se-classic.identity -o se-classic.recipient
P keygen --access-control none --recipient-type tag -o tag-classic.identity
P recipients --recipient-type tag -i tag-classic.identity -o tag-classic.recipient
P keygen --pq --access-control none --recipient-type tag -o tag-pq.identity
P recipients --pq --recipient-type tag -i tag-pq.identity -o tag-pq.recipient
```

There is no `se-pq` set: post-quantum keys always use the `tag` recipient
type, and `keygen --pq --recipient-type se` prints an `age1tagpq1`
recipient in both revisions.

Then, for each set (`se-classic`, `tag-classic`, `tag-pq`), with the
plaintext `age-plugin-se fixture` and a newline, and the recorder below
installed as `age-plugin-se` first on `PATH`:

```sh
SESSION_LOG=$PWD/<set>-encrypt.session age -e -a -R <set>.recipient -o <set>.age plain
SESSION_LOG=$PWD/<set>-decrypt.session age -d -i <set>.identity -o <set>.out <set>.age
cmp plain <set>.out
```

Every decryption gave back the plaintext. The ciphertext and plaintext were
not kept: the sessions hold the stanzas and the file keys. age v1.3.2
encrypts to `age1tag1` and `age1tagpq1` recipients itself, without the
plugin, so only the `se` set has an `-encrypt.session` (recipient-v1);
every set has a `-decrypt.session` (identity-v1).

The recorder runs the real binary (`REAL_PLUGIN`) with age's arguments,
passes stdin and stdout through byte for byte, and appends each line to
`SESSION_LOG`, prefixed `> ` (age to plugin) or `< ` (plugin to age):

```python
#!/usr/bin/env python3
import os, subprocess, sys, threading
real = os.environ["REAL_PLUGIN"]; log = open(os.environ["SESSION_LOG"], "ab")
lock = threading.Lock()
p = subprocess.Popen([real] + sys.argv[1:], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
def pump(src, dst, tag):
    for line in iter(src.readline, b""):
        with lock:
            log.write(tag + line); log.flush()
        dst.write(line); dst.flush()
    try: dst.close()
    except Exception: pass
t1 = threading.Thread(target=pump, args=(sys.stdin.buffer, p.stdin, b"> "), daemon=True)
t1.start()
pump(p.stdout, sys.stdout.buffer, b"< ")
sys.exit(p.wait())
```

## Manifest

Every file, its producer and the command that wrote it (fixtures V1).
`keygen`, `recipients`, `encrypt` and `decrypt` are the commands above.

| file | producer | command |
| --- | --- | --- |
| `v0.2.1/se-classic.identity` | `v0.2.1` | `keygen --access-control none --recipient-type se` |
| `v0.2.1/se-classic.recipient` | `v0.2.1` | `recipients --recipient-type se` |
| `v0.2.1/tag-classic.identity` | `v0.2.1` | `keygen --access-control none --recipient-type tag` |
| `v0.2.1/tag-classic.recipient` | `v0.2.1` | `recipients --recipient-type tag` |
| `v0.2.1/tag-pq.identity` | `v0.2.1` | `keygen --pq --access-control none --recipient-type tag` |
| `v0.2.1/tag-pq.recipient` | `v0.2.1` | `recipients --pq --recipient-type tag` |
| `v0.2.1/se-classic-encrypt.session` | `v0.2.1` | encrypt to `se-classic.recipient` |
| `v0.2.1/se-classic-decrypt.session` | `v0.2.1` | decrypt with `se-classic.identity` |
| `v0.2.1/tag-classic-decrypt.session` | `v0.2.1` | decrypt with `tag-classic.identity` |
| `v0.2.1/tag-pq-decrypt.session` | `v0.2.1` | decrypt with `tag-pq.identity` |
| `57ccea1/se-classic.identity` | `57ccea1` | `keygen --access-control none --recipient-type se` |
| `57ccea1/se-classic.recipient` | `57ccea1` | `recipients --recipient-type se` |
| `57ccea1/tag-classic.identity` | `57ccea1` | `keygen --access-control none --recipient-type tag` |
| `57ccea1/tag-classic.recipient` | `57ccea1` | `recipients --recipient-type tag` |
| `57ccea1/tag-pq.identity` | `57ccea1` | `keygen --pq --access-control none --recipient-type tag` |
| `57ccea1/tag-pq.recipient` | `57ccea1` | `recipients --pq --recipient-type tag` |
| `57ccea1/se-classic-encrypt.session` | `57ccea1` | encrypt to `se-classic.recipient` |
| `57ccea1/se-classic-decrypt.session` | `57ccea1` | decrypt with `se-classic.identity` |
| `57ccea1/tag-classic-decrypt.session` | `57ccea1` | decrypt with `tag-classic.identity` |
| `57ccea1/tag-pq-decrypt.session` | `57ccea1` | decrypt with `tag-pq.identity` |

## What the bytes show

These are upstream's bytes as each revision wrote them, faults included;
the tests decide what this build must match.

- `v0.2.1/tag-pq.recipient` is a classic `age1tag1` recipient, not
  `age1tagpq1`: `v0.2.1` ignores `--pq` in `recipients`, fixed by
  `19c59f2` before `57ccea1`. `v0.2.1/tag-pq-decrypt.session` therefore
  decrypts a classic `tag` stanza with the post-quantum identity.
- `recipients -o` writes the recipient without a final newline, in both
  revisions.
- A protocol message with an empty body ends in an empty line; the
  recorder writes it as `> ` or `< `, the prefix alone, trailing blank
  included.
- age adds a random `grease-…` stanza to each identity-v1 request, so the
  sessions are not reproducible byte for byte; the tests pin randomness
  with `DummyCrypto` (root V2).

`.gitattributes` here marks the files `-text`, so git never rewrites their
line endings, and the hk steps that would fix blanks and final newlines
skip `fixtures/<rev>/` (root V17 baseline).

## Manual checks

What `swift test` cannot check, because it runs without a Secure Enclave
or Touch ID (root V15). Run by hand on the Mac named above:

1. Each `*.identity` here decrypts on that Mac with the fork's build:
   `age -d -i fixtures/<rev>/<set>.identity` on a file encrypted to the
   matching `.recipient`, with the fork's `age-plugin-se` on `PATH`.
2. The same identity on any other Mac fails to decrypt (the key is bound
   to the Secure Enclave that made it).
3. A key made with the default access control asks for Touch ID on
   decrypt, and `AGE_PLUGIN_SE_PROMPT` sets the prompt text (root V12).
4. Denying Touch ID gives an error carrying the denial marker; no other
   error carries it (root V13).
