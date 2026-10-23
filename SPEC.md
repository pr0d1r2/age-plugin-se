# SPEC

## §G GOAL

`age-plugin-se` hard fork (owner 2026-10-23, upstream silent) of upstream `remko/age-plugin-se` (age plugin; identity in Mac Secure Enclave; Touch ID per decrypt) + nix flake, hk gate & federated spec, built paradigm's way. ⊥ new product. formats byte-identical w/ upstream. functional changes ⊥ offered upstream (V5 off). daily consumer: T (private secrets tool, named by letter only).

PARADIGM: paradigm `6c7e6cd` (no tag yet, D9), used as process; repo ⊥ fleet member yet (D1). cited `paradigm/V<n>`.

LINEAGE: `SPEC-PROMPT.md` (HISTORICAL after this run). where it & this spec differ, this spec wins. prompt decisions cited as `D<n>`.

## §F FEDERATION

dir|owns|⊥owns|tokens
Sources|upstream plugin code: CLI & option parser, plugin protocol, stanzas, bech32, base64, crypto boundary; fork changes (prompt env, denial marker, CLI bug fixes)|tests (`Tests`), fixture bytes (`fixtures`), build (`nix`)|-
Tests|XCTest target `Tests`: upstream tests as-is & fork tests beside them; `DummyCrypto`, `MemoryStream`|product code (`Sources`), fixture bytes (`fixtures`)|-
fixtures|format-freeze corpus: identities, recipients & stanzas made by upstream `v0.2.1` & `57ccea1`; how each was made|tests reading it (`Tests`), the formats (upstream)|-
nix|flake parts: package, checks, dev shell, host-toolchain guard|gate rows (root `.pklith`), CI workflow (root)|-
Scripts|upstream build & coverage scripts (`ProcessCoverage.swift`), unchanged; ⊥ node|fork gate & coverage ratchet (root)|-
Documentation|upstream man page sources, unchanged; ⊥ node|fork docs (`docs`; root `README.md` stays upstream's)|-
docs|fork notices & LLM disclaimer; ⊥ node|`LICENSE.txt` (root)|-
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
- hard fork (owner 2026-10-23, amends D3 & D18): ⊥ merge from upstream; upstream fix ported by hand when wanted (as PR #22 ported upstream PR 15); `Sources/` change ⊥ minimises diff vs upstream, fork style allowed. upstream PR only if owner reopens V5: branch from `upstream/main`, ⊥ fork file (`SPEC*.md`, `FORMAT*.md`, `flake.*`, `nix/`, `fixtures/`, `docs/`, `.pklith`, `hk.pkl`, `.coverage`, `.context-limits`, fork CI).
- `LICENSE.txt` = upstream's + 1 fork copyright line under its own: owner decision 2026-10-18, exception to D3.
- upstream tests kept & run as-is (D7); fork tests in own files beside them.
- Swift ≥ 6.2 & macOS SDK from host; nix pins every other tool (D11). tests need Xcode's XCTest (D21). `.macOS(.v14)`; ML-KEM `@available(macOS 26)` (V6).
- darwin aarch64 & x86_64 (owner 2026-10-21, amends D12). fork CI = GitHub macOS runner running same `hk.pkl`; upstream `build.yml` untouched.
- `Sources/` & `Tests/` flat, ⊥ moved (D17). ⊥ 2 workers in `Sources` in one wave. node `SPEC.md` inside a SwiftPM target dir excluded in `Package.swift` (D22).
- gate = one `hk.pkl` from `.pklith` (`paradigm/V23`). Swift rows local first, then filed upstream (D13, D16). upstream code ⊥ reformatted; its debt baselined (V17).
- `main` protected, PR-only (D8). ∀ PR human review (D5).
- outward acts (push, upstream PR, issue, comment, tag) need explicit owner approval. private repos ⊥ named (`paradigm/V37`).
- prose for humans in pages; caveman only in `SPEC.md` files.

## §I INTERFACES

- cmd: `age-plugin-se keygen [--pq] [-o OUTPUT] [--access-control ACCESS_CONTROL] [--recipient-type se|tag]` — upstream, unchanged. access controls: `none` `passcode` `any-biometry` `any-biometry-or-passcode` (default) `any-biometry-and-passcode` `current-biometry` `current-biometry-and-passcode`.
- cmd: `age-plugin-se recipients [--pq] [-o OUTPUT] [-i INPUT] [--recipient-type se|tag]` — upstream, unchanged.
- cmd: `age-plugin-se --age-plugin=recipient-v1|identity-v1` — age plugin protocol over stdio, upstream, frozen.
- format: identity `AGE-PLUGIN-SE-1…`; recipients `age1se1…`, `age1tag1…`, `age1tagpq1…` (bech32, `Sources/Plugin.swift`). frozen (D2).
- env: `AGE_PLUGIN_SE_PROMPT=<text>` — Touch ID prompt text; unset → upstream text. fork change (cf. upstream PR 18).
- error: denial marker `AGE_PLUGIN_SE_DENIED_V1: <error text>` opens identity-v1 unwrap `msg` iff user cancelled | failed Touch ID; callers match prefix (owner 2026-10-23). fork change.
- nix: `packages.<sys>.default` (`age-plugin-se`), `checks.<sys>.*` & `devShells.<sys>.default`, sys `{aarch64,x86_64}-darwin` (`nix` node).
- file: `gate/names.sh FILE…` (denylist `.private/denylist`, gitignored), `gate/commit-msg.sh MSG`, `gate/universal.sh [BIN]` (push: arm64 & x86_64, `minos` 14.0), `gate/coverage.sh` (push: `sherd coverage --check`; macOS < 26 → notice, exit 0; `AGE_PLUGIN_SE_MACOS_MAJOR` overrides); `.bats` beside each & `release/*.sh` (`exists` rules); push: `bats-changed` for changed, `bats-unit` all.
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
R11|help ↔ parser drift 2026-10-18|`Options.parse` accepts `--age-plugin`, `--help`, `-h`, `--version`; `Options.help` names none ∴ upstream drift, baselined in `OptionsHelpTests.undocumented`, only shrinks (D13)|`Tests/Fork/CLIForkTests.swift`
R12|CI runner 2026-10-18|`macos-latest` = `macos-26-arm64`, Xcode 26.0.1 … 26.6; 26.6 pin ran green. `nix develop` overwrites `DEVELOPER_DIR` ∴ pin passed as `HOST_DEVELOPER_DIR`. recount: job log|runner-images readme, run 39133346951
R13|CLI error path 2026-10-18|`CLI.main` prints errors to stdout (`print`), ⊥ stderr, & exits 255 (`exit(-1)`); B1's error too. upstream style or bug: owner's call|`Sources/CLI.swift:49`, local probe
R14|macOS 14 port 2026-10-21|∀ `fixtures/` identity & recipient re-encodes same; ∀ session replayed on stand-in keys → same bytes before & after (`.:T30`). w/ Swift ≥ 6.2 below macOS 26, 7 upstream PQ tests fail or trap ∴ skip there. nixpkgs 26.05 = last w/ `x86_64-darwin`; pklith & actlith ⊥ `x86_64-darwin` shell or runner; pklith shell since `028c65c` (pklith PR 103)|local probe, PR body

## §V INVARIANTS

V1: ∀ identity & recipient in `fixtures/` (made by upstream `v0.2.1` & `57ccea1`; sets `se-classic`, `tag-classic`, `tag-pq`; ⊥ `se-pq` ∵ `--pq` always `tag`) parses & re-encodes byte-identical in this build (D2).
V2: ∀ fixture plugin session (recipient-v1, identity-v1) → this build emits same protocol messages & stanza bytes as upstream, modulo fresh randomness pinned by `DummyCrypto` (D2).
V3: `Sources/Crypto.swift` & `Sources/HPKE.swift` ≠ upstream only in commits citing a failing test, an upstream commit | the upstream PR they carry (D4).
V4: upstream test files ⊥ edited, except by a hand port of upstream | a fork change's test seam (D7).
V5: ∀ upstream PR branch ∌ fork file (§C list) (D3). deferred (owner 2026-10-21); off for good unless owner reopens (owner 2026-10-23).
V6: build & dev shell refuse Swift < 6.2 ∵ `--pq` would silently become `pqUnavailable` (D11, R2). macOS ≥ 14; ML-KEM-768 only on macOS 26, else `pqUnavailable` ⊥ trap (owner 2026-10-21).
V7: ⊥ compiler warning: clean build has 0 since `f62703c` (R7) ∴ build runs `-warnings-as-errors`. warning arriving by upstream sync → baseline entry in that sync PR, baseline only shrinks (D13).
V8: `swift format lint --strict` clean on fork-written & fork-changed lines; upstream violations in baseline that only shrinks (D13).
V9: ⊥ force unwrap `!`, `try!`, `as!`, `fatalError` in fork-written Swift (swiftlint) (D13).
V10: line coverage ≥ `.coverage` floor, floor only rises; Secure-Enclave-only fns exempt by `.coverage` `exclude` row w/ reason; `excluded` cap only falls (D14). target 100% of rest (D1). floor measured on macOS 26 ∵ PQ tests skip below ∴ `coverage` row (`gate/coverage.sh`) skips w/ notice on macOS < 26; CI & macOS 26 hosts hold it.
V11: ∀ option in `Options.help` parses & ∀ parsed option appears in `Options.help` (D15).
V12: `AGE_PLUGIN_SE_PROMPT` set & non-empty → Touch ID prompt = its text; unset | empty → upstream prompt text.
V13: Touch ID denied by user → plugin error carries denial marker; ∀ other error ∌ it. denial = user acts only (owner 2026-10-23): cancel | failed match; lockout, unavailable, system | app cancel, fallback, non-interactive ⊥ denial.
V14: `keygen -o OUTPUT` write fails → exit ≠ 0, error names OUTPUT, ⊥ `Public key:` line ∵ B1.
V15: `swift test` needs ⊥ SE, ⊥ Touch ID (`DummyCrypto`); real SE: `Tests/§I` gated | `fixtures/README.md` manual.
V16: ∀ commit from `5fffb16` on passes hk hooks, ⊥ `--no-verify`: pre-commit checks, ⊥ stash (`paradigm/V15`); commit-msg: parsed `Paradigm-Stage:` & cited id (`paradigm/V43`, `paradigm/V27`); name guard on files & message (`paradigm/V37`); pre-push adds tests & coverage (`paradigm/V24`).
V17: upstream findings → baseline naming each file | string (`hk.pkl`, `.typos.toml`, `.secretsignore`, `.markdownlintignore`, `.pklith` exempt); only shrinks (D13).
V18: `recipients -o OUTPUT` write fails → exit ≠ 0, error names OUTPUT ∵ B2.
V19: `recipients` stdin ⊥ UTF-8 → error, exit ≠ 0, ⊥ trap; empty = empty `-i` file: ⊥ recipient, exit 0 ∵ B3.

## §T TASKS

id|status|task|cites
T1|x|ARCHIVED to SPEC-ARCHIVE.md|V6,V15
T2|x|ARCHIVED to SPEC-ARCHIVE.md|V6,V15
T3|x|ARCHIVED to SPEC-ARCHIVE.md|V7
T4|x|ARCHIVED to SPEC-ARCHIVE.md|V1,V2,V15
T5|.|`Tests`: format-freeze tests over `fixtures/`, RED → GREEN|V1,V2,V4
T6|~|gate via pklith, one check per commit, planted violation each: name guard, mth & sherd steps, commit-msg, swift-format, swiftlint, warnings-as-errors, Swift ≥ 6.2, `swift test` pre-push, coverage ratchet. laid (R10) ⊥ swiftlint T18, allowlist T19, itok T21|V6,V7,V8,V9,V10,V16,V17
T7|x|ARCHIVED to SPEC-ARCHIVE.md|-
T8|x|ARCHIVED to SPEC-ARCHIVE.md|V11
T9|x|ARCHIVED to SPEC-ARCHIVE.md|V12,V3
T10|x|ARCHIVED to SPEC-ARCHIVE.md|V13
T11|x|ARCHIVED to SPEC-ARCHIVE.md|V14
T12|x|ARCHIVED to SPEC-ARCHIVE.md|V7
T13|~|issues w/ approval: pklith Swift catalog rows (pklith#87, #88), sherd Swift coverage (sherd#138; Swift data on #126, #132), paradigm Swift page & seed (paradigm#1), `paradigm/V20` `paradigm/V28` `paradigm/V29` (paradigm#2) (D16, D20); open until each lands|V8,V9,V10
T14|x|ARCHIVED to SPEC-ARCHIVE.md|V6
T15|.|first tag `v0.2.1-fork.1`; T switches its input (D19)|V1
T16|.|force-push `spec-prompt` after private-name rewrite; scrub PR #1 body (`paradigm/V37`), w/ approval|-
T17|~|wave plan by hand ∵ `sherd wave` reads only Rust edges (sherd#132): W1 = T4 ∥ T8 ∥ T11, merged & reconciled (`reconcile-1`); W2 = T5 `Tests` ∥ T9 `Sources`; W3 = T10 `Sources`; each ends w/ reconcile commit (`paradigm/V18`). `Sources` task's RED test in its `Tests/Fork` mirror ∴ ⊥ `Tests` worker there. T5 waits on owner (`Tests` T1, T2)|V5,V15
T18|.|swiftlint: seeded `.swiftlint.yml` → 120 upstream findings; owner picks baseline convention (D13), then row laid|V9
T19|.|name guard allowlist half (`paradigm/V37`) for CI, which has ⊥ denylist; owner picks its rows|V16
T20|x|ARCHIVED to SPEC-ARCHIVE.md|V10
T21|.|itok ⊥ laid: `.context-limits` = sherd chain ceilings, itok reads it as file ceilings; owner picks|-
T22|.|owner: require `gate (macos-latest)` on `main` (D8); run `nix develop -c release/alpine-keygen.sh`, re-run `build (macos-26)`; Actions on, first run green|V6
T23|x|ARCHIVED to SPEC-ARCHIVE.md|-
T24|.|deferred until official releases: distribution key replaces T23's. private key only in ALPINE_KEY, made in memory; `--rotate` ⊥ recovery; pubs append-only in `release/keys/` w/ `revoked/`; ALPINE_KEY_NAME var names `.SIGN.RSA.<name>.pub`; fork script calls `dir2apk.go --key=`; reconcile w/ D12|-
T25|x|ARCHIVED to SPEC-ARCHIVE.md|V18
T26|x|ARCHIVED to SPEC-ARCHIVE.md|V19
T27|.|offer upstream: `--help`, `-h`, `--version` in `Options.help` (R11), w/ owner approval; owner picks if age-facing `--age-plugin` is listed or stays baselined. fork ⊥ edits help alone (D3); `OptionsHelpTests.undocumented` shrinks on upstream sync|V11,V5
T28|x|ARCHIVED to SPEC-ARCHIVE.md|V10
T29|x|ARCHIVED to SPEC-ARCHIVE.md|V10
T30|~|macOS 14 & Intel (owner 2026-10-21): PR 15 ported + `isMLKEMAvailable` seam; `x86_64-darwin` package & checks; `universal` row|V6,V1,V2
T31|.|owner: Intel Mac (A1990): macOS 15.6+, Xcode 26, clone, `nix develop` (1st run builds hk, sherd, mth, itok, pklith, actlith from source: ⊥ x86_64 cache), `swift package resolve` once before 1st push (else pre-push hook may fail on SwiftPM's dependency clone), hooks, `swift test`, `hardware` row. `coverage` row skips there (V10)|V6,V15,V10
T32|~|`x86_64-darwin` shell done (pklith `028c65c`); macOS 15 CI row ⊥ in actlith (`macos-latest` only); issue w/ approval|V6

## §B BUGS

id|date|cause|fix
B1|2026-10-18|`keygen -o` ignores `FileManager.createFile` result (`Sources/CLI.swift:23`) ∴ failed write loses identity yet prints `Public key:`; upstream bug, found in spec run|V14
B2|2026-10-18|`recipients -o` ignores `FileManager.createFile` result (`Sources/CLI.swift:32`), B1's cause in its sibling ∴ failed write exits 0, writes nothing, says nothing; upstream bug, found in W1 (PR #6), probed. sweep (`paradigm/V19`): `Sources/` has 2 `createFile` calls, both rowed|V18; fork fixed (T25)
B3|2026-10-18|`recipients` force-unwraps stdin (`Sources/CLI.swift:27`) ∴ empty or non-UTF-8 stdin traps, exit 133; upstream bug, probed in W1 reconcile|V19; fork fixed (T26)
