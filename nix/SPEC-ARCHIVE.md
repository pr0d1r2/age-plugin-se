# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`. An id is never reused
(`V12`), so a citation to an archived row still resolves -- here.

This is a SINK, not a spec. The citations inside these rows point into
`SPEC.md`, so `mth check` on this file reports every one of them as dangling,
correctly and uselessly. The verb that reads it is `mth tasks`.

## §T TASKS

T1|x|`toolchain.sh` guard, planted old-Swift & no-XCTest runs refused (`.:T1`, `.:T2`)|V1
T2|x|package builds `57ccea1` + `f62703c` w/o source change (`.:T1`)|V2
T3|x|checks & dev shell via pklith `lib.devShell` (`.:T1`)|V2
T4|x|pre-push step (`.:T6`) runs `swift test` as `checks.aarch64-darwin.tests` does: both call `nix/test.sh`|V2
