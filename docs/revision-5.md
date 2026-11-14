# Revision 5: exterior view, signs and building finishes

## Accepted design

- One resort-wide Interior/Exterior control changes every enclosed building together. Exterior mode renders complete roofs and front facades and hides covered interiors/furniture/actors. Pools remain outdoors and keep their guests and furnishings visible. Simulation and navigation do not change.
- Build mode temporarily uses the interior view for editing, then restores the user's view preference. Save/load preserves the preference; older saves default to interior. Ceiling inspection is a separate transient selected-building preview.
- Buildings store `display_name` and `finishes` (`floor`, `wall`, `ceiling`). Defaults are Room A–H, Lobby, Restaurant and Pool. Names are trimmed, single-line, printable and 1–24 characters. Physical signs show the selected name; long names must fit the available plaque and remain fully visible in the properties editor.
- Selecting an enclosed building in Design opens an on-demand compact properties panel for its name and finishes. Pools support names only. Floor choices are Original/Tile/Wood/Stone; wall choices Original/Plaster/Brick/Timber; ceiling choices Original/Plaster/Beams/Panels.
- Materials must change visible patterns. Floor and wall finishes are visible in the cutaway. **Inspect ceiling** shows the selected building's ceiling plane and a labeled material preview; it does not relabel the exterior roof as a ceiling.
- Regular mode charges $12 per final floor change, $10 per wall change and $8 per ceiling change. Developer mode is free. New buildings pay a surcharge only for nondefault finishes; repeated draft cycling charges only the final differences. Finish expenses do not add to demolition refunds. Renaming is free.
- All changes use existing drafts, previews, Apply now/Apply tomorrow and saved/pending layouts. Existing saves gain default names/finishes without a migration charge.
- Name entry must accept spaces, numbers and letters without triggering global pause, speed, rotation or camera shortcuts. Properties controls block world editing; Escape dismisses editing focus/panel deliberately.

## Ownership

Root owns layout schema, validation, names/finish catalogs, quote semantics and model tests, plus README/launch notes/final packaging. The building visual specialist owns `building_renderer.gd`, finish assets and physical signage. The UI/core integrator owns selected-building settings, view preference, input/focus, actor visibility, save integration, routed tests and export. PM maintains scope, contracts and acceptance.

## Constraints

Keep the coast fixed and preserve the existing landscape/construction behavior. No computer use, desktop capture, visible game/editor windows or tester resumption. Use headless checks and local generated-art inspection; record native playtesting as deferred. Deliver a local executable/ZIP without committing, pushing or publishing a release.
