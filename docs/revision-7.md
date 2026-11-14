# Revision 7: beach leisure and entertainment

## Scope and timing

The user requested autonomous expansion after pushing the prior version. Root confirmed that push before this work. This iteration adds four functional, editable outdoor amenities informed by the official resort examples in `resort-research.md`: shaded beach relaxation, volleyball, a beach bar and evening stage entertainment. Target scope freeze is 06:05 UTC and a tested local package by approximately 06:20 UTC on 14 November 2026.

The coast remains fixed. This pass makes dry beach grounds usable; it does not add ocean swimming. The red beach flag denotes closed water conditions and does not close dry-land activities.

## Editable amenities

| Kind | Footprint in 8px cells | Regular cost | Family capacity |
| --- | --- | --- | --- |
| `beach_lounge` | 4 × 3 | $40 | 2 |
| `volleyball` | 10 × 7 | $100 | 2 |
| `beach_bar` | 6 × 4 | $100 | 2 |
| `stage` | 8 × 5 | $120 | 4 |

These are physical landscape props with existing placement, rotation, movement, bulldozing, Regular cost/refund and Developer free-build rules. New runs receive a free starter set on reachable dry grounds. Existing saved layouts are preserved without inserting new amenities or replacing the player's scenery. The editor exposes a compact Amenities group.

## Functional loop and shared contract

After the pool, families can use a lounge or volleyball court, collect a drink at a beach bar, and return to their room. Guests resting in the evening can attend a stage performance before checkout. Missing, inaccessible or full optional venues are skipped safely rather than trapping guests. Every visit uses the actual property's route, identity, capacity and a stable activity slot. Volleyball players visibly occupy the court; they do not merely stand beside it. Drinks are included family refreshments, without a separate transaction. Each completed distinct activity contributes +1 satisfaction, capped at +3 per stay before the overall 100-point cap. Reviews store/show this small activity bonus; old reviews default to zero. A completed activity can inform the review text when no stronger wait complaint applies.

`Layout.amenities(kind = "")` returns connected records `{id, kind, point, rect, capacity}`; `point` is the reachable AStar access tile and `rect` is the physical footprint. `amenity_by_id(id)` returns the record or an empty dictionary. `Layout.new(false)` omits starter amenities for old-save migration.

Starter world rectangles are lounge `(480,112,32,24)`, volleyball `(360,72,56,80)` at rotation 1, beach bar `(416,256,48,32)` and stage `(320,256,64,40)`. The lounge and stage were repositioned after generated-art inspection to reduce palm occlusion; rotating the court makes its net readable. All 67 original scenery props remain. The layout API reports valid connected facilities and preserves the existing operational hotel.

Simulation phases are `to_leisure`, `leisure` and `from_leisure`. Families persist `amenity_id`, `leisure_kind`, `leisure_slot`, `leisure_step` (0 initial, 1 daytime attempted, 2 bar attempted, 3 evening attempted), and a unique ordered `leisure_completed` list. `leisure_origin_id` and `leisure_origin_slot` preserve the actual position when moving directly from a daytime venue to the bar. Departure to the room retains its reservation for four seconds before releasing it. Save wrapper 7 requires new leisure state while retaining meal, appearance and fixed-coast migrations for older saves.

The Home view uses center `(280,170)` and zoom `1.7` so the new stage sits above the bottom HUD and original north rooms remain below the Design header. Saved camera snapshots continue to restore unchanged.

## Ownership and acceptance

The Sol/xhigh model/UI developer owns landscape/layout/simulation, editor and management UI, save integration, regressions and export. The Sol/xhigh visual specialist owns landscape/map rendering, amenity art and activity poses plus CPU preview checks. Root owns research, independent `tests/beach_contract_test.gd`, README/launch/credits, packaging and Git operations. The Astra/high PM coordinates contracts, review and acceptance with at most two active specialists.

No computer use, desktop capture, visible game/editor windows, tester resumption or paid services. Headless tests and generated CPU artifact inspection are allowed. Required evidence includes editable and reachable starter venues, real guest activities and slots, safe missing/full amenities, legacy/current saves, complete days and a standalone exported smoke. Native visual playtesting remains deferred.
