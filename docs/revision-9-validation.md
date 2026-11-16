# Revision 9 validation

Status: R9 source/art/headless acceptance complete and delivered in the verified combined R9/R10 Windows archive. Per root's direction, no separate intermediate R9 export was made. See `revision-10-validation.md` for final standalone, executable and archive evidence. Native playtesting remains deferred by user instruction.

## Initial evidence

- Root delivered `scripts/resort_calendar.gd` and reports `tests/calendar_test.gd` passes 104,130 checks over a two-year invariant sweep. This is a large set of numeric invariants, not 104,130 gameplay scenarios. Seasonal research is documented in `seasonal-research.md`.
- Visual source inspection reproduced replacement court artwork and an occupancy-driven table atlas subregion in `resort_map.gd`. Corrections and rendered invariance checks are pending.
- Root's final clean independent R9 contract now reports **210 checks, zero failures**, exit 0 with no parse/runtime diagnostics. It covers all building types over four turns with contents and save roundtrip, atomic collision rejection, real shared-room routes including minimum 16-pixel staggered contact and corner-only non-merge, group finishes/rotation/selected-room demolition/rejoin, price lock and exact cash, actual 31-day calendar progression, cleanup and review penalties, and six-day Safe/Allow-red/Closed runs with active-phase restored states compared against the uninterrupted simulation. An earlier provisional run logged a visual finish-script parse error despite exit 0; that defect is fixed and the clean rerun supersedes it.
- No computer use, visible game/editor windows, native captures or tester resumption. No R9 Git push or release.

## Final acceptance evidence

- **Routed R9 scene 24/24:** actual viewport mouse input for price and policy controls, cleanup transaction, draft-only rotation, facade/roof previews in neutral edit light, apply/save/load, real R8-envelope migration and eight malformed new-state cases rejected atomically.
- **Visual suites:** R9 133/133, building renderer 113/113, dining visual 34/34 and beach visual 121/121. PM and root inspected generated `.tools/r9-rotation-atlas.png`, `.tools/r9-architecture.png` and `.tools/r9-activity.png`. Upright orientation, stable table/court materials, connected L-shaped roof/interior openings, seasonal shoreline and swimming poses are coherent. The initial north-facing door-on-roof artifact was corrected to proper occlusion; side entrances lie on exposed wall strips. A plaque that obscured an internal opening was also moved. These are CPU-generated visual artifacts, not native screenshots.
- **Model and scene regressions:** layout 34, landscape 63 plus legacy 12 and scene 35, consistency 137, construction transactions 24 and scene 46 plus resume 6, identity 43 and appearance 46, dining contract 63 and scene 37, beach contract 127 and scene 60, Facilities 616 (includes geometry), management UI geometry 2,069, independent management 73 plus resume 9, and simulation suite pass. Three prior expectations were updated for intentional adjacency, added finish fields and continuous pricing behavior.
- **Legacy fixtures:** authentic v1 4/4 and derived v2 4/4 passed. The focused R9 scene also verifies a pre-expansion R8 save retains its price and receives default rotation/safe swim policy/zero buildup.
- **Extended source smoke:** exit 0, 12 stays, 95.42 rating, $1,120. Additional smoke fixtures exercise actual ocean use, calendar/light, sargassum, a locked $135 booking, building rotation/roof, and a red-flag incident with save roundtrip. No intermediate export was made.

Core persisted logs include `.tools/r9-source-smoke.log`, `.tools/r9-v1-final.log`, `.tools/r9-independent_acceptance-tester-appdata-r9-core-v2-v2.log`, and `.tools/r9-construction_scene_test-tester-appdata-r3-design-r9-core-resume.log`. Other root results were reported from isolated headless CLI stdout. Specialists confirmed source frozen for this acceptance before commencing the separately scoped R10 pass.

Root preserved accepted generated visuals as `docs/screenshots/architecture-preview.png`, `docs/screenshots/interactions-preview.png`, and `docs/screenshots/rotation-preview.png` before the expansion pass.

Every R9 feature in `revision-9.md` has implementation and automated/source or generated-visual evidence. Final Windows portability/package verification is complete in the combined R9/R10 build, recorded in `revision-10-validation.md`. No native playtesting, Git push or release occurred.
