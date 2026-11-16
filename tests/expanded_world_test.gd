extends SceneTree
## World footprint regression and CPU-only preview of the real Developer plan.

const Layout := preload("res://scripts/layout_model.gd")
const Landscape := preload("res://scripts/landscape_model.gd")
const Sim := preload("res://scripts/simulation.gd")
const Ocean := preload("res://scripts/ocean.gd")
const Camera := preload("res://scripts/resort_camera.gd")
const TerrainArt := preload("res://scripts/landscape_renderer.gd")
const Amenities := preload("res://scripts/amenity_renderer.gd")
const Buildings := preload("res://scripts/building_renderer.gd")
const BuildingTest := preload("res://tests/building_renderer_test.gd")
const TERRAIN := preload("res://assets/art/resort.png")
const WORLD := Rect2i(Landscape.WORLD_BOUNDS)
const OLD_WORLD := Rect2i(-160, -120, 960, 600)
const OLD_CELLS := Rect2i(-20, -15, 120, 75)
# Recorded from the unchanged R12 outputs before expanding the generator.
const OLD_TERRAIN_DIGEST := "6c5d414b076d4f64b1ace5122a089bbd1302d37149519badade55de8018d627c"
const OLD_DEFAULTS_DIGEST := "d379c2285e2e9576e92d63d2873b04d6bc692e685fd4d1c8ceae53029412d285"
const OLD_SHORE_DIGEST := "bfbaec0acf7d4c8d7ef5a7a5966aebd318b84f474c6c370b6c3d0d29dbd266a1"
const OLD_PROPS_DIGEST := "b81f6b7220c8d38214d7b92d3a054a7076ddf926637cd21fb4e95c9a9e41351c"

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var layout := Layout.new()
	_check(WORLD == Rect2i(-480, -240, 1280, 960) and Layout.WORLD_BOUNDS == Landscape.WORLD_BOUNDS, "Own one common expanded world")
	_check(Landscape.REGION.position * Layout.GRID == WORLD.position and Landscape.REGION.size * Layout.GRID == WORLD.size, "Grid and world origins agree")
	_check(TERRAIN.get_size() == Vector2(WORLD.size) and Landscape.DEFAULT_MAP.get_size() == Vector2(Landscape.REGION.size), "Base textures fill the precise world and cell rectangles")
	_check_legacy_art(layout)
	_check_real_edges(layout)
	_check_expansion_build()
	var sim := Sim.new()
	_check(sim.configure_new_run("developer"), "Build the actual fresh Developer layout")
	if sim.mode == "developer":
		_check_overview(sim)
	print("Expanded world: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _check_legacy_art(layout: Layout) -> void:
	var image := TERRAIN.get_image().get_region(Rect2i(OLD_WORLD.position - WORLD.position, OLD_WORLD.size))
	image.convert(Image.FORMAT_RGBA8)
	_check(_digest(image.get_data()) == OLD_TERRAIN_DIGEST, "Every old terrain pixel stays byte-identical")
	var defaults := Landscape.DEFAULT_MAP.get_image().get_region(Rect2i(OLD_CELLS.position - Landscape.REGION.position, OLD_CELLS.size))
	defaults.convert(Image.FORMAT_RGBA8)
	_check(_digest(defaults.get_data()) == OLD_DEFAULTS_DIGEST, "All old terrain IDs and path cells stay byte-identical")
	var profile := Landscape.coastline()
	var shore_bytes := PackedByteArray()
	for y in range(OLD_WORLD.position.y, OLD_WORLD.end.y):
		var x := profile[y - WORLD.position.y]
		shore_bytes.append(x & 255)
		shore_bytes.append(x >> 8)
	_check(profile.size() == WORLD.size.y and _digest(shore_bytes) == OLD_SHORE_DIGEST, "All 600 original rows retain their exact first wet world pixel")
	_check(FileAccess.get_sha256(Landscape.DEFAULT_PROPS_PATH) == OLD_PROPS_DIGEST and layout.landscape.props.size() == 71,
		"Legacy scenery definitions, order and starter amenities stay intact")
	var version_one := layout.snapshot()
	version_one.version = 1
	version_one.erase("landscape")
	var imported := Layout.new(false)
	_check(imported.restore(version_one) and imported.room_points().size() == 4 and imported.landscape.props.size() == 67,
		"Legacy layout still restores the original hotel and scenery without extra west props")


func _check_real_edges(layout: Layout) -> void:
	var shore := Landscape.coastline()
	var water := Ocean.new()
	root.add_child(water)
	water.set_landscape(layout.landscape)
	_check(water._shore == shore and water._disturbed_rows.size() == WORLD.size.y, "Ocean waves and saved coast share the same expanded rows")
	for y in [WORLD.position.y, -121, -120, 479, 480, WORLD.end.y - 1]:
		var coast_x := shore[y - WORLD.position.y]
		_check(not layout.landscape.is_water_pixel(Vector2(coast_x - 1, y)) and layout.landscape.is_water_pixel(Vector2(coast_x, y)),
			"Exact coast separates dry and wet at world y %d" % y)
		var offshore := water.offshore(Vector2(coast_x - 10, y))
		_check(layout.landscape.is_water_pixel(offshore) and WORLD.has_point(Vector2i(offshore)),
			"Swim pose clips against the real coast at world y %d" % y)
	var outer_counts := [0, 0]
	for point in water.sargassum_pixels(90):
		if point.y < OLD_WORLD.position.y:
			outer_counts[0] += 1
		if point.y >= OLD_WORLD.end.y:
			outer_counts[1] += 1
	_check(outer_counts[0] > 0 and outer_counts[1] > 0, "Seasonal seaweed reaches both new coast stretches")
	for y in [-220, 620]:
		var coast_x := shore[y - WORLD.position.y]
		var wet := Vector2i(floori(float(coast_x) / Layout.GRID) + 2, floori(float(y) / Layout.GRID))
		var snapshot := layout.landscape.snapshot()
		snapshot.terrain = [[wet.x, wet.y, "sand"]]
		_check(not layout.landscape.cell_is_dry(wet) and not layout.paint_landscape_stroke("terrain", "sand", [wet]).ok
			and Landscape.has_protected_water_edits(snapshot), "The extended ocean cannot be reclaimed or saved as dry land")
	water.free()


func _check_expansion_build() -> void:
	var layout := Layout.new()
	var paint := Vector2i(-59, -29)
	var prop_site := Vector2i(-57, -27)
	var dry_destination := Vector2(WORLD.position.x + Layout.GRID * 0.5, WORLD.end.y - Layout.GRID * 0.5)
	_check(layout.landscape.cell_is_dry(paint) and layout.landscape.path_at(paint).is_empty(), "Fresh northwest terrain is dry and open")
	var destination := layout.route(Layout.ENTRY, dry_destination)
	_check(not destination.is_empty() and destination[-1] == dry_destination, "Guests can reach the new southwest boundary")
	_check(not layout.route(Layout.ENTRY, layout.landscape.cell_rect(paint).get_center()).is_empty(),
		"Guests can also reach the northwest corner")
	var terrain := "grass" if layout.landscape.terrain_at(paint) != "grass" else "sand"
	_check(layout.paint_landscape_stroke("terrain", terrain, [paint]).ok and layout.paint_landscape_stroke("path", "stone", [paint]).ok,
		"Terrain and paths work on new dry cells")
	var bench := layout.add_prop("bench", prop_site, 1)
	var house := layout.add_building("bedroom", Rect2(-464, 608, 64, 64))
	_check(bench.ok and house.ok and layout.add_asset("bed", house.id, Vector2i(1, 1)).ok,
		"New land supports rotated scenery and furnished rooms")
	_check(layout.room_points().size() == 5 and layout.readiness().ok, "A far southwest room is actually reachable")
	var restored := Layout.new()
	_check(restored.restore(bytes_to_var(var_to_bytes(layout.snapshot()))), "Landscape snapshot round-trips extended coordinates")
	_check(restored.landscape.terrain_at(paint) == terrain and restored.landscape.path_at(paint) == "stone"
		and restored.landscape.prop_by_id(bench.id).rotation == 1 and restored.room_points().size() == 5,
		"Extended terrain, paths, prop identity/rotation and room routes survive")
	var bad := layout.snapshot()
	bad.landscape.terrain.append([Landscape.REGION.position.x - 1, paint.y, "sand"])
	_check(not restored.restore(bad) and restored.landscape.path_at(paint) == "stone", "Reject invalid world extensions transactionally")


func _check_overview(sim: Sim) -> void:
	var camera := Camera.new()
	camera.size = Vector2(1280, 720)
	camera.configure(Layout.WORLD_BOUNDS, Vector2(160, 120), 1.0)
	var visible := Rect2(camera.screen_to_world(Vector2.ZERO), camera.size / camera.zoom_level)
	for venue: Dictionary in sim.layout.amenities():
		_check(visible.encloses(sim.layout.prop_visual_rect(sim.layout.landscape.prop_by_id(venue.id))),
			"Developer Home fits the entire %s artwork" % venue.kind)
	camera.free()
	if "--preview" not in OS.get_cmdline_user_args():
		return
	var canvas := _draw_developer_layout(sim)
	_check(canvas.save_png("res://docs/screenshots/expanded-developer-map.png") == OK, "Save full-world CPU overview")
	var home := canvas.get_region(Rect2i(Vector2i(visible.position) - WORLD.position, Vector2i(visible.size)))
	_check(home.save_png("res://.tools/r13-developer-home.png") == OK, "Save actual Developer Home crop")


func _draw_developer_layout(sim: Sim) -> Image:
	var layout := sim.layout
	var canvas: Image = TERRAIN.get_image().duplicate()
	canvas.convert(Image.FORMAT_RGBA8)
	var material := TerrainArt.MATERIALS.get_image()
	material.convert(Image.FORMAT_RGBA8)
	for cy in range(Landscape.REGION.position.y, Landscape.REGION.end.y):
		for cx in range(Landscape.REGION.position.x, Landscape.REGION.end.x):
			var cell := Vector2i(cx, cy)
			var path := layout.landscape.path_at(cell)
			var at := cell * Layout.GRID - WORLD.position
			if layout.landscape.terrain_overrides.has(cell):
				_surface(canvas, material, cell, at, layout.landscape.terrain_overrides[cell])
			if not path.is_empty():
				_surface(canvas, material, cell, at, path)
				_path_edges(canvas, layout.landscape, cell, at, path)
	var scenery := TerrainArt.PROPS.get_image()
	scenery.convert(Image.FORMAT_RGBA8)
	var furniture := Buildings.FURNITURE.get_image()
	furniture.convert(Image.FORMAT_RGBA8)
	var props: Array = layout.landscape.props.duplicate()
	props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _depth(layout, a) < _depth(layout, b))
	for prop: Dictionary in props:
		var kind: String = prop.kind
		var turn: int = prop.rotation
		var footprint := layout.prop_rect(prop)
		if Amenities.handles(kind):
			var frame := Amenities.frame(kind, turn)
			_blend(canvas, frame, Vector2i(footprint.position + Amenities.art_offset(kind)))
		elif kind == "bench":
			var source := Rect2i(Buildings.furniture_source(kind, turn, footprint.size))
			canvas.blend_rect(furniture, source, Vector2i(footprint.position - Buildings.FURNITURE_LIFT) - WORLD.position)
		elif TerrainArt.PROP_BOUNDS.has(kind):
			var bounds: Rect2 = TerrainArt.PROP_BOUNDS[kind]
			var rows := scenery.get_height() / TerrainArt.PROP_SPAN - 2
			var row := rows if kind == "bush" else rows + 1 if kind == "rock" else int(prop.variant)
			var origin := Vector2(turn, row) * TerrainArt.PROP_SPAN + TerrainArt.PROP_ANCHOR
			canvas.blend_rect(scenery, Rect2i(origin + bounds.position, bounds.size), Vector2i(TerrainArt.prop_anchor(prop) + bounds.position) - WORLD.position)
		elif kind == "beach_flag":
			_flag(canvas, TerrainArt.prop_anchor(prop))
	var paint := BuildingTest.Probe.new()
	var buildings := Buildings.resolve_buildings(layout)
	for building in buildings:
		if building.kind == "pool":
			building.upgraded = sim.terrace
	paint.present(buildings, layout.render_assets())
	paint.picture = canvas
	paint._draw()
	paint.free()
	return canvas


func _depth(layout: Layout, prop: Dictionary) -> float:
	if Amenities.handles(prop.kind) or prop.kind == "bench":
		return layout.prop_rect(prop).end.y
	return TerrainArt.prop_anchor(prop).y


func _surface(canvas: Image, material: Image, cell: Vector2i, at: Vector2i, kind: String) -> void:
	var origin := Vector2i(posmod(cell.x, 4), posmod(cell.y, 4)) * Layout.GRID
	origin.x += TerrainArt.MATERIAL_COLUMNS[kind] * TerrainArt.MATERIAL_SPAN
	canvas.blit_rect(material, Rect2i(origin, Vector2i.ONE * Layout.GRID), at)


func _path_edges(canvas: Image, landscape: Landscape, cell: Vector2i, at: Vector2i, kind: String) -> void:
	var ink: Array = TerrainArt.PATH_EDGES[kind]
	if landscape.path_at(cell + Vector2i.UP).is_empty():
		canvas.fill_rect(Rect2i(at, Vector2i(Layout.GRID, 1)), ink[0])
	if landscape.path_at(cell + Vector2i.LEFT).is_empty():
		canvas.fill_rect(Rect2i(at, Vector2i(1, Layout.GRID)), ink[0])
	if landscape.path_at(cell + Vector2i.DOWN).is_empty():
		canvas.fill_rect(Rect2i(at + Vector2i(0, Layout.GRID - 1), Vector2i(Layout.GRID, 1)), ink[1])
	if landscape.path_at(cell + Vector2i.RIGHT).is_empty():
		canvas.fill_rect(Rect2i(at + Vector2i(Layout.GRID - 1, 0), Vector2i(1, Layout.GRID)), ink[1])


func _flag(canvas: Image, anchor: Vector2) -> void:
	var at := Vector2i(anchor) - WORLD.position
	canvas.fill_rect(Rect2i(at + Vector2i(-1, -43), Vector2i(3, 43)), Color("#966952"))
	var shape := TerrainArt.flag_outline(Vector2(at), 0, 0.0, 0.0)
	for y in range(at.y - 43, at.y - 25):
		for x in range(at.x, at.x + 24):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), shape):
				canvas.set_pixel(x, y, Color("#78c897"))
	var sign := at + Vector2i(-23, -23)
	canvas.fill_rect(Rect2i(sign, Vector2i(49, 21)), Color("#443b40"))
	canvas.fill_rect(Rect2i(sign, Vector2i(49, 1)), Color("#fff0c5"))
	var paint := BuildingTest.Probe.new()
	paint.picture = canvas
	paint._draw_plaque_text(ThemeDB.fallback_font, Vector2(sign + WORLD.position + Vector2i(8, 16)), "OCEAN")
	paint.free()


func _blend(canvas: Image, frame: Image, at: Vector2i) -> void:
	canvas.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), at - WORLD.position)


func _digest(input: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(input)
	return hash.finish().hex_encode()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
