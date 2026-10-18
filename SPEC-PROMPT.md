DRAFT INPUT. This file is the prompt for the first ck:spec run. When that
run lands SPEC.md, mark this file HISTORICAL INPUT in its own commit; from
then on SPEC.md and the node specs it federates are the law, and where they
differ from this file, they win.

Paradigm: paradigm, prompt round 7 (commit 6c7e6cd, no tag yet), used as
a process only: this repository is not a fleet member for now (decision
1). There is no paradigm language page for Swift yet. This file states
only the product and its deviations.

age-plugin-se (fork)

A fork of `remko/age-plugin-se`, the age plugin that keeps an age identity
in the Mac's Secure Enclave and asks for Touch ID on every decrypt. The
fork is used daily by T, a private secrets tool named here by letter only
(paradigm/V37), built with the same spec-first process and gate, and
offers every change back upstream.

# Problem and goals

T encrypts a project's secrets to one Secure Enclave key per Mac
through this plugin (T decisions 4, 17, 26, 27). That puts the
plugin in the trust path of every secret T guards, so three things
follow:

- Upstream is healthy but slow: one maintainer wrote 161 of 164 commits,
  commit counts fell from 72 (2023) and 67 (2024) to 20 (2025) and 5
  (2026), and outside PRs wait for months (PR 15 since 2026-04-19, PR 18
  since 2026-05-17). A bug T hits today could wait as long.
- The changes T wants are small and belong in the plugin, not in
  T: a Touch ID prompt that names the file being decrypted (PR 18),
  and a stable marker when the user denies the prompt, so a caller can tell
  "touch denied" from a real error.
- The fleet builds with nix and gates with hk. Upstream builds with
  SwiftPM and a Makefile, and its `main` declares Swift 6.2 while the fleet
  nixpkgs pin ships Swift 5.10.1.

Goals:
- a nix flake that builds `age-plugin-se` from this tree against the fleet
  nixpkgs, on aarch64-darwin first, with the Swift tests as flake checks
- the same gate a fleet repository has: hk from `.pklith`, a spec, TDD
  order, a coverage ratchet, CI on GitHub Actions
- identity and recipient formats byte-for-byte compatible with upstream,
  proven by tests, so a key made by either build works with the other
- every change offered upstream as a PR from a clean branch, and every
  carried change dropped once upstream merges it
- tagged releases that T pins as a flake input

# Naming

- Repository and binary name stay `age-plugin-se`. age finds a plugin by
  its binary name (`age-plugin-<name>`) and the recipient prefix
  (`age1se1...`), so a renamed binary would not be found by age, sops or
  rage, and a renamed repository would hide that this is a fork. A
  deviation from the `-lith` naming rule; local.
- `pr0d1r2/age-plugin-se` created 2026-10-18 as a PUBLIC GitHub fork of
  `remko/age-plugin-se`, `main` identical to upstream `57ccea1` that day.
  Recount: `gh repo view pr0d1r2/age-plugin-se --json isFork,parent`, `gh
  api repos/remko/age-plugin-se/compare/main...pr0d1r2:main`.
- Rejected: a `-lith` name such as `enclavelith` for the repository: free
  to take, but it breaks the fork relation GitHub shows and says nothing to
  an age user looking for the plugin.

# Survey (2026-10-18)

The tree at `57ccea1`:
- 1,531 lines of Swift in `Sources/` (`Plugin.swift` 681, `CLI.swift` 249,
  `Bech32.swift` 233, `Crypto.swift` 185, `HPKE.swift` 183) and 1,851 in
  `Tests/`; 108 test functions (`PluginTests` 58, `CLITests` 17,
  `StanzaTests` 14, `Base64Tests` 10, `CryptoTests` 5, `Bech32Tests` 4).
  Tests run against `DummyCrypto`, so they need no Secure Enclave.
- One dependency: `apple/swift-crypto` `2.0.0..<5.0.0`, used on Linux and
  Windows only.
- `Package.swift`: `swift-tools-version: 6.2`, `.macOS(.v26)`. `make
  patch-package-swift-legacy` rewrites both to `5.9` and `.macOS(.v14)`;
  upstream CI uses it for older runners.
- Makefile targets: `all package package-linux test test-loop lint install
  install-doc man clean patch-package-swift-legacy smoke-test
  smoke-test-noninteractive smoke-test-encrypt gen-manual-tests
  run-manual-tests`. `make test COVERAGE=1` measures coverage with
  `Scripts/ProcessCoverage.swift`.
- CI: `build.yml` on macos-14, macos-15, macos-26, ubuntu-24.04 and
  windows-2022 (Windows builds, does not test); `build-main.yml`;
  `release.yml`.
- CLI: `keygen [--pq] [-o OUTPUT] [--access-control ACCESS_CONTROL]
  [--recipient-type se|tag]`, `recipients [--pq] [-o OUTPUT] [-i INPUT]
  [--recipient-type se|tag]`, and `--age-plugin` for the plugin protocol.
  Access controls: `none`, `passcode`, `any-biometry`,
  `any-biometry-or-passcode` (default), `any-biometry-and-passcode`,
  `current-biometry`, `current-biometry-and-passcode`.
- Tags: `v0.1.2` to `v0.2.1`; v0.2.1 released 2025-12-27. Merged after it:
  PR 16 and PR 17 (post-quantum key fixes), PR 21 (ISO 8601 fallback for
  older Swift). Open: PR 15 (build with older SDKs), PR 18 (custom Touch ID
  prompt via `AGE_PLUGIN_SE_PROMPT`), issues 12 (`age1tag1` and
  `age1tagpq1` recipients), 13, 14.
- Forks: 9 besides this one; only `dcosson` carries real changes (PR 18's
  prompt, a stable presence-denial marker, better classification of
  unavailable authentication, fork release CI), idle since 2026-07-23.
- nixpkgs: the fleet pin (nixos-26.05 `a5cc6f2c`) ships `age-plugin-se`
  0.1.4 and `swift` 5.10.1; its `age-plugin-se` builds on darwin and
  linux.
- Recount: `find Sources Tests -name '*.swift' | xargs wc -l`, `grep -c
  'func test' Tests/*.swift`, `git log --format=%ad --date=short | cut
  -c1-4 | uniq -c`, `gh pr list -R remko/age-plugin-se --state all`, `nix
  eval --raw <pin>#swift.version`.

# Flake and gate sketch

Sketch, not final:
- `packages.aarch64-darwin.default`: `age-plugin-se` built by SwiftPM
  inside nix, Swift tools from the fleet nixpkgs pin.
- Linux packages, if nix can build them (open question 5): encrypt-only
  use in CI, since encrypting to a Secure Enclave recipient needs the
  plugin but not the chip.
- `checks.<system>`: `swift test` with `DummyCrypto`; the smoke encrypt
  test; the format-compatibility tests below.
- `devShells.default`: Swift toolchain, swift-format, hk, pklith, mth,
  sherd, itok.
- Format freeze: fixtures of identities and recipients made by upstream
  v0.2.1 and by upstream `main` (`se` and `tag`, classic and `--pq`) that
  every build must parse and reproduce byte for byte.

# CLI sketch

Upstream's CLI stays as it is. Additions, each one also offered upstream:

```
AGE_PLUGIN_SE_PROMPT=<text>   Touch ID prompt text (upstream PR 18)
```

- On a denied prompt, the plugin reports a fixed, documented error string,
  so a caller such as T can say "touch denied" instead of a raw
  failure (from the `dcosson` fork).

# Decisions (2026-10-18)

1. This repository is a fork, not a fleet member for now: it is not in
   the paradigm registry and the fleet loop does not tend it. It keeps
   upstream's history, binary name and formats, and adds a flake, a gate
   and a spec built the fleet's way. Once its guardrails meet the fleet's
   standard, 100% line coverage included, it is handed to the fleet loop
   if the loop can run it (it needs a Mac). Narrows T decision 27.
   Local.
2. Formats are frozen: no change may alter the identity or recipient
   encoding, the stanza format, or the plugin protocol messages. A change
   that needs one is proposed upstream first and waits there. Local.
3. Every functional change goes upstream as a PR from a branch cut from
   `upstream/main`, with none of this fork's flake, gate or spec files in
   it. A carried change is dropped once upstream merges it. Local.
4. Cryptography is not rewritten here: `Crypto.swift` and `HPKE.swift`
   change only to follow upstream or to fix a bug proven by a failing test,
   and every such change needs a human review. Local.
5. Every PR needs a human review, as in T (T decisions 11
   and 23). Local.
6. Swift is not a fleet language. What this repository learns about
   gating it is noted for a paradigm `docs/SWIFT.md`, proposed only if the
   repository joins the fleet. Local.
7. Upstream's tests are kept and run as they are; this fork's tests are
   added beside them, not in their place. Local.
8. `main` is protected on GitHub, set 2026-10-18: every change lands by
   PR, admins included (`enforce_admins`), with 0 required approvals
   because GitHub does not let the owner approve their own PR; no force
   push, no deletion, conversations resolved before merge. Syncing from
   upstream also goes through a PR. Required status checks are added when
   CI exists. Recount: `gh api
   repos/pr0d1r2/age-plugin-se/branches/main/protection`. Local.

# Non-goals

- a new plugin, new key types or a new recipient type ahead of upstream
- Linux or Windows Secure-Enclave-like backends (TPM): a separate plugin
- releasing to Homebrew or other package managers; T pins the flake
- T-specific behaviour: anything only T needs belongs in T

# Prior art and rejected designs

- Pin upstream without a fork (T decision 26): rejected by T decision
  27; the fork lets T fix bugs on its own schedule.
- Soft fork (patch files on top of an upstream commit, built inside T):
  rejected by T decision 27 for a gated member.
- The `dcosson` fork: right changes, but fork-only release CI and idle
  after two months; its changes are ported here and offered upstream.
- `age-plugin-yubikey`: touch-gated and portable, but a different key
  holder; a possible recovery backend in T, not a replacement.

# Open questions

Ask before guessing. A question marked blocking stops the node it names.

1. Swift toolchain: build with the fleet's Swift 5.10.1 after `make
   patch-package-swift-legacy` (tools 5.9, macOS 14), or bring a newer
   Swift from elsewhere? Does lowering `.macOS(.v26)` cost anything we use
   (post-quantum keys in the Secure Enclave)? T open question 8.
   Blocks the flake node.
2. Branches: does fork `main` carry the flake, gate and spec files on top
   of upstream, and does it follow upstream by rebase or by merge? Upstream
   PR branches are cut from `upstream/main` either way (decision 3). Blocks
   the first push of those files.
3. Versions: tag scheme for fork releases (for example
   `v0.2.1-fork.1`), and the base: upstream `57ccea1` or the v0.2.1 tag?
   Blocks the first tag.
4. Coverage: adopt upstream's `ProcessCoverage.swift` measure as the
   ratchet floor in `.coverage`, or measure another way? Not blocking.
5. Linux build: the package targets Macs, and whether nix can build it
   on Linux is unknown (upstream CI builds it on ubuntu-24.04 with
   SwiftPM, using `swift-crypto` there). darwin only in v1, and Linux
   tried later for T's CI, or required now? Not blocking.
6. Gate tools for Swift: swift-format from nixpkgs (5.10.1) as the lint,
   and what pklith row covers `.swift` files? Not blocking.

# Process

Built in its own session on a Mac with more resources than the one that
wrote this prompt. The paradigm lifecycle: dev shell, then ask me to
reload; guardrails first, one check per commit, then ask me to reload;
TDD, with RED commits red on purpose and tests on push; federated SPEC-DAG
built in sherd waves.

Build order:
1. The flake builds upstream `57ccea1` unchanged and runs its tests.
2. The format-freeze fixtures and tests.
3. The gate.
4. The prompt env var and the denial marker, each RED then GREEN, each
   offered upstream.
5. The first tag; T switches its input (T `nix:T3`).

Outward-facing steps need my explicit approval: every push, every upstream
PR, tags, and comments on upstream issues or PRs. Before the first push,
check every repository named in a committed file with `gh repo view`, and
name no private repository.
