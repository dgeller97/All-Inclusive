# All Inclusive visual direction

The scene is a tropical hotel courtyard viewed from above and slightly from the south. Cream masonry and orange roof tiles frame rooms with exposed interiors. A shaded arcade joins the lobby and buffet, with the pool on the seaward side. The beach, palms, and shallow water mark the right edge of the map.

## Art and scale

- The map uses a 500 × 288 pixel canvas. At 2× with nearest-neighbor filtering, the map fills 1000 × 576 screen pixels. Keep map graphics, sprites, and footsteps on the same local coordinate system. Use screen-space text for room labels, statuses, and interactive controls.
- Use deep plum `#483747` for furniture and character outlines, terracotta `#ad624c` for brick and tile, ivory `#fff0c8` for stone highlights, and lagoon blue `#3caaac` for water. Use wine and gold for a quiet interface on cream backgrounds. Make destructive, warning, and disabled states distinguishable by shape or text as well as color.
- Bedroom floors use cool blue-green tiles. The reception has a wine runner and wood desk, the buffet has apricot and cream floor tile, and the pool uses aqua water and limestone coping. The room silhouettes stay distinct at gameplay scale.
- Use a small contact shadow beneath feet and move each actor by its foot anchor. People use four walking frames at about 7 frames per second. Keep the scene's long edge on the horizontal axis and sort people by foot Y when they overlap.

## Map coordinates

All coordinates are measured from the top left of `resort.png` at 1×. Use the same placement for the upgrade overlay. The front walk runs through Y 239 and the bedroom arcade runs through Y 147.

| Location | Ground footprint (X, Y, W, H) | Foot anchor |
| --- | --- | --- |
| Arrival | 37, 247, 42, 41 | 57, 270 |
| Reception | 36, 161, 105, 71 | 94, 218 |
| Buffet | 156, 160, 122, 72 | 214, 213 |
| Bedroom A | 23, 59, 66, 71 | 56, 123 |
| Bedroom B | 95, 59, 66, 71 | 128, 123 |
| Bedroom C | 167, 59, 66, 71 | 200, 123 |
| Bedroom D | 239, 59, 66, 71 | 272, 123 |
| Pool | 310, 158, 128, 70 | 374, 195 |

Reception and buffet access the front walk. The bedroom arcade meets the front walk through the passage at X 293. Pool visitors can stop at the long edge of the pool. Use the center of the visible floor for prompts if foot anchors are occupied.

## Asset contract

| File | Dimensions | Use |
| --- | --- | --- |
| `assets/art/resort.png` | 500 × 288 | Base scene |
| `assets/art/resort_pool_upgrade.png` | 500 × 288 | Transparent upgrade art aligned to the base scene |
| `assets/art/people.png` | 80 × 120 | Four 20 × 24 walking frames per row, with three adult guest palettes, one staff palette, and a smaller child sprite |
| `assets/art/icon.png` | 64 × 64 | Game application icon |

The foot anchor in each character frame is local X 10, Y 22. Select guest rows 0–2, staff row 3, and child row 4. Use the same feet anchor for character placement and selection rings. The pool upgrade adds decorated coping, a shade structure, and a brighter tile mosaic. Its silhouette fits inside the pool deck and leaves the same walking routes available.

The art is original to this project. Run `node assets/art/generate_art.mjs` from the repository root to reproduce the PNGs. The script uses Node.js built-in modules and a fixed seed for the sand and water textures.
