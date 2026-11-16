# Revision 18 validation

Status: **Revision 18 accepted and delivered locally**. Functional model, routed controls, generated visual evidence, extended source/standalone smoke and final archive identity are verified. Specialists are finished and source/docs are frozen.

## Independent functional evidence

PM-owned `tests/revision18_acceptance.gd` passes **109/109**, exit 0, log `.tools/r18-independent.log`. This is separate from the backend developer's own tests and the UI integrator's routed scene checks.

Environment coverage checks Regular rejection of Developer actions, July selection without altering live guests/bookings/day/second/cash, bounded numeric intensity and Auto, existing trajectory retention, no duplicate same-second forced patch, exact per-record mass deposition at the corresponding landfall row, and no unseen arrivals with natural births disabled. Every tick of a saved live cohort is compared to the uninterrupted original hotel. Cleaning clears deposits without changing incoming patches. Seeded samples produce broad patch sizes and varying fronts. Frequent legitimate slider changes/forced arrivals still serialize without dropping cohorts. Legacy pre-ledger state preserves its 37% buildup as 3,700 localized units without injecting a hired guard or changing guests.

Lifeguard coverage verifies insufficient cash, exact $60 hire, duplicate-hire rejection, free idle reassignment, actual day-end $120 base plus $25 guard payroll, and free Developer guard costs even with negative cash. Both Beach and main Pool exercise explicit volunteer drills, real currently swimming guest drills, and natural non-drill distress. Outbound, tow and dry-return saves are compared to the live uninterrupted hotel ten seconds later. Busy actions reject without teleporting or altering state; malformed family references reject transactionally; rescued families complete ordinary checkout; late drills cannot cross day cleanup. PM reran all 109 checks on the final backend geometry/cost fixes; exit 0.

During review, PM identified reachable Developer cohorts exceeding the first restore cap, potential pool-slot reuse during rescue and negative-cash free hiring. The backend owner corrected the cap, held the rescue slot and restricted affordability checks to paid hires. The pool post now prefers a lateral dry deck position and the returning guard leads the victim into the dry approach path, avoiding late-tow crossing. No PM production edits were made.

Backend-owned `tests/coast_state_validation_test.gd` passes **41/41**, log `.tools/r18-backend-validation.log`. It covers malformed coast/rescue transactions, held pool slots, real geometry of all four rotated main pools and 40 sampled rescue positions per site, alongside the debt-safe Developer case. Existing R9 independent **210** and R17 seasonal **60** checks remain clean.

Authentic legacy v1/v2 save suites each pass **4/4**, logs `.tools/r18-backend-legacy-v1-final.log` and `.tools/r18-backend-legacy-v2-final.log`. The historical v1 equality projection now excludes only the new coast-runtime metadata and explicitly checks no injected deposits or hired guard, preserving previous-state assertions.

## Routed UI evidence

UI integrator reports **359/359** routed checks in `tests/environment_staff_scene_test.gd`: Developer gating, actual embedded month popup/keyboard/Escape and viewport bounds, live guest/day invariance, intensity/Auto and real patch count, hiring/costs/both drill destinations/busy feedback and current payroll toast. F8 dismisses the month popup and restores focus after the viewer; controls do not silently save. Log `.tools/r18-ui-lifeguard-final.log`.

Final UI regression logs: `.tools/r18-ui-layout-final.log` (**2,103** geometry checks), `.tools/r18-ui-layer-final.log` (**68** canvas checks), `.tools/r13-scene-r18-ui-final.log` (**59** Developer), `.tools/r8-facilities-scene-r18-final.log` (**666** Facilities), `.tools/r14-scene-r18-final.log` (**42** viewer), `.tools/r9-scene-r18-final.log` (**24** R9 scene). Counts are assertions/geometry samples, not distinct playthroughs. UI source is frozen.

## Generated visual acceptance

Root and PM inspected final production-command reconstructions:

- `docs/screenshots/sargassum-landfall.png`: the same actual 20-unit raft at world row −85 advances from deep birth through midflight and visible shoreline contact, then creates its localized deposited pile. The final fade lasts 1.25 simulation seconds; no deposit was injected to construct the comparison.
- `docs/screenshots/sargassum-patches.png`: actual July/100% field shows seeded 8–49-pixel raft widths, organic grain and scattered arrival-generated shore piles, with buoy/water clipping preserved.
- `docs/screenshots/lifeguard-rescue.png`: Beach above/main Pool below, showing seated duty, outbound at 1.2 seconds, contact at 2, tow at 3.5, shore approach at 4.7 and dry return at 5.5. Final lateral pool/landward beach posts and leading tow geometry are used. Characters retain native proportions; close assistance and normal entry staffing can still overlap naturally in projection.

Root reports **128** targeted renderer checks in `tests/coast_visual_test.gd`, including final art, plus expanded world **48** and interface canvas **68**. Floating patches are drawn from the saved model ledger; rendering itself neither births nor deposits material. The shared rescue geometry drives actual world actor positions, rather than a special preview-only animation.

## Final source smoke

`.tools/r18-source-smoke-final-integration.log` exits 0. A separate Developer trial exercises July/70% intensity, actual forced offshore landfall, free hiring, both seated/active map posts, both drills, and restoration of an active beach rescue. It verifies that the original hotel snapshot is unchanged and restores the original map. Existing smoke still finishes with **12 stays, 95.42 rating, $1,120**, fourteen Developer activities and twenty viewer clips. PM read the completed log. `git diff --check` reports only existing CRLF normalization warnings, no whitespace errors. No Git write/publication was performed.

## Verification limits

All checks are headless or file-based. No desktop use, native capture, visible game/editor launch, process termination or Git publication. Generated drawing evidence is not native framebuffer inspection. One guard covers only the assigned Beach or main Pool, never all optional pools simultaneously. Ordinary pool distress is a rare post-introductory nonfatal cramp; red-flag ocean risk remains real and one busy guard is not blanket protection. Existing synchronized crowd-bunching limitations remain.

## Final Windows package

Current executable: `build/windows-r18/AllInclusive.exe`, **111,634,904 bytes**, SHA-256 `A44F4C7F7072E815ACD79BAD9E6DAABAE6AF4B89A93131D7BD473C2CBAA4CC32`.

Current ZIP: `build/AllInclusive-Windows.zip`, **41,546,552 bytes**, SHA-256 `950872526CF857361DFC65E4AD97C6A157AD9A3BBA4750FDA1FE46DBF4456B92`. Root verified exactly four flat entries (`AllInclusive.exe`, `START_HERE.txt`, `CREDITS.txt`, `THIRD_PARTY_NOTICES.txt`) and streamed the archived executable to confirm the accepted hash. `build/SHA256SUMS.txt` is updated. Prior R17 ZIP is preserved at `.tools/releases/AllInclusive-r17-ocean-Windows.zip`.

The hidden standalone candidate exits 0 in `.tools/r18-standalone.log`, including the explicit R18 landfall, both lifeguard posts/drills and active rescue restore checks, alongside unchanged baseline results. README and new versioned launch notes identify R18 and explain inspection controls, prices, rescue limits and legacy migration. Older running builds remain untouched.
