# SPEC

## §G GOAL

format-freeze corpus (D2): identities, recipients & plugin sessions made by upstream `v0.2.1` & `57ccea1`, the bytes `.:V1` & `.:V2` compare against.

## §N NAV

rel|path|lens
up|.|-
self|fixtures|format-freeze corpus: identities, recipients & stanzas made by upstream `v0.2.1` & `57ccea1`; how each was made
sib|Sources|upstream plugin code: CLI & option parser, plugin protocol, stanzas, bech32, base64, crypto boundary; carried changes (prompt env, denial marker)
sib|Tests|XCTest target `Tests`: upstream tests as-is & fork tests beside them; `DummyCrypto`, `MemoryStream`
sib|nix|flake parts: package, checks, dev shell, host-toolchain guard
sib|Scripts|upstream build & coverage scripts (`ProcessCoverage.swift`), unchanged; ⊥ node
sib|Documentation|upstream man page sources, unchanged; ⊥ node
sib|gate|fork gate scripts: name guard (denylist half), commit-msg check & their bats tests; ⊥ node
sib|release|fork CI-only Alpine keygen & its bats test; ⊥ node

## §C CONSTRAINTS

- made once by owner on a Mac w/ Secure Enclave, w/ upstream binaries built from the named rev; ⊥ by this fork's build.
- throwaway keys made for the corpus only, `--access-control none`; ⊥ key that guards anything. Secure Enclave identity file only works on its own Mac ∴ public is safe; still never reused.
- append-only: a file ⊥ regenerated | edited; new upstream rev → new dir.
- plain files, ⊥ binary blobs w/o text twin.

## §I INTERFACES

- dir: `fixtures/<rev>/` per producer rev (`v0.2.1`, `57ccea1`).
- file: `<rev>/<se|tag>-<classic|pq>.identity`, `.recipient` — `keygen` & `recipients` output.
- file: `<rev>/<set>-<encrypt|decrypt>.session` — recorded plugin stdio, recipient-v1 | identity-v1; each line `>` (age → plugin) | `<` (plugin → age), a space, line as sent.
- file: `README.md` — per file: producer rev, exact command, date, Mac model; manual Secure Enclave checks (`.:V15`).

## §V INVARIANTS

V1: ∀ fixture file listed in `README.md` w/ producer rev & command; ∀ row has its file.
V2: fixture bytes ⊥ change after first commit (append-only).

## §T TASKS

id|status|task|cites
T1|x|ARCHIVED to SPEC-ARCHIVE.md|V1
T2|x|ARCHIVED to SPEC-ARCHIVE.md|V1
T3|x|ARCHIVED to SPEC-ARCHIVE.md|V1,V2
