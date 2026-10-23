# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`. An id is never reused (`V12`), so a citation to an archived row still resolves -- here.

This is a SINK, not a spec. The citations inside these rows point into `SPEC.md`, so `mth check` on this file reports every one of them as dangling, correctly and uselessly. The verb that reads it is `mth tasks`.

## §T TASKS

T1|x|`nix` node: flake builds `57ccea1` (+ `f62703c`) w/o source change w/ host Swift, runs `swift test` as check (107 pass); refuses Swift < 6.2|V6,V15
T2|x|owner installed Xcode 27.1 machine-wide via the owner's machine config, outside this repo (D21, R3, R9); dev shell sets `DEVELOPER_DIR` & refuses w/o XCTest; CI runner's Xcode → T14|V6,V15
T3|x|`Package.swift`: exclude `SPEC.md` from `Sources` & `Tests` targets (D22, R7)|V7
T4|x|`fixtures` node: corpus made w/ upstream `v0.2.1` & `57ccea1` binaries on `MacBookPro18,3` w/ Secure Enclave, 2026-10-18; commands in `fixtures/README.md`|V1,V2,V15
T5|x|`Tests`: format-freeze tests over `fixtures/` (`Tests` T1, T2): `FormatFreezeTests` (V1) & `FormatFreezeSessionTests` (V2, structural) in `Fork/PluginForkTests.swift`; real-identity replay in `CryptoKitHardwareTests`. characterization ∴ red run = planted byte in a fixture copy|V1,V2,V4
T7|x|`.context-limits` measured w/ slack per node (`paradigm/V12`)|-
T8|x|`Tests`: help ↔ parser drift test `OptionsHelpTests` (R11)|V11
T9|x|`Sources`: `AGE_PLUGIN_SE_PROMPT` RED → GREEN; `CryptoKitCrypto(environment:)` sets `LAContext.localizedReason`. fork only (V5 off)|V12,V3
T10|x|`Sources`: denial marker RED → GREEN (`Plugin.isDenial`, `Plugin.message(for:)`). fork only (V5 off)|V13
T11|x|`Sources`: B1 fix RED → GREEN (`keygenOutput` throws `CLIError.cannotWriteOutput`). fork only (V5 off)|V14
T12|x|`#unavailable(macOS 21.0)` → `26.0` (R7): fixed in fork PR #3 (`f62703c`, issue #2). fork only (V5 off)|V7
T14|x|fork CI `ci.yml` rendered by actlith from `.actlith` (actlith main, PR 19): gate on `macos-latest`, Xcode 26.6 pinned (R12), `hk check --all --check`; upstream workflows hand-written; actlith-check, actionlint, zizmor, yamllint on it; required checks → T22 (D8, D12)|V6
T20|x|coverage exclusions w/ reasons (D14) as `.coverage` fn rows + cap (sherd PR 142); floor re-recorded 99.56%|V10
T23|x|CI-only throwaway Alpine signing key (`release/alpine-keygen.sh`) so upstream `Package (Alpine)` stays green for regression; ⊥ distribution key ∴ D12 (darwin only) unaffected; owner run in T22|-
T25|x|`Sources`: B2 fix RED → GREEN (`writeOutput`, shared w/ B1). fork only (V5 off)|V18
T26|x|`Sources`: B3 fix RED → GREEN. fork only (V5 off)|V19
T27|x|`-h`, `--help`, `--version` in `Options.help` & man page (R11), owner approved; hard fork ∴ fork edits help alone. `--age-plugin` stays baselined ∵ age runs it, ⊥ user|V11
T28|x|`Sources`: `CLI.main` dispatch → `CLI.run` w/ injected stdin & print, ∴ testable; behaviour same (R13). fork only (V5 off)|V10
T29|x|owner 2026-10-23: HPKE ML-KEM-768 guards in `mlkemp256Encap` & `mlkemp256Decap` read `crypto.isMLKEMAvailable` (carried), RED → GREEN; 2 lines covered, floor 99.75%, 3 unrun (CLI 2, Plugin 1)|V10
T33|x|B4 fix: `try!` → `try`, `assert` → `Stanza.readAnswer`, `Stanza.argument`, `recipient-stanza` checked at read, `Bech32.decode("")`; throwing `recipientV1()` / `identityV1()`, upstream `run*V1()` wrap them (V4); `CLIError.pluginProtocol` on stderr. fixture probe: 8 sessions same bytes (PR body)|V20,V2,V4
