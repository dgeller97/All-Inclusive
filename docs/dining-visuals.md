# Restaurant meal visuals

The map uses the active simulation and layout. Buffet collection takes place at the counter's reachable edge. The map projects food tray positions from the furnishing's rotation and animates guests picking up plates there. Guests who are waiting for a table step to reachable positions near the counter with their plates. The Restaurant's status chip identifies the buffet line and table wait separately.

The adult and child walk independent routes to the two positions supplied by the reserved table. At the table, the renderer draws two plates on the rotated tabletop, shortens the guest silhouettes to show them seated, and animates each guest bringing food to their mouth. The seats, chairs, and plates are visualized from the current meal state. The existing table furnishing is the only item placed through construction. Departure starts at both seat positions and follows the route to the pool entrance. A departure resumed from an older save without a table reservation still starts at the counter.

The actor layer draws plates and chair detail only when their guest is visible. Building exterior mode covers indoor actors and meal detail, and Build mode hides live guests during ceiling inspection. Actor animation uses the simulation's presentation clock; pausing holds the eating gesture in place.

## Reproduce the visual check

```powershell
$godot = ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --audio-driver Dummy --path . --script res://tests/dining_visual_test.gd -- --preview
```

The probe takes frames from a real simulated day and a restaurant with a moved, rotated table. It verifies counter and seat positions, independent paths, plate and chair drawing, the meal animation clock, and exterior and ceiling visibility. The optional flag saves the labeled CPU-rendered contact sheet at `.tools/r6-dining-preview.png`. Native visual playtesting remains deferred.
