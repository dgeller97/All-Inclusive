# Modular resort art

`assets/art/resort.png` is a 960 × 600 terrain texture anchored at world (−160, −120). It contains the beach, groves and tiled promenade. The map draws the ocean and beach flag from `scripts/ocean.gd` using the existing shoreline profile.

Place `scripts/building_renderer.gd` in the same world coordinate space as the terrain, above the terrain and below the guests and construction overlay. Use it for both the active layout and the construction draft. Call `present(layout.buildings, layout.render_assets(), visual_time)` when the layout changes and `advance_time(visual_time)` to update the pool surface. To show the installed terrace, pass a copy of the pool dictionary with `upgraded` set from `layout.readiness().terrace`. The two loungers and umbrella are regular layout assets.

The model supplies building and furniture rectangles in world pixels. Rooms have a south-center doorway on the 8-pixel grid. The roof rises up to 8 pixels above a room and stays within its footprint at the north edge of the map or beside a neighboring building. The pool water starts 24 pixels inside the west edge and 16 pixels inside the north edge, leaving 24 pixels of deck on each side and at the south. Its edges and animations follow the pool footprint.

The transparent furniture atlas is 128 × 256 pixels. It has four rotation columns and eight rows with a 32-pixel stride. Each sprite begins at the tile's top-left corner and uses the rotated model footprint as its source rectangle.

| Row | Asset | Unrotated footprint in pixels |
| --- | --- | --- |
| 0 | Bed | 16 × 24 |
| 1 | Reception desk | 24 × 16 |
| 2 | Buffet counter | 32 × 16 |
| 3 | Dining table | 16 × 16 |
| 4 | Lounger | 8 × 24 |
| 5 | Umbrella | 16 × 16 |
| 6 | Plant | 8 × 8 |
| 7 | Bench | 24 × 8 |

Run `node assets/art/generate_art.mjs` from the project root to regenerate the terrain, furniture, shoreline profile, people and application icon. The fixed-coordinate `resort_pool_upgrade.png` is a legacy overlay.
