# Revision 9: connected architecture, seasons and ocean swimming

Baseline R8 is committed and pushed at `37e2520795bc1847e121705ba30693f95bb2cc43`. This revision is a local implementation/delivery; do not push or publish it without the root coordinator's subsequent authorization. The user requests all features below. Fixed coastline geometry remains; the earlier exclusion of ocean swimming is superseded.

## Accepted behavior

- Every furniture/scenery/facility asset supports four visually correct orientations matching its footprint. Upright objects remain upright in the three-quarter view. Guest activity adds overlays without replacing the underlying table or court material.
- Buildings rotate in quarter turns with their doors, pool water and furniture. Edge-adjacent enclosed rooms sharing at least 16 pixels become a connected building unit with actual internal doorways and continuous exterior treatment. Room identities and booking capacities remain distinct. Whole-unit rotation is atomic and rejects collisions, wet ground or inaccessible layouts without partial edits. Pools remain independent outdoor facilities.
- Selected-building settings expose separate facade and roof finishes in addition to existing interior finishes. Connected exterior choices propagate across the unit. Charges use final differences; old saves migrate to the original appearance and zero rotation.
- Ocean swimming uses actual reachable shore access and water positions. Beach controls expose Safe flags (default), Allow red risk and Closed. The default returns swimmers safely when conditions close; deliberately permitting red conditions introduces a deterministic, serializable risk of a non-graphic adult fatality, companion evacuation and an explicit severe review consequence. Events are recorded once and explained to the player. Dry-land amenities remain usable under red flags.
- A deterministic calendar compresses three resort days into each month, starts in March and advances a 24-hour visual cycle over each 240-second resort day, starting at 06:00. Seasonal temperature and visible month/time are game climate values, not forecasts. Night lighting affects the world while preserving UI readability.
- Persisted sargassum accumulation responds to seasonal pressure, appears along the fixed beach and affects guest satisfaction through actual exposure. A clear paid Regular/free Developer beach-cleaning action reduces it. Research and game assumptions are distinguished in `seasonal-research.md`.
- A continuous nightly-price slider runs from $90 to $200 in $5 increments. Satisfaction preserves the prior anchor values ($90: +5, $120: 0, $170: -12) with interpolation. Demand is four families below $150, three above, bounded by usable rooms. Booked price/value are captured so later slider changes cannot retroactively change a stay.

All changes retain staged construction, actual costs/refunds, old-save migration, safe draft/queue handling and the existing restaurant/leisure loops. No desktop use, native captures, visible game/editor windows or native tester resumption; verification is headless plus generated offscreen artifacts.

## Ownership and acceptance

The Astra/high PM owns scope, this contract, board, decisions and acceptance. Two Sol/xhigh specialists run with separate files: `systems_r9` owns layout/simulation/UI/controller/save integration, its tests and export; `visual_r9` owns building, amenity, landscape, ocean and map renderers, original art, visual tests and offscreen previews. Root owns `resort_calendar.gd`, calendar/independent contract tests, research, README/launch notes and final packaging. No shared production file has two owners.

Acceptance requires meaningful tests for all four rotation states and four-turn identity, atomic blocked unit transforms, connected doorway routes and capacities, visible exterior choices, invariant table/court materials, default-safe and explicit-risk swimming with exact resume/once-only incidents, month/temperature/daylight and sargassum/cleanup/price effects, old/current saves, routed controls, and standalone Windows smoke. Native visual/playtest validation remains deferred and must not be implied by geometry or generated screenshots.

## Integration API

Layout schema 4 adds building `rotation` (clockwise 0–3), `finishes.facade` (Original/Plaster/Brick/Timber) and `finishes.roof` (Original/Terracotta/Slate/Metal). `building_unit(id)` returns member dictionaries sorted by ID. `rotate_building(id)` and `rotate_asset(id)` return the existing `{ok, reason, id}` mutation result. `shared_doors(building)` returns world doorway points; `door_side(building)` identifies the rotated external door side. `ocean_access()` returns reachable `{shore, water}` points or an empty dictionary.

Simulation exposes `selected_price`, `booked_price` (zero before bookings lock), `booked_value`, `sargassum`, `swim_policy` (`safe`, `allow_red`, `closed`) and `ocean_incidents`. Methods are `calendar_state()`, `set_price(price)`, `price_value(price)`, `bookings_for_price(price)`, `set_swim_policy(policy)`, `clean_beach()` and `surf_condition()`. The outer save advances to version 8. Calendar `state(day, second)` returns month, month name, day within compressed month, year, hour, temperature, daylight, seasonal pressure and season label.

`set_swim_policy()` returns a boolean. `clean_beach()` returns `{ok, reason, cost, removed}`; cleanup costs $30 in Regular, is free in Developer, and removes up to 60 accumulation points. Bulldoze continues to remove the selected room only, then recomputes connected neighbors; rotating the unit and changing its exterior are explicitly group actions, while interior finishes remain per-room.
