# Reusable specialist role instructions

Every role reads the shared brief, relevant design contracts, and applicable repository instructions. Own only assigned files; communicate any cross-owner change instead of overwriting concurrent work. Report blockers immediately, otherwise report completion and evidence. For long work report around ten minutes with files changed, observed results and remaining work. Do not present planned behavior as tested behavior.

## Team model roster and scheduling

| Role | Model | Reasoning effort |
| --- | --- | --- |
| Project manager | `gpt-6-astra` | `high` |
| Planner | `gpt-6.1-sol` | `xhigh` |
| Visual designer | `gpt-6.1-sol` | `xhigh` |
| UI designer | `gpt-6.1-sol` | `xhigh` |
| Software developer | `gpt-6.1-sol` | `xhigh` |
| Audio designer | `gpt-6.1-sol` | `xhigh` |
| Tester | `gpt-6.1-sol` | `xhigh` |

The root coordinator and project manager occupy two of four concurrency slots, leaving at most two active specialist agents. The manager explicitly delegates each role instead of implementing every discipline itself. Spawn specialists with `model: "gpt-6.1-sol"`, `reasoning_effort: "xhigh"`, and `fork_turns: "none"`; pass this brief, relevant file paths, ownership and the concrete task in their message. Do not exceed two active specialist children.

Use waves: planner plus visual designer first; replace planner with the sole software developer; replace the completed visual designer with audio designer; replace completed audio with independent tester while retaining the developer for fixes. A completed agent may be reused with a clearly stated new role. Report blockers immediately, handoffs/completion with evidence, and progress about every ten minutes during sustained work. The manager passes meaningful milestone updates to the root coordinator and keeps the board current.

For interface/world revisions, start the UI designer and visual/world designer together with separate new component files; replace the finished UI designer with the sole integration developer. Root may own an isolated camera component and its tests. Respect session-specific user restrictions: during revision 2 the user requested no further computer use and a break for the tester, so developer/root headless verification continues while independent native playtesting is deferred.

For revision 4, the two specialist slots are a combined UI/core integrator and a landscape visual designer. Root owns landscape data, navigation and model tests, while the PM coordinates contracts and acceptance. The existing no-computer-use and tester-break instructions continue. Local development/export is authorized; publishing a GitHub release or pushing these changes is outside this request.

For revision 5, use the same model roster with a building visual designer (renderer, textures and signs) and a UI/core integrator (properties, view mode, saves and export). Root owns building metadata, finish pricing and model tests. Keep the fixed coast and the no-computer-use/tester-break restrictions. The PM accepts against headless evidence and records native visual QA as deferred.

For revision 6, the two specialist slots are the simulation/layout/core developer and dining map/visual specialist. Root owns a separate independent dining-contract test plus launch documentation and packaging. Keep the Astra/high PM and Sol/xhigh specialists, fixed coast, no computer use and tester break. New activity states must use real editable geometry and serializable reservations, with visual poses derived from the same state.

For revision 7's autonomous expansion, retain the same roster with a model/UI/core developer and beach visual/map specialist. Root owns official-source research, a separate beach-contract test, packaging and Git. Target a coherent tested subset within the user's hour: four functional editable amenities, compatibility and artifact verification before optional polish. No computer use or native tester resumption.

For revision 8's focused consistency fix, use one Sol/xhigh UI/core integrator under the Astra/high PM. Root owns an independent construction-consistency test and packaging. Reproduce the category-gated bug before changing controls, then test actual routed selection, purchases, removal and occupied-hotel staging. Do not recruit a second specialist or resume the native tester without a concrete need and authorization.

Revision 9 uses two Sol/xhigh specialists under Astra/high PM: one model/UI/core integrator and one render/map/visual specialist. Root owns the isolated deterministic calendar, independent tests, research and final packaging. Keep ownership disjoint; no desktop use or tester resumption. The broad request includes every item in `revision-9.md`; final acceptance cannot silently defer a requested feature. No R9 push/release is authorized in this task.

Revision 10 follows R9 source acceptance using the same two specialists and ownership. Root owns the independent activity-expansion test and final combined Windows packaging. Implement every catalog item in `revision-10.md`, preserving all four orientations and actual saved activity visits. No native tester or desktop capture; no push/release.

Revision 11 uses one Sol/xhigh visual/core specialist under Astra/high PM for the seated-proportion bug, focused tests and export. Root owns independent proportion/spacing tests and packaging. Do not dismiss the user's screenshot based on earlier bounds-only tests; require native pixel scale and before/after actual-phase evidence. Preserve all R9/R10 source and the no-desktop restriction.

Revision 13 uses two existing Sol/xhigh specialists: world expansion owns asset generation and geometry/indexing; systems owns the explicit Developer showcase factory and simulation coverage. Root owns new-run UI integration, independent tests and packaging. Preserve old world coordinates and every restored layout. Developer initialization is explicit, never a side effect of a mode setter or load. No native tester, desktop use or publication.

Revision 14 uses one Sol/xhigh visual implementer for the isolated in-game animation viewer and one Sol/xhigh independent headless reviewer/test author with no production edits. Root owns main UI integration/modal lifecycle and packaging. Use actual production CanvasItem rendering and pose functions; never substitute CPU preview semantics. Preserve the user's live run and no-desktop restriction; do not resume native testing or redesign animations outside viewer correctness.

Revision 15 uses the existing Sol/xhigh visual specialist as sole production owner of rendering/depth/art/pose changes, plus the Sol/xhigh systems specialist for independent semantic occlusion tests and audit notes only. Root owns integration/build, PM owns scope and acceptance. Require actual world/viewer parity, physical front/behind cases, rotated static-art inspection and generated visual evidence; do not rely on assertion counts or fix only the inspection viewer. Preserve the no-desktop restriction and all prior local work.

Revision 17 uses one existing Sol/xhigh systems reviewer for independent ocean-season/swim-boundary tests only. Root owns Ocean/Map production and visual artifacts; PM reviews actual swimmer geometry, seasonal contract and acceptance. Keep floating seasonal patches deterministic from game time and separate from saved shore cleanup. No desktop/native testing or publication.

Revision 18 reuses both Sol/xhigh specialists with explicit roles: systems owns simulation/new sargassum model and backend tests; visual specialist switches to UI integration owning HUD/controller actions and UI tests. Root owns Ocean/Map visual production and packaging. PM coordinates the shared arrival/rescue APIs and acceptance. R18 supersedes R17's decorative-only offshore field with an authoritative saved cohort/deposit ledger. No desktop use, native tester resumption or publication.

## Planner

Define the smallest coherent loop that satisfies the brief. Provide numeric defaults, pacing, state changes, controls and acceptance criteria. Highlight assumptions. Hand off a concrete contract rapidly; avoid expanding scope.

## Visual designer

Create a consistent palette, scene composition and original assets. Specify dimensions, pivot/anchor, transparency, sprite frame layout and exact paths. Coordinate scene positions before generating backgrounds. Ensure pixel assets are readable at intended display scale.

## Software developer

Own Godot project, scenes, scripts, simulation and integration. Implement all required systems with clear feedback. Keep state serializable and simulation testable. Use assets according to the shared contract, tolerate assets still in production, and run relevant parsing/headless checks. Fix independently reported defects and provide exported builds with launch documentation.

## UI designer

Own reusable interface components, original icon assets and interaction specifications. Keep essential state visible while opening one contextual panel at a time. Provide tooltips and meaningful accessible text labels, explicit close controls and consistent keyboard handling. UI input must not move the world beneath it. Hand off an implementation-ready component API early, then verify actual layout at the target viewport.

## Audio designer

Create a restrained original looping soundtrack and short recognizable interaction/event effects. Supply standard WAV files and integration notes including loop behavior and recommended volume. Avoid clipping and overly loud sounds. Own only audio assets and audio documentation.

## Tester

Independently verify the actual build against acceptance criteria. Exercise normal progression, economy decisions, timing controls, upgrade, audio and save/load. Inspect parse/runtime output and exported launch. Separate automated findings, directly observed UI results and design judgment. Report exact reproduction steps and severity; rerun only affected tests after fixes.

## Project manager

Maintain brief, board and decisions; assign ownership; resolve dependencies and keep scope bounded. Accept milestones only against evidence. Preserve work continuity and ensure launch/readme/test instructions match actual deliverables.
