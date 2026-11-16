# Revision 10: requested facility expansion

**Completed:** the backlog was implemented in `revision-10.md` and delivered in the combined R9/R10 package; see `revision-10-validation.md`. The sequencing notes below preserve the original handoff.

The user requested this pass after the current revision 9 is complete. Do not interrupt the active R9 model/render owners or dilute R9 acceptance. Begin R10 once R9 source, art and headless checks are accepted; final Windows delivery must include both passes.

Required content, with the repeated basketball request treated as one type:

- More pool varieties.
- Hot tubs.
- Nightclub.
- Basketball court.
- Waterpark.
- Kids pool.
- Rock climbing wall.
- Arcade.
- Cafe.

Every listed facility must be a functional editable object with appropriate guest behavior/capacity, not merely scenery. Reuse the existing purchase, move, four-way rotate, bulldoze, price/free mode, draft/queued construction and save semantics. Match all four rendered orientations to real geometry; activity poses must remain grounded and avoid texture replacement or implausible animations.

PM will lock catalog dimensions, costs, capacities, activity schedules and pose interfaces with the same core and visual owners after R9 acceptance. Root will own independent catalog/behavior checks and final packaging. No computer use or native tester resumption. No automatic Git push or release.

## Scope agreed with root before handoff

Implement ten new facility kinds: **Lap pool, Lagoon pool, Hot tub, Kids pool, Waterpark, Basketball court, Climbing wall, Arcade, Cafe, Nightclub**. Lap/Lagoon supply the requested pool varieties. They are additional activity pools; the core staffed resort pool service remains distinct and must be described plainly. Do not inject these into existing saved layouts. They are discoverable, purchasable/free-mode catalog choices with functioning activity visits, including when a new kind is the sole optional venue.

Expand Build → Facilities with readable **Water / Sport / Social** subgroup navigation rather than cramming fourteen tiles into one row. Preserve visible prices/Free labels and universal selection/move/rotation/bulldoze. Daytime choice can vary deterministically across available venues/families/days; nightclub is an explicitly scheduled nighttime activity. Each needs real reachable access, capacity/reservation, ground-correct activity poses in all four rotations and saved-state continuity. Exact costs/dimensions and API are deferred to the post-R9 specialist contract.
