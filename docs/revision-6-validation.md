# Revision 6 validation

Status: accepted and delivered locally. Implementation, permitted headless acceptance, standalone executable smoke and archive verification are complete. This package supersedes R5 while preserving its appearance features and the fixed coast.

## Evidence received

| Check | Result | Evidence |
| --- | --- | --- |
| Independent dining contract | 63 passed | Root `tests/dining_contract_test.gd`, exit 0, stdout-only, isolated `APPDATA=.tools/r6-root-appdata` |
| Existing layout model | 34 passed | Root CLI, exit 0 |
| Building identity/finishes | 43 passed | Root CLI, exit 0, stdout-only, same isolated profile |
| Construction transactions | 24 passed | Root CLI, exit 0, stdout-only, same isolated profile |
| Routed dining scene | 37 passed | `.tools/r6-developer-logs/final-dining-scene.log`: five meal checkpoint phases, v5 appearance migration, old service deadline/no replay, staged tables, nearby/cramped geometry and malformed current metadata |
| Management and relaunch | 73 + 9 passed | Developer; includes 48 seeded staffing days |
| Legacy saves | v1 4, v2 4, legacy queued/draft 12 passed | Developer |
| Construction scene and resume | 46 + 6 passed | Developer; moved-pool departure now originates at the table |
| Landscape scene | 35 passed | Developer |
| Appearance scene | 46 passed | Developer |
| HUD geometry | 1581 checks passed | Developer; geometry audit, not native visual QA |
| Simulation and source smoke | Passed | Developer simulation; `.tools/r6-developer-logs/final-source-smoke.log` reports 12 stays, 93.25 rating and $1120 |
| Dining visuals | 34 passed with CPU preview | `.tools/r6-developer-logs/final-dining-visual.log`; actual phase poses, plates/chairs, pause clock, moved/rotated table, exterior concealment and combined queue badge fit within an 80px buffet |
| Existing building renderer | 94 passed without preview | Visual specialist headless regression |
| Windows export | Passed, exit 0 | `.tools/r6-developer-logs/final-export.log`; same nonfatal sandbox editor-preference safe-save warning as R5 |
| Standalone executable-only smoke | Passed, exit 0 | `.tools/r6-developer-logs/final-portable-smoke.log`; 12 stays, 93.25 rating, $1120 and meal/terrace/landscape/ocean/audio resources |

The root model checks and earlier developer regression suite were captured in tool stdout. Final focused check/export logs are persisted under `.tools/r6-developer-logs/`. The candidate was copied to an executable-only directory, `.tools/r6-portable-smoke-final`, with a matching hash and isolated APPDATA before headless smoke; runtime output is clean.

Independent dining checks cover one versus two real tables, unique reachable seats outside solid furniture, FIFO/exclusive reservations, actual moved-table geometry, every family eating once, separate waits, $20 table cost, exact uninterrupted versus resumed results in waiting/walking/eating states, and transactional rejection of nonexistent/duplicate reservations.

## Explained timing changes

The old 18-second buffet abstraction is replaced by 6 seconds collecting food, a separate FIFO table wait, 4 seconds walking and 12 seconds eating. With the starter single table, Standard families finish collection at seconds 52/60/68/76 and depart the table at 68/84/100/116. Their dining waits are 0/8/16/24 seconds; pool waits are 0/4/8/12. Independently predicted and developer-measured Day 1 scores are 92/91/86/80; upgraded-pool scores are 100/99/95/91. The three-day terrace run produces 12 stays, 93.25 average and $1120. These are intentional changed fixtures, not a regression hidden by retaining old expectations.

## Accepted artifact

- Executable: `build/windows/AllInclusive.exe`, 111,362,472 bytes, SHA-256 `FB06BB622432D4E34A0AC29B56E887A027F7FCEE9FD52D3EB48DDECD8573C05C`.
- Archive: `build/AllInclusive-Windows.zip`, 41,274,527 bytes, SHA-256 `9A1796C03BD08A5BFDD601CAA2BA8DB0157086F48AADDDDB7943F343E4907ADB`.
- Root verified exactly four flat entries: `AllInclusive.exe`, `START_HERE.txt`, `CREDITS.txt`, `THIRD_PARTY_NOTICES.txt`. The streamed archived executable matches the accepted candidate and canonical executable. `build/SHA256SUMS.txt` is updated.
- The provisional candidate before the compact status fix was replaced; the identities above are authoritative. The prior R5 archive is preserved at `.tools/releases/AllInclusive-r5-building-appearance-Windows.zip`.

PM acceptance: all requested meal interaction work and required permitted checks are complete. Both specialists are finished; no commit, push or release publication occurred.

## Limits and follow-up

The root coordinator, PM and visual specialist inspected the CPU-generated `.tools/r6-dining-preview.png`. The initial seated sprites hid too much of the tabletop; the corrected compact silhouettes leave both filled plates visible. The artifact shows collection, waiting with plates, walking, sitting/eating, departure and exterior concealment from actual phase snapshots. It is not a native gameplay capture. A final status adjustment uses `Food 2 · Tables 1` when both queues are present, with measured fit at the smallest restaurant width.

The 6-second food collection is as fast as the default arrivals, so extra buffet staffing provides little benefit in the starter layout. Extra tables now provide a real capacity improvement. Future balancing can strengthen buffet-staff tradeoffs; it is outside this focused visible-dining iteration.

No computer use, desktop capture, visible windows or independent tester resumption is permitted. Headless geometry/logic and generated CPU previews are not native visual playtesting. Native playtesting remains deferred. No Git commit, push or release publication is part of this local delivery.
