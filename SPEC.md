# SPEC

## §G GOAL

`age-plugin-se` fork: upstream `remko/age-plugin-se` (age plugin; identity in Mac Secure Enclave; Touch ID per decrypt) + nix flake, hk gate & federated spec, built paradigm's way. ⊥ new product. formats byte-identical w/ upstream. ∀ functional change offered upstream. daily consumer: T (private secrets tool, named by letter only).

PARADIGM: paradigm `6c7e6cd` (no tag yet, D9), used as process; repo ⊥ fleet member yet (D1). cited `paradigm/V<n>`.

LINEAGE: `SPEC-PROMPT.md` (HISTORICAL after this run). where it & this spec differ, this spec wins. prompt decisions cited as `D<n>`.

## §F FEDERATION

dir|owns|⊥owns|tokens
Sources|upstream plugin code: CLI & option parser, plugin protocol, stanzas, bech32, base64, crypto boundary; carried changes (prompt env, denial marker, CLI bug fixes)|tests (`Tests`), fixture bytes (`fixtures`), build (`nix`)|-
Tests|XCTest target `Tests`: upstream tests as-is & fork tests beside them; `DummyCrypto`, `MemoryStream`|product code (`Sources`), fixture bytes (`fixtures`)|-
fixtures|format-freeze corpus: identities, recipients & stanzas made by upstream `v0.2.1` & `57ccea1`; how each was made|tests reading it (`Tests`), the formats (upstream)|-
nix|flake parts: package, checks, dev shell, host-toolchain guard|gate rows (root `.pklith`), CI workflow (root)|-
Scripts|upstream build & coverage scripts (`ProcessCoverage.swift`), unchanged; ⊥ node|fork gate & coverage ratchet (root)|-
Documentation|upstream man page sources, unchanged; ⊥ node|fork docs (root `README.md` stays upstream's)|-
gate|fork gate scripts: name guard (denylist half), commit-msg check & their bats tests; ⊥ node|gate rows (root `.pklith`), hooks (root `hk.pkl`)|-
release|fork CI-only Alpine keygen & its bats test; ⊥ node|upstream packaging|-
pkl|hk `Config.pkl` vendored by `pklith seed`, unchanged; ⊥ node|gate rows (root `.pklith`)|-

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

## §I INTERFACES

- cmd: `age-plugin-se keygen [--pq] [-o OUTPUT] [--access-control ACCESS_CONTROL] [--recipient-type se|tag]` — upstream, unchanged. access controls: `none` `passcode` `any-biometry` `any-biometry-or-passcode` (default) `any-biometry-and-passcode` `current-biometry` `current-biometry-and-passcode`.
- cmd: `age-plugin-se recipients [--pq] [-o OUTPUT] [-i INPUT] [--recipient-type se|tag]` — upstream, unchanged.
- cmd: `age-plugin-se --age-plugin=recipient-v1|identity-v1` — age plugin protocol over stdio, upstream, frozen.
- format: identity `AGE-PLUGIN-SE-1…`; recipients `age1se1…`, `age1tag1…`, `age1tagpq1…` (bech32, `Sources/Plugin.swift`). frozen (D2).
- env: `AGE_PLUGIN_SE_PROMPT=<text>` — Touch ID prompt text; unset → upstream text. carried, offered upstream (PR 18).
- error: denial marker — fixed documented string in the plugin error when user denies Touch ID; ⊥ in any other error. carried, offered upstream.
- nix: `packages.aarch64-darwin.default` (`age-plugin-se`), `checks.aarch64-darwin.*`, `devShells.aarch64-darwin.default` (`nix` node).
- file: `gate/names.sh FILE…` (denylist `.private/denylist`, gitignored), `gate/commit-msg.sh MSG`; `.bats` beside each.
- file: `.actlith` → `.github/workflows/ci.yml` (fork CI, job `gate`).
- file: `release/alpine-keygen.sh [--rotate]` — PKCS#8 RSA 4096 made in memory → `gh secret set ALPINE_KEY` stdin; ⊥ file; ALPINE_KEY set → nothing done.
- file: `.pklith` → `hk.pkl` (gate, amends `pkl/Config.pkl`), `.coverage` (line-coverage ratchet floor, `paradigm/V25`), `.context-limits` (chain ceilings, `paradigm/V12`).
- tag: `v<upstream>-fork.<n>`, first `v0.2.1-fork.1` (D19). binary keeps upstream version string.
- trailer: `Paradigm-Stage: <stage>` per paradigm §I.trailer.

## §R RESEARCH

id|topic|finding|src
R1|upstream survey 2026-10-18|1,531 Swift lines in `Sources/`, 1,851 in `Tests/`, 108 test funcs, all on `DummyCrypto`; 1 dep `swift-crypto` (Linux & Windows only); one maintainer wrote 161 of 164 commits; PRs 15 & 18 open for months|`SPEC-PROMPT.md` Survey
R2|post-quantum needs Swift 6.2 2026-10-18|`SecureEnclave.MLKEM768` only under `#if compiler(>=6.2)` ∴ older compiler builds stub that throws `pqUnavailable`; upstream tests guard PQ cases the same way|`Sources/Crypto.swift:108`, `Tests/PluginTests.swift:51`
R3|build Mac toolchain 2026-10-18|Swift 6.3.3 (`arm64-apple-macosx26.0`), Command Line Tools 26.6, no Xcode. CLT ships `Testing.framework`, ⊥ `XCTest.framework` ∴ `swift test` fails `no such module 'XCTest'`. recount: `swift --version`, `pkgutil --pkg-info=com.apple.pkg.CLTools_Executables`|local probe
R4|fleet nixpkgs pin 2026-10-18|nixpkgs `26f4107e` (via nixpkgs-lock): `swift` 5.10.1, `swift-format` 5.10.1, `swiftlint` 0.63.2, `swiftformat` 0.61.1, all aarch64-darwin; `periphery` absent. recount: `nix eval --raw github:NixOS/nixpkgs/<rev>#<pkg>.version`|local probe
R5|hk 2.7.0 Swift support 2026-10-18|1 builtin: `swiftlint` (`lint {{files}}`, fix `--fix`, indicator `.swiftlint.yml`); ⊥ swift-format, ⊥ build, ⊥ test builtin|hk `pkl/builtins/swiftlint.pkl`
R6|pklith & sherd Swift support 2026-10-18|pklith catalog: 0 Swift rows (`swift` only in vendored Config.pkl type list). sherd code verbs read Rust only; Ruby filed the same gap|pklith `src/catalog`; paradigm `docs/RUBY.md`
R7|upstream warnings 2026-10-18|`swift build` on `57ccea1`: 4× `'21.0' is not a valid version number for macOS` (`#unavailable(macOS 21.0)`, `Crypto.swift:109,122`, `HPKE.swift:87,120`); fixed on fork `main` by PR #3 (`f62703c`, issue #2) → clean build 0 warnings. non-Swift file in target dir → SwiftPM `found 1 file(s) which are unhandled` (∴ D22)|local probe, PR #3
R8|argument parsing 2026-10-18|`Options.parse` hand-written in `Sources/CLI.swift`; help text separate string|`Sources/CLI.swift`
R9|build Mac Xcode 2026-10-18|Xcode 27.1 installed (D21 said 26): Swift 6.4, `xcrun --find xctest` resolves. nix darwin stdenv sets `DEVELOPER_DIR` & `SDKROOT` to apple-sdk 14.4 ∴ `/usr/bin/swift` → `tool 'swift' not found` until reset. recount: `xcodebuild -version`|local probe
R10|gate 2026-10-18|39 steps on commit, +4 on push, 2 on commit-msg (after T14, T23); coverage 88.57% (1,015/1,146 `Sources/` lines) after W1. recount: `hk.pklith.pkl`, `sherd coverage --check`|`.pklith`
R11|help ↔ parser drift 2026-10-18|`Options.parse` accepts `--age-plugin`, `--help`, `-h`, `--version`; `Options.help` names none ∴ upstream drift, baselined in `OptionsHelpTests.undocumented`, only shrinks (D13)|`Tests/OptionsHelpTests.swift`
R12|CI runner 2026-10-18|`macos-latest` = `macos-26-arm64`, Xcode 26.0.1 … 26.6; 26.6 pin ran green. `nix develop` overwrites `DEVELOPER_DIR` ∴ pin passed as `HOST_DEVELOPER_DIR`. recount: job log|runner-images readme, run 39133346951
R13|CLI error path 2026-10-18|`CLI.main` prints errors to stdout (`print`), ⊥ stderr, & exits 255 (`exit(-1)`); B1's error too. upstream style or bug: owner's call|`Sources/CLI.swift:49`, local probe

## §V INVARIANTS

V1: ∀ identity & recipient in `fixtures/` (made by upstream `v0.2.1` & `57ccea1`; sets `se-classic`, `tag-classic`, `tag-pq`; ⊥ `se-pq` ∵ `--pq` always `tag`) parses & re-encodes byte-identical in this build (D2).
V2: ∀ fixture plugin session (recipient-v1, identity-v1) → this build emits same protocol messages & stanza bytes as upstream, modulo fresh randomness pinned by `DummyCrypto` (D2).
V3: `Sources/Crypto.swift` & `Sources/HPKE.swift` ≠ upstream only in commits citing a failing test, an upstream commit | the upstream PR they carry (D4).
V4: upstream test files ⊥ edited, except by upstream sync | by a carried change whose upstream PR edits them (D7).
V5: ∀ upstream PR branch ∌ fork file (§C list) (D3).
V6: build & dev shell refuse Swift < 6.2 ∵ `--pq` would silently become `pqUnavailable` (D11, R2).
V7: ⊥ compiler warning: clean build has 0 since `f62703c` (R7) ∴ build runs `-warnings-as-errors`. warning arriving by upstream sync → baseline entry in that sync PR, baseline only shrinks (D13).
V8: `swift format lint --strict` clean on fork-written & fork-changed lines; upstream violations in baseline that only shrinks (D13).
V9: ⊥ force unwrap `!`, `try!`, `as!`, `fatalError` in fork-written Swift (swiftlint) (D13).
V10: line coverage ≥ `.coverage` floor, floor only rises; Secure-Enclave-only & terminal-only code (`CryptoKitCrypto`, `StandardIOStream`, `CLI.main`) exempt w/ reason in `.pklith` (D14). target 100% of rest (D1).
V11: ∀ option in `Options.help` parses & ∀ parsed option appears in `Options.help` (D15).
V12: `AGE_PLUGIN_SE_PROMPT` set & non-empty → Touch ID prompt = its text; unset | empty → upstream prompt text.
V13: Touch ID denied by user → plugin error carries denial marker; ∀ other error ∌ it.
V14: `keygen -o OUTPUT` write fails → exit ≠ 0, error names OUTPUT, ⊥ `Public key:` line ∵ B1.
V15: `swift test` needs ⊥ Secure Enclave & ⊥ Touch ID (`DummyCrypto`); checks needing a real one are manual & listed in `fixtures/README.md`.
V16: ∀ commit from `5fffb16` on passes hk hooks, ⊥ `--no-verify`: pre-commit checks, ⊥ stash (`paradigm/V15`); commit-msg: parsed `Paradigm-Stage:` & cited id (`paradigm/V43`, `paradigm/V27`); name guard on files & message (`paradigm/V37`); pre-push adds tests & coverage (`paradigm/V24`).
V17: upstream findings → baseline naming each file | string (`hk.pkl`, `.typos.toml`, `.secretsignore`, `.markdownlintignore`, `.pklith` exempt); only shrinks (D13).
V18: `recipients -o OUTPUT` write fails → exit ≠ 0, error names OUTPUT ∵ B2.
V19: `recipients` input empty | ⊥ UTF-8 → error, exit ≠ 0, ⊥ trap ∵ B3.

## §T TASKS

id|status|task|cites
T1|x|ARCHIVED to SPEC-ARCHIVE.md|V6,V15
T2|x|ARCHIVED to SPEC-ARCHIVE.md|V6,V15
T3|x|ARCHIVED to SPEC-ARCHIVE.md|V7
T4|x|ARCHIVED to SPEC-ARCHIVE.md|V1,V2,V15
T5|.|`Tests`: format-freeze tests over `fixtures/`, RED → GREEN|V1,V2,V4
T6|~|gate via pklith, one check per commit, planted violation each: name guard, mth & sherd steps, commit-msg, swift-format, swiftlint, warnings-as-errors, Swift ≥ 6.2, `swift test` pre-push, coverage ratchet. laid (R10) ⊥ swiftlint T18, allowlist T19, coverage exclusions T20, itok T21|V6,V7,V8,V9,V10,V16,V17
T7|x|ARCHIVED to SPEC-ARCHIVE.md|-
T8|x|ARCHIVED to SPEC-ARCHIVE.md|V11
T9|.|`Sources`: `AGE_PLUGIN_SE_PROMPT` RED → GREEN; upstream PR from `upstream/main` w/ approval|V12,V5,V3
T10|.|`Sources`: denial marker RED → GREEN; upstream PR w/ approval|V13,V5
T11|~|`Sources`: B1 fix RED → GREEN; upstream PR w/ approval. fork half done (`keygenOutput` throws `CLIError.cannotWriteOutput`); upstream PR waits for owner approval|V14,V5
T12|~|`#unavailable(macOS 21.0)` → `26.0` (R7): fixed in fork PR #3 (`f62703c`, issue #2); offer to `remko/age-plugin-se` w/ approval|V7
T13|~|issues w/ approval: pklith Swift catalog rows (pklith#87, #88), sherd Swift coverage (sherd#138; Swift data on #126, #132), paradigm Swift page & seed (paradigm#1), `paradigm/V20` `paradigm/V28` `paradigm/V29` (paradigm#2) (D16, D20); open until each lands|V8,V9,V10
T14|x|ARCHIVED to SPEC-ARCHIVE.md|V6
T15|.|first tag `v0.2.1-fork.1`; T switches its input (D19)|V1
T16|.|force-push `spec-prompt` after private-name rewrite; scrub PR #1 body (`paradigm/V37`), w/ approval|-
T17|~|wave plan, by hand ∵ `sherd wave` reads only Rust edges (sherd#132). after dev shell (T1, T2) & guardrails (T6, T14) per `paradigm/V13`: W1 = T4 `fixtures` ∥ T8 `Tests` ∥ T11 `Sources`; W2 = T5 `Tests` (needs T4) ∥ T9 `Sources`; W3 = T10 `Sources`. ∀ wave ends w/ reconcile commit (`paradigm/V18`). `Sources` task writes its RED test in `Tests/ForkCLITests.swift` ∴ `Tests` worker in same wave ⊥ touches that file. W1 merged (PRs #6 #7 #8) & reconciled (`reconcile-1`). W2 ready: T9 ⊥ deps; T5 has T4, its open items (owner reads V1, V2) in `Tests` T1, T2|V5,V15
T18|.|swiftlint: seeded `.swiftlint.yml` → 120 upstream findings; owner picks baseline convention (D13), then row laid|V9
T19|.|name guard allowlist half (`paradigm/V37`) for CI, which has ⊥ denylist; owner picks its rows|V16
T20|.|coverage exclusions w/ reasons (D14); owner picks their home (sherd#138), then floor re-recorded|V10
T21|.|itok ⊥ laid: `.context-limits` = sherd chain ceilings, itok reads it as file ceilings; owner picks|-
T22|.|owner: require `gate (macos-latest)` on `main` (D8); run `nix develop -c release/alpine-keygen.sh`, re-run `build (macos-26)`; Actions on, first run green|V6
T23|x|ARCHIVED to SPEC-ARCHIVE.md|-
T24|.|deferred until official releases: distribution key replaces T23's. private key only in ALPINE_KEY, made in memory; `--rotate` ⊥ recovery; pubs append-only in `release/keys/` w/ `revoked/`; ALPINE_KEY_NAME var names `.SIGN.RSA.<name>.pub`; fork script calls `dir2apk.go --key=`; reconcile w/ D12|-
T25|.|`Sources`: B2 fix RED → GREEN; upstream PR w/ approval. W4 ∵ `Sources` busy W2, W3 (T17)|V18,V5
T26|.|`Sources`: B3 fix RED → GREEN; upstream PR w/ approval. W4, w/ T25|V19,V5
T27|.|offer upstream: `--help`, `-h`, `--version` in `Options.help` (R11), w/ owner approval; owner picks if age-facing `--age-plugin` is listed or stays baselined. fork ⊥ edits help alone (D3); `OptionsHelpTests.undocumented` shrinks on upstream sync|V11,V5

## §B BUGS

id|date|cause|fix
B1|2026-10-18|`keygen -o` ignores `FileManager.createFile` result (`Sources/CLI.swift:23`) ∴ failed write loses identity yet prints `Public key:`; upstream bug, found in spec run|V14
B2|2026-10-18|`recipients -o` ignores `FileManager.createFile` result (`Sources/CLI.swift:32`), B1's cause in its sibling ∴ failed write exits 0, writes nothing, says nothing; upstream bug, found in W1 (PR #6), probed. sweep (`paradigm/V19`): `Sources/` has 2 `createFile` calls, both rowed|V18
B3|2026-10-18|`recipients` force-unwraps stdin (`Sources/CLI.swift:27`) ∴ empty or non-UTF-8 stdin traps, exit 133; upstream bug, probed in W1 reconcile|V19
