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
