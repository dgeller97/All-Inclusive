# Beach amenity visuals

The four venues use original pixel art generated in `scripts/amenity_renderer.gd`. The landscape and Design placement preview draw the same cached texture at the prop's cell. Rotation turns the ground footprint and seating plan while keeping umbrellas, posts, thatch, and stage lights upright.

| Amenity | Footprint at rotation 0 | Art above footprint | Adults and children |
| --- | --- | --- | --- |
| Beach lounge | 32 × 24 px | 12 px | Sit by the striped recliners beneath a coral parasol |
| Volleyball | 80 × 56 px | 10 px | Play on opposite sides of a marked court and animated ball |
| Beach bar | 48 × 32 px | 15 px | Lift mocktail cups from the thatched counter and sip |
| Evening stage | 64 × 40 px | 18 px | Clap along to a performer and changing stage lights |

The map uses each reservation's amenity ID and slot to place the family. En route, actors follow the layout navigation path to the venue's dry access tile. Within the venue, their positions follow its rotated footprint. A bar trip starts at the previous activity's reserved spots when the previous activity is available. Outdoor activities continue to draw in Exterior view. The animation uses simulation time.

Run the headless probe from the project root with the bundled Windows Godot console. Use `--preview` to save the CPU contact sheet to `.tools/r7-beach-preview.png`.

```powershell
$env:APPDATA = "$PWD/.tools/r7-visual-profile"
& ./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/beach_visual_test.gd -- --preview
```

The contact sheet composites the terrain, nearby scenery, amenity textures, and live actor drawing calls from four saved starter-day states. The probe checks visual bounds across all four rotations, live activity positions, moved and rotated venues, Exterior visibility, and pause-stable animation.
