# Revision 10: additional playable activities

R9 source/art/headless acceptance is complete; see `revision-9-validation.md`. This second requested pass adds every listed facility and produces the final combined Windows build. No Git push/release, desktop use or native tester resumption is authorized.

## Catalog contract

| Kind | Display name | Footprint (8px cells) | Regular cost | Family slots | Active seconds |
| --- | --- | --- | ---: | ---: | ---: |
| `lap_pool` | Lap pool | 12 × 8 | $160 | 2 | 12 |
| `lagoon_pool` | Lagoon pool | 12 × 10 | $180 | 3 | 12 |
| `hot_tub` | Hot tub | 5 × 5 | $100 | 1 | 10 |
| `kids_pool` | Kids pool | 8 × 7 | $120 | 2 | 12 |
| `waterpark` | Waterpark | 14 × 11 | $220 | 3 | 12 |
| `basketball` | Basketball court | 10 × 8 | $100 | 2 | 10 |
| `climbing_wall` | Climbing wall | 7 × 6 | $100 | 1 | 12 |
| `arcade` | Arcade | 7 × 5 | $90 | 2 | 10 |
| `cafe` | Cafe | 8 × 6 | $60 | 2 | 6 |
| `nightclub` | Nightclub | 10 × 8 | $140 | 4 | 10 |

These are editable prefab activity venues. The additional pools do not replace or duplicate the core staffed resort-pool station. Cafe/arcade/nightclub internals are prefab art, while R9 room/building interior and exterior settings remain fully available for enclosed structures. Developer placement is free with zero refundable paid basis; Regular retains existing purchase/half-paid demolition refunds and staging. Do not inject venues into saved layouts or the starter layout.

## Discovery and guest behavior

Build → Facilities adds Water, Sport and Social subgroup navigation. Water holds the five aquatic kinds. Sport holds Basketball/Climbing plus existing Volleyball. Social holds Arcade/Cafe/Nightclub plus existing Beach lounge/Beach bar/Evening stage. Keep full readable labels, visible cost/Free, and universal Select/Move/Rotate/Bulldoze. Use a wider compact palette or paging if needed; do not overlap controls or crowd fourteen tiles into one row.

Daytime activities choose deterministically among available connected venues, changing choices across guests/days. Cafe is an alternative refreshment stop to the beach bar; nightclub is a clearly scheduled nighttime alternative to the stage. Each new kind must be genuinely used when it is the sole optional venue, with real access routes, exclusive slots/capacity, saved active phases and departures. Existing behavior stays stable when none of the new venues is built.

Aquatic poses remain inside actual pool shapes. Waterpark guests follow its slide action rather than floating over the structure; climbers follow the wall with upright projection; basketball/arcade/cafe/nightclub have distinct interaction poses. All four orientations transform footprints, entry/access points and guest positions together. Upright slides/hoops/walls/roofs stay upright. Action overlays must preserve base surface materials.

## Ownership and acceptance

The existing Sol/xhigh core integrator (`systems_r9`) adds catalog/model/simulation/UI/save behavior, tests and final export. The existing Sol/xhigh visual specialist (`visual_r9`) adds art/renderers/poses and generated previews. Files remain disjoint. Astra/high PM owns contract/docs/acceptance. Root owns independent `tests/activity_expansion_test.gd`, README/launch notes, package verification and any Git decision.

Acceptance includes every kind at every orientation, real sole-venue participation, capacity/unique reservations, paid/free purchase and demolition, moved geometry, active visit save/resume, scheduled nightclub, current/legacy saves, R9 regression preservation, routed UI geometry and final standalone Windows smoke. Root/PM inspect generated art, including a polished `docs/screenshots/activities-preview.png`; this is not native capture. Detailed rotation/phase atlases may remain under `.tools`.
