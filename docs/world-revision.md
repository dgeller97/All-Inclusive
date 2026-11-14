# Enlarged resort grounds and ocean

**Revision 2 historical contract.** Revision 3 retains the world bounds, terrain/coast profile and deterministic ocean, but replaces baked buildings and the fixed terrace overlay with editable layout-model structures and furniture. Use `revision-3.md` and `modular-art.md` for current building geometry and rendering. Fixed facility coordinates below describe the earlier release only.

The new resort ground covers world coordinates **(−160, −120)** through **(800, 480)**, with the right and bottom edges exclusive. Draw the 960 × 600 `resort.png` at (−160, −120). The four bedrooms, staff stations, pool, paths used by guests and entrance retain their world coordinates. Draw the transparent 500 × 288 `resort_pool_upgrade.png` at (0, 0). The terrace purchase extends the raised deck east while retaining an uninterrupted sandy buffer between the pool and the surf.

`ocean.gd` is a world-space Node2D. Add it to the map at (0, 0) and call `present(total_sim_time)` with elapsed simulation seconds across all days, including after loading. Map panning and zooming affect the ocean and flag with the rest of the world. Keep the pool's own shimmer in the map renderer. The new ocean component draws the shoreline wash, offshore breakers, water glints and the beach flag near (477, 158).

| Simulated time in each 112-second cycle | Representative condition |
| ---: | --- |
| 0 seconds | Calm, green flag |
| 29 seconds | Caution, yellow flag |
| 56 seconds | Closed, red flag |
| 84 seconds | Caution, yellow flag |
| 112 seconds | Calm, green flag |

The beach board names the current condition in text. `condition_name()` and `condition_color()` expose the same state to the interface. Wave height and brightness rise and fall continuously with the simulation clock. The flag is environmental information about ocean conditions; this prototype has no ocean swimming mechanic. Families continue using the resort pool independently of the beach flag.

Run `node assets/art/generate_art.mjs` to regenerate the pixel art. It produces `resort_shore.png` from the same profile that paints the base terrain. Each row encodes the first water column, and the ocean component clips each animated run against that column and the map boundary.
