# Revision 3: build, bulldoze and furnish

## Outcome

Give the player a real editable resort layout: draw rectangular building footprints on a grid, furnish them with functional and decorative assets, select and bulldoze structures or furniture, and see management guests use the resulting layout. Buildings must no longer be painted into the terrain texture.

## Scope decisions

- The user selected both modes: Regular play uses construction costs; Developer mode permits free building. Choose the mode explicitly on a new run and persist it. Older saves default to Regular. Objects placed free refund zero; regular bulldozing refunds half the actual paid cost.
- Add a Build icon to the compact pixel dock. Enter a distinct paused design mode with a draft clone of the current, saved draft or pending layout. Hide live guests while previewing the draft. Discard returns to management and drops changes since the last draft save, while retaining any explicitly saved draft.
- Use an 8-world-pixel grid. Left drag draws bedrooms, reception, buffet and pool footprints. Asset placement uses a ghost preview; R rotates quarter turns. Select and bulldoze target the actual model objects. Right click/Escape cancel the current operation before leaving design mode. Middle drag and wheel continue camera navigation.
- Keep one reception, one buffet and one pool, with one to eight usable bedrooms. A bedroom needs a bed; reception needs a desk; buffet needs a counter and table. Required doorways/routes must connect to the entrance.
- Furnish pools with two loungers and an umbrella to activate the physical pool improvement. Remove the one-click purchase as the source of the upgrade. Plants and benches add decoration; no ocean swimming or extra building types in this pass.
- Draft mutation may temporarily be incomplete. Apply requires a valid operational layout. With no active families, apply immediately; otherwise explicitly queue it for the next day. Never delete or teleport live families by silently resetting a day.
- Save draft explicitly preserves the live run and incomplete draft. Normal saves include active and queued layouts. Old version 1/2 saves migrate to a furnished default layout, including the prior pool-upgrade state.
- Show a clear construction quote, refund and available cash before committing. Apply Tomorrow reserves its net funds when queued; canceling or replacing the pending plan must reconcile that reservation exactly. Insufficient funds prevents applying but does not prevent saving a draft.

## Ownership

UI designer/planner owns `scripts/design_ui.gd` and design UI notes. Modular visual designer owns terrain/art generation and `scripts/building_renderer.gd`. Root owns pure `scripts/layout_model.gd`, geometry/readiness/navigation and its tests. The sole integration developer owns existing game scripts, Build input/controller integration, simulation adaptation, persistence and export. PM coordinates contracts and acceptance.

## Validation constraints

The user's no-computer-use restriction remains in effect. Do not capture the desktop, use native/browser automation, or open visible game/editor windows. The tester remains on break. Implementation-team headless checks must cover footprints, asset placement/rotation/collision, shore validity, bulldozing, invalid drafts, apply-now/apply-tomorrow, functional capacity, guest paths and save migration. Inspect generated art files locally. Deliver a Windows executable and archive while clearly recording deferred native playtesting.
