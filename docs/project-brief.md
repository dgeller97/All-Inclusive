# Shared production brief

## Current revision

Revision 7 adds functional editable dry-beach relaxation, volleyball, a beach bar and evening stage entertainment. Use `revision-7.md` for the current model/pose contract and `resort-research.md` for official-source design context. Revision 6's actual buffet/table meal loop and revision 5's exterior view, names and finishes remain. The user-selected fixed coast is authoritative; no ocean swimming or coast painting is introduced. Earlier construction, Regular/Developer costs, staged layout application and the compact management loop remain in place.

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
