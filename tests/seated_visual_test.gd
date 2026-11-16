extends SceneTree

const Sim := preload("res://scripts/simulation.gd")
const Layout := preload("res://scripts/layout_model.gd")
const Building := preload("res://scripts/building_renderer.gd")
const BuildingTest := preload("res://tests/building_renderer_test.gd")
const DiningTest := preload("res://tests/dining_visual_test.gd")
const Amenities := preload("res://scripts/amenity_renderer.gd")
const Facilities := preload("res://scripts/facility_activity.gd")
const WORLD := Rect2i(Layout.WORLD_BOUNDS)
const TERRAIN := preload("res://assets/art/resort.png")
const RESTING := {"beach_lounge": 0.5, "stage": 0.5, "cafe": 0.71, "hot_tub": 0.64, "kids_pool": 0.52, "waterpark": 0.5}
const PAPER := Color("#3b3040")
const ATLAS_CARD := Vector2i(123, 163)

var checks := 0
var failures := 0
var preview := "--preview" in OS.get_cmdline_user_args()
var map := SeatProbe.new()
var scene_art := BuildingTest.Probe.new()


class SeatProbe extends DiningTest.ActorProbe:
	var native_marks: Array[Dictionary] = []

	func _actor_region(destination: Rect2, source: Rect2) -> void:
		native_marks.append({"target": destination, "source": source})
		super(destination, source)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.add_child(map)
	map.atlas = map.people.get_image()
	var dining := _paper(Vector2i(222, 78))
	var venues := _paper(Vector2i(ATLAS_CARD.x * 4 + 14, ATLAS_CARD.y * RESTING.size() + 28))
	_caption(dining, Vector2i(5, 10), "Diners at every table orientation")
	for turn in range(4):
		var sim := Sim.new()
		var original: Dictionary = sim.layout.dining_tables()[0]
		sim.layout.remove_asset(original.id)
		var placed := sim.layout.add_asset("table", original.building_id, Vector2i(9, 3), turn)
		_check(placed.ok, "Place table turned %d degrees" % (turn * 90))
		var family := _first_meal(sim)
		_check(not family.is_empty(), "Actual guests eat at table turned %d degrees" % (turn * 90))
		if family.is_empty():
			continue
		var picture := _stay(sim, family, 0.76)
		_check(_native_separate(), "Turned meal keeps true head and body pixels apart at %d degrees" % (turn * 90))
		var table: Dictionary = map.dining_tables[family.table_id]
		var view := Rect2i(Vector2i(table.table_center) - Vector2i(23, 22), Vector2i(47, 47))
		var at := Vector2i(5 + turn * 53, 25)
		_caption(dining, at - Vector2i(0, 4), "%d°" % (turn * 90))
		_place(dining, picture, view, at)
		if turn == 0 and preview:
			_before_after(picture, table.table_center)
	_cramped_seats()
	_resting_groups(venues)
	if preview:
		_save(dining, "res://.tools/r11-table-turns.png", 4)
		_save(venues, "res://.tools/r11-resting-turns.png", 2)
	scene_art.free()
	map.queue_free()
	await process_frame
	print("Seated visuals: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _first_meal(sim: Sim) -> Dictionary:
	for tick in range(154):
		sim.tick()
		for family in sim.families:
			if family.phase == "eating":
				return family
	return {}


func _stay(sim: Sim, family: Dictionary, age: float) -> Image:
	map.present(sim, float(family.since) + age, null, true)
	scene_art.present(Building.resolve_buildings(sim.layout), sim.layout.render_assets())
	scene_art.picture = _ground()
	scene_art._draw()
	map.picture = scene_art.picture
	var pose := map._pose(family)
	map._draw_plate(pose.adult_plate, true)
	map._draw_plate(pose.child_plate, true)
	map.native_marks.clear()
	var pair := [map._guest_sprite(family, pose, false), map._guest_sprite(family, pose, true)]
	pair.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.ground.y < b.ground.y)
	for sprite in pair:
		map._draw_actor(sprite)
	map.picture = null
	return scene_art.picture


func _cramped_seats() -> void:
	var sim := Sim.new()
	var layout := sim.layout
	var buffet: Dictionary = layout.building_at(layout.station_point(1))
	for asset in layout.assets.duplicate():
		if asset.building_id == buffet.id:
			layout.remove_asset(asset.id)
	_check(layout.add_asset("counter", buffet.id, Vector2i(5, 1)).ok, "Cramped room has a valid food counter")
	var placed := layout.add_asset("table", buffet.id, Vector2i(1, 1))
	_check(placed.ok, "Cramped table fills corner")
	for cell in [Vector2i(3, 1), Vector2i(3, 2), Vector2i(2, 3)]:
		_check(layout.add_asset("plant", buffet.id, cell).ok, "Block an otherwise usable table edge")
	_check(layout.readiness().ok and layout.dining_tables().size() == 1 and layout.dining_tables()[0].child == Vector2(172, 196),
		"Only the original aisle fallback accommodates the companion")
	var family := _first_meal(sim)
	_check(not family.is_empty(), "Cramped table still receives an actual meal")
	if family.is_empty():
		return
	var surface := _stay(sim, family, 0.37)
	_check(_native_separate(), "Cramped aisle fallback keeps both upright silhouettes separate")
	var table: Dictionary = map.dining_tables[placed.id]
	_check(not layout.route(table.seat, table.adult_sit).is_empty() and not layout.route(table.child, table.child_sit).is_empty(),
		"Cramped draw anchors are on floor the model can route to")
	if preview:
		var crop := Rect2i(Vector2i(158, 147) - WORLD.position, Vector2i(72, 72))
		_save(surface.get_region(crop), "res://.tools/r11-cramped-table.png", 5)


func _resting_groups(sheet: Image) -> void:
	_caption(sheet, Vector2i(7, 13), "Full reservations at every orientation")
	for index in range(4):
		_caption(sheet, Vector2i(7 + index * ATLAS_CARD.x, 25), "%d degrees" % (90 * index))
	var row := 0
	for kind: String in RESTING:
		var record: Dictionary = Layout.Landscape.PROP_CATALOG[kind]
		for turn in range(4):
			var size := Amenities.ground_size(kind)
			var rotated := size if turn % 2 == 0 else Vector2(size.y, size.x)
			var venue := {"kind": kind, "rect": Rect2(Vector2(0, 0), rotated), "rotation": turn, "capacity": record.capacity}
			var frame := Amenities.frame(kind, turn)
			var art := _ground()
			var top := Vector2i(venue.rect.position + Amenities.art_offset(kind))
			art.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), top - WORLD.position)
			map.picture = art
			map.native_marks.clear()
			var sample: float = RESTING[kind]
			var period: float = Sim.LEISURE_DURATIONS[kind]
			map.time = period * sample
			var sprites := []
			for slot in range(venue.capacity):
				var family := {"id": slot, "since": 0.0, "leisure_slot": slot}
				var pose := map._amenity_pose(venue, slot) if kind in ["beach_lounge", "stage"] else Facilities.pose(venue, slot, sample, map.time)
				sprites.append(map._guest_sprite(family, pose, false))
				sprites.append(map._guest_sprite(family, pose, true))
			sprites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.ground.y < b.ground.y)
			for sprite in sprites:
				map._draw_actor(sprite)
			_check(_native_separate(), "%s full capacity has separate bodies at %d degrees" % [kind, turn * 90])
			if preview:
				var at := Vector2i(7 + turn * ATLAS_CARD.x, 28 + row * ATLAS_CARD.y)
				_caption(sheet, at + Vector2i(0, 11), str(record.label))
				var view_size := Vector2i(116, 146)
				var crop := Rect2i(top + frame.get_size() / 2 - view_size / 2, view_size)
				_place(sheet, art, crop, at + Vector2i(0, 14))
		row += 1
	map.picture = null


func _native_separate() -> bool:
	var ink := {}
	for region in map.native_marks:
		var source: Rect2i = Rect2i(region.source)
		var target: Rect2 = region.target
		if Vector2(source.size) != target.size.abs():
			return false
		var mirrored := target.size.x < 0
		var origin := Vector2i(target.position)
		for y in source.size.y:
			for x in source.size.x:
				if map.atlas.get_pixelv(source.position + Vector2i(x, y)).a < 0.9:
					continue
				var pixel := origin + Vector2i(source.size.x - 1 - x if mirrored else x, y)
				if ink.has(pixel):
					return false
				ink[pixel] = true
	return not ink.is_empty()


func _before_after(after: Image, center: Vector2) -> void:
	var before := Image.load_from_file("res://.tools/r11-seated-before.png")
	if not before or before.is_empty():
		return
	before.resize(109, 62, Image.INTERPOLATE_NEAREST)
	var sheet := _paper(Vector2i(163, 62))
	sheet.blit_rect(before, Rect2i(0, 0, 53, 62), Vector2i.ZERO)
	var crop := Rect2i(Vector2i(center) - Vector2i(24, 19), Vector2i(49, 44))
	_place(sheet, after, crop, Vector2i(57, 15))
	_caption(sheet, Vector2i(57, 11), "After fix")
	sheet.blit_rect(before, Rect2i(57, 0, 52, 62), Vector2i(110, 0))
	_save(sheet, "res://docs/screenshots/seated-before-after.png", 6)


func _ground() -> Image:
	var ground: Image = TERRAIN.get_image().duplicate()
	ground.convert(Image.FORMAT_RGBA8)
	return ground


func _paper(size: Vector2i) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(PAPER)
	return image


func _caption(sheet: Image, at: Vector2i, label: String) -> void:
	scene_art.picture = sheet
	scene_art._draw_plaque_text(ThemeDB.fallback_font, Vector2(at + WORLD.position), label)


func _place(sheet: Image, image: Image, area: Rect2i, target: Vector2i) -> void:
	sheet.blit_rect(image, Rect2i(area.position - WORLD.position, area.size), target)


func _save(sheet: Image, path: String, scale: int) -> void:
	sheet.resize(sheet.get_width() * scale, sheet.get_height() * scale, Image.INTERPOLATE_NEAREST)
	_check(sheet.save_png(path) == OK, "Save " + path)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(message)
