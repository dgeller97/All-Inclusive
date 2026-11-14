# Resort interface revision

The resort fills the viewport behind four small controls. Day, clock, cash, and rating stay at the upper left. Pause and speed sit at the upper right. The lower-left dock holds Booking, Staff, Pool, Reviews, Goals, and Settings. Zoom out, zoom in, and Home sit at the lower right. Temporary event feedback appears in the space between the dock and camera controls.

The dock uses original icons drawn on a 12-pixel grid, visible labels, and descriptive tooltips. The active button has a gold fill. A cream panel opens above the dock and follows the selected button within the viewport margins. The active button, close button, outside click, or Escape closes it. Switching dock buttons replaces the current panel. Booking and staffing update in place so the player can see the results of their decisions.

## Scene integration

Add `scripts/resort_ui.gd` as a full-rect `Control` after the map and before welcome or recap overlays. Call `refresh` with the live `simulation` object and `paused`, `speed`, `muted`, `can_load`, and `notice` fields. Set `notice` to an empty string when an event expires. Call `set_interactive(false)` while a modal owns focus and `set_interactive(true)` when it closes.

| Signal action | Value |
| --- | --- |
| `open_panel`, `close_panel` | `package`, `staff`, `pool`, `reviews`, `goals`, or `settings` |
| `package`, `staff` | Zero-based option index |
| `speed` | `1`, `2`, or `4` |
| `upgrade`, `pause`, `save`, `load`, `mute`, `quit`, `zoom_in`, `zoom_out`, `home` | `null` |

When a panel changes, `open_panel` emits the newly opened ID. The game can pause while Settings is open by setting its settings-pause flag on `open_panel` and clearing it on `close_panel`. The game owns keyboard shortcuts and handles Escape with `has_open_panel()`, `close_panel()`, and `open_panel("settings")`. For pointer navigation, `is_pointer_over_ui` accepts viewport coordinates. A click that dismisses a panel is consumed before it starts a map drag.

## Verification

Godot 4.7.2 parsed the component. A headless instance at 1280 × 720 verified all six panels, one-panel switching, package and staff action values, outside-click dismissal, UI and world hit testing, settings state, the Day 1 upgrade lock, and the modal focus lock. Visual inspection and integrated input remain part of the game preview.
