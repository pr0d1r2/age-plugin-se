# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`. An id is never reused
(`V12`), so a citation to an archived row still resolves -- here.

This is a SINK, not a spec. The citations inside these rows point into
`SPEC.md`, so `mth check` on this file reports every one of them as dangling,
correctly and uselessly. The verb that reads it is `mth tasks`.

## §T TASKS

T1|x|prompt env, RED → GREEN (`.:T9`): written fresh, ⊥ diffed against upstream PR 18 (unread, owner's call)|V2,V3
T2|x|denial marker, RED → GREEN (`.:T10`): `Plugin.isDenial` by code, 4 codes, underlying errors followed|V1,V3
T3|x|B1: `keygen -o` write failure → error, RED → GREEN (`.:T11`)|V3
T4|x|B2: `recipients -o` write failure → error, RED → GREEN (`.:T25`)|V3
T5|x|B3: `recipients` empty or non-UTF-8 input → error ⊥ trap, RED → GREEN (`.:T26`)|V3
