# Editable landscape art

`assets/art/resort.png` is the 960 × 600 starting ground and ocean texture at world (−160, −120). The image preserves the beach, dune colors, and water shading. The editable scene supplies its own paths and scenery.

## Generated assets

Run `node assets/art/generate_art.mjs` from the project root to regenerate the original artwork and landscape layers. Import the textures in Godot after generating them.

| Asset | Contents |
| --- | --- |
| `landscape_defaults.png` | 120 × 75 cells, beginning at absolute cell (−20, −15). Red encodes grass 1, sand 2, dirt 3, or water 4. Green encodes no path 0, stone 1, or boardwalk 2. |
| `landscape_materials.png` | Six 32 × 32 texture patches. Grass, sand, dirt, water, stone paving, and boardwalk run left to right. Absolute world coordinates select the 8 × 8 subregion, so flecks and paving continue across strokes. |
| `landscape_props.json` | Starter scenery in deterministic order. Each row gives the kind, absolute cell, pixel offset within the cell, atlas variant, and quarter-turn rotation. |
| `landscape_props.png` | Four rotation columns at a 96-pixel stride. Rows hold palm sizes followed by shrub and rock. The ground anchor is at (44, 67) in each cell. |
| `resort_shore.png` | One encoded red/green sample per world pixel row. Samples locate the original first water pixel, including within partly wet grid cells. |

The starter promenade and boardwalk are editable cells. Short connecting paths serve the starter rooms, reception, buffet, and pool. All 38 original palms keep their exact root positions and original sizes. Grove shrubs have their own anchors so their physical footprints can be edited independently of the palms. Bench rotations reuse the original furniture atlas.

## Drawing order

Attach `LandscapeRenderer` above the base texture, then `Ocean`, then the building and actor layers. Call `LandscapeRenderer.present(layout.landscape)` and `Ocean.set_landscape(layout.landscape)` when the visible layout or landscape revision changes. Use the staged layout while designing, and resume the active layout when leaving the draft view.

Terrain strokes cover full 8 × 8 cells on dry land. The renderer trims path edges against neighboring path cells. The user's fixed-coast choice supersedes the initial water-capable implementation: the original row profile controls the ocean, and water/coastal painting is prohibited. Water texture support is retained for baseline rendering, not exposed as an editor tool. The ocean layer takes the beach flag position and rotation from the current model and animates the flag with the current sea condition.

The same `LandscapeRenderer.draw_prop` function draws scenery and placement previews at the prop anchor. Each prop has a physical footprint and a separate visual extent, allowing palm fronds and other scenery to overhang adjacent land cells.
