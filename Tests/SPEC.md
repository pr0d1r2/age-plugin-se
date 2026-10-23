# SPEC

## §G GOAL

XCTest target `Tests`: upstream's suite as-is & fork tests in `Tests/Fork/`, 1 file per source (V4), all on `DummyCrypto` & `MemoryStream`, ⊥ Secure Enclave. exception: `*ProcessTests`, `CLIProcessCoverageTests` & `StandardIOStreamEndTests` run the built binary as a child (`BuiltBinary`), ⊥ SE key; its profile merges via inherited `LLVM_PROFILE_FILE`. exception: `CryptoKitHardwareTests` (§I): real SE, gated.

## §N NAV

rel|path|lens
up|.|-
self|Tests|XCTest target `Tests`: upstream tests as-is & fork tests beside them; `DummyCrypto`, `MemoryStream`
sib|Sources|upstream plugin code: CLI & option parser, plugin protocol, stanzas, bech32, base64, crypto boundary; fork changes (prompt env, denial marker, CLI bug fixes)
sib|fixtures|format-freeze corpus: identities, recipients & stanzas made by upstream `v0.2.1` & `57ccea1`; how each was made
sib|nix|flake parts: package, checks, dev shell, host-toolchain guard
sib|Scripts|upstream build & coverage scripts (`ProcessCoverage.swift`), unchanged; ⊥ node
sib|Documentation|upstream man page sources + fork help option lines; ⊥ node
sib|docs|fork notices & LLM disclaimer; ⊥ node
sib|gate|fork gate scripts: name guard (denylist half), commit-msg check & their bats tests; ⊥ node
sib|release|fork CI-only Alpine keygen & its bats test; ⊥ node
sib|pkl|hk `Config.pkl` vendored by `pklith seed`, unchanged; ⊥ node

## §C CONSTRAINTS

- upstream test files edited only per `.:V4` ∴ fork tests ⊥ merged into them, 1 per source (V4); `FormatFreezeTests` (T1, T2) → class in its source's mirror. suffix `ForkTests` ∵ swiftc refuses 2 files w/ 1 basename in a module. `Package.swift` unchanged: flat `path: "Tests"` compiles `Fork/`.
- fixture bytes read from `fixtures/` by path from `#filePath`, ⊥ SwiftPM resources.
- RED commit compiles: tests land w/ stubs answering wrong (`paradigm/V44`).
- XCTest needs Xcode (D21); `swift test` from dev shell | CI macOS runner.
- `SPEC.md` here excluded from target in `Package.swift` (D22).

## §I INTERFACES

- cmd: `swift test` — whole suite; pre-push & `checks.<sys>` (`nix`).
- cmd: `swift test --enable-code-coverage` → `.build/debug/codecov/*.json` read by the coverage ratchet (`.:V10`).
- helpers ⊥ `*Tests.swift`: upstream `DummyCrypto`, `MemoryStream`; fork `Fork/BuiltBinary.swift` (`run`; `runCapturingAll` adds stderr & termination reason; `assertProtocolError`: exit 255 ⊥ trap, `.:V20`). fork seam `DummyCrypto.operationError`: set → P-256 key agreement throws it (`.:T10`).
- hardware: `CryptoKitHardwareTests` (`Fork/CryptoForkTests.swift`): 4 `.coverage`-excluded `newSecureEnclave*` fns & age round trip (classic, `--pq`). runs iff `AGE_PLUGIN_SE_HARDWARE=1` ∧ `SecureEnclave.isAvailable`, else `XCTSkip` w/ why.
- hardware safety: `.privateKeyUsage` only ∴ ⊥ Touch ID; keys = `dataRepresentation` in memory | removed `.build/tmp-hw/`; ⊥ keychain.
- `.pklith` row `hardware` (pre-push) sets the var; `CI` set → ⊥ run. `test`, `coverage` ⊥ set it ∴ floor = CI's. `coverage` skips on macOS < 26 (`.:V10`).
- `.pklith` rules (V4): `swift-test` exists `Sources/*.swift` → `Tests/Fork/{stem}ForkTests.swift`, ⊥ except; `swift-orphan` orphan `Tests/*Tests.swift` (`*` crosses `/` ∴ `Fork/` too) → `Sources/{stem\|chop:ForkTests\|chop:Tests}.swift`, except `Tests/StanzaTests.swift` ∵ upstream's, tests `Stanza` in `Plugin.swift`. upstream has no `HPKE`, `Stream` test ∴ ⊥ upstream exists row.
- `.pklith` rule (V5): `swift-tdd` tdd-order `Sources/*.swift` → `Tests/Fork/{stem}ForkTests.swift`, ⊥ except. judged pre-push by check `tdd-order` (`pklith check --pushed`); in CI by `pklith check --range origin/main..HEAD` ∵ CI's commits already on the remote ∴ `--pushed` judges none.

## §V INVARIANTS

V1: suite deterministic: fixed clock, fixed randomness via `DummyCrypto`; same tree → same result (`.:V15`).
V2: format-freeze failure prints fixture path & first differing byte offset.
V3: ∀ fork test file ⊥ duplicates an upstream test; covers fork invariant it names in its doc comment.
V4: ∀ `Sources/X.swift` ∃ `Tests/Fork/XForkTests.swift`; ∀ `*Tests.swift` maps to 1 source | is an except in §I.
V5: ∀ commit changing `Sources/X.swift` changes `Tests/Fork/XForkTests.swift` in it | an earlier judged commit (test first). commits before a push | PR ⊥ judged; deleting a source needs ⊥ test.

## §T TASKS

id|status|task|cites
T1|.|`FormatFreezeTests`: parse & re-encode ∀ fixture (`.:T5`). open, owner reads `.:V1` before RED: `v0.2.1/tag-pq.recipient` is classic `age1tag1` (`v0.2.1` ignores `recipients --pq`); `DummyCrypto` reads identity data as raw P-256 (`DummyCrypto.swift:53`), fixture identities hold Secure Enclave blobs ∴ identity → recipient ⊥ derivable here, bech32 round trip is|V2
T2|.|`FormatFreezeTests`: replay recipient-v1 & identity-v1 sessions (`.:T5`). open, owner reads `.:V2` before RED: sessions hold age's random `grease` stanza & real CryptoKit randomness, ⊥ `DummyCrypto`'s; identity-v1 unwrap needs the Secure Enclave that made the key (`.:V15`)|V1,V2
T3|x|ARCHIVED to SPEC-ARCHIVE.md|V3
T4|x|ARCHIVED to SPEC-ARCHIVE.md|V3
