# Revision 14 validation

Status: **Revision 14 accepted and delivered locally**. Source, independent headless behavior, standalone Windows and archive verification are complete. Both specialists are finished and source is frozen.

## Runtime rendering and fixture contract

PM read `scripts/animation_viewer.gd` and `scripts/animation_preview.gd`. Panels contain ordinary production `ResortMap` instances under `SubViewportContainer`/`SubViewport`, call `ResortMap.present`, and use the attached actor draw callbacks. There is no CPU pixel compositor or overridden texture-region draw implementation. Local fixtures use actual rotated model geometry and shared production poses, with ID allocator restoration. All panels sample the same phase/time; ocean clips explicitly use a single fixed-coast panel.

Independent review confirmed that headless Godot dispatches actual `actors.draw` callbacks and binds `ViewportTexture`. These checks establish runtime-path wiring, not rendered pixel correctness under the dummy rendering backend. No native capture or visible window was used.

## Issues caught before acceptance

- Root's original modal integration allowed `ResortUI._input` to consume viewer clicks and close the underlying Settings popup before GUI handling. Root now preserves and disables HUD input processing while the viewer is visible, then restores it.
- Opening during a construction/pan gesture now cancels only the unfinished pointer gesture, preserving the actual draft, selection and camera transform. This prevents a stuck or accidentally committed drag after closing.
- Independent first-run assertions found the walking fixture could not prepare all four rotations; matching the rotated room and furniture footprints corrected the door/bed clearance conflict. Dining fixtures rotate the actual table/counter assets, not the entire restaurant; the corresponding overstrict test expectations were corrected.
- Keyboard focus remains inside the viewer through an explicit enabled-control cycle. Root preserves/restores prior focus. Walking Fit now follows the actor group at readable scale, with optional 2×/4× magnification and a common span across rotations.
- PM found off-grid seeks could skip a numbered frame because the displayed frame used floor while stepping used round. Next/prior stepping now moves to the next/prior 30Hz boundary, with off-grid assertions rather than only already-aligned timestamps.

The initial root integration passed **13/13** in `.tools/r14-viewer-scene.log`; the initial `.tools/r14-source-smoke.log` correctly failed on walking preparation and is historical failed evidence. The final expanded controller suite passes **42/42** (`.tools/r14-final-scene.log`), including fourteen Tab and fourteen Shift+Tab traversals plus Space from welcome without changing the covered run, live/Settings/draft entry, actual mouse handling, transient gesture cancellation and exact save/allocator preservation. UI geometry passes **2,075/2,075** (`.tools/r14-final-ui.log`); this is geometry coverage, not 2,075 distinct gameplay scenarios or rendered UI inspection.

The implementer's `tests/animation_viewer_fixture_test.gd` passes **304/304** across all twenty clips and applicable phases at beginning/middle/end, body framing and deterministic seeking (`.tools/r14-animation-fixtures.log`). PM reviewed the final frame-boundary, shared framing and magnification code.

Final independent `tests/animation_viewer_contract_test.gd` completes naturally with **852/852**, no failures or runtime diagnostics (`.tools/r14-viewer-contract-release.log`). It checks actual draw callbacks and ViewportTexture bindings for all twenty clips; four-way geometry/poses/capacity and fixed-coast exceptions; phase/time synchronization; single/full occupancy, three adult variants, speed/pause/seeking and off-grid frame boundaries; Fit/2×/4× pose/time preservation; actual Tab/Shift+Tab/Space and pointer Play; cleanup/reopen; and unrelated simulation, allocator and saved-file byte preservation.

The independent reviewer reran root integration **42/42** (`.tools/r14-scene-systems-review.log`) and the integrated source smoke (`.tools/r14-systems-source-smoke.log`), exit 0, covering all twenty viewer clips, all fourteen Developer visits and unchanged Regular **12 stays, 95.42 rating, $1,120** with prior feature checks. Developer scene **59/59** also passes. PM read the final completion logs. No production animation behavior was redesigned; changes are isolated inspection fixtures/viewer and main UI integration.

Final suites must finish naturally with their completion banners. A Godot `--quit-after` timeout returning exit 0 is not proof that awaited-frame tests completed.

## Final Windows delivery

The existing `build/windows/AllInclusive.exe` was locked by the user's running R13 game. Root preserved that process/executable and restored its matching launch note from `.tools/releases/AllInclusive-r13-showcase-Windows.zip`. **The new R14 executable is `build/windows-r14/AllInclusive.exe`**, not the older `build/windows` file. No process was stopped and no desktop interaction occurred.

R14 executable: **111,569,336 bytes**, SHA-256 `EA1EED17744BA79C32B5FB1DEEE1F83502F0D32286651C298628940E2D96A8DD`. Current `build/AllInclusive-Windows.zip`: **41,480,125 bytes**, SHA-256 `CADBFB962278240AC0A5824B817D03A29B9A0B244C62C4293B7CAEAD2E2F22B2`.

Root verified exactly four flat archive entries (`AllInclusive.exe`, `START_HERE.txt`, `CREDITS.txt`, `THIRD_PARTY_NOTICES.txt`) and streamed the embedded executable to verify the accepted R14 hash. `build/SHA256SUMS.txt` and README point to the versioned current executable. Export exits 0 (`.tools/r14-export.log`). Standalone smoke exits 0 with a clean `.tools/r14-standalone.log`, including all twenty viewer clips, all fourteen Developer activities and unchanged Regular **12 stays, 95.42 rating, $1,120**. PM read that log and independently matched the versioned executable hash.

All work remains local. No Git push/release, native capture, visible-window launch or native tester resumption. Runtime callback/geometry and standalone checks do not establish rendered pixel correctness; the viewer is provided for the user's direct inspection.
