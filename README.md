# All Inclusive

A compact resort-management game. Welcome families, set package prices, balance staff, and design the resort with buildings and furnishings.

![Expanded resort terrain artwork](assets/art/resort.png)

## Play on Windows

[Download the latest Windows build](https://github.com/dgeller97/All-Inclusive/releases/latest/download/AllInclusive-Windows.zip), extract the ZIP, and double-click `AllInclusive.exe`. No Godot installation is required. [Release notes and checksums](https://github.com/dgeller97/All-Inclusive/releases/latest) are available on GitHub. Use the Windows ZIP asset, not GitHub's automatically generated source-code archives.

Extract `build/AllInclusive-Windows.zip` and open `AllInclusive.exe`. From the project folder, you can also open `build/windows/AllInclusive.exe` directly. The game runs on 64-bit Windows and includes its assets.

Open the resort to begin a three-day run. At 1×, the resort clock runs for 12 minutes before the Day 3 recap. Reach eight completed stays, earn a 75 average rating, and install the pool terrace. The recap lets you keep managing on Day 4 or start a fresh run.

- Use **Booking** to set the day’s package before 00:20. Later selections apply to the following day.
- Use **Staff** to assign the floating worker to reception, the buffet, or the pool.
- Use **Build** to draw bedrooms, reception, a buffet, and a pool. Place beds, desks, counters, dining tables, loungers, umbrellas, plants, and benches. Two accessible loungers and an umbrella give the pool its terrace bonus.
- Use **Reviews** and **Goals** to track guest ratings and Day 3 targets. Click another dock icon to switch panels. Close a panel with its X, by clicking outside it, or by pressing Esc.
- Space and the on-screen Pause button pause or resume. Keys 1, 2, and 3 resume at 1×, 2×, and 4×.
- Open **Settings** from the dock or with Esc when all panels are closed. Settings pauses the clock and contains Save, Load, sound, and Quit. Loading restores the saved run paused.
- Hold the left or middle mouse button and drag to explore. Scroll to zoom toward the cursor, use the on-screen zoom buttons, or press Home to return to the opening view.
- The beach flag shows **Calm** (green), **Caution** (yellow), or **Closed** (red) as the surf changes with the resort clock.

Windows stores the save and audio preference under `%APPDATA%\Godot\app_userdata\All Inclusive`.

## Design your resort

Start a **Regular resort** to pay construction costs, or choose **Developer · Free build** to experiment without spending money. The mode is saved with the run. A regular pool improvement costs $100 in furnishings (two $30 loungers and a $40 umbrella); starter hotel assets have no demolition refund. Newly purchased assets refund half their paid cost when removed.

Build mode pauses the clock and edits a draft. Choose a building and drag a rectangle on the land; choose a furnishing and click inside its matching building. Press R to rotate furnishings. Use Select to inspect objects and Bulldoze to remove them. Bulldoze prioritizes furniture; click empty floor to remove a whole building and its contents. Moving an existing object currently requires bulldozing and rebuilding it. Middle-button drag and the mouse wheel still pan and zoom. Right click or Esc cancels the current tool.

Rooms need accessible beds, reception needs a desk, and the buffet needs a counter and dining table. Keep doorways open and buildings clear of the ocean. Apply an operational layout immediately when no families are staying, or queue it for tomorrow while guests finish their holiday. Save draft preserves unfinished work. Discard returns to the hotel and drops edits made since the last draft save; a saved draft remains available from Build. Queued construction reserves its cost, and canceling the queued plan returns the reserved amount.

## Run from source

This repository includes the game source, original assets and their generators, tests, and design records. Local Godot binaries, import caches, exported builds, and development save files are excluded from Git. On a fresh clone, install Godot 4.7.2 and open `project.godot`; the editor imports the included assets automatically. The `.tools/` commands below refer to the original development workspace's locally installed runtime.

To export from a fresh clone, install the matching Godot export templates and clear the two custom template overrides in the Windows Desktop export preset (or provision the local template files at the paths shown there).

Open `project.godot` in Godot 4.7.2 and run the project, or use the bundled development runtime from the project folder.

```powershell
$godot = ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
& $godot --headless --path . --script res://tests/simulation_test.gd
& $godot --headless --path . --script res://tests/camera_test.gd
& $godot --headless --path . --script res://tests/ui_layout_test.gd
& $godot --headless --path . --script res://tests/layout_model_test.gd
& $godot --headless --path . --script res://tests/construction_transactions_test.gd
& $godot --headless --path . -- --smoke-test
& ".\.tools\godot\Godot_v4.7.2-stable_win64.exe" --path .
```

With the custom Windows templates in `.tools/godot/templates/`, export the game with the **Windows Desktop** preset.

```powershell
& $godot --headless --path . --export-release "Windows Desktop" build/windows/AllInclusive.exe
```

The design and production notes are in `docs/`.

## Resort scope

The starter resort has four bedrooms and three service areas. You can build up to eight bedrooms and one reception, buffet, and pool. Bookings remain capped at four families per day (three on Premium), limited by the number of usable bedrooms. Families follow a repeating daily schedule and swim in the resort pool. Pricing and staffing affect revenue and reviews. Plants and benches are decorative; multiple floors, multiple copies of service buildings, and a larger progression system are deferred.

See `docs/revision-3.md` for the construction design and scope. Current validation uses headless checks; interactive desktop playtesting is paused at the user's request. The native Windows playthrough in `docs/native-playtest.md` covers the original first playable release only.
