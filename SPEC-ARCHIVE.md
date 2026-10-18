# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`. An id is never reused
(`V12`), so a citation to an archived row still resolves -- here.

This is a SINK, not a spec. The citations inside these rows point into
`SPEC.md`, so `mth check` on this file reports every one of them as dangling,
correctly and uselessly. The verb that reads it is `mth tasks`.

## §T TASKS

T1|x|`nix` node: flake builds `57ccea1` (+ `f62703c`) w/o source change w/ host Swift, runs `swift test` as check (107 pass); refuses Swift < 6.2|V6,V15
T2|x|owner installed Xcode 27.1 machine-wide via the owner's machine config, outside this repo (D21, R3, R9); dev shell sets `DEVELOPER_DIR` & refuses w/o XCTest; CI runner's Xcode → T14|V6,V15
T3|x|`Package.swift`: exclude `SPEC.md` from `Sources` & `Tests` targets (D22, R7)|V7
T4|x|`fixtures` node: corpus made w/ upstream `v0.2.1` & `57ccea1` binaries on `MacBookPro18,3` w/ Secure Enclave, 2026-10-18; commands in `fixtures/README.md`|V1,V2,V15
T7|x|`.context-limits` measured w/ slack per node (`paradigm/V12`)|-
T8|x|`Tests`: help ↔ parser drift test `OptionsHelpTests` (R11)|V11
T14|x|fork CI `ci.yml` rendered by actlith from `.actlith` (actlith main, PR 19): gate on `macos-latest`, Xcode 26.6 pinned (R12), `hk check --all --check`; upstream workflows hand-written; actlith-check, actionlint, zizmor, yamllint on it; required checks → T22 (D8, D12)|V6
T23|x|CI-only throwaway Alpine signing key (`release/alpine-keygen.sh`) so upstream `Package (Alpine)` stays green for regression; ⊥ distribution key ∴ D12 (darwin only) unaffected; owner run in T22|-
