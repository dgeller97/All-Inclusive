# Revision 14: in-game animation inspection

The user wants to inspect each animation in each rotation to identify remaining visual problems. Add an in-game Animation viewer accessible from the welcome screen, Settings and F8. This revision supplies inspection tools; it does not silently redesign animations.

## Viewer contract

The viewer is a full-viewport modal `Control` with `viewer_closed`, `show_viewer()` and `close()`. Root instantiates it lazily above the game. While visible, the underlying resort, design draft, camera and saved run remain unchanged. Closing restores the previous context without changing pause, speed, progression or selections.

Show four synchronized, clearly labelled 0°, 90°, 180° and 270° panels for the selected activity. Include all fourteen activity venues plus dining, buffet food collection, main-pool swimming and walking. Ocean swimming and evacuation use an explicitly labelled fixed-coast view instead of invented rotated shorelines. Offer play/pause, time seeking, speed, 1/30-second frame stepping, single/full occupancy and guest variants. Inspect sequence/approach/activity/departure phases where applicable, with a reproducible clip/phase/time readout; controls distinguish selected activity time from the live resort clock. Fit framing and fixed 2×/4× inspection magnification follow actual guests without changing their poses or time; fixed magnification may intentionally crop a broad full-occupancy group, while Fit includes it.

Use the actual production runtime renderers, guest pose functions and CanvasItem texture calls. A synthetic local fixture may provide valid geometry/reservations, but no CPU pixel-blitting approximation or alternate sprite draw semantics is acceptable. R12 demonstrated why a seemingly faithful CPU mirror implementation can conceal a real rendering defect. Keep all four panels on the same sampled time and use real rotated venue/building geometry rather than rotating the finished panel image.

Local fixture creation, playback and disposal must not mutate the active simulation, construction queue, save file or camera. Ensure modal input does not reach world panning, building actions or live-run shortcuts. Native rendered inspection remains the user's task under the existing no-desktop restriction; headless tests must be labelled accordingly.

Public control methods are `select_clip(id)`, `select_phase(id)`, `seek(seconds)`, `step_frame(direction)`, `set_playing(value)`, `set_speed(value)`, `set_full_occupancy(value)`, `set_guest_variant(index)` and `set_view_zoom(value)` (0 for Fit, 2 or 4). Public inspection fields are `clip_id`, `phase_id`, `playhead`, `duration`, `playing`, `speed`, `full_occupancy`, `guest_variant`, `view_zoom`, `panel_maps`, `panel_viewports` and `fixtures`. Fixture construction restores both global building and landscape ID allocators so merely inspecting animations cannot change a live run's next-ID save state.

## Ownership and acceptance

- Sol/xhigh visual specialist `visual_r9`: new viewer and isolated runtime fixture/helper scripts, focused tests. Existing production pose/art changes require a demonstrated viewer-correctness dependency and coordination.
- Sol/xhigh systems specialist `systems_r9`: independent viewer contract tests/review only, no production edits.
- Root: `resort.gd`, `resort_ui.gd`, welcome/Settings/F8 integration, independent lifecycle/modal/preservation tests, README/launch notes and Windows package.
- Astra/high PM: interface, scope, acceptance and durable records.

Require complete selector coverage, synchronized four-way real geometry/pose sampling, working controls, valid capacity/variant fixtures, unchanged live simulation/draft/save through open/play/close, safe repeated lifecycle and clean Windows smoke. Preserve all R9–R13 work. No desktop use, screen capture, visible game/editor windows, native tester resumption, Git push or release.
