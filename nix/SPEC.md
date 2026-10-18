# SPEC

## §G GOAL

flake parts: `age-plugin-se` package, checks, dev shell & host-toolchain guard, on aarch64-darwin (D12).

## §N NAV

rel|path|lens
up|.|-
self|nix|flake parts: package, checks, dev shell, host-toolchain guard
sib|Sources|upstream plugin code: CLI & option parser, plugin protocol, stanzas, bech32, base64, crypto boundary; carried changes (prompt env, denial marker)
sib|Tests|XCTest target `Tests`: upstream tests as-is & fork tests beside them; `DummyCrypto`, `MemoryStream`
sib|fixtures|format-freeze corpus: identities, recipients & stanzas made by upstream `v0.2.1` & `57ccea1`; how each was made
sib|Scripts|upstream build & coverage scripts (`ProcessCoverage.swift`), unchanged; ⊥ node
sib|Documentation|upstream man page sources, unchanged; ⊥ node

## §C CONSTRAINTS

- nixpkgs follows nixpkgs-lock (`paradigm/V20`); hk, pkl, pklith & spec tools via pklith `lib.devShell`, as paradigm does.
- Swift, macOS SDK & XCTest from host Xcode via `DEVELOPER_DIR` (D11, D21) ∴ package & checks ⊥ hermetic; stated deviation, revisit when nixpkgs ships Swift ≥ 6.2.
- every other tool pinned by `flake.lock`: swiftlint & swift-format from nixpkgs pin (R4), mth, sherd, itok. sherd pinned newer than pklith's catalog; pklith follows it ∴ one sherd.
- package & checks run host Xcode ∴ `__noChroot` (refused on `sandbox = true`). SwiftPM resolves Linux-only pins too (`swift-crypto`, `swift-asn1`) ∴ each pin = fixed-output git checkout, SwiftPM mirror → it; build ⊥ network.
- darwin stdenv sets `DEVELOPER_DIR` & `SDKROOT` to its apple-sdk ∴ shell & builds reset them to host Xcode.
- logic in `.sh` files beside the `.nix` that call them ⊥ embedded shell (xenolith rule).

## §I INTERFACES

- file: root `flake.nix` imports `nix/package.nix`, `nix/checks.nix`, `nix/shell.nix`.
- file: `nix/toolchain.sh` — guard: Swift ≥ 6.2 & XCTest present | exit 1 naming the fix (`.:V6`); `nix/toolchain-test.sh` — its planted refusals.
- file: `nix/shell-hook.sh` (shell entry), `nix/swift.sh` & `nix/swiftpm.nix` (SwiftPM in a nix build): host Xcode, vendored pins.
- nix: `packages.aarch64-darwin.default` — `swift build -c release`, binary `age-plugin-se`.
- file: `nix/test.sh <swift…>` — the one test command: `<swift…> test --disable-sandbox --only-use-versions-from-resolved-file` (V2).
- nix: `checks.aarch64-darwin.tests` — `nix/test.sh` w/ `nix/swift.sh` wrapper; `checks.aarch64-darwin.toolchain` — guard.
- nix: `devShells.aarch64-darwin.default` — guard on entry, then gate tools.

## §V INVARIANTS

V1: guard runs before any build, test | shell; message names the missing piece & D21.
V2: `checks.aarch64-darwin.tests` runs same command as pre-push ∴ ⊥ drift.

## §T TASKS

id|status|task|cites
T1|x|ARCHIVED to SPEC-ARCHIVE.md|V1
T2|x|ARCHIVED to SPEC-ARCHIVE.md|V2
T3|x|ARCHIVED to SPEC-ARCHIVE.md|V2
T4|.|pre-push step (`.:T6`) runs `swift test` as `checks.aarch64-darwin.tests` does|V2
