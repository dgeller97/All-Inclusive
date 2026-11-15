# Shared production brief

## Current revision

Revision 8 makes construction controls consistent: a top-level Facilities catalog with visible prices/Free, universal object selection/bulldozing, and Move for selected outdoor assets regardless of the catalog. Use `revision-8.md` for this focused UI contract. R7's functional beach amenities, R6's actual restaurant meal loop and R5's appearance features remain. The fixed coast, Regular/Developer transactions, saved layouts and staged Apply Tomorrow workflow are preserved.

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
