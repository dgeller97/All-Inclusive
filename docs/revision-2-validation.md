# Revision 2 implementation validation

The user requested no further computer use for this session and a break for the tester. All revision 2 checks were performed by the implementation team through headless Godot, file inspection and generated artwork inspection. No native game/editor windows, desktop captures or browser automation were used after that restriction. **Rendered UI appearance and interactive native playtesting of revision 2 remain deferred.** Revision 1 native reports are historical evidence only.

## Implemented scope

- Compact original pixel-icon dock with six contextual panels; one panel at a time, close button, outside press and global Escape handling.
- Enlarged 960×600 world, grounded pool/deck and extra grass, paths and beach.
- Deterministic ocean wave strength and labelled green/yellow/red Calm/Caution/Closed flag. This is environmental information; the game has no ocean swimming mechanic, and pool service is independent.
- Bounded left hold-drag/middle-drag camera, cursor-anchored wheel zoom, plus/minus controls and Home. World labels, actors, terrain and ocean share the camera transform; UI remains fixed.
- Existing simulation and manual saves retained, with optional camera state and default Home view when loading older saves.

## Evidence

| Check | Result |
| --- | --- |
| Expanded artwork | PM and root inspected the generated PNG file. The full pool and terrace have an uninterrupted dry-land buffer. |
| Terrain/coast agreement | Headless validation matched all 600 imported shoreline-profile rows to the terrain's first wet and last dry pixels. Every opaque upgrade pixel is at least 27 world pixels inland. |
| Ocean state | Seven representative condition samples and a rewind passed. Wave energy varies smoothly over a 112-second cycle and uses persisted simulation time across days. |
| UI component | Parsing and isolated headless checks passed for all six panels, replacement, actions, outside-dismissal, UI/world hit testing, upgrade lock and modal focus. |
| Camera component | 34 headless tests passed for cursor anchor, bounds, drag threshold, middle drag, UI/modal guards, release/focus loss, resize, state roundtrip and invalid state rejection. |
| UI geometry | 1,244 geometry assertions passed across initial/completed states and all six panels. This is control-bounds validation, not 1,244 gameplay tests or rendered visual QA. |
| Integrated revision | 73 headless assertions passed using `Viewport.push_input`, including dock/X/outside close, left/middle drag, UI-blocked wheel, cursor anchor, zoom/Home, global Space with focused controls, Escape precedence, saves and weather thresholds. A separate resumed process passed nine further checks. |
| Original-save compatibility | Four checks passed on the authentic revision 1 save fixture: Day 1 00:58, $620, Standard, buffet float, four occupied rooms, default Home camera and resumed simulation. The ocean condition at the restored time is Closed. |
| Source full progression | Headless simulation fixtures and smoke passed 12 stays, exact 95.25 rating, $800, installed terrace and production art/audio loading. |
| Portable Windows executable | An isolated executable-only staging copy passed the headless smoke with exit code 0, exact 12 stays / 95.25 rating / $800, and expanded terrain, ocean and audio loaded. Source and portable runtime logs were clean. |

The final executable SHA-256 is `61942B3CF917B629904C1803F50B74164E23EEEE6FC4CFF1B39560A048A7B9CC`. The staged executable matched the final standard-path copy. The export included the new shoreline texture, ocean, camera and UI components. Godot printed a nonfatal editor-settings safe-save warning during sandboxed export; resource packing completed and the actual runtime tests passed.

Final archive `build/AllInclusive-Windows.zip`: 41,107,901 bytes, SHA-256 `0A1E15CF69B16E9CB8A3188BA3F7A8DFDB78D0392A48CE4225635795A899657F`. Root verified exactly four entries: `AllInclusive.exe` (111,184,856 bytes), `START_HERE.txt`, `CREDITS.txt` and `THIRD_PARTY_NOTICES.txt`. Streaming the executable from inside the archive produced the same accepted executable checksum. The launch note covers the new controls, flags and old-save compatibility. No desktop use occurred after the user's restriction.

## Reproduce headless checks

Use process-local `APPDATA` in a new workspace `.tools/` test directory. Reuse that directory between the initial acceptance command and its `--resume` pass; use a separate directory for the historical-save fixture.

```powershell
$godot = '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tests/simulation_test.gd
& $godot --headless --path . --script res://tests/camera_test.gd
& $godot --headless --path . --script res://tests/ui_layout_test.gd
& $godot --headless --path . --script res://tests/independent_acceptance.gd
& $godot --headless --path . --script res://tests/independent_acceptance.gd -- --resume
& $godot --headless --path . --script res://tests/independent_acceptance.gd -- --v1
& $godot --headless --path . -- --smoke-test
& '.\build\windows\AllInclusive.exe' --headless --quit-after 240 -- --smoke-test
```
