# Revision 15 validation

Status: **Revision 15 accepted and delivered locally**. Source, independent audit, generated visual review, standalone Windows and final archive verification are complete. Production is frozen and both specialists are finished.

## Baseline evidence

Source review by root, PM and independent reviewer confirms the same structural fault: complete scenery and furniture are submitted before all guests. Actor sorting cannot allow the earlier opaque asset pixels to cover later actors/effects. Static climbing-wall art also needs orientation-aware front/side/back inspection; rear-view holds/rope drawn last can be incorrect even without guests.

The independent probe `.tools/r15-baseline-depth.gd` samples the exact reported climbing Activity **5.47/12 seconds**. Actual submitted opaque actor texels overlap rock pixels: 0° climber 0/belayer 32; 90° climber 46/belayer 0; 180° climber 21/belayer 71; 270° climber 46/belayer 0. Submitted rope rectangles also overlap rock: 180° belayer 6; 270° belayer 1/climber 2. These counts identify coverage that the old earlier scenery CanvasItem cannot occlude. They are sampled submitted geometry/order, not native rendered output or counts of separate bugs.

## Accepted implementation direction

The production painters now produce cached ground/upright layers, interleaved with guests/effects by physical projected contact depth. Static rotated front/side/back artwork is corrected. `_depth_plan()` and `_draw_depth_item()` expose the actual production submissions for independent audit. Varying-depth surfaces and climbing ropes use segments rather than blanket whole-prop foreground masks. Balls, lights and surface-contact effects have distinct depth records. The same path drives the world and Animation Viewer, including incidental walkers. Design rendering retains its static fallback.

Root owns core `building_renderer.gd`/`furniture_depth.gd` layers and visibility after explicit transfer before any visual-owner edit. Visual owns ResortMap integration and outdoor facilities/poses; reviewer owns semantic tests only. One explicit parse-only `String` annotation in root's file was delegated to the visual owner to unblock testing; no broader ownership overlap occurred.

## Final independent and regression evidence

`tests/depth_occlusion_test.gd` completes with **2,484/2,484** checks, **68 clip/rotation configurations**, **476 full-occupancy phase samples** and **68 single-occupancy middle frames**. Each configuration samples approach at .05/.95, activity at .08/.46/.85 (including exact climbing 5.47 seconds), and departure at .05/.95. The seventeen clips comprise all fourteen venues plus dining, buffet and main pool. Log: `.tools/r15-final-full.log`.

Semantic cases verify front-side overlapping guests remain visible, rear rock occludes appropriate body/rope portions, side-on slices straddle raised actors' ground contact, rear art omits front-only holds, nets and airborne balls use physical contact rather than displayed height, incidental walkers cross gate-post depth, furniture/architecture exposes real opaque depth records, and the viewer submits the same plan as the world. The first executable pass caught a real 270° rope overlap; correct cap attachment and nearest-edge slices resolved it. Completely covered 180° rope is accepted where all overlapping portions physically lie behind solid rock, rather than demanding artificial visibility.

R14 viewer contract **852/852** and source smoke pass (`.tools/r15-final-viewer.log`, `.tools/r15-final-smoke.log`). Other reported clean checks: exact climbing **168/168**, dining visual **27**, facility visual **1,026**, beach visual **120**, R9 visual **130**, viewer fixtures **304**, seated proportions **375**, Developer showcase **85**, furniture depth **32**, building renderer **112**, landscape **63**, building appearance scene **46**, actor facing **75** and viewer modal scene **42**. The furniture suite verifies all eight kinds × four turns retain byte-identical atlas appearance with valid layer metadata. Counts are assertions/samples, not separate gameplay scenarios.

## Generated visual review and limits

Root and PM inspected `.tools/r15-climbing-5.47.png`, copied to `docs/screenshots/depth-rotation-preview.png`: front guests remain legible, opaque rear rock covers the overlapping body/rope while heads above its silhouette can remain visible, and side-view rope no longer paints over the wrong face. The unobstructed belayer remains distinct. Root's `.tools/r15-climbing-preview.gd` reconstructs the actual shared depth dispatch, using original cached layer images and engine-correct in-place mirroring; it does not invent separate animation poses.

PM inspected the fourteen-kind/four-turn static atlas `.tools/r15-static-venues.png` and all six full-occupancy outdoor sheets `.tools/r15-venues-{activity,approach,departure}-{1,2}.png` (**168** generated frames). Rear arcade/rock faces, bars/counters, net/posts, pool rims and slide layers are directionally coherent. Root and PM also inspected `.tools/r15-core-depth.png` (dining/buffet/main pool across four turns at 5.47 seconds): native diner proportions, plates, stable furniture surfaces and pool rotations are preserved. These are production-command CPU reconstructions, not native captures or framebuffer validation.

Known remaining spacing limitation: synchronized full-occupancy fixtures bunch at shared narrow entrance waypoints, buffet service positions and some pool/lounge positions. This audit corrects depth/rotation and records those crowding cases; it does not introduce traffic avoidance or claim every animation is perfect. README and launch notes disclose the limitation. Ordinary staggered arrivals do not necessarily produce every synchronized stress-frame overlap.

## Windows candidate

`build/windows-r15/AllInclusive.exe` is **111,599,600 bytes**, SHA-256 `81D2E6D65068EF8FEA26D5D05A477600DDA08E4F892256360538C1AE1678EE45`. Root reports clean standalone exit 0 (`.tools/r15-standalone.log`), preserving **12 stays, 95.42 rating, $1,120**, all fourteen Developer activities and twenty viewer clips. Import/export complete successfully with the familiar environment editor-startup safe-save warning; no script errors and clean standalone runtime. Existing running builds remain untouched; the new package uses `build/windows-r15`.

Final `build/AllInclusive-Windows.zip`: **41,510,347 bytes**, SHA-256 `1133DA631A294C5A9D4022B4ABFC7FD15E1E8458AF551E0475C2C95B7FAEE031`. Root verified exactly four flat entries (`AllInclusive.exe`, `START_HERE.txt`, `CREDITS.txt`, `THIRD_PARTY_NOTICES.txt`) and streamed the embedded executable to confirm the identical accepted R15 hash. `build/SHA256SUMS.txt` is updated. Prior R14 archive: `.tools/releases/AllInclusive-r14-viewer-Windows.zip`. README and versioned launch notes identify R15 and disclose generated/headless evidence and remaining spacing limitations. The locked canonical R13 executable remains untouched.

No desktop use, capture, visible game/editor window or native tester. Generated previews and headless runtime draw evidence are distinguished from native pixel output; no Git publication.
