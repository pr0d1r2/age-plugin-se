# SPEC

## §G GOAL

`age-plugin-se` fork: upstream `remko/age-plugin-se` (age plugin; identity in Mac Secure Enclave; Touch ID per decrypt) + nix flake, hk gate & federated spec, built paradigm's way. ⊥ new product. formats byte-identical w/ upstream. ∀ functional change offered upstream. daily consumer: T (private secrets tool, named by letter only).

PARADIGM: paradigm `6c7e6cd` (no tag yet, D9), used as process; repo ⊥ fleet member yet (D1). cited `paradigm/V<n>`.

LINEAGE: `SPEC-PROMPT.md` (HISTORICAL after this run). where it & this spec differ, this spec wins. prompt decisions cited as `D<n>`.

## §N NAV

rel|path|lens
up|-|-
self|.|-

## §C CONSTRAINTS

- formats frozen (D2): identity, recipient & stanza encoding, plugin protocol messages ⊥ change. change needing one → upstream first, waits there.
- crypto ⊥ rewritten (D4): `Sources/Crypto.swift`, `Sources/HPKE.swift` change only to follow upstream | fix bug proven by failing test; human review each.
- upstream-bound change (D3): branch cut from `upstream/main`, ⊥ fork file in it (`SPEC*.md`, `FORMAT*.md`, `flake.*`, `nix/`, `fixtures/`, `.pklith`, `hk.pkl`, `.coverage`, `.context-limits`, fork CI). carried change dropped once upstream merges it.
- upstream tests kept & run as-is (D7); fork tests in own files beside them.
- Swift ≥ 6.2 & macOS SDK from host; nix pins every other tool (D11). tests need Xcode's XCTest (D21). `.macOS(.v26)` stays.
- darwin only v1 (D12). fork CI = GitHub macOS runner running same `hk.pkl`; upstream `build.yml` untouched.
- `Sources/` & `Tests/` flat, ⊥ moved (D17). ⊥ 2 workers in `Sources` in one wave. node `SPEC.md` inside a SwiftPM target dir excluded in `Package.swift` (D22).
- gate = one `hk.pkl` from `.pklith` (`paradigm/V23`). Swift rows local first, then filed upstream (D13, D16). upstream code ⊥ reformatted; its lint & warning debt in baseline that only shrinks.
- `main` protected, PR-only (D8); follows upstream by merge commit via PR (D18). ∀ PR human review (D5).
- outward acts (push, upstream PR, issue, comment, tag) need explicit owner approval. private repos ⊥ named (`paradigm/V37`).
- prose for humans in pages; caveman only in `SPEC.md` files.
