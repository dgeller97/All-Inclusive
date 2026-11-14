# Revision 7 validation

Status: accepted and delivered locally; source handoff is ready for root's authorized commit/push. Implementation, required headless acceptance, standalone executable smoke and archive verification are complete. This package supersedes R6.

## Evidence received

| Check | Result | Evidence |
| --- | --- | --- |
| Independent beach contract | 127 passed | Root `tests/beach_contract_test.gd`, exit 0; stdout-only, isolated `APPDATA=.tools/r7-root-appdata` |
| Routed beach scene | 61 passed | Developer; actual tool clicks, prices, rotation/free move/apply, moved sprite geometry, occupancy, red-flag dry-land activity, active-show save, malformed schema and v6 migration |
| Beach visual probe | 121 passed | Visual specialist; actual starter-day activity scenes, every amenity after move/rotate, outdoor visibility and generated CPU preview |
| Management/relaunch | 73 + 9 passed | Developer; full progression and separate process resume |
| Authentic old saves | v1 4, v2 4 passed | Developer |
| Landscape scene/resume | 35 + 12 passed | Developer; old brush fixtures intentionally retain amenity-free geometry |
| Construction scene/resume | 46 + 6 passed | Developer |
| Legacy queued/draft migration | 12 passed | Developer |
| Dining contract/scene/visual | 63 / 37 / 27 passed | Developer regressions |
| Building identity/appearance/renderer | 43 / 46 / 94 passed | Developer regressions; renderer run without optional preview |
| Layout/landscape/transactions | 34 / 63 / 24 passed | Developer regressions |
| Camera | 34 passed | Developer |
| HUD geometry | 1621 checks passed | Developer geometry audit; not 1621 separate gameplay tests |
| Simulation | Passed | Developer; suite prints no numeric count |
| Source and standalone smoke | Passed | 12 stays, displayed 95.42 rating, $1120; meals, terrace, all four beach activities, landscape, ocean and audio |

All checks above passed with zero failures. Root reran the 127-check independent contract after final starter positions and it still passed. Apart from the logs below, the test evidence was captured in tool stdout. No broad retesting was added after the final source freeze.

Persisted logs: `.tools/r7-developer-logs/import.log`, `export.log`, `portable-smoke.stdout.log`, and `portable-smoke.stderr.log` (empty). Import/export each emitted the existing sandbox editor-startup `Safe save failed` diagnostic, exited 0 and produced the packed executable. The executable-only standalone run used a separate working directory and isolated APPDATA, exited 0 and had clean runtime output.

The independent contract covers four dry connected starter amenities; all four activity kinds actually visited; capacity and unique slots in travel/activity/departure; moved bar geometry; missing amenities skipped without invisible visits; exact interrupted/uninterrupted outcomes across every amenity kind and all three phase checkpoints, including bar origin state and evening schedule; malformed IDs/slots rejected transactionally; capped completed-activity bonus compared with an amenity-free run; $100 bar construction/$50 demolition refund; Developer free construction with no resale windfall; and pre-expansion save migration with no free venue injection or unearned bonus.

## Expected balance

Each completed distinct activity adds one satisfaction point, capped at three before the overall 100-point cap. With all three eligible activities completed by every family, independent expected Standard scores are Day 1 `[95,94,89,83]` and upgraded `[100,100,98,94]`, for `1145/12 = 95.4166667` over three days and unchanged $1120 cash. Developer source smoke matches: 12 stays, displayed 95.42 rating and $1120.

## Accepted artifacts

- Executable: `build/windows/AllInclusive.exe`, 111,390,200 bytes, SHA-256 `A15CDA2AC965BE162DFF726759F95797D05A67F598C96DF1AE72612613E6ACCE`.
- Archive: `build/AllInclusive-Windows.zip`, 41,301,812 bytes, SHA-256 `66199887A1FC43EAD15C01C768348359DFAA16F1BF4C55A1E6DEEC51EB8A2EE5`.
- Root verified exactly four flat entries: `AllInclusive.exe`, `START_HERE.txt`, `CREDITS.txt`, `THIRD_PARTY_NOTICES.txt`. The streamed archived executable matches the accepted candidate and canonical executable. `build/SHA256SUMS.txt` is updated.
- Accepted generated preview: `docs/screenshots/beach-leisure-preview.png`, copied from the actual-phase CPU diagnostic after visual freeze. Root, PM and the visual specialist inspected it. The initial palm occlusion and edge-on net were corrected; the final parasol, net, drinks and stage are readable. The README explicitly labels this as generated CPU evidence, not native capture.
- Prior R6 archive preserved at `.tools/releases/AllInclusive-r6-restaurant-Windows.zip`.

PM acceptance: this is a coherent tested stopping point for the autonomous expansion. Both specialists are finished, production files are frozen and all required local package work is complete. Root owns the authorized source commit/push after this handoff; no new GitHub binary release was requested.

## Boundaries and limitations

The coast stays fixed, and no ocean swimming is added. Red flags govern water conditions; dry beach activities remain usable. Old layouts are preserved. No computer use, native capture, visible game/editor windows, independent tester resumption or spending. Generated CPU artifacts and headless geometry/logic checks are not native visual playtesting. Root owns the authorized Git push and package delivery.
