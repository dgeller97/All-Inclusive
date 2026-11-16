# Revision 13 validation

Status: **Revision 13 accepted and delivered locally**. Source, Developer behavior, expanded-world compatibility, final generated overview, standalone Windows and canonical archive verification are complete. Both specialists are finished and source/art are frozen.

## Developer behavior

Specialist `tests/developer_showcase_test.gd` passes **85/85**. It verifies explicit single-use initialization, unchanged Regular and old Developer layouts, every catalog kind, reachable entrances and boardwalks, zero paid basis, working hotel/terrace/two dining tables, and actual visits/completions of all fourteen activities across the first three days with twelve stays. It compares active walking/participating/departing saves against uninterrupted endpoints and validates opening/completed markers, malformed-marker rejection, queued removal/relocation into expanded southern land, and no asset resurrection on load. Logs: `.tools/r13-showcase-model.log` and the passing baseline Simulation check `.tools/r13-showcase-regular.log`.

Root's independent `tests/developer_scene_test.gd` passes **59/59** through actual controller entry. It clicks the Developer welcome button, finds all four building kinds, eight furnishing kinds and nineteen outdoor prop kinds (fourteen activities plus five scenery types), observes actual three-day activity coverage/twelve reviews, and checks overview/Home, free demolition/save, Regular restart and legacy Developer reload without injection. Log: `.tools/r13-developer-scene.log`.

Root scene regressions pass: actor facing **75**, dining **37**, activity expansion **79**, R9 scene **24**, construction scene **46**, landscape scene **35**. Existing isolated construction/landscape fixtures initially collided with the newly preplaced items/paths or assumed the old camera zoom. They now explicitly use their prior sparse Developer fixture and original zoom for the same editing assertions; the new independent scene suite covers the real showcase entry. Logs are `.tools/r13-<test_script_basename>.log`.

No model-side mode setter or restore populates a showcase. The optional persisted `developer_showcase.completed` marker changes only explicitly configured new Developer choice priority; ordinary capacity/reservation/phase logic remains authoritative. Removed/moved venues stay edited after queued application and reload.

Systems specialist additionally reports clean R9 model **210**, activity expansion **1,395**, layout **34**, landscape **63**, construction consistency **137** and transactions **24**, dining contract **63** and beach contract **127**. Final model/scene logs are `.tools/r13-final-developer_showcase_test.log`, `.tools/r13-final-developer_scene_test.log`; integrated smoke `.tools/r13-systems-source-smoke.log` passes. Root's `.tools/r13-source-smoke.log` independently passes, including all fourteen showcase visits and the unchanged Regular **12 stays, 95.42 rating, $1,120** result.

## Expanded-world evidence

`tests/expanded_world_test.gd` passes **50/50**. Digest comparisons preserve all **576,000** original terrain pixels, **9,000** original terrain/path cells, **600** original shoreline rows and original scenery JSON/order. These are preserved-data counts, not distinct gameplay tests. The suite also verifies common grid/world/texture bounds, expanded dry/wet edges, valid expanded construction/routes/save behavior and camera overview of the actual configured Developer layout.

PM inspected `docs/screenshots/expanded-developer-map.png` and `.tools/r13-developer-home.png`: the new venue campus is distinct, connected to the original hotel and leaves extensive clear expansion land. The initial frame fits the facilities above the bottom controls. Root and PM accepted the final regenerated images after restoring the CPU-only OCEAN plaque text, removing texture streaks outside the preserved old crop, and shifting only the new climbing wall two cells west to `(-22,0)` with rotation 1. The original palm remains intact, the wall is clear of its canopy, and its gate/path still connects correctly. Showcase **85/85**, expanded world **50/50** and integrated smoke pass after that coordinate adjustment. Final imagery remains generated, not a desktop capture.

World specialist additionally reports camera **34**, legacy queued-layout migration **12**, building renderer **112**, R9 visual **130**, R11 proportions **375** and R10 facility visual **1,026** passes. Import exits 0; `.tools/r13-world-import.log` contains the familiar editor-startup safe-save diagnostic followed by successful imports, distinct from clean gameplay checks. Original sprite sheets and unrelated art/props outputs remain byte-identical.

## Final Windows delivery

Root's final routed controller suite passes **59/59** in `.tools/r13-developer-scene-final.log`. The final expanded-world suite passes **48/48** in `.tools/r13-expanded-world-final.log`; the earlier **50/50** includes two additional generated-preview output checks. This is the same core coverage, not removed assertions.

Export exits 0 (`.tools/r13-export.log`). The standalone executable exits 0 with a clean `.tools/r13-standalone.log`, exercising all fourteen real Developer activity visits alongside the unchanged Regular **12 stays, 95.42 rating, $1,120** and prior feature smoke checks. PM read this log and independently verified the canonical executable hash.

Canonical `build/windows/AllInclusive.exe` is **111,543,400 bytes**, SHA-256 `69EEB717DFABD969FDE545D4902A7640F5A09976538302DE79E19F8CF63CC5F9`. `build/AllInclusive-Windows.zip` is **41,454,331 bytes**, SHA-256 `6C6F78E70EF9FA8A3475B0CACCCE77CFA46699A2DDBC7D43A75B7C417B7E3F82`.

Root verified exactly four flat entries (`AllInclusive.exe`, `START_HERE.txt`, `CREDITS.txt`, `THIRD_PARTY_NOTICES.txt`) and streamed the archive's executable to confirm the identical accepted hash. `build/SHA256SUMS.txt` is updated. R12 is backed up at `.tools/releases/AllInclusive-r12-facing-Windows.zip`. README and launch notes identify Revision 13.

## Verification limits

Use headless runtime checks and generated file inspection only. Native rendering/playtesting remains deferred under the user's no-desktop restriction. No computer use, screen capture, visible windows, native tester, Git push or release. All prior uncommitted R9–R12 work is preserved.
