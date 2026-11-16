# Revision 13: Developer showcase and larger grounds

The user wants every asset already placed in Developer mode so its behavior can be inspected, and a larger map with room to expand. A fresh Developer run becomes a complete editable showcase. Regular starts keep their existing hotel and amenities; loading any existing save must retain its actual layout rather than populate new content.

## World contract

Expand the fixed world from `Rect2(-160,-120,960,600)` to `Rect2(-480,-240,1280,960)`, about 2.13 times the area. The grid remains eight pixels with absolute cells `Rect2i(-60,-30,160,120)`. Existing coordinates, terrain pixels/materials, paths, shoreline and default scenery remain intact in the old rectangle. Extend the natural fixed coast outside its former vertical span; never introduce water painting or reinterpret saved cell coordinates.

New western land supplies generous grounds for the activity campus. Map, shore mask, navigation, terrain editor and camera must all use the same bounds. Keep the existing hotel and each facility gate connected by usable paths, with sufficient clear space for props, guests and camera inspection.

## Developer contract

`Sim.configure_new_run(mode) -> bool` is invoked only for an explicit new run before the controller installs the simulation, with a failed setup leaving the current run intact. Setting `mode` directly and restoring a save do not populate anything. A new Developer showcase contains all four building kinds, all eight furnishing kinds, all fourteen functional activity kinds, and all five ordinary scenery kinds as normal editable entities. Free starter objects have zero paid cost and produce no demolition cash.

Guests must use all fourteen venues through real reachable routes, reservations and normal activity phases within the first three showcase days. An optional persisted `developer_showcase` marker tracks completed kinds and prioritizes actual uncompleted/unreserved choices; old Developer saves without that marker retain ordinary choices. Preserve capacity constraints, evening scheduling and save/resume continuity. Removed or moved assets remain meaningful edits; there must be no hidden respawn or invisible visits. Furniture and scenery retain their usual interactions and roles; placing them does not invent new behaviors.

The new-run UI describes the showcase clearly and opens with useful campus framing. Existing saved cameras and layouts are preserved. Showcase scenery/paths should aid readability without crowding activity sprites or blocking gates. All R9–R12 features and the mirrored actor correction remain.

## Ownership and acceptance

- Sol/xhigh world specialist `visual_r9`: world generator/art, landscape/ocean/camera indexing, layout bounds and graph dimensions only, focused expansion/compatibility tests and generated overview.
- Sol/xhigh systems specialist `systems_r9`: `developer_showcase.gd`, `simulation.gd`, explicit new-run API, deterministic activity coverage and focused model/save tests.
- Root: `resort.gd` new-run/UI/camera integration, independent `developer_scene_test.gd`, README/launch notes, export and packaging.
- Astra/high PM: dependencies, scope, shared records and acceptance.

Require complete catalogs, reachable editable geometry, real per-kind activity completion, no refundable free assets, Regular/old-save preservation, active showcase save continuation, larger-world camera/paint/shore/navigation checks and clean standalone Windows smoke. Use headless tests and generated image inspection only. No desktop use, capture, visible windows, native tester, Git push or release.
