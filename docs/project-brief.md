# Shared production brief

## Current revision

R18 is delivered locally: Developer month/offshore intensity controls, a saved authoritative offshore patch ledger whose arrivals form localized beach deposits, seeded size/weather variation, and one hireable Beach/Pool lifeguard with visible duty and rescue/tow behavior. Launch `build/windows-r18/AllInclusive.exe`. See `revision-18-validation.md` for independent109/backend41/routed359 checks, generated evidence, extended standalone and verified archive identity. Operational progression, legacy saves and prior local features are preserved. Both specialists finished, source/docs frozen; no desktop use or Git publication.

R17 is delivered locally: deterministic seasonal offshore sargassum arrivals and floating patches, plus a buoy outline derived from the actual guest swimming/wading zone. Root owns production/visual harness; one independent Sol/xhigh reviewer passes 60 checks covering seasonal lifecycle, save/pause behavior, cleanup separation and real swimmer containment. Shore buildup/cleaning and flag-risk mechanics remain unchanged. See `revision-17-validation.md` for verified executable/archive identity; current executable is `build/windows-r17/AllInclusive.exe`. Reviewer finished and source/docs frozen. No desktop use, new water-editing scope or Git publication.

R16 is delivered locally: screen controls/modal/viewer now use a dedicated CanvasLayer above all world labels, correcting the R15 plaque-over-welcome regression and welcome text/button overlap. Launch **`build/windows-r16/AllInclusive.exe`**. Root implemented/tests/packaged; PM independently reviewed source, engine ordering contract and regression evidence. See `revision-16-validation.md` for 68 canvas/spacing checks, 42 viewer checks, 2,075 UI geometry checks and verified standalone/archive identity. No specialists, desktop access, running-process changes or Git publication.

R15 is delivered locally: production asset/guest/effect depth and rotated static art are corrected across all fourteen venues, dining, buffet and main pool. The exact climbing-wall Activity5.47/frame164 case and broader generated comparisons are accepted, with 2,484 independent depth checks and clean standalone/package verification. Launch **`build/windows-r15/AllInclusive.exe`**; older/running executables remain untouched. See `revision-15.md` and `revision-15-validation.md`. Some synchronized full-occupancy crowdspacing remains and is documented; native pixel inspection is deferred, and no Git publication occurred.

R14 is delivered locally: an in-game Animation viewer displays four synchronized runtime rotations for eighteen clips, plus two honestly fixed-coast ocean clips, with phase/playback/seek/frame/occupancy/variant/zoom controls. It opens from welcome, Settings or F8 and preserves the underlying resort state. See `revision-14.md` and `revision-14-validation.md` for 852 independent/304 fixture/42 integration checks and verified Windows package. **Launch `build/windows-r14/AllInclusive.exe`**; the locked running R13 executable at `build/windows` was preserved. This is inspection tooling, not animation redesign. No native pixel QA or Git publication is claimed.

R13 is delivered locally: a fresh Developer showcase places every building/furnishing/scenery type and all fourteen functioning activities on expanded grounds. World bounds are 1280×960 without changing existing coordinates/coast/terrain; Regular starts and loaded layouts remain intact. Guests complete all fourteen activities through normal phases within the first three default showcase days. See `revision-13.md` and `revision-13-validation.md` for explicit new-run behavior, generated overview, 85 model/59 routed/world compatibility evidence and final verified Windows package. Both specialists are released, native playtesting remains deferred and new source remains local.

R12 is delivered locally and corrects the follow-up screenshot's mirrored upper-body displacement: Godot flips textures in place, so the renderer must not shift their origin. CPU preview probes now follow that same engine contract. Source/generated visual review, clean standalone smoke and matching archived executable are accepted. Use `revision-12.md` and `revision-12-validation.md` for current evidence. R11 native proportions, chairs/bent legs and opposite-side seats where aisles allow remain, together with all R9/R10 features. Verification is offscreen/headless only, with no desktop use or native tester; new source remains local.

Revisions 9 and 10 are delivered locally in the verified combined Windows build. R9 provides correct asset/building rotation, connected room units, exterior customization, stable activity surfaces, ocean swimming with explicit red-flag risk, seasonal calendar/day-night, sargassum and a price slider. R10 adds all ten requested playable prefab facilities; use `revision-10.md` for the exact catalog and `revision-10-validation.md` for final acceptance. R8's Facilities controls, restaurant/leisure loops, fixed coast geometry, Regular/Developer transactions and staged Apply Tomorrow remain. Ocean swimming supersedes the earlier no-swimming limit. Native playtesting remains deferred; new changes are not pushed or released.

## Outcome

Deliver a polished, runnable Windows first playable in Godot/GDScript. The player manages a small family resort for one compact 10–15-minute session, improves service and buys a visible pool upgrade. A complete loop and legible interface take priority over breadth.

## Required scope

- Fixed three-quarter 2D pixel-art tropical resort with bedrooms, reception, buffet and pool.
- Animated guests moving through resort activities; understandable occupancy and feedback.
- Package pricing and staffing decisions with observable economy/service consequences.
- One visible pool upgrade, clear objective/progression, and finish state that permits continued play.
- Pause and speed controls; functional save/load; original sound effects and music with audio toggle.
- Onboarding, responsive feedback and a downloadable Windows executable/build.

## Constraints and decisions

- Godot/GDScript, original procedural art/audio permitted, no paid assets or services.
- Single developer owns core game/project scripts. Art and audio specialists own independent asset folders.
- Prefer a small deterministic simulation with carefully tuned economy over elaborate systems.
- Use a low-resolution pixel-art scene scaled with nearest-neighbor filtering; crisp readable UI may sit above it.
- No network service, account, analytics or external runtime dependency for players.
- Report observed test results separately from design expectations.

## Ownership

Project manager: scope, shared documentation, dependency coordination, milestone acceptance.
Planner: `docs/game-design.md`, `docs/test-acceptance.md`.
Visual designer: `docs/visual-direction.md`, `assets/art/**`.
Software developer: `project.godot`, scenes, scripts, integration and build configuration.
Audio designer: `docs/audio-direction.md`, `assets/audio/**`.
Tester: `docs/test-report.md`, independent test evidence and regression reports.
Root coordinator: host runtime/export tools, native UI playtest assistance and final delivery.
