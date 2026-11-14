# Resort design controls

Design mode pauses the clock and opens a top status strip and a bottom palette over the resort. Choose Bedroom, Reception, Buffet, or Pool and left-drag a rectangle on the 8 px world grid. Choose a furniture icon and left-click to place it. Rotate the furniture 90° clockwise with **R** or **Rotate**. **Select** inspects a building or furnishing. **Bulldoze** removes the object you click from the draft. Right-click or press **Esc** to cancel the current tool. Middle-drag to pan and use the wheel to zoom.

The top strip shows whether construction is free or paid, the current tool and orientation, placement or validation feedback, and the selected object. In Regular mode it shows construction cost, refunds, the net amount, and available cash. **Save draft** saves the run with its unfinished design and keeps the editor open. **Discard** returns to management and drops changes made since the last draft save; a previously saved draft remains available when Build is reopened. **Apply now** updates the live resort immediately when safe. **Apply tomorrow** queues the plan when guests are active. The strip shows the scheduled day and any reservation of funds. **Cancel queued plan** releases reserved funds.

## Integration

Add `DesignUI.new()` as a screen-space sibling of `ResortUI` and before modal overlays. The controller owns editing, pausing, shortcuts, placement previews, and persistence. Route the camera and editor's pointer blocking to `DesignUI.is_pointer_over_ui(viewport_point)` while the design UI is active. That method blocks both strips, including blank space within their borders. The controller can supply the Design dock icon by copying `DesignUI.PixelIcon.PATTERNS["design"]` into the existing icon set.

Call `refresh(data)` with the complete display state. Missing keys use the defaults below. `active` controls visibility.

| Fields | Meaning |
| --- | --- |
| `active`, `tool` | Visibility defaults to `false`. Tool is `select` (default), `building`, `asset`, or `bulldoze`. |
| `building`, `asset`, `rotation`, `can_rotate` | The catalog IDs in `DesignUI.BUILDINGS` and `DesignUI.ASSETS`, plus a quarter-turn count. The default choices are `bedroom` and `bed`, with zero rotation. Rotate is available in asset mode by default. |
| `instruction`, `feedback`, `feedback_valid`, `selection` | Optional display copy for the tool, placement or validation, and the selected object. The UI supplies default instructions. Omit `feedback_valid` for neutral feedback. |
| `mode`, `cost`, `refund`, `cash`, `quote_label` | Mode is `developer` (default) or `regular`. Currency values are integers. Set `quote_label` to override the generated Regular-mode quote. |
| `can_apply`, `apply_reason`, `defer_apply`, `apply_day` | Apply defaults to disabled. The controller sets readiness and can supply a reason when disabled. The deferred flag changes the action label to **Apply tomorrow**. An optional day number appears in its tooltip. |
| `has_pending`, `pending_day`, `pending_reserve` | Shows the pending-plan action and status. The pending day and monetary reservation are optional integers. |
| `can_save_draft` | Defaults to `true` and is independent of Apply readiness. |

| `action_requested` action | Value |
| --- | --- |
| `tool` | `select` |
| `building` | `bedroom`, `reception`, `buffet`, or `pool` |
| `asset` | `bed`, `desk`, `counter`, `table`, `lounger`, `umbrella`, `plant`, or `bench` |
| `bulldoze`, `rotate`, `apply`, `discard`, `save_draft`, `cancel_pending` | `null` |

At 1280 × 720, the top strip occupies `(16, 16, 1248, 120)` and the bottom palette occupies `(52, 614, 1176, 90)`. The resort remains directly interactive in the middle. Palette labels remain visible beside buttons' accessible names and tooltips. The interface uses the existing UI's dark plum, cream, and gold colors and its 12-pixel icon grid.
