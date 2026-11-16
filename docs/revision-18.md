# Revision 18 — seasonal deposits and lifeguard

Status: **accepted and delivered locally**. See `revision-18-validation.md` for final tests, generated evidence and executable/archive identity. All prior local revisions and fixed coastline geometry remain. No desktop use, screen capture, visible launches or Git publication.

## Ownership

PM coordinates scope and acceptance. Existing Sol/xhigh systems specialist owns `simulation.gd`, new `sargassum_model.gd` and backend tests. Existing Sol/xhigh visual specialist takes the UI integrator role, owning `resort_ui.gd`, action/controller integration in `resort.gd` and focused UI tests. Root owns `ocean.gd`, `resort_map.gd`, visual helpers/assets, independent review, export and packaging. Single ownership applies to all production files.

## Environment contract

Developer controls live in Beach: month selection (Natural or January–December), numeric offshore intensity (Auto or 0–100), and an incoming-patch action for inspecting actual landfall. They do not reset day, guests, bookings, cash or construction. No direct artificial shore-buildup slider is needed. Regular runs hide these controls and simulation methods enforce mode restrictions.

An authoritative saved patch ledger replaces R17's independent offshore decoration and periodic shore scalar growth. Patches have seeded size/weather variation, offshore positions and finite travel; each completed arrival deposits its own mass into a localized shoreline band exactly once. The same record drives rendering and arrival accounting. Month/intensity changes affect new births while preserving existing cohorts, and cannot retroactively deposit skipped months. Saves preserve random/ledger state, active cohorts, localized deposits and controls. Legacy scalar buildup migrates into initial localized piles without pretending those piles were observed arrivals.

`Sim.floating_sargassum(visual_second = NAN)` supplies shared render records. `seed_sargassum_arrival()` introduces a real incoming cohort. Calendar overrides use an offset, leaving operational day progression intact. Weather variation can improve or worsen arrival conditions deterministically. Cleaning removes shore deposits only; offshore cohorts continue. Existing bounded satisfaction exposure reflects actual deposited buildup.

## Lifeguard contract

One hireable lifeguard costs $60 upfront and $25 per operating day in Regular mode; Developer hiring/payroll is free. Assign Beach or the main staffed Pool. Optional prefab pools are outside this one-guard coverage. The guard visibly sits on duty at a valid site, swims to a distressed guest, then brings them back to the shore/pool exit. Assignment changes are blocked during a rescue; one busy guard cannot cover a second incident or the other site.

The matching available beach guard can intervene before the existing red-flag fatal outcome; this is not blanket immunity. Pool distress is rare and begins after the introductory three days; an unguarded pool guest self-returns with feedback rather than introducing a new pool-fatality system. Developer rescue drills exercise either assignment using an eligible real guest or a clearly identified training volunteer, without inventing completed stays/reviews. Rescue timing is two seconds to contact, three seconds towing and one second returning to the seat. Drills too late to finish before day cleanup are rejected. Pool rescue retains its occupied service slot until completion.

Public actions: `hire_lifeguard(site)`, `assign_lifeguard(site)`, `start_rescue_drill()`. Shared `rescue_positions(visual_second)` returns guard/victim/child positions, swim flags, phase, site, family and drill identity. Model and renderer use this geometry contract rather than separately guessing positions. Persist rescue phase/times/target/family and validate it transactionally on load. Normal checkout, reservations and survivor handling must remain coherent.

## Acceptance gates

- Actual offshore-to-shore ledger accounting, broad reproducible sizes, localized landfalls, cleanup isolation, capped readable satisfaction and exact save continuation.
- Developer-only controls, numeric intensity/Auto, month changes without progression reset, no duplicate arrivals after jumps/load, and old-save migration.
- Hire/payroll/insufficient funds, Beach/Pool availability, seated duty, outbound contact/tow/return, busy/assignment limits, actual guest recovery and both-site drills.
- Rescue save/load at every phase; malformed references rejected without mutating live state; existing booking, construction, viewer and interface regression checks.
- Generated visual inspection of different patch sizes/localized piles and beach/pool seated/outbound/tow/return poses, followed by clean headless source and standalone Windows checks. No native framebuffer validation claim.

Deliver a versioned R18 Windows executable and verified four-entry ZIP; preserve earlier running builds.
