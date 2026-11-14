# Fixed-coast correction validation

The user's answer, “Keep the coast fixed for now,” overrides the earlier optional water-editing assumption. This correction removes the Water brush and makes the original coastline authoritative. Grass/sand/dirt painting on fully dry land, paths, movable/removable scenery and resort construction remain available.

## Save policy

Compatible land-only version 4 saves and versions 1–3 remain supported. A prior water-capable save containing genuine water/coast edits in its active layout, pending plan or saved draft is rejected with a specific explanation. Its file and current live run remain unchanged; the correction does not silently erase terrain, reclaimed-land buildings or queued financial state. Truly no-op explicit Water overrides on wholly ocean cells may normalize safely.

## Validation constraints

No desktop captures, native/browser automation, visible game/editor windows or tester resumption. Implementation-team headless checks and local packaging only; no Git commit, push or release.

## Results

- Root model suite: **63 checks passed**, including protected ocean/partly wet cells, original-shore authority, valid land edits and detection of protected terrain/path data.
- Routed scene: **35 checks passed**, plus **12 fresh-process resume checks**. The Water option is absent, dry-land tools remain functional, and incompatible active/pending/draft saves produce the specific protected-coast error with file bytes and the live run unchanged. True no-op overrides on wholly ocean cells normalize safely.
- Existing construction regression: **46 checks plus six relaunch checks** passed. The legacy queued-plan/draft migration regression passed **12 checks**; v1 and v2 fixtures passed four checks each.
- Standalone Windows headless smoke exited 0 with clean runtime output: **67 default props, 214 path cells, 12 stays, exact 95.25 rating and $1,120 cash**. Resort pools, ocean animation and editable dry-land scenery remain available.
- Export exited 0. The known sandbox editor-preference safe-save warning was nonfatal; the standalone game log was clean. Native visual/playtesting remains deferred.

Final executable: **111,322,896 bytes**, SHA-256 `9EA6A5E2EF8F4F6B24F4B0C300A9E1144B231A74C56FEAA4FD95515B239CBA1E`.

Logs are under `.tools/r4-integrator-logs/`: `fixed-coast-export.log`, `fixed-coast-portable-smoke.log`, `fixed-coast-scene.log`, `fixed-coast-resume.log`, `fixed-coast-legacy-v3-queue.log`, `fixed-coast-source-smoke.log`, `fixed-coast-construction.log`, `fixed-coast-construction-resume.log`, `fixed-coast-legacy-v1.log` and `fixed-coast-legacy-v2.log`.

Final local archive: `build/AllInclusive-Windows.zip`, **41,234,389 bytes**, SHA-256 `E36BD1A6B4AD63F2473D1CAA9AA62C8DFB25AA587FE038E291856C25B1FF7D48`. Root verified exactly four flat entries (`AllInclusive.exe`, `START_HERE.txt`, `CREDITS.txt`, `THIRD_PARTY_NOTICES.txt`) and streamed the archived executable to confirm its hash matches the accepted fixed-coast candidate. The standard executable path is `build/windows/AllInclusive.exe`; checksum sidecar and launch notes were updated. The superseded water-capable ZIP was retained under `.tools/releases/`.
