# SPEC

## §G GOAL

upstream plugin code, flat SwiftPM target `age-plugin-se`. fork changes here are carried changes only: prompt env, denial marker, B1 to B3 fixes, `CLI.run` seam, upstream PR 15 (`.:T30`).

## §N NAV

rel|path|lens
up|.|-
self|Sources|upstream plugin code: CLI & option parser, plugin protocol, stanzas, bech32, base64, crypto boundary; carried changes (prompt env, denial marker, CLI bug fixes)
sib|Tests|XCTest target `Tests`: upstream tests as-is & fork tests beside them; `DummyCrypto`, `MemoryStream`
sib|fixtures|format-freeze corpus: identities, recipients & stanzas made by upstream `v0.2.1` & `57ccea1`; how each was made
sib|nix|flake parts: package, checks, dev shell, host-toolchain guard
sib|Scripts|upstream build & coverage scripts (`ProcessCoverage.swift`), unchanged; ⊥ node
sib|Documentation|upstream man page sources, unchanged; ⊥ node
sib|docs|fork notices & LLM disclaimer; ⊥ node
sib|gate|fork gate scripts: name guard (denylist half), commit-msg check & their bats tests; ⊥ node
sib|release|fork CI-only Alpine keygen & its bats test; ⊥ node
sib|pkl|hk `Config.pkl` vendored by `pklith seed`, unchanged; ⊥ node

## §C CONSTRAINTS

- ∀ change upstream-bound: smallest diff passing its RED test, in upstream's style (2-space indent, `// swift-format` as found), on a branch from `upstream/main` too (`.:V5`).
- crypto boundary (`Crypto.swift`, `HPKE.swift`) per `.:V3`: T9 carries upstream PR 18's diff as-is where it touches them, human review.
- ⊥ file moved, renamed | split (D17); ⊥ new dependency.
- `SPEC.md` here excluded from target in `Package.swift` (D22).
- 1 worker in this node per wave.

## §I INTERFACES

- file: `CLI.swift` — `@main CLI`, `Options.parse`, `Options.help`, version string (upstream's, D19); fork: `keygenOutput(_:output:)`, `writeOutput(_:to:)`, `CLIError` (B1 to B3, `.:T11`, `.:T25`, `.:T26`); `CLI.run` (`.:T28`).
- file: `Plugin.swift` — plugin state machines `runRecipientV1` / `runIdentityV1`, stanza I/O, identity & recipient encode/decode, `Plugin.Error`.
- file: `Crypto.swift` — `protocol Crypto` (test seam; `DummyCrypto` in `Tests`), `CryptoKitCrypto` (Secure Enclave, `LAContext`); fork: `init(environment:)` sets prompt (`.:T9`), `isMLKEMAvailable` (test seam, `.:T30`).
- file: `HPKE.swift` — HPKE seal/open, P-256 & ML-KEM-768 hybrid; fork: ML-KEM-768 encap & decap guard on `crypto.isMLKEMAvailable`, decap takes `crypto:` (`.:T29`).
- file: `Bech32.swift`, `Base64.swift` — encodings. `Stream.swift` — `StandardIOStream`.
- env: `AGE_PLUGIN_SE_PROMPT` (`.:V12`).
- error: `Plugin.denialMarker` `AGE_PLUGIN_SE_DENIED_V1`; `Plugin.message(for:)` → `<marker>: <localizedDescription>` iff `Plugin.isDenial`, else text alone; used by identity-v1 unwrap `msg` (`.:V13`, `.:T10`).
- denial codes (owner 2026-10-23): `LAError` `userCancel`, `authenticationFailed`; OSStatus `errSecUserCanceled`, `errSecAuthFailed`; found at top | under `NSUnderlyingErrorKey` | `NSMultipleUnderlyingErrorsKey`, recursive. ∀ other code ⊥ denial.

## §V INVARIANTS

V1: denial classified from `LAError` | OSStatus code, ⊥ from message text ∴ locale-proof (`.:V13`).
V2: prompt text read once per process, ⊥ logged, ⊥ in any stanza (`.:V12`).
V3: ∀ carried change reverts cleanly once upstream merges its equivalent ∴ diff stays local to its feature.

## §T TASKS

id|status|task|cites
T1|x|ARCHIVED to SPEC-ARCHIVE.md|V2,V3
T2|x|ARCHIVED to SPEC-ARCHIVE.md|V1,V3
T3|x|ARCHIVED to SPEC-ARCHIVE.md|V3
T4|x|ARCHIVED to SPEC-ARCHIVE.md|V3
T5|x|ARCHIVED to SPEC-ARCHIVE.md|V3
T6|~|`CLI.run`: `CLI.main`'s dispatch, injectable (`.:T28`). fork half done; upstream PR w/ approval|V3
