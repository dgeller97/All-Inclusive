# Building artwork and finishes

The map draws bedroom, lobby and restaurant as open cutaways in Interior view. Exterior view replaces them with terracotta roofs and south-facing façades. The scaled hip roof, shaded tile courses, windows, entrance and bronze-edged name plaques are drawn in world pixels. The visible doorway aligns with the layout model’s entrance cell. The pool keeps its open deck, furniture, water and pool animation in both views.

Plaques use the saved `display_name`. The cutaway mounts them above the rear face, the exterior mounts them below the front eave, and the pool mounts its plaque along the north deck. Plaques truncate long names with an ellipsis at narrow footprints. The building settings keep the complete name.

| Surface | Original | Other finishes |
| --- | --- | --- |
| Floor | The existing room-specific pavers | Glazed checkerboard tile, staggered wood planks, stone pavers |
| Wall | The existing plaster and stone trim | Sage plaster, clay brick, timber boards |
| Ceiling | Warm cream plaster | Cool plaster, exposed timber beams, inset panels |

The wall finish covers the cutaway wall faces and the area around the exterior door and windows. Inspect ceiling shows the chosen finish on a plane inside the selected building’s walls, complete with light fixtures. Its floor and furnishings become visible again when inspection ends. The terracotta exterior roof has its own palette and does not use the ceiling finish.

`assets/art/building_finishes.gd` generates and caches the original 16 × 16 pixel swatches. The renderer repeats these textures at native pixel scale. `BuildingRenderer.finish_preview(surface, choice)` returns the corresponding swatch for the settings panel, including a representative sample of the original floor palette.

`BuildingRenderer.set_view(exterior, ceiling_building_id)` updates the global view and optional ceiling inspection. Pass `-1` for ordinary Interior view. `present(buildings, assets, visual_time)` accepts layout rectangles and resolved furniture rectangles in world coordinates. `is_interior_hidden(world_point)` reports whether an actor’s foot position is inside a roofed or ceiling-inspected building. The north edge may overhang by one 8-pixel grid cell when no neighbor or world edge would be crossed.

Run `godot --headless --path . --script tests/building_renderer_test.gd` for geometry and texture checks. Add `-- --preview` to save a CPU-rendered contact sheet of the three view states in `.tools/r5-building-art-preview.png`.
