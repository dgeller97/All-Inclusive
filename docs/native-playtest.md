# Native Windows playtest

**Historical revision 1 evidence.** This report predates the expanded world and icon interface. Revision 2 native playtesting is deferred at the user's request; see `revision-2-validation.md` for that revision's headless checks.

Performed by the root coordinator on 2026-11-12 using the Computer Use skill and `@oai/sky` against the running Godot game window. This is direct UI evidence, separate from the independent tester's automated results in `test-report.md`.

## Environment

- Godot 4.7.2 stable, native Windows, OpenGL compatibility renderer on NVIDIA GeForce RTX 3070.
- Game viewport 1280 × 720. Process-local APPDATA pointed to `.tools/gui-test-appdata` to isolate test saves.
- Source process launched before final audio integration; this run does not establish listening quality or final export behavior.

## Observed results

- Resort scene, four bedroom occupancy labels, top status bar, management panel, bottom goals, pause menu, and final recap fit without visible text clipping.
- Adult and child sprites moved together through rooms, buffet, pool, and checkout. Pool swimmers and walking animations were visible.
- Moving the floating worker from buffet to pool changed displayed capacity and queues. Existing buffet service was allowed to finish when capacity decreased.
- Saved during active buffet service at Day 1 00:58, cash $620, Standard pricing, buffet float, and 1× speed. Changed staffing and speed, advanced to 02:00, and loaded. The UI returned to 00:58, $620, buffet float, 1×, with clock paused and guest positions restored.
- Changed to Premium after Day 1 bookings. The UI clearly stated that it applied to Day 2, with three families and higher expectations; Day 1 remained Standard.
- Clicked 4× to resume/accelerate, and the Pause button to stop the clock. The menu also paused the simulation.
- Bought the pool terrace while paused on Day 2 02:25: cash changed from $1,010 to $590, pool capacity changed from one to two, the pool/deck artwork changed, and the upgrade goal was marked complete.
- Completed the mixed-price run: Standard on Day 1, Premium on Days 2–3; terrace purchased after Day 2 swimming. Final recap showed 10 stays, 83.6 average rating, installed terrace, and $860. All three targets were marked met. Day 3's latest review was 88/100, “Loved the pool terrace.”
- Continued into Day 4. Cash, reviews, upgrade, and original milestone results remained visible.
- Closed the native window; process exited 0 with no runtime error output.

## Caveats and design observations

- The first captured scene was already running, so onboarding was not verified by this source-run session. The independent tester is assigned a fresh exported launch.
- One Escape press was not reflected in the immediate screenshot; keyboard injection/snapshot timing and a tooltip were possible explanations. This was reported for independent reproduction rather than asserted as a confirmed defect.
- Space while a speed button held keyboard focus activated that button instead of pausing. The on-screen Pause button worked. This was reported for control-hint clarification or a global shortcut fix.
- Guests spend a substantial part of the day resting after facilities finish. The status line explains this and 4× speed reduces the wait, but further activities and consequential decisions are sensible next-stage improvements.
- Visual appeal/readability are reviewer judgments. This report is not evidence of human enjoyment, audio listening quality, or testing on other hardware.
