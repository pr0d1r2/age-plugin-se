# Third-party notices

This repository is a fork. Most of its code was written upstream, some
was written by others before that, and the build pulls in two Apple
packages. This file says what each part is, who holds its copyright and
which licence it carries.

## Upstream: `age-plugin-se`

The fork is built on
[`remko/age-plugin-se`](https://github.com/remko/age-plugin-se): the
plugin's code in `Sources/`, its tests in `Tests/`, the build and
coverage scripts in `Scripts/`, the man page and design notes in
`Documentation/`, `Makefile`, `README.md` and the upstream CI.

- Licence: MIT
- Copyright (c) 2023 Remko Tronçon

The licence text is [`LICENSE.txt`](../LICENSE.txt), kept as upstream
wrote it with one fork copyright line added under upstream's.

## Carried and adapted changes

- The macOS 14 build, with post-quantum keys only where macOS 26 has
  ML-KEM-768, carries upstream
  [PR 15](https://github.com/remko/age-plugin-se/pull/15), "add some
  guards to allow compiling with older SDK", by Andreas Metsälä
  ([`verokarhu`](https://github.com/verokarhu)), adapted to this fork's
  code. It was offered to upstream under upstream's MIT licence above.
- `gate/universal.sh`, the check that the release binary holds arm64 and
  x86_64 slices with `minos` 14.0 each, adapts the idea of the
  `verify-macos-deployment` Makefile target in the
  [`dcosson/age-plugin-se`](https://github.com/dcosson/age-plugin-se)
  fork, a fork of the same upstream under the same MIT licence. Its
  version string and release steps are not taken.
- The Touch ID denial marker (`AGE_PLUGIN_SE_DENIED_V1`) takes ideas
  from the presence-denial marker in the same
  [`dcosson/age-plugin-se`](https://github.com/dcosson/age-plugin-se)
  fork: classify the error by its code, never its text; let
  `DummyCrypto` throw a chosen error from a key operation; check the
  `msg` stanza of an identity-v1 unwrap. Its marker string and its list
  of codes are not taken: here only a user's cancel or failed Touch ID
  counts, and the marker comes before the error's own text.

## Bech32

The Bech32 checksum code in `Sources/Bech32.swift`, and its copy in
`Scripts/ConvertBech32HRP.swift`, is a modified version of
[`0xDEADP00L/Bech32`](https://github.com/0xDEADP00L/Bech32). Both files
carry its notice in their header.

- Licence: MIT
- Copyright 2018 Evolution Group Limited

## SwiftPM dependencies

The repository holds only their pins, in `Package.resolved`; their source
is fetched at build time.

| Package | Version | Licence |
| --- | --- | --- |
| [`apple/swift-crypto`](https://github.com/apple/swift-crypto) | 4.2.0 | Apache-2.0 |
| [`apple/swift-asn1`](https://github.com/apple/swift-asn1) | 1.5.1 | Apache-2.0 (pulled in by `swift-crypto`) |

`Package.swift` links `swift-crypto` on Linux and Windows only; the macOS
build uses Apple's CryptoKit and links neither. Any binary that does link
them must ship each package's `LICENSE.txt` and `NOTICE.txt` with it, as
Apache-2.0 requires.

## Fixtures

`fixtures/` holds identities, recipients and plugin sessions made by
running upstream's binaries (`v0.2.1` and `57ccea1`). They are that
program's output, kept byte for byte, and come under upstream's licence
above as far as any licence reaches them.

## Not distributed: build-time tools

These run in the dev shell, the gate and CI. None is linked into the
plugin or shipped with it.

- [`nix`](https://github.com/NixOS/nix): pins the dev shell and builds
  the package.
- [`hk`](https://github.com/jdx/hk): runs the gate in `hk.pkl`.
- [`pklith`](https://github.com/pr0d1r2/pklith): writes `hk.pkl` from
  `.pklith`.
- [`sherd`](https://github.com/pr0d1r2/sherd): checks the federated spec
  and holds the coverage floor.
- [`actlith`](https://github.com/pr0d1r2/actlith): writes the fork CI
  workflow from `.actlith`.

## The fork's own additions

Everything the fork adds (the specs, the nix flake, the gate, the fork
tests, the fixtures' notes and these pages) is licensed under the MIT
License in [`LICENSE.txt`](../LICENSE.txt).
