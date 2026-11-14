# Revision 2: resort exploration and contextual controls

**Historical revision 2 brief.** Revision 3 adds editable structures/furniture and two construction modes. Fixed building and terrace coordinates in this brief are superseded by `revision-3.md`, `modular-art.md` and the layout model.

## Requested outcome

Replace the permanent management sidebar with clickable original icons and one contextual panel at a time. Expand the resort world with open land and beach, ground the entire pool and upgraded deck on land, animate changing ocean conditions with calm/caution/closed flags, and support bounded zoom and click-drag navigation.

## Scope and ownership

- UI designer: new `scripts/resort_ui.gd`, `assets/ui/**`, `docs/ui-revision.md`; original icon dock and on-demand controls.
- Visual/world designer (reassigned planner agent): `assets/art/**`, new `scripts/ocean.gd`, `docs/world-revision.md`; expanded terrain, corrected coast, ocean animation and flags.
- Root coordinator: new `scripts/resort_camera.gd` and targeted camera tests, runtime/native QA and final packaging.
- Sole integration developer: existing core scripts, integration and regression fixes, export.
- Independent tester: revision acceptance harness/report after integration.

The first playable economy, guest schedules and save compatibility remain intact. No ocean swimming, beach staffing or construction simulation is added. Beach flags communicate ocean conditions independently from the pool.

## Contracts

- World coordinates for existing buildings and guests remain unchanged. Proposed world bounds are `Rect2(-160,-120,960,600)`; expanded art is drawn at `(-160,-120)`. The world designer owns final coastline/bounds details.
- UI lives in screen space above the camera; `action_requested(action,value)` sends management and camera actions to the core controller. `refresh` receives simulation and screen-state data. One panel at a time; X, outside click and Escape close it.
- Ocean intensity and flag phase use absolute persisted simulation time, `(day-1)*240 + second + fraction`. Load restores the same conditions; no wall-clock random weather.
- Camera supports left hold-drag, middle drag, cursor-anchored wheel zoom, zoom buttons and Home. Gestures beginning on UI are blocked. World labels, families, ocean and terrain share the same transform.
- Original release backup remains under `.tools/releases/`; old active-save fixture is `tests/fixtures/v1_active_save.sav`.

## Acceptance

Verify a clear ground buffer between both pool/deck versions and ocean; surf never overlays land or pool. Observe low/high surf and all labelled flag states. Verify icon panel switching/closing, global Escape and Space behavior, safe UI-versus-camera input, bounded panning and cursor-anchored zoom. Test existing save fixture, active queue save/load, original full progression, source and exported launch. Native QA must inspect the actual new layout and navigation. Preserve exact tested executable in the final archive.

## Session validation constraint

The user is using the computer and explicitly requested no more computer use for this session and a break for the tester. Therefore do not launch visible game/editor windows, capture the desktop, or use native/browser automation. Continue implementation, headless checks and local generated-image inspection. Native interactive validation of revision 2 is deferred, not claimed complete; the existing revision 1 native reports do not establish this revision's visual/input behavior.
