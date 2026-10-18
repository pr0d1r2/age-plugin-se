# SPEC

## §G GOAL

XCTest target `Tests`: upstream's suite as-is & fork tests beside it, all on `DummyCrypto` & `MemoryStream`, ⊥ Secure Enclave.

## §N NAV

rel|path|lens
up|.|-
self|Tests|XCTest target `Tests`: upstream tests as-is & fork tests beside them; `DummyCrypto`, `MemoryStream`
sib|Sources|upstream plugin code: CLI & option parser, plugin protocol, stanzas, bech32, base64, crypto boundary; carried changes (prompt env, denial marker)
sib|fixtures|format-freeze corpus: identities, recipients & stanzas made by upstream `v0.2.1` & `57ccea1`; how each was made
sib|nix|flake parts: package, checks, dev shell, host-toolchain guard

## §C CONSTRAINTS

- upstream test files edited only per `.:V4`. fork tests in own files: `FormatFreezeTests.swift`, `OptionsHelpTests.swift`, `ForkCLITests.swift`.
- fixture bytes read from `fixtures/` by path from `#filePath` ⊥ SwiftPM resources ∴ `Package.swift` unchanged beyond D22.
- RED commit compiles: tests land w/ stubs answering wrong (`paradigm/V44`).
- XCTest needs Xcode (D21); `swift test` from dev shell | CI macOS runner.
- `SPEC.md` here excluded from target in `Package.swift` (D22).

## §I INTERFACES

- cmd: `swift test` — whole suite; pre-push & `checks.aarch64-darwin` (`nix`).
- cmd: `swift test --enable-code-coverage` → `.build/debug/codecov/*.json` read by the coverage ratchet (`.:V10`).

## §V INVARIANTS

V1: suite deterministic: fixed clock, fixed randomness via `DummyCrypto`; same tree → same result (`.:V15`).
V2: format-freeze failure prints fixture path & first differing byte offset.
V3: ∀ fork test file ⊥ duplicates an upstream test; covers fork invariant it names in its doc comment.

## §T TASKS

id|status|task|cites
T1|.|`FormatFreezeTests`: parse & re-encode ∀ fixture (`.:T5`)|V2
T2|.|`FormatFreezeTests`: replay recipient-v1 & identity-v1 sessions (`.:T5`)|V1,V2
T3|.|`OptionsHelpTests`: help ↔ parser (`.:T8`)|V3
T4|.|`ForkCLITests`: prompt env, denial marker, B1 (`.:T9`, `.:T10`, `.:T11`)|V3
