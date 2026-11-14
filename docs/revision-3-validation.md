# Revision 3 construction validation

Revision 3 was checked through implementation-team headless tests and local generated-file inspection. The user's no-computer-use instruction remained in force: no desktop captures, native/browser automation or visible game/editor windows; the tester remained on break. Native interaction, rendered gameplay appearance and subjective audio quality are not verified for this revision.

## Component evidence

- Design UI: 373 headless geometry, action, state and pointer checks passed, including Regular/Developer modes, unaffordable but saveable drafts, deferred apply and held funds.
- Layout model: 34 headless checks passed for building/furniture geometry, doors, shoreline, operational readiness, navigation, quotes and saved state.
- Construction transactions: root's public simulation API suite passed 24 checks for purchases/refunds, free mode, queued holds, atomic replacement, save validation, no double charge, deferred refunds and room-capacity changes. The developer's final rerun also passed.
- Modular art/renderer: 111 headless geometry checks passed for 32 furniture rotations, model alignment, doors, roof limits, pool furnishing, renderer cache and bulldozing. Repeated asset generation was byte-identical.
- PM and root inspected the generated terrain, furniture atlas and a CPU diagnostic modular composite. The composite is not a game screenshot. Buildings and furniture are no longer baked into the playable terrain.

## Integrated and portable results

- Routed construction scene: **46 checks passed**, using real viewport input dispatch for Build entry, footprint dragging, furniture placement/rotation, selection, bulldozing, land/collision rejection, camera separation, operational reasons, both modes, construction quotes, saved drafts and queued plans. A separate relaunch passed **six checks** for restored draft, camera, queued reservation and safe next-day application.
- Dynamic guest routes: a usable bedroom was rebuilt at a new position and reduced room capacity changed bookings. The final targeted regression moved the pool to `(96,40,144,80)` through routed editor controls; guests approached its new deck on the navigation graph, swam in the new water outside the former pool, and returned through the relocated deck. This passed without production changes after export.
- Management regression: **73 checks passed**, plus the simulation fixture suite. Camera regression passed **34 checks**. The management HUD passed **1,532 geometry assertions**; these are control-bounds checks, not rendered visual QA or 1,532 independent gameplay scenarios.
- Save compatibility: the authentic original active-save fixture passed **four checks**. A **synthetic upgraded version 2 fixture** passed four checks for functional terrace furnishing, zero migrated paid cost and preserved camera; it is distinguished from a save captured from the prior executable. New saves retain active layout, pending plan/reservation, incomplete draft, mode, simulation, speed and camera.
- Source and isolated executable-only headless smoke passed **12 stays, exact 95.25 average rating, $1,120 cash, furnished terrace and modular map/ocean/audio loading**, with exit code 0 and clean runtime output. The new $100 physical pool furnishings replace the historical $420 purchase.
- Export/import completed successfully. Godot emitted a nonfatal editor-preference safe-save warning in the sandbox; resource packing and the actual portable runtime passed.

## Delivered artifact

`build/windows/AllInclusive.exe`: **111,236,520 bytes**, SHA-256 `440128AA3378ABA61704296D3E13CB2C834233C7F42099C759094AFDC019698D`.

`build/AllInclusive-Windows.zip`: **41,158,774 bytes**, SHA-256 `410EF0FE0CBA4F96CF935877B0A80D02F16E9610C7BC4B7E818FADFA71B15074`.

Root verified exactly four flat archive entries (`AllInclusive.exe`, `START_HERE.txt`, `CREDITS.txt`, `THIRD_PARTY_NOTICES.txt`) and streamed the archived executable to confirm its hash matches the frozen, smoke-tested candidate. The relocated-pool regression changed tests only, so the packaged executable remains the accepted production build.

## Reproduction

Use the Godot 4.7.2 console executable under `.tools/godot/` with `--headless --path .`. Run `tests/layout_model_test.gd`, `tests/construction_transactions_test.gd`, `tests/simulation_test.gd`, `tests/camera_test.gd`, `tests/ui_layout_test.gd` and `tests/independent_acceptance.gd` via `--script`.

For `tests/construction_scene_test.gd`, use a new process-local `APPDATA` directory whose path contains `.tools/tester-appdata-r3-design`. Run once normally and again with `-- --resume` using the same test profile. Use separate isolated profiles for legacy-save fixtures. Source/portable smoke uses `-- --smoke-test`; the portable command additionally uses `--headless --quit-after 240` and never opens a visible game window.

Portable runtime log: `.tools/r3-portable-41f59ea6-7ed4-4c9e-ada7-4880c0da97ea/headless.log`.

Final clean suite logs are under `.tools/r3-logs/`: `construction-scene.log`, `construction-relaunch.log`, `management.log`, `legacy-v1.log`, `legacy-v2-synthetic.log`, `transactions.log`, `layout.log`, `camera.log`, `hud.log` and `simulation.log`. All exited 0. The final explicit portable process exit-code/hash recheck is `headless-recheck.log` beside the portable log above; export output is `.tools/r3-export.log`.
