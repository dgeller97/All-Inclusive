# Revision 10 and combined-build validation

Status: **combined R9/R10 delivered locally and accepted**. Source, functional/UI, generated-visual, standalone Windows and canonical archive verification are complete. R9 evidence is preserved in `revision-9-validation.md`; the R8 artifact is superseded and backed up.

## Required evidence

- All ten catalog kinds at all four orientations: actual footprint/gate, purchase/refund, capacity and unique slots, sole-optional-venue visitation, all three leisure phases, active save/resume and completion; nightclub schedule and Developer no-resale behavior.
- Routed Facilities Water/Sport/Social selection, visible prices/Free, move/rotate/bulldoze, draft/queue/save and non-overlapping readable controls in both Build and the Leisure summary.
- Every new venue has coherent upright art and grounded family poses, including full-capacity samples for three-slot water venues and four-slot nightclub. Entry/activity/departure transitions must match rotated gates. Base materials remain stable.
- R9 rotation/connected architecture/exteriors, seasonal ocean risk/cleanup/pricing and legacy save regressions remain clean.
- A generated catalog/activity preview is inspected by PM and root. Detailed rotation/phase atlases are offscreen artifacts, not native screenshots.
- The final Windows executable passes standalone smoke in an isolated profile. Root verifies canonical and archived executable hashes, four-entry archive and checksum sidecar.

Root owns `tests/activity_expansion_test.gd`; core and visual specialists own their separate routed/render tests. No computer use, visible windows, native tester resumption, Git push or release.

## Evidence received

Root's independent `activity_expansion_test.gd` passes **1,395 checks, zero failures**, exit 0 with clean diagnostics under isolated `.tools/r10-root-appdata`. These checks span 50 venue scenarios: all ten kinds at all four orientations in Regular mode plus ten Developer cases. Each venue is moved to another location before use, verifying a changed actual entrance, free movement and preserved paid basis. The tests exercise each as the sole optional venue, all three leisure phases, unique slots/capacity, actual completion/checkout, saved continuation against uninterrupted play, purchase and half-paid refund (or zero Developer resale), and unchanged four-starter layout. This accepts the functional model; UI/render acceptance is still pending.

Routed R10 scene **79/79** passes with real viewport input for placement, Rotate, Move and Bulldoze of every new kind, queued payment/load and installed capacity. It installs all 14 facilities, scrolls the Leisure list to Nightclub with an actual wheel event, and verifies the world camera remains unchanged. Persisted evidence: `.tools/r10-scene-routed.log`.

Routed Beach catalog **70/70** and management UI geometry **2,067/2,067** pass. Build → Facilities opens Water with Sport/Social choices and readable six-tile Social catalog; Leisure uses a scrolling installed-venue capacity list. PM reviewed the 1140-pixel palette and capacity-list implementation; native rendering is not claimed.

Expanded source smoke is clean: **12 stays, 95.42 rating, $1,120**, plus actual visits to all ten new kinds (`.tools/r10-core-source-smoke.log`). Root reran R9 independent acceptance **210/210** under `.tools/r10-root-r9-appdata` and the calendar invariant sweep **104,130** under `.tools/r10-root-calendar-appdata`; both clean. Full-capacity render/pose acceptance and the final standalone package remain pending.

Final core regression checkpoint: R9 contract 210 and scene 24, construction consistency 137 and scene 46, Facilities scene 666, Beach scene 70 and contract 127, dining scene 37 and contract 63, layout 34, landscape 63/scene 35/legacy 12, identity 43/appearance 46, camera 34, management UI geometry 2,067, simulation and calendar all pass. Independent management **73/73** also completes, including 48 seeded staffing schedules with sampled state restores (`.tools/r10-final-independent.log`). No further functional regression is needed unless subsequent production changes affect these areas.

## Visual acceptance and freeze

`tests/facility_visual_test.gd -- --preview` passes **1,078/1,078**. The base suite has 1,026 checks; preview adds 40 full-reservation surface-overlay comparisons, ten actual saved-phase restore checks and two PNG writes. It covers all ten kinds × four orientations, dry rotated gates, full-capacity separation, bounded continuous activity motion, actual wet/elevated interaction and unchanged base materials. Entry columns are nine pixels apart with at least six-pixel separation between all gate anchors; actors pass the real gate waypoint before spreading across the apron.

The initial full-capacity review found narrow gate overlap, an adult/climber overlap at 180°, lap wakes during dry travel and cropped waterpark QA cards. These are corrected, with stronger gate spacing assertions and regenerated previews. No behavioral checks were weakened. Final non-preview regression counts are R9 visual 130, building 112, dining 27 and beach 120; differences from earlier preview totals are PNG/extra preview scenario checks, not removed assertions.

PM and root inspected the generated ten-venue [activities preview](screenshots/activities-preview.png) and `.tools/r10-activity-turns-full.png`. Each activity is distinct and readable; waterpark geometry is fully visible, climbing participants remain separate, cafe service/seating and nighttime full-capacity dancing are coherent. The public image contains real saved activity-phase samples rendered offscreen. Neither artifact is a desktop capture or evidence of native playtesting.

Both specialists are finished and source/tests are frozen. The final candidate passed isolated standalone verification and root verified the canonical archive.

## Executable and portability

`build/r10-candidate/AllInclusive.exe` is **111,469,712 bytes**, SHA-256 `1815D813B5CA8DFEBDFE8EE6DBB34DC5D99447A7C59081DD2E5D1234B73F12D0`. PM independently calculated the same hash and read persisted routed and standalone output. The executable-only copy in `build/r10-portable-smoke/` matches this hash.

With isolated workspace APPDATA, the standalone executable exits **0** with **no runtime warnings/errors**. Its smoke reports **12 stays, 95.42 rating, $1,120**, and exercises dining, terrace, all ten added facility visits, calendar, surf risk, sargassum, locked price, construction, art and audio. Evidence: `.tools/r10-standalone-smoke.log`.

Final headless import and release export both exit 0. Logs `.tools/r10-export-import.log` and `.tools/r10-release-export.log` each contain the known Godot Windows editor-startup `Safe save failed` diagnostic before project scanning, as in prior revisions. The operations complete and the packaged runtime is clean; this editor-only diagnostic is not hidden or represented as a failed runtime test.

## Final archive

Canonical `build/windows/AllInclusive.exe` is **111,469,712 bytes** and matches the accepted executable hash above. `build/AllInclusive-Windows.zip` is **41,380,445 bytes**, SHA-256 `61FDD6C1F15936F799033E16D02ED466EF37BCDEBB4FCA59D91FCC5467677593`. Root streamed the executable inside the archive and confirmed its hash matches the candidate. Exactly four flat entries are present: `AllInclusive.exe`, `START_HERE.txt`, `CREDITS.txt`, and `THIRD_PARTY_NOTICES.txt`. `build/SHA256SUMS.txt` is updated.

Root confirmed final README/launch notes contain current controls, costs, activity-pool/prefab limits and generated-preview labels. The previous R8 archive is preserved at `.tools/releases/AllInclusive-r8-consistent-construction-Windows.zip`. Baseline commit `37e2520795bc1847e121705ba30693f95bb2cc43` was pushed before this work as requested; new R9/R10 changes remain local and the existing published v0.3.0 release is unchanged. No native playtesting, desktop capture, visible game/editor window or Git publication is claimed. PM acceptance is complete with both specialists released.
