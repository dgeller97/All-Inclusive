# Asset integration contract

## Revision 7 outdoor amenities

`scripts/amenity_renderer.gd` generates original pixel frames for the beach lounge, volleyball court, beach bar and stage. Ground furniture/markings rotate with placement while posts, canopies, nets and lighting retain their upright presentation. Landscape drawing and editor ghosts share those frames. The map derives activity poses, volleyball motion, cups, stage performer/lights and audience slots from actual saved property reservations. See `beach-visuals.md` and `revision-7.md`. `docs/screenshots/beach-leisure-preview.png` is the accepted CPU-generated actual-phase contact sheet, explicitly not a native capture.

## Revision 6 restaurant interaction

`resort_map.gd` derives food collection, plate carrying, table approach, seated eating and departure from actual simulation phases and `Layout.dining_tables()` records. Seated sprites use compact cropped silhouettes, chair/knee details and animated hands; plates remain visible above the seated bodies. Meal details use the same exterior/ceiling concealment as guests. No furniture is baked into a background or assigned a fake fixed dining location. See `dining-visuals.md` for the reusable headless CPU preview/test and `revision-6.md` for reservations and timing.

## Revision 5 building appearance

The modular building renderer owns physical name plaques, floor/wall finish patterns, complete exterior roofs/facades and explicit selected-building ceiling inspection. `set_view(exterior, ceiling_building_id)` changes presentation only; pool furnishings and activity stay outdoors. Names and three surface finish IDs come from layout metadata rather than duplicated UI constants. See `revision-5.md` and `building-appearance.md` for the current appearance contract; exterior roofing is distinct from the selected indoor ceiling finish.

## Revision 4 current landscape contract

The base `resort.png` contains only natural terrain/coast texture. All original scenery and paths are editable data. `landscape_defaults.png` encodes the 120×75 grid (red: grass/sand/dirt/water IDs; green: none/stone/boardwalk path IDs), and `landscape_props.json` supplies the initial scenery objects. Include the JSON explicitly in exported resources. `landscape_materials.png` and `landscape_props.png` supply live paint/prop art. The landscape model is authoritative for edited land material, path and prop state. Following the user's fixed-coast choice, water IDs/textures describe the baseline ocean only; original shore pixels remain authoritative and no water/coast editing is exposed or accepted. See `revision-4.md` and `landscape-art.md` for the current contract.

## Revision 3 building contract (still used)

`resort.png` is now terrain-only. Buildings and furniture are rendered from `scripts/layout_model.gd` through `scripts/building_renderer.gd`; their locations and sizes are editable. The furniture atlas `assets/art/furniture.png` supplies eight asset rows with four rotations at a 32-pixel cell stride. The fixed `resort_pool_upgrade.png` is retained only as a legacy artifact and must not be drawn by the current game. Use `modular-art.md` for the renderer API and `revision-3.md` for construction behavior. World bounds and the ocean shoreline profile below remain valid.

## Revision 2 scene and art (historical)

- Expanded world texture: `res://assets/art/resort.png`, 960×600 pixels, drawn at world (-160,-120), giving bounds `Rect2(-160,-120,960,600)`.
- Existing facility, guest and path coordinates remain unchanged. The 500×288 pool upgrade overlay is still drawn at world (0,0).
- `res://assets/art/resort_shore.png` encodes the exact first-water X coordinate for each terrain row. `scripts/ocean.gd` uses it to clip all animated surf to the ocean.
- Camera navigation transforms terrain, overlay, guests, world labels and ocean together. The compact icon dock, status and contextual panels stay in screen space.
- See `world-revision.md` and `ui-revision.md` for current integration contracts. The original first-playable layout below is retained as historical reference.

## Revision 1 original scene and art

- Viewport: 1280×720, scalable to window; artwork nearest-neighbor.
- World image: `res://assets/art/resort.png`, 500×288 pixels, displayed at 2× with top-left screen position (16,80).
- Upgrade overlay: `res://assets/art/resort_pool_upgrade.png`, same 500×288 full-canvas size, transparent except pool additions; show after pool upgrade.
- People sheet: `res://assets/art/people.png`, 80×120 pixels; four 20×24 frames per row, rows 0–2 adult guest variants, row 3 staff and row 4 child. Frame foot anchor (10,22).
- Approximate destinations in source-image pixels: entrance (57,270), reception (94,218), buffet (214,213), pool (374,195). Shared boardwalk waypoints y=147 and y=239.
- Final four bedroom destination coordinates: (56,123), (128,123), (200,123), (272,123). Visual designer records these in `visual-direction.md`.
- Inspector right column starts around x=1032. A header and narrow lower objective strip complete the UI.

## Audio

Original audio files under `assets/audio/`: `music_resort.wav` (32-second looping soundtrack), `ui_click.wav`, `guest_checkin.wav`, `resort_upgrade.wav`, `day_close.wav`, `guest_review.wav`. Audio specialist provides gain and loop details in `audio-direction.md`. The game must provide an obvious audio toggle and avoid clipping.

Root also supplied `ambience_surf.wav`, an original 16-second stereo PCM16/44.1kHz surf loop (705600 frames). Loop from frame 0 through 705600 beneath the music at approximately −16 dB player gain; the source is already quiet (measured RMS −26.26 dBFS). Include ambience in the global sound toggle. Regenerate via root-owned `tools/generate_ambience.py`.
