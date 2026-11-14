# First playable test report

**Historical revision 1 evidence.** This report and its executable checksum predate the expanded world and icon interface. The tester is on break at the user's request for revision 2; see `revision-2-validation.md` for the implementation team's headless checks.

Tested November 12, 2026 on Windows using Godot 4.7.2 stable. The Windows candidate was `AllInclusive.exe` (111,131,392 bytes), SHA-256 `4EDFCBD2946E90417B5978DB2E076CA28A889FBEC1249A97601C18DC53DAA7D2`. Native and headless export tests used a separate folder with the executable and notices, with process-local `APPDATA` for each test profile.

## Native Windows export

| Check | Observed result |
| --- | --- |
| Presentation | The 1280 × 720 game area fit in the window. The selected 1×, 2× and 4× labels fit with their checkmarks. The welcome screen named the facilities, all three targets, booking cutoff, float assignment and speed control. The start button had a visible focus outline. The map showed adult and child pairs, swimmers, occupied rooms, queues and per-station staffing. |
| Save, quit and relaunch | With a fresh profile, Load was disabled in the menu. Saved at Day 1 01:09 with $620, Standard, 1×, four occupied rooms, two buffet services and one pool service. The game confirmed the timestamp and quit with exit code 0. The relaunched welcome screen enabled Load. It returned to 01:09 with the same cash, room occupancy, staffing, guest positions and speed, and the clock stayed paused. |
| Upgrade | The 4× replay reached Day 2 with $500, four completed stays and an 85.8 displayed rating. Purchased before 00:49 and before the first swim. The chairs and umbrellas appeared, the pool showed two slots, and the installed button was disabled. Day 2 closed with eight total stays, a 92.9 rating and $440. |
| Recap and sandbox | The resumed Standard run reached Day 3 04:00 and showed all three targets met, 12 stays, a displayed 95.3 rating and $800. Continue opened Day 4 with the same totals and terrace. New Day 4 guests checked in and changed cash while the Day 3 goals remained met. |
| Sound toggle | The label changed from `Sound on` to `Sound off`, and the isolated settings file recorded `muted=true`. |
| Runtime | Both native sessions exited with code 0. Their logs showed OpenGL Compatibility on an RTX 3070 with no warnings or errors. Controls responded throughout the 4× run. |

The coordinator separately observed a complete native source run with Standard on Day 1, Premium on Days 2–3 and a late Day 2 terrace purchase. That run displayed 10 stays, 83.6 rating and $860, met all targets and continued to Day 4. The coordinator also verified live staffing changes and a separate save/load during buffet service.

## Automated evidence

- The independent source harness passed 49 checks in the initial process and seven checks in a second process that reopened the same isolated save. It exercised the game scene's buttons, input routing and clock logic with controlled frame deltas.
- The executable's built-in smoke test independently returned exit code 0 with 12 stays, an unrounded rating of 95.25, $800, the installed terrace and all production art and audio loaded.
- Budget locked four $90 check-ins even after selecting Premium for the next day. Premium locked three $170 check-ins. Budget closed Day 1 with $380 and the first Day 2 check-in funded the upgrade.
- Buffet staffing gave a 34-second peak pool wait. Pool staffing eliminated the pool wait and moved the longest wait to the buffet at 30 seconds. Transfer during parallel service preserved both finish times, then admitted the waiting families in order with the revised capacity. Forty-eight seeded staff-schedule days cleared all rooms and guests before closing. Sampled live states restored exactly.
- Standard Day 1 ratings were 92, 89, 84 and 78. The three penalized reviews cited the pool line. Buying the terrace before Day 2 arrivals yielded eight later scores of 100. The no-upgrade recap marked only the terrace goal missed, and its fresh-run button reset the game. Continuing a successful recap advanced to Day 5 after normal Day 4 payroll and kept the original Day 3 milestone.
- The save checkpoint at Day 1 01:34.5 contained one active pool service, two waiting families, locked Standard and pending Premium. The restored state matched the checkpoint at 2× and opened paused. The 4× continuation matched the uninterrupted simulation and posted four reviews and one payroll. Advancing did not overwrite the explicit save. Truncated files and invalid nested waits displayed an error and preserved the current run.
- Fixed and retested a malformed save found during code review. At Day 1 00:55, changing family 0's saved buffet station to reception previously passed validation even though the family already had a room. On its next service completion the original code would try another room assignment and charge. The regression now rejects the state at restore, and legal reception and buffet states still round-trip.
- Music and surf streams started and used forward loops ending at frames 1,411,200 and 705,600. All five cue resources loaded. The toggle changed the master audio bus. The audio specialist measured PCM, loop boundaries and peak levels. Listening quality and the distinction between audible cues remain unverified.

## Remaining issue and pacing

- **Low severity, Escape with a tooltip.** Hover over the installed terrace button until its tooltip appears, then press Escape. In the export this sometimes left the menu closed and the running clock advanced. Escape worked away from the tooltip. Moving the pointer away or using the on-screen Menu avoids the issue. Space activates a focused button under normal keyboard navigation, so the Pause button is the reliable alternative when another control has focus.
- The configured three days total 720 simulation seconds. The native runs used faster speeds and pauses, so a full 12-minute wall-clock run at 1× was not measured. No formal frame-rate or hardware benchmark was performed.
- With the float kept at the buffet and the terrace bought as soon as affordable, three Budget days gave 12 stays, 96.92 and $440. Standard gave 12 stays, 95.25 and $800. Premium gave 9 stays, 84.11 and $890. Premium trades three stays and about 11 rating points for $90 over Standard, and all three fixed prices can still pass. The quiet stretch after swimming leaves time to prepare tomorrow's price or staffing, and most queue decisions occur earlier in the day. The speed controls materially shorten that stretch.

## Reproduce the independent suite

From the project root in PowerShell, use a unique test profile for each initial run and reuse that profile for its `--resume` pass.

```powershell
$env:APPDATA = Join-Path (Get-Location) ('.tools/tester-appdata-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
$testerGodot = '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $testerGodot --headless --path . --script tests/independent_acceptance.gd
& $testerGodot --headless --path . --script tests/independent_acceptance.gd -- --resume
```
