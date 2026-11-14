# Revision 4: landscape and path editing

## Requested outcome

Draw functional paths, paint land terrain and edit the existing environment rather than add decoration over a fixed backdrop. Existing palms, groves, promenade and beach flag become model objects or cells that can be changed, moved or removed. The user's later scope answer is authoritative: **keep the coast fixed for now**.

## Scope and decisions

- Keep the paused staged Design flow, Regular construction costs, Developer free editing, Save draft and safe Apply now/Apply tomorrow behavior from revision 3.
- Add compact landscape categories rather than expanding the entire catalog into one permanent toolbar.
- Terrain brushes: grass, sand and dirt, plus Restore original ground/path on fully dry land. Path brushes: stone, boardwalk and erase path. Brush sizes 1, 3 and 5 cells; drag strokes interpolate across crossed cells. There is no Water brush.
- Paths affect guest route preference. Ordinary land remains walkable; water and physical scenery footprints obstruct navigation. Required hotel routes must remain operational before a plan can be applied.
- Props include existing palms, shrubs/rocks, outdoor benches and the beach flag. Support selecting, moving and removing existing props, preserving their identity and actual paid cost when moved.
- The original shore profile is authoritative. Ocean and partly wet coastal cells are protected from terrain, path and Restore strokes. No water painting, ponds, reclamation, bridges, elevation or ocean swimming simulation in this pass.
- Default terrain and paths are encoded at the existing 8 px world grid. All generated paths/props must come from editable default data, and the base art must not retain ghost palms or a baked promenade after removal.
- Regular quotes use final draft changes, not pointer-event counts. Ground paint costs $1 per changed grass/sand/dirt cell; paths cost $2 for stone and $3 for boardwalk. Terrain/path edits have no resale refund. Props use catalog prices and half-actual-paid refunds; moving preserves identity/basis. Repeated brush touches must not charge twice. Developer and initial free objects must not create refund money.
- Ocean clipping and dry-cell validation always use the original detailed shore profile. Path weight is 1; ordinary grass, dirt and sand have greater traversal weights, so routes prefer useful paths without making unpaved land impassable.
- Old saves receive the default landscape while retaining their building/furniture layout, money and management state. New saves include active, pending and draft landscapes.
- Compatible land-only version 4 saves and versions 1–3 remain supported. A prior water-capable R4 save with genuine water/coast edits is rejected with a specific message, preserving both the file and current run. Do not silently alter terrain, dependent buildings or queued finances. Truly no-op water overrides on wholly ocean cells may be normalized safely.

## Ownership

- Root: `scripts/landscape_model.gd`, `scripts/layout_model.gd`, default-data/model/navigation/finance integration and model tests.
- Landscape visual specialist: `assets/art/**`, `scripts/landscape_renderer.gd`, `scripts/ocean.gd`, visual contract and generated-file checks.
- UI/core integrator: existing Design UI/controller, game/map/simulation/save integration, routed input/regression tests and Windows export.
- PM: contracts, scope, documentation, evidence and acceptance. Root packages the final local ZIP.

## Session constraints

No computer use, desktop captures, native/browser automation or visible game/editor windows. The tester remains on break; implementation-team headless checks and local generated-file inspection are permitted. Do not push or publish a GitHub release for this request. Deliver the revised executable and ZIP locally, recording native playtesting as deferred.
