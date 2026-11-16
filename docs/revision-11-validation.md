# Revision 11 validation

Status: **Historical Revision 11 delivery, superseded by R12**. Source/render, independent regression, standalone Windows and canonical archive verification below record the R11 result. The follow-up screenshot exposed a separate mirrored-origin defect concealed by incorrect CPU probe semantics; see `revision-12-validation.md`. R11's proportion and seat-layout improvements remain included, as do all R9/R10 features.

PM inspected the user-provided local screenshot and confirmed the shared seated/resting atlas rescaling in `resort_map.gd`: adult 11×16 → 11×10, child 11×12 → 11×7. The existing dining visual assertion checked compressed output heights, so the regression suite needs a proportion invariant rather than retaining those heights.

The generated before reproduction `.tools/r11-seated-before.png` matches the screenshot and includes standing adult/child references. Actual default eating anchors are `(236,204)` and `(244,204)`: eight pixels apart for eleven-pixel-wide upper bodies. Root's new independent `tests/seated_proportions_test.gd` reproduces the defect with **358 checks, 120 failures**, exit 1. These failures span sampled poses, not 120 unrelated bugs. It inspects real atlas source/destination ratios, opaque head overlap across four table rotations and six bite ages, actual meal/save state and arrival/departure continuity, plus six shared resting actions across all guest rows and both facings.

The first native-scale implementation passed root's updated **358/358**, including actual `_guest_sprite` drawing-anchor continuity (`.tools/r11-root-proportions.log`). PM and root nevertheless withheld visual acceptance: `.tools/r11-seated-after.png` still put the two diners in front of the table with plates above their hats. Root authorized the minimal reachable opposite-edge seat preference described in `revision-11.md`; generated composition and dining/save/capacity checks must pass after that correction. A numeric pass alone is insufficient.

The revised composition passes root's strengthened independent suite: **375/375**, exit 0, clean log `.tools/r11-root-proportions.log`. Open-table display anchors straddle the actual west/east edges for all four rotations, plates remain on the tabletop, native head pixels remain separate through sampled bite ages, and arrival/departure drawing anchors are continuous. The six-plant cramped fixture retains a usable one-edge fallback, meal-state save/load and four completed stays.

PM and root inspected `docs/screenshots/seated-before-after.png` and `.tools/r11-table-turns.png` and accepted the normal/default and four-orientation composition: unchanged native face/body proportions, opposite chairs, bent legs and food between the diners. The separate extreme fallback image is `.tools/r11-cramped-table.png`; fallback compatibility does not imply the same open-table composition when no space exists on opposite sides. Root inspected and accepted that preserved fallback with this limitation. These are generated CPU artifacts, not native captures.

## Final source evidence

- Independent seated proportions/composition **375/375**, clean; focused visual **49/49**, including four rotated actual eating arrangements, the extreme one-open-cell fallback and 24 full-venue combinations for shared resting consumers.
- Dining contract **63**, scene **37**, renderer **27**; Layout **34**, Construction scene **46** and Simulation suite pass.
- R9 contract **210** and visual **130**; Beach contract **127** and visual **120**; R10 facility visual/actual-phase preview **1,078/1,078** pass.
- Source smoke passes with **12 stays, 95.42 rating and $1,120**, preserving all R9/R10 content. `docs/screenshots/activities-preview.png` was regenerated using the corrected shared resting art, so the current README does not retain the old cafe/companion squashing.

Rendering helper `scripts/seated_art.gd` keeps original atlas dimensions and provides consistent body/face/shoulder coordinates. Display-anchor easing preserves arrivals/departures. The only physical model change is the authorized reachable opposite west/east seat preference with existing constrained-layout fallback. No simulation/economy/save schema change or unrelated feature was introduced. Source/tests are frozen and the sole specialist is finished.

## Windows candidate

`build/r11-candidate/AllInclusive.exe` is **111,469,840 bytes**, SHA-256 `6A54FEFB80D900207505E81E76582DE7E32BF6F9531E8737B691FE03FE805DC6`. PM independently verified the file hash and read the persisted standalone log.

An executable-only copy in `.tools/r11-standalone-f6eb74efeecc412886d77c847ff3c2fa` has the same hash and ran with a fresh separate `.tools/r11-portable-appdata-f6eb74efeecc412886d77c847ff3c2fa` APPDATA profile. It exits **0** with a clean runtime log: **12 stays, 95.42 rating, $1,120**, exercising dining, terrace, all ten new facility visits, calendar, surf risk, sargassum, price lock, construction, art and audio.

Logs: `.tools/r11-logs/import.log`, `.tools/r11-logs/export.log`, `.tools/r11-logs/standalone-smoke.log`. Import/export both exit 0 and include the compiled `seated_art` resource; they retain the familiar Godot editor-startup `Safe save failed` diagnostic before successful packing. This is distinct from the clean standalone runtime.

## Final package

Root verified canonical `build/windows/AllInclusive.exe` is **111,469,840 bytes** and matches SHA-256 `6A54FEFB80D900207505E81E76582DE7E32BF6F9531E8737B691FE03FE805DC6`. `build/AllInclusive-Windows.zip` is **41,380,885 bytes**, SHA-256 `4776C5A0B3330C0457C5CC5C4D562EB60850295FC436C94E3718859C1C3C4389`. The streamed executable inside the archive matches the accepted candidate exactly.

The archive has exactly four flat entries: `AllInclusive.exe`, `START_HERE.txt`, `CREDITS.txt`, and `THIRD_PARTY_NOTICES.txt`; `build/SHA256SUMS.txt` is updated. README/launch notes identify Revision 11, link the generated before/after preview and explain opposite-side seating where space allows. R10 is backed up at `.tools/releases/AllInclusive-r10-seasons-activities-Windows.zip`.

The sole specialist is finished/released and all source/tests/previews are frozen. No desktop use, native capture, visible game/editor window, native tester resumption, Git push or release occurred. Native playtesting remains deferred; the user screenshot and offscreen before/after evidence are explicitly distinguished.

Required evidence: before/after generated actual dining frames at all table orientations with standing references, native pixel proportions, face/body separation, plate/hand/chair consistency, stable table surface, shared-resting regressions, preserved dining/model/save behavior, standalone smoke and root package hash verification. Native playtesting remains deferred; no desktop capture or visible window is permitted.
