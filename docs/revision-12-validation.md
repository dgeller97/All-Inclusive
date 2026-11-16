# Revision 12 validation

Status: **Revision 12 accepted and delivered locally**. Source, generated visual correction, standalone Windows smoke and canonical archive verification are complete.

## Reproduction and correction

`tests/actor_facing_test.gd` reproduces the bug with **75 checks, 25 failures** in `.tools/r12-facing-before.log`. It exercises all five atlas rows in standing, walking, seated, resting and swimming states, comparing both facings. The failed origin assertions explain the right diner's displaced upper body in the supplied screenshot; these are sampled cases of one shared rendering bug.

After removing the redundant horizontal position shift, the same suite passes **75/75**, with no failures in `.tools/r12-actor_facing_test.log`. The production renderer retains the body anchor and changes only the texture flip. Both CPU sprite probes and related opaque/overlay-bound helpers now match the engine's position-preserving negative-size behavior.

PM inspected the implementation, regression and `docs/screenshots/diner-facing-fix.png`. The before reproduction visibly separates the right diner's head from arms/chair; the corrected image aligns them. `tools/dining_facing_preview.gd` reproduces the previous extra offset explicitly using the corrected probe. The preview log is `.tools/r12-facing-preview.log`.

R11's native pixel scale and seating improvements remain valid, but its CPU mirror-position assumptions were wrong and concealed this additional defect. Its historical generated images were not native-render validation. R12 acceptance specifically requires the corrected renderer contract and reproduction rather than relying on those earlier passes.

## Regression evidence

Root reports clean headless passes: seated proportions/composition **375/375**, focused seated visuals **49/49**, dining visual **27**, beach visual **120**, R9 visual **130**, facility visual **1,026**, and dining scene **37**. Logs are `.tools/r12-seated_proportions_test.log`, `r12-seated_visual_test.log`, `r12-dining_visual_test.log`, `r12-beach_visual_test.log`, `r12-revision9_visual_test.log`, `r12-facility_visual_test.log` and `r12-dining_scene_test.log`, all under `.tools`.

The initial dining-scene invocation exited 2 because its isolated profile guard rejected the profile path. Re-running with `.tools/r6-dining-scene-r12` produced the clean 37-check pass; this was test setup, not a production fix.

The Windows candidate export exits 0 (`.tools/r12-export.log`). PM read the clean standalone log `.tools/r12-standalone.log`: **12 stays, 95.42 rating, $1,120**, exercising dining, terrace, all ten new facility visits, calendar, surf risk, sargassum, price lock, construction, art and audio. Root confirms standalone exit 0.

## Final package

Canonical `build/windows/AllInclusive.exe` is **111,469,824 bytes**, SHA-256 `E624AC93EEBB67FDF5124BB34A5C0D56FC1D69004E7FDF0786674FD63D8C1343`. `build/AllInclusive-Windows.zip` is **41,380,909 bytes**, SHA-256 `2BFDE992E9FABE11E0244202201776EE0B6AA83A30CFC813EF2434FC6EC95232`.

Root verified exactly four flat archive entries (`AllInclusive.exe`, `START_HERE.txt`, `CREDITS.txt`, `THIRD_PARTY_NOTICES.txt`) and streamed the embedded executable to confirm the same accepted hash. `build/SHA256SUMS.txt` is updated. The R11 backup is `.tools/releases/AllInclusive-r11-seated-Windows.zip`. README and launch notes identify R12. Source/docs are frozen for local delivery.

All checks are headless or generated file inspections. No desktop use, native capture, visible game/editor window or native tester resumption occurred. Native playtesting remains deferred. Changes remain local; no Git push or release.
