# Revision 6: restaurant meal interaction

## Accepted behavior

Guests collect food at the actual buffet counter, wait for a reachable dining table, walk to their reserved table, sit and eat, then leave for the pool from that table. Editable furniture geometry and real reservations determine the activity; it is not a timed visual substitution for buffet service.

- Counter collection takes 6 simulation seconds and uses the existing buffet staffing capacity and queue.
- After collection, `wait_table` releases the counter slot and waits FIFO by entry time then family ID. Table waiting is tracked separately from the counter line.
- Each accessible table reserves one family through `to_table` (4 seconds) and `eating` (12 seconds). A second table provides real additional dining capacity.
- Eating releases the reservation; `to_pool` begins at that table's seat and lasts 4 seconds. The table ID remains available for departure rendering until the family reaches the pool queue.
- Adults and children carry plates and visibly sit/eat. The map uses actual reachable seats and counter/table routes. Interior actors and meal visuals remain concealed in Exterior view; the outdoor pool is unchanged.
- Table-wait feedback and review penalties are distinct from buffet-counter waits. The existing per-station penalty formula also applies to table waits, with `Long dining table wait` as the table-specific reason. Changed rating/timing fixtures must be explained by this real meal flow rather than preserving the old 18-second buffet abstraction.

## Model contract

`Layout.dining_tables()` returns accessible table records sorted by asset ID: `{id, building_id, seat, child, table_center}`. Two reachable side cells are preferred for the adult/child positions. A cramped previously valid table uses the nearest second accessible aisle cell as a fallback; this revision does not silently invalidate existing layouts. Results are cached and invalidated with layout geometry.

`Sim.MEAL_VERSION = 1`, `TABLE_WALK_DURATION = 4`, `EAT_DURATION = 12`. Families store `table_id` and `dining_wait`; reviews also store `dining_wait`. Reservations are derived only from `to_table`/`eating` families, avoiding a second mutable reservation registry. New meal phases use station 1 and slot -1.

Save wrapper version 6 requires meal-state metadata. Legacy saves gain defaults, preserve active counter-service deadlines, and enter dining afterward. Guests already past the buffet continue their old journey without replaying a meal. New saves validate phase, timing, table identity and exclusive reservations transactionally. Current construction, pending-plan finance, appearance metadata, camera state and fixed-coast validation remain intact.

## Ownership and acceptance

The simulation/layout developer owns model, timing, save/controller/UI integration, affected regression expectations and export. The visual specialist owns map poses, plates, seated animation and reusable visual checks. Root owns independent `tests/dining_contract_test.gd`, README, credits, launch notes and final packaging. PM owns scope, contracts, review and persistent records. Both specialists use GPT-6.1 Sol/xhigh under the Astra/high PM; no more than two specialist slots are active.

Required checks cover actual counter/table routes, moved/rotated tables, exclusivity and FIFO, adding tables, plate/seated/departure poses, malformed and legacy saves, reload in each phase, fixed coast/construction/appearance regressions and complete management days. Deliver a local tested Windows executable and ZIP. No computer use, desktop capture, visible game/editor windows, tester resumption, Git commit/push or release publication. Native playtesting remains deferred.
