extends SceneTree

const Layout := preload("res://scripts/layout_model.gd")
const Sim := preload("res://scripts/simulation.gd")
const Art := preload("res://scripts/amenity_renderer.gd")
const LandscapeArt := preload("res://scripts/landscape_renderer.gd")
const BuildingTest := preload("res://tests/building_renderer_test.gd")
const Terrain := preload("res://assets/art/resort.png")
const WORLD := Rect2i(Layout.WORLD_BOUNDS)
const KINDS := ["beach_lounge", "volleyball", "beach_bar", "stage"]
const TITLES := ["Beach loungers", "Beach volleyball", "Beach bar", "Evening show"]

var checks := 0
var failures := 0
var map: ActorProbe


class ActorProbe extends "res://scripts/resort_map.gd":
	var picture: Image
	var atlas: Image
	var marks: Array[Dictionary] = []
	var regions: Array[Rect2] = []

	func _actor_block(at: Rect2, color: Color) -> void:
		marks.append({"rect": at, "color": color})
		if picture:
			var bounds := Rect2i(at)
			if bounds.has_area():
				var patch := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
				patch.fill(color)
				picture.blend_rect(patch, Rect2i(Vector2i.ZERO, bounds.size), bounds.position - WORLD.position)

	func _actor_region(destination: Rect2, source: Rect2) -> void:
		regions.append(destination)
		if not picture:
			return
		var frame := atlas.get_region(Rect2i(source))
		frame.convert(Image.FORMAT_RGBA8)
		var draw_size := Vector2i(destination.size.abs())
		if frame.get_size() != draw_size:
			frame.resize(draw_size.x, draw_size.y, Image.INTERPOLATE_NEAREST)
		var point := Vector2i(destination.position) - WORLD.position
		if destination.size.x < 0:
			frame.flip_x()
			point.x -= frame.get_width()
		picture.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), point)

	func has_color(color: Color) -> bool:
		return marks.any(func(block: Dictionary) -> bool: return block.color == color)

	func _draw_actors() -> void:
		marks.clear()
		regions.clear()
		super()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	map = ActorProbe.new()
	root.add_child(map)
	map.atlas = map.people.get_image()
	var sim := Sim.new()
	_test_frames(sim.layout)
	var samples := _samples(sim)
	_check(samples.size() == KINDS.size() * 2, "Normal day visits all four amenities on the route and in use")
	if samples.size() == KINDS.size() * 2:
		_test_live_poses(sim, samples)
		if "--preview" in OS.get_cmdline_user_args():
			_write_preview(sim, samples)
	_test_rotated_venues()
	map.queue_free()
	await process_frame
	print("Beach visual probe: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _test_frames(layout: Layout) -> void:
	for kind: String in KINDS:
		var rotations := {}
		for turn in 4:
			var frame := Art.frame(kind, turn)
			var prop := {"id": -1, "kind": kind, "cell": [41, 1], "offset": [4, 4], "rotation": turn}
			var footprint := layout.prop_rect(prop)
			var visual := layout.prop_visual_rect(prop)
			var bounds := frame.get_used_rect()
			_check(bounds.has_area() and frame == Art.frame(kind, turn),
				"%s rotation %d has cached art" % [kind, turn])
			_check(visual == Rect2(footprint.position + Art.art_offset(kind), Vector2(frame.get_size())),
				"%s rotation %d matches the editor's art envelope" % [kind, turn])
			_check(bounds.size.x >= footprint.size.x * 0.50 and bounds.size.y >= footprint.size.y * 0.50,
				"%s rotation %d occupies a readable part of its footprint" % [kind, turn])
			rotations[frame.get_data().hex_encode()] = true
		_check(rotations.size() == 4, "%s has distinct artwork for every rotation" % kind)


func _samples(sim: Sim) -> Dictionary:
	var result := {}
	for second in range(1, 226):
		sim.tick()
		for family in sim.families:
			if family.phase not in ["to_leisure", "leisure"]:
				continue
			var key: String = family.leisure_kind + "/" + family.phase
			if not result.has(key):
				result[key] = {"snapshot": sim.snapshot(), "id": family.id}
	return result


func _show(sim: Sim, sample: Dictionary, age: float, exterior: bool = false) -> Dictionary:
	if not sim.restore(sample.snapshot):
		_check(false, "Restore actual beach frame")
		return {}
	var family := sim.families[sample.id]
	map.present(sim, float(family.since) + age, null, true, exterior)
	map._draw_actors()
	return family


func _test_live_poses(sim: Sim, samples: Dictionary) -> void:
	for kind: String in KINDS:
		var walking := _show(sim, samples[kind + "/to_leisure"], 0.0)
		if walking.is_empty():
			continue
		var venue := sim.layout.amenity_by_id(walking.amenity_id)
		var start := map._pose(walking)
		var origin := sim.layout.station_point(2)
		if kind == "stage":
			origin = sim.layout.room_points()[walking.room]
		elif walking.leisure_origin_id >= 0:
			var previous := sim.layout.amenity_by_id(walking.leisure_origin_id)
			origin = previous.point
			var departure := map._amenity_pose(previous, walking.leisure_origin_slot)
			_check(start.point == departure.point and start.child == departure.child, "Bar walk starts at the previous reserved activity spot")
		if walking.leisure_origin_id < 0:
			_check(start.point == origin, "%s walk starts at its real dry origin" % kind)
		_check(not sim.layout.route(origin, venue.point).is_empty(), "%s has a walkable access route" % kind)
		map.present(sim, float(walking.until))
		var arrival := map._pose(walking)
		var active := _show(sim, samples[kind + "/leisure"], 1.1, true)
		if active.is_empty():
			continue
		var pose := map._pose(active)
		_check(pose.point == arrival.point and pose.child == arrival.child and pose.point != pose.child,
			"%s walk finishes at both reserved positions" % kind)
		_check(pose.leisure == kind and not pose.swim and venue.rect.has_point(pose.point)
			and venue.rect.has_point(pose.child), "%s activity uses dry spots inside its real footprint" % kind)
		_check(map.actor_visible(pose.point) and map.actor_visible(pose.child), "%s guests stay visible in Exterior" % kind)
		match kind:
			"beach_lounge":
				_check(map.regions.any(func(rect: Rect2) -> bool: return rect.size.y == 10)
					and map.regions.any(func(rect: Rect2) -> bool: return rect.size.y == 7),
					"Loungers use seated adult and child sprites")
			"volleyball":
				_check(map.has_color(map.BEACH_BALL), "Volleyball draws the ball during real play")
			"beach_bar":
				_check(map.has_color(map.DRINK_CUP), "Bar service puts a mocktail cup in guests' hands")
			"stage":
				_check(map.has_color(map.SHOW_LAMP) and map.regions.any(func(rect: Rect2) -> bool:
					return venue.rect.has_point(Vector2(rect.get_center().x, rect.end.y - 2))),
					"Evening show draws stage lighting, a performer and visible audience seats")
		var marks := map.marks.duplicate(true)
		map.present(sim, map.time, null, false, true)
		map._draw_actors()
		_check(map.marks == marks, "%s action freezes when simulation time is still" % kind)
		if kind != "beach_lounge":
			map.present(sim, map.time + 0.43, null, false, true)
			map._draw_actors()
			_check(map.marks != marks and map._pose(active).point == pose.point,
				"%s action animates while the reservation stays anchored" % kind)


func _test_rotated_venues() -> void:
	for kind: String in KINDS:
		var sim := Sim.new()
		var amenity := sim.layout.amenities(kind)[0]
		var original: Vector2 = amenity.rect.position
		var turn := posmod(int(amenity.rotation) + 1, 4)
		var cell := _relocation(sim.layout, amenity, turn)
		var moved := sim.layout.move_prop(amenity.id, cell, turn)
		_check(moved.ok, "%s has a valid moved and rotated fixture" % kind)
		if not moved.ok:
			continue
		amenity = sim.layout.amenity_by_id(amenity.id)
		_check(not amenity.is_empty(), "%s stays reachable after moving and rotating" % kind)
		if amenity.is_empty():
			continue
		var positions := {}
		for slot in amenity.capacity:
			var pose := map._amenity_pose(amenity, slot)
			var rect: Rect2 = amenity.rect
			_check(rect.position != original and rect.has_point(pose.point) and rect.has_point(pose.child),
				"%s rotated slot %d stays on the actual prop" % [kind, slot])
			_check(not positions.has(pose.point) and not positions.has(pose.child) and pose.point != pose.child,
				"%s rotated slot %d is visually distinct" % [kind, slot])
			positions[pose.point] = true
			positions[pose.child] = true
		var samples := _samples(sim)
		_check(samples.has(kind + "/leisure"), "%s is used after moving and rotating" % kind)
		if samples.has(kind + "/leisure"):
			var family := _show(sim, samples[kind + "/leisure"], 1.0, true)
			if not family.is_empty():
				var pose := map._pose(family)
				var expected := map._amenity_pose(amenity, family.leisure_slot)
				_check(pose.point == expected.point and pose.child == expected.child and family.amenity_id == amenity.id,
					"Live reservations follow the moved and rotated %s" % kind)


func _relocation(layout: Layout, amenity: Dictionary, turn: int) -> Vector2i:
	var rect: Rect2 = amenity.rect
	var origin := Vector2i(rect.position / Layout.GRID)
	for distance in range(2, 18):
		for offset in range(-distance, distance + 1):
			for cell: Vector2i in [
				origin + Vector2i(offset, -distance), origin + Vector2i(offset, distance),
				origin + Vector2i(-distance, offset), origin + Vector2i(distance, offset),
			]:
				if layout.validate_prop(amenity.kind, cell, turn, 0, amenity.id).ok:
					return cell
	return Vector2i(1000, 1000)


func _landscape_picture(layout: Layout, crop: Rect2i) -> Image:
	var picture := Terrain.get_image()
	picture.convert(Image.FORMAT_RGBA8)
	var landscape := layout.landscape
	var materials := LandscapeArt.MATERIALS.get_image()
	materials.convert(Image.FORMAT_RGBA8)
	var start := Vector2i(floori(float(crop.position.x) / Layout.GRID), floori(float(crop.position.y) / Layout.GRID))
	var end := Vector2i(ceili(float(crop.end.x) / Layout.GRID), ceili(float(crop.end.y) / Layout.GRID))
	for y in range(start.y, end.y):
		for x in range(start.x, end.x):
			var cell := Vector2i(x, y)
			var kind := landscape.path_at(cell)
			if not kind.is_empty() and landscape.cell_is_dry(cell):
				var source := Vector2i(posmod(x, 4) * Layout.GRID, posmod(y, 4) * Layout.GRID)
				source.x += LandscapeArt.MATERIAL_COLUMNS[kind] * LandscapeArt.MATERIAL_SPAN
				picture.blit_rect(materials, Rect2i(source, Vector2i(Layout.GRID, Layout.GRID)), cell * Layout.GRID - WORLD.position)
	var props := landscape.props.duplicate()
	props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return map.landscape_renderer._prop_depth(a) < map.landscape_renderer._prop_depth(b))
	var scenery := LandscapeArt.PROPS.get_image()
	scenery.convert(Image.FORMAT_RGBA8)
	for prop in props:
		if not crop.intersects(Rect2i(landscape.prop_visual_rect(prop))):
			continue
		var turn: int = prop.rotation
		if Art.handles(prop.kind):
			var frame := Art.frame(prop.kind, turn)
			var dest := Vector2i(landscape.prop_rect(prop).position + Art.art_offset(prop.kind)) - WORLD.position
			picture.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), dest)
		elif LandscapeArt.PROP_BOUNDS.has(prop.kind):
			var bounds: Rect2 = LandscapeArt.PROP_BOUNDS[prop.kind]
			var row: int = prop.variant
			var palm_rows := scenery.get_height() / LandscapeArt.PROP_SPAN - 2
			if prop.kind == "bush":
				row = palm_rows
			elif prop.kind == "rock":
				row = palm_rows + 1
			elif row < 0 or row >= palm_rows:
				row = 0
			var source := Rect2i(Vector2(turn, row) * LandscapeArt.PROP_SPAN + LandscapeArt.PROP_ANCHOR + bounds.position, bounds.size)
			var dest := Vector2i(LandscapeArt.prop_anchor(prop) + bounds.position) - WORLD.position
			picture.blend_rect(scenery, source, dest)
	return picture


func _write_preview(sim: Sim, samples: Dictionary) -> void:
	var cell := Vector2i(117, 101)
	var sheet := Image.create(cell.x * 2, cell.y * 2 + 16, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#392b38"))
	var labels := BuildingTest.Probe.new()
	labels.picture = sheet
	var font := ThemeDB.fallback_font
	labels._draw_plaque_text(font, Vector2(WORLD.position + Vector2i(7, 11)), "Beach leisure / CPU preview")
	for index in KINDS.size():
		var kind: String = KINDS[index]
		var sample: Dictionary = samples[kind + "/leisure"]
		var family := _show(sim, sample, 2.37)
		var venue := sim.layout.amenity_by_id(family.amenity_id)
		var rect := Rect2i(venue.rect)
		var crop := Rect2i(rect.get_center() - Vector2i(55, 44), Vector2i(111, 82))
		map.picture = _landscape_picture(sim.layout, crop)
		map._draw_actors()
		var offset := Vector2i(index % 2 * cell.x, floori(float(index) / 2.0) * cell.y + 16)
		sheet.blit_rect(map.picture, Rect2i(crop.position - WORLD.position, crop.size), offset + Vector2i(3, 14))
		labels._draw_plaque_text(font, Vector2(WORLD.position + offset + Vector2i(7, 11)), TITLES[index])
	map.picture = null
	labels.free()
	sheet.resize(sheet.get_width() * 4, sheet.get_height() * 4, Image.INTERPOLATE_NEAREST)
	_check(sheet.save_png("res://.tools/r7-beach-preview.png") == OK, "CPU beach visual saved")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(message)
