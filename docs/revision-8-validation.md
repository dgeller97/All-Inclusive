# Revision 8 validation

Status: accepted and delivered locally. Frozen source, headless acceptance, standalone smoke and canonical archive verification are complete.

## Baseline reproduction

Before edits, root's `tests/construction_consistency_test.gd` ran 76 checks with 39 failures and early returns. The integrator independently confirmed that all four starter amenities could neither be selected nor bulldozed from default Buildings. Their actual footprint centers were lounge `(496,124)`, court `(388,112)`, bar `(440,272)` and stage `(352,276)`; each remained after the attempted removal. The model already supplied purchase prices, removal and refunds; the defect was in the category-gated controller and hidden catalog.

## Required acceptance

The focused fix must expose visible price/Free tiles in Build → Facilities, make Select/Bulldoze category-independent, preserve safe hit priority and selected-object Move/settings, and retain real Regular/Developer transactions. Tests must include all four starter facilities, building/furniture/scenery selection from other catalogs, paid refunds/free starter removal, current guest use with Apply Tomorrow, reload and actual following-day removal. The model, simulation, saved schema and starter content stay unchanged.

## Evidence received

Root's independent consistency suite now passes **137/137**, exit 0, with isolated `APPDATA=.tools/r8-root-appdata` and stdout-only evidence. It covers all four categories against all four facility types; furnishings, building settings/whole-building removal and ordinary scenery; eight Regular/Developer purchase-delete cycles with actual cash/refunds; and an occupied bar removed in a queued plan, preserved through save/reload and applied on Day 2. No model or transaction defect was found.

The dedicated `tests/facilities_scene_test.gd` passes **610/610** checks against frozen production source. This count includes geometry checks, not 610 separate gameplay scenarios. It routes real mouse/Escape input through the scene to inspect all palettes, Regular prices and Developer Free labels; selects, rotates, moves and removes all four starters from Buildings; verifies Move remains available after choosing Bulldoze; checks furniture/building/scenery hit priority and settings; and exercises saved drafts, paid placement, occupied-bar queue cancellation/reload, Day 2 demolition/refund, and free Developer placement/removal. Geometry checks include sibling overlap, containment and text width. PM reviewed the actual input and transaction coverage.

Final affected routed regressions pass: Beach scene **60/60** (including current and v6 saves), Construction scene **46/46** plus resume **6/6**, Landscape scene **35/35**, Appearance scene **46/46**, and Dining scene **37/37**. Management UI geometry passes **1,621/1,621** containment checks. The Beach scene uses the new direct Facilities tab. Root reran the independent **137/137** after the final Move adjustment. Model, simulation, finance, layout defaults and saved schema are unchanged.

Both source and standalone executable-only headless smoke runs pass with **12 stays, 95.42 rating and $1,120**, including restaurant meals, furnished terrace, all four beach activities, editable landscape, ocean and audio loading. Standalone exit code is 0 and stderr is empty. Export exits 0; its log contains the pre-existing editor-startup `Safe save failed` diagnostic also observed in R7, distinct from the clean standalone runtime.

Persisted integrator evidence is under `.tools/r8-integrator-logs/`: `facilities.log`, `consistency.log`, `beach.log`, `landscape.log`, `construction.log`, `construction-resume.log`, `appearance.log`, `dining.log`, `management-layout.log`, `source-smoke.log`, `export.log`, `standalone-smoke.stdout.log`, and empty `standalone-smoke.stderr.log`. Tests use isolated workspace APPDATA profiles and the supplied Godot 4.7.2 runtime. Root's independent rerun is stdout-only as recorded above.

## Artifact identity

Frozen candidate `build/r8-candidate/AllInclusive.exe`: **111,390,616 bytes**, SHA-256 `D0E9742C8AA834279DAF374D99EC31AFBC613E9C120FA4AF19906EE74DB08624`. PM independently checked the file hash and read the persisted dedicated-test and standalone-smoke output. Root owns copying the accepted candidate and verifying the four-file Windows archive.

Root verified canonical `build/windows/AllInclusive.exe` and the streamed executable inside `build/AllInclusive-Windows.zip` match that accepted hash. The ZIP is **41,302,336 bytes**, SHA-256 `28EC2E5CF5CAF90028081FB717C77CF05CF7327A5A84DBAF6E2FDD7D7ADCAF8D`, with exactly four flat entries: `AllInclusive.exe`, `START_HERE.txt`, `CREDITS.txt`, and `THIRD_PARTY_NOTICES.txt`. `build/SHA256SUMS.txt` is updated. R7 remains backed up under `.tools/releases/AllInclusive-r7-beach-Windows.zip`. The integrator is finished and production is frozen.

No computer use, desktop capture, visible game/editor windows or native tester resumption. Headless controller and geometry checks do not constitute native visual playtesting. Root owns any Git operations; no new release is part of this fix.
