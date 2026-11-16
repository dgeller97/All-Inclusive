extends SceneTree

const Layout := preload("res://scripts/layout_model.gd")
const Sim := preload("res://scripts/simulation.gd")
const BuildingTest := preload("res://tests/building_renderer_test.gd")
const TERRAIN := preload("res://assets/art/resort.png")
const WORLD := Rect2i(Layout.WORLD_BOUNDS)
const CROPS := ["collecting", "wait_table", "to_table", "eating", "to_pool", "exterior"]
const TITLES := ["1. Collect food", "2. Wait with plates", "3. Carry plates", "4. Sit and eat", "5. Leave the table", "Exterior concealment"]

var checks := 0
var failures := 0
var map: ActorProbe


class ActorProbe extends "res://scripts/resort_map.gd":
	var picture: Image
	var atlas: Image
	var pixels: Array[Dictionary] = []
	var sprite_regions: Array[Rect2] = []

	func _actor_block(at: Rect2, color: Color) -> void:
		pixels.append({"rect": at, "color": color})
		if picture:
			var position := Vector2i(at.position) - Vector2i(WORLD_BOUNDS.position)
			var size := Vector2i(at.size)
			if color.a == 1.0:
				picture.fill_rect(Rect2i(position, size), color)
			else:
				var patch := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
				patch.fill(color)
				picture.blend_rect(patch, Rect2i(Vector2i.ZERO, size), position)

	func _actor_texture(texture: Texture2D, at: Vector2) -> void:
		if picture:
			var pixels_image := texture.get_image()
			pixels_image.convert(Image.FORMAT_RGBA8)
			picture.blend_rect(pixels_image, Rect2i(Vector2i.ZERO, pixels_image.get_size()), Vector2i(at) - WORLD.position)

	func _actor_flag(_prop: Dictionary) -> void:
		# The meal probe records texture and actor commands, outside the engine draw callback.
		pass

	func _actor_region(destination: Rect2, source: Rect2) -> void:
		sprite_regions.append(destination)
		if picture:
			var frame := atlas.get_region(Rect2i(source))
			frame.convert(Image.FORMAT_RGBA8)
			var draw_size := Vector2i(destination.size.abs())
			if frame.get_size() != draw_size:
				frame.resize(draw_size.x, draw_size.y, Image.INTERPOLATE_NEAREST)
			var point := Vector2i(destination.position) - Vector2i(WORLD_BOUNDS.position)
			if destination.size.x < 0:
				frame.flip_x()
			picture.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), point)

	func clear_marks() -> void:
		pixels.clear()
		sprite_regions.clear()

	func has_color(color: Color) -> bool:
		return pixels.any(func(block: Dictionary) -> bool: return block.color == color)

	func _draw_actors() -> void:
		clear_marks()
		super()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	map = ActorProbe.new()
	root.add_child(map)
	map.atlas = map.people.get_image()
	var sim := Sim.new()
	var preview := "--preview" in OS.get_cmdline_user_args()
	var samples := _meal_samples(sim)
	_check(samples.size() == CROPS.size() - 1, "Starter day reaches every meal stage")
	if samples.size() == CROPS.size() - 1:
		_test_meal(sim, samples)
		if preview:
			_write_preview(sim, samples)
	_test_moved_table()
	map.queue_free()
	await process_frame
	print("Dining visual probe: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _meal_samples(sim: Sim) -> Dictionary:
	var result := {}
	for second in range(1, 150):
		sim.tick()
		for family in sim.families:
			var key: String = family.phase
			if key == "service" and family.station == 1:
				key = "collecting"
			if key in CROPS and not result.has(key):
				result[key] = {"snapshot": sim.snapshot(), "id": family.id}
		if result.size() == CROPS.size() - 1:
			break
	return result


func _show(sim: Sim, sample: Dictionary, age: float, exterior: bool = false) -> Dictionary:
	_check(sim.restore(sample.snapshot), "Restore real meal frame")
	var family := sim.families[sample.id]
	map.present(sim, float(family.since) + age, null, true, exterior)
	map._draw_actors()
	return family


func _test_meal(sim: Sim, samples: Dictionary) -> void:
	var family := _show(sim, samples.collecting, 3.0)
	var collecting := map._pose(family)
	_check(collecting.meal == "collecting" and collecting.point == sim.layout.station_point(1)
		and collecting.point != collecting.child, "Adult and child collect at actual counter access cells")
	_check(map.has_color(map.PLATE_RIM) and not map.has_color(map.CHAIR_WOOD), "Collection places plates in guests' hands")

	family = _show(sim, samples.wait_table, 1.0)
	var waiting := map._pose(family)
	_check(waiting.meal == "carrying" and waiting.frame == 0 and waiting.child != waiting.point
		and map.has_color(map.FOOD), "Table wait holds filled plates at separate stops")
	_check(not sim.layout.route(sim.layout.station_point(1), waiting.point).is_empty()
		and not sim.layout.route(sim.layout.station_point(1), waiting.child).is_empty(), "Both waiting positions have routes")
	var combined_status := map._buffet_status(2)
	var table_waiting := sim.count_at(1, "wait_table")
	_check(combined_status == "Food 2 · Tables %d" % table_waiting and "waiting for tables" in map._buffet_status(0),
		"Counter and table waits have separate map feedback")
	var status_width := ceilf(map.label_font.get_string_size(combined_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x) + 6.0
	var min_buffet_width: int = Layout.BUILDING_CATALOG.buffet.min_size[0] * Layout.GRID
	_check(status_width <= min_buffet_width, "Combined wait badge including padding fits the minimum buffet width")

	family = _show(sim, samples.to_table, 2.0)
	var walking := map._pose(family)
	var table: Dictionary = map.dining_tables[family.table_id]
	_check(walking.meal == "carrying" and walking.point != table.seat and map.has_color(map.PLATE_RIM), "Travel shows carried plates before reaching the table")
	map.present(sim, float(family.since + Sim.TABLE_WALK_DURATION))
	var seated_at := map._pose(family)
	_check(seated_at.point == table.seat and seated_at.child == table.child, "Both table routes meet the reserved seat markers")

	family = _show(sim, samples.eating, 0.3)
	var eating := map._pose(family)
	var asset := sim.layout.asset_at(table.table_center)
	var bounds := sim.layout.asset_rect(asset)
	_check(eating.point == table.seat and eating.child == table.child and eating.meal == "seated", "Eating sits at the reserved table")
	_check(map.has_color(map.CHAIR_WOOD) and map.has_color(map.FOOD)
		and bounds.has_point(eating.adult_plate) and bounds.has_point(eating.child_plate)
		and eating.adult_plate != eating.child_plate, "Scene draws seats and two filled plates on the tabletop")
	_check(map.sprite_regions.any(func(rect: Rect2) -> bool: return rect.size.abs() == Vector2(11, 16))
		and map.sprite_regions.any(func(rect: Rect2) -> bool: return rect.size.abs() == Vector2(11, 12)),
		"Both seated silhouettes keep native upper-body dimensions")
	var before := map.pixels.duplicate(true)
	map.present(sim, map.time + 0.6)
	map._draw_actors()
	_check(map.pixels != before and map._pose(family).point == eating.point, "Animated bite changes hand pixels while diners remain seated")
	var new_time: float = map.time
	map.present(sim, new_time)
	map._draw_actors()
	var paused := map.pixels.duplicate(true)
	map.present(sim, new_time)
	map._draw_actors()
	_check(map.pixels == paused, "The simulation clock controls eating animation")
	map.present(sim, new_time, null, false, true)
	map._draw_actors()
	_check(not map.has_color(map.CHAIR_WOOD) and not map.has_color(map.PLATE_RIM)
		and not map.actor_visible(eating.point) and map.actor_visible(sim.layout.station_point(2)), "Exterior covers diners and all meal overlays and keeps the pool visible")
	map.present(sim, new_time, sim.layout.duplicate_layout(), true, false, table.building_id)
	map._draw_actors()
	_check(not map.actors.visible and map.pixels.is_empty() and map.renderer.is_interior_hidden(eating.adult_plate), "Ceiling inspection conceals meal overlays")

	family = _show(sim, samples.to_pool, 0.0)
	var departure := map._pose(family)
	_check(departure.point == table.seat and departure.child == table.child and departure.meal.is_empty(), "Departure begins at both seats with empty hands")
	map.present(sim, float(family.until))
	var arrived := map._pose(family)
	_check(arrived.point == sim.layout.station_point(2) and arrived.child == arrived.point, "Both departure routes reach the pool entrance")


func _test_moved_table() -> void:
	var sim := Sim.new()
	var table: Dictionary = sim.layout.dining_tables()[0]
	var old_center: Vector2 = table.table_center
	sim.layout.remove_asset(table.id)
	var added := sim.layout.add_asset("table", table.building_id, Vector2i(10, 4), 1)
	_check(added.ok, "Moved and rotated table fixture is valid")
	if not added.ok:
		return
	var samples := _meal_samples(sim)
	_check(samples.has("eating"), "Moved table has a live family eating")
	if not samples.has("eating"):
		return
	var family := _show(sim, samples.eating, 0.8)
	table = sim.layout.dining_tables()[0]
	var pose := map._pose(family)
	var bounds := sim.layout.asset_rect(sim.layout.asset_at(table.table_center))
	_check(table.table_center != old_center and family.table_id == added.id and pose.point == table.seat
		and pose.child == table.child and bounds.has_point(pose.adult_plate) and bounds.has_point(pose.child_plate), "Eating pose and both plates track moved and rotated furnishings")


func _write_preview(sim: Sim, samples: Dictionary) -> void:
	var renderer := BuildingTest.Probe.new()
	var terrain := TERRAIN.get_image()
	terrain.convert(Image.FORMAT_RGBA8)
	var restaurant := sim.layout.building_at(sim.layout.station_point(1))
	var crop := Rect2i(sim.layout.building_rect(restaurant)).grow(7)
	crop.position.y -= 3
	crop.size.y += 3
	var panel_size := crop.size + Vector2i(6, 20)
	var sheet := Image.create(panel_size.x * 2, panel_size.y * 3 + 16, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#392b38"))
	var ages := [3.3, 1.0, 2.25, 0.74, 0.32, 0.74]
	for index in CROPS.size():
		var key: String = CROPS[index]
		var exterior := key == "exterior"
		_show(sim, samples.eating if exterior else samples[key], ages[index], exterior)
		renderer.present(sim.layout.buildings, sim.layout.render_assets(), map.time)
		renderer.set_view(exterior)
		renderer.picture = terrain.duplicate()
		renderer._draw()
		map.picture = renderer.picture
		map._draw_actors()
		var offset := Vector2i((index % 2) * panel_size.x, floori(index / 2.0) * panel_size.y + 16)
		sheet.blit_rect(map.picture, Rect2i(crop.position - WORLD.position, crop.size), offset + Vector2i(3, 14))
		renderer.picture = sheet
		renderer._draw_plaque_text(ThemeDB.fallback_font, Vector2(WORLD.position + offset + Vector2i(5, 11)), TITLES[index])
	map.picture = null
	renderer._draw_plaque_text(ThemeDB.fallback_font, Vector2(WORLD.position + Vector2i(5, 11)), "Restaurant meal  /  CPU preview")
	renderer.free()
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tools"))
	_check(sheet.save_png("res://.tools/r6-dining-preview.png") == OK, "CPU dining visual saved")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(message)
