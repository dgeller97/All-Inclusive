# Shared production brief

## Current revision

Revision 6 adds real restaurant interaction: guests collect food at the editable buffet counter, reserve a reachable table, sit/eat and depart from the table. Use `revision-6.md` for current ownership, timing and save contracts. Revision 5's exterior view, named signs and building finishes remain. Revision 4's editable dry-land terrain, functional paths and scenery retain the user's fixed coast. `revision-3.md`, `design-mode-ui.md` and `modular-art.md` cover construction, Regular costs, Developer free building and staged application. The original brief below remains the baseline management loop; the pool improvement comes from actual placed furniture rather than the original one-click upgrade.

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
