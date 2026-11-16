# Revision 16 validation

Status: **Revision 16 accepted and delivered locally**. Source, headless regressions, standalone Windows smoke and final archive verification are complete.

## Cause and previously missing coverage

R15 introduced an elevated world plaque `Node2D` at local `z_index = 2`. The welcome/HUD remained at local z 0 on the same default canvas, so world plaques could draw over the welcome despite later UI sibling order. The user's screenshot correctly exposed a regression in our change. Earlier depth tests checked world ordering and UI tests checked geometry separately; they did not test the shared world/interface rendering boundary. Their passing results were insufficient for this case.

Root separates the HUD, design controls, modal overlay and lazy Animation Viewer into a single fixed `CanvasLayer` at layer 1. The world and its design preview remain on the default canvas, preserving R15's physical object/guest depth. PM independently reviewed the source and the [official CanvasLayer ordering contract](https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html): canvas-layer order takes precedence over child drawing indices. This addresses the cause rather than hiding plaques or merely raising an individual modal's z index.

Root also increases the welcome card/explanation space and moves buttons down. PM reviewed the resulting control hierarchy and geometry. No model/save/economy change or specialist implementation was needed.

## Regression evidence

`tests/world_ui_layer_test.gd` passes **68/68**. It recreates welcome over the live labelled resort with plaque local z above modal local z, then checks actual different canvas RIDs and a positive identity/non-following interface layer. It covers HUD, design controls, modal shade, every HUD popup, viewer sibling ordering and the viewer's isolated map subviewports. At 1280×720, 1600×900 and 1920×1080, it checks viewport containment, shade coverage, the explanation's actual font minimum height and nonintersection with every welcome button.

Existing viewer modal/input checks pass **42/42**; UI geometry passes **2,075/2,075**. Those geometry/assertion counts are not distinct gameplay scenarios. PM read the new regression and current source; no remaining structural issue was found.

These are headless canvas/geometry/input checks, not native framebuffer inspection. No desktop use, capture, visible game/editor launch, process termination or Git publication. Running older builds remain untouched; R16 is packaged in its own directory.

## Final Windows delivery

Current executable: `build/windows-r16/AllInclusive.exe`, **111,599,744 bytes**, SHA-256 `C26F8C7CA9BA5D73715736B9FC0C46731CFB28A3156EB6CBD0C65D9108A4D4AD`. Current `build/AllInclusive-Windows.zip`: **41,510,628 bytes**, SHA-256 `A1821CBE30E87E8D3E8363F45A0469DB29564D8C81EC6906F6581317007E13C7`.

Root verified exactly four flat entries (`AllInclusive.exe`, `START_HERE.txt`, `CREDITS.txt`, `THIRD_PARTY_NOTICES.txt`) and streamed the embedded executable to confirm the accepted R16 hash. `build/SHA256SUMS.txt` is updated. Prior R15 ZIP: `.tools/releases/AllInclusive-r15-depth-Windows.zip`. README and new versioned launch notes identify R16; older notes/executables and running processes remain untouched.

Source and standalone smoke both exit 0 with **12 stays, 95.42 rating, $1,120**, all fourteen Developer activities and twenty viewer clips. PM read the clean `.tools/r16-standalone.log`. Export completes successfully (`.tools/r16-export.log`), with the familiar environment editor-startup safe-save warning but no script/runtime errors. Root's 68/42/2,075 regression results were reported from completed runs; the persisted export/standalone logs are listed separately.
