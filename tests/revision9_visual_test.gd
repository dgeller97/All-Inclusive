extends SceneTree

const Layout := preload("res://scripts/layout_model.gd")
const Sim := preload("res://scripts/simulation.gd")
const Buildings := preload("res://scripts/building_renderer.gd")
const LandscapeArt := preload("res://scripts/landscape_renderer.gd")
const Amenity := preload("res://scripts/amenity_renderer.gd")
const BuildingTest := preload("res://tests/building_renderer_test.gd")
const ActorTest := preload("res://tests/dining_visual_test.gd")
const WORLD := Rect2i(Layout.WORLD_BOUNDS)
const TERRAIN := preload("res://assets/art/resort.png")
const PAPER := Color("#4c3845")
const STONE := Color("#e6cb9c")
const ROTATION_LABELS := ["0 degrees", "90 degrees", "180 degrees", "270 degrees"]

var checks := 0
var failures := 0
var building_probe := BuildingTest.Probe.new()
var map := ActorTest.ActorProbe.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.add_child(map)
	map.atlas = map.people.get_image()
	var atlas := _rotation_atlas()
	var architecture := _architecture_sheet()
	var activity := _activity_sheet()
	if "--preview" in OS.get_cmdline_user_args():
		_save(atlas, "r9-rotation-atlas")
		_save(architecture, "r9-architecture")
		_save(activity, "r9-activity")
	map.queue_free()
	building_probe.free()
	await process_frame
	print("Revision 9 visual verification: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _rotation_atlas() -> Image:
	var layout := Layout.new()
	var furniture := Buildings.FURNITURE.get_image()
	furniture.convert(Image.FORMAT_RGBA8)
	var scenery := LandscapeArt.PROPS.get_image()
	scenery.convert(Image.FORMAT_RGBA8)
	var kinds := ["bed", "desk", "counter", "table", "lounger", "umbrella", "plant", "bench",
		"palm", "bush", "rock", "beach_flag", "beach_lounge", "volleyball", "beach_bar", "stage"]
	var sheet := _sheet(Vector2i(436, 993))
	var y := 16
	_caption(sheet, Vector2i(6, 11), "Placed asset orientations")
	for turn in 4:
		_caption(sheet, Vector2i(99 + 84 * turn, 26), ROTATION_LABELS[turn])
	y = 34
	for kind: String in kinds:
		var row_height := 43
		if Amenity.handles(kind) or kind == "palm":
			row_height = 92
		elif kind == "beach_flag":
			row_height = 56
		_caption(sheet, Vector2i(6, y + 13), kind.capitalize())
		var unique := {}
		for turn in 4:
			var frame: Image
			var footprint := Vector2i.ZERO
			if Layout.ASSET_CATALOG.has(kind):
				footprint = layout.asset_size(kind, turn) * Layout.GRID
				frame = furniture.get_region(Rect2i(Buildings.furniture_source(kind, turn, Vector2(footprint))))
				var ink := frame.get_used_rect()
				_check(frame.get_size() == footprint + Vector2i(Buildings.FURNITURE_LIFT)
					and ink.has_area() and ink.size.x >= footprint.x / 2,
					"%s turn %d stays in the resolved asset footprint" % [kind, turn])
			elif Amenity.handles(kind):
				var prop := {"kind": kind, "cell": [0, 0], "rotation": turn}
				footprint = Vector2i(layout.prop_rect(prop).size)
				frame = Amenity.frame(kind, turn)
				_check(layout.prop_visual_rect(prop).size == Vector2(frame.get_size()) and frame.get_used_rect().has_area(),
					"%s turn %d uses the model's artwork envelope" % [kind, turn])
			elif kind == "beach_flag":
				frame = _flag_frame(turn)
			else:
				var scenery_row := 0 if kind == "palm" else scenery.get_height() / LandscapeArt.PROP_SPAN - (2 if kind == "bush" else 1)
				var bounds: Rect2 = LandscapeArt.PROP_BOUNDS[kind]
				frame = scenery.get_region(Rect2i(Vector2(turn, scenery_row) * LandscapeArt.PROP_SPAN
					+ LandscapeArt.PROP_ANCHOR + bounds.position, bounds.size))
			unique[frame.get_data().hex_encode()] = true
			var tile := Rect2i(91 + turn * 85, y, 84, row_height - 3)
			sheet.fill_rect(tile, STONE)
			var at := tile.get_center() - frame.get_size() / 2
			if footprint.x > 0:
				var base := Rect2i(at + Vector2i(0, frame.get_height() - footprint.y), footprint)
				sheet.fill_rect(base, Color("#d7ae81"))
			_blend(sheet, frame, at)
		_check(unique.size() == 4, "%s has distinct projected art in each orientation" % kind)
		y += row_height
	return sheet.get_region(Rect2i(0, 0, sheet.get_width(), y))


func _flag_frame(turn: int) -> Image:
	var frame := Image.create(52, 48, false, Image.FORMAT_RGBA8)
	var outline := LandscapeArt.flag_outline(Vector2(24, 46), turn, 0.0, 0.0)
	frame.fill_rect(Rect2i(23, 3, 2, 43), Color("#966952"))
	frame.fill_rect(Rect2i(22, 1, 5, 3), Color("#fbe8b7"))
	for y in range(5, 22):
		for x in range(52):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), outline):
				frame.set_pixel(x, y, Color("#78c897"))
	frame.fill_rect(Rect2i(1, 23, 49, 21), Color("#443b40"))
	frame.fill_rect(Rect2i(1, 23, 49, 1), Color("#fff0c5"))
	_caption(frame, Vector2i(9, 39), "OCEAN")
	return frame


func _bare_layout() -> Layout:
	var layout := Layout.new(false)
	for building: Dictionary in layout.buildings.duplicate():
		layout.remove_building(building.id)
	for prop: Dictionary in layout.landscape.props.duplicate():
		layout.remove_prop(prop.id)
	return layout


func _architecture_sheet() -> Image:
	var sheet := _sheet(Vector2i(642, 842))
	var sizes := {"bedroom": Vector2(64, 80), "reception": Vector2(112, 72), "buffet": Vector2(120, 72), "pool": Vector2(144, 80)}
	_caption(sheet, Vector2i(6, 11), "Buildings and connected rooms")
	for turn in 4:
		_caption(sheet, Vector2i(26 + turn * 158, 27), ROTATION_LABELS[turn])
	var index := 0
	for kind: String in sizes:
		var layout := _bare_layout()
		var added := layout.add_building(kind, Rect2(Vector2.ZERO, sizes[kind]))
		_check(added.ok, "%s render fixture" % kind)
		if not added.ok:
			continue
		layout.set_building_finish(added.id, "facade", "plaster")
		layout.set_building_finish(added.id, "roof", ["terracotta", "slate", "metal", "default"][index])
		for turn in 4:
			var building := layout.building_by_id(added.id)
			var art := Buildings.resolve_buildings(layout)
			var bounds := Rect2i(layout.building_rect(building))
			var crop := Rect2i(-5, -10, 154, maxi(bounds.size.y + 10, 126))
			var exterior := _building_picture(layout, true, 1.0)
			var bounds_ok := building_probe.boxes.all(func(box: Rect2i) -> bool: return crop.encloses(box))
			_check(bounds_ok and art[0].door == layout.door_point(building)
				and art[0].door_side == layout.door_side(building), "%s turn %d fits its rotated footprint and entrance" % [kind, turn])
			if kind == "pool":
				_check(building_probe.terrace_water == Rect2i(layout.water_rect(building)), "Pool water aligns in turn %d" % turn)
			var y := 38 + index * 153
			_caption(sheet, Vector2i(8 + turn * 158, y), kind.capitalize())
			_crop_into(sheet, exterior, crop, Vector2i(4 + 158 * turn, y + 4))
			_check(layout.rotate_building(added.id).ok, "%s advances to the next orientation" % kind)
		index += 1

	var layout := _bare_layout()
	var one := layout.add_building("bedroom", Rect2(0, 0, 64, 80))
	var two := layout.add_building("bedroom", Rect2(64, 0, 64, 80))
	var three := layout.add_building("bedroom", Rect2(0, 80, 64, 64))
	_check(one.ok and two.ok and three.ok, "L-shaped rooms can be constructed")
	for id in [one.id, two.id, three.id]:
		layout.add_asset("bed", id, Vector2i(1, 2))
	layout.set_building_finish(two.id, "facade", "timber")
	layout.set_building_finish(three.id, "roof", "metal")
	var resolved := Buildings.resolve_buildings(layout)
	var sections := Buildings._unit_sections(resolved)
	_check(sections.size() == 2 and sections.all(func(section: Rect2i) -> bool:
		return not section.intersects(Rect2i(64, 80, 64, 64))), "Merged roof follows the L-shaped union")
	var outdoors := _building_picture(layout, true, 1.0)
	var gap := Rect2i(64, 80, 64, 64)
	_check(outdoors.get_region(Rect2i(gap.position - WORLD.position, gap.size)).get_data()
		== _terrain().get_region(Rect2i(gap.position - WORLD.position, gap.size)).get_data(), "Roof leaves the empty courtyard untouched")
	_check(building_probe.labels_drawn.size() == 1 and building_probe.finishes_drawn.has("facade/timber"), "Joined rooms share one furnished exterior")
	var indoors := _building_picture(layout, false, 1.0)
	_check(building_probe.labels_drawn.size() == 3 and building_probe.assets_drawn.size() == 3, "Cutaway keeps room identities and contents")
	for building in resolved:
		_check(not building.shared_doors.is_empty(), "Room has a real shared passage")
		for door: Vector2 in building.shared_doors:
			var threshold := indoors.get_pixelv(Vector2i(door) - WORLD.position)
			_check(threshold.is_equal_approx(Buildings.STONE_LIGHT) or threshold.is_equal_approx(Color("#d6b995")),
				"Cutaway exposes shared door at %s, got #%s" % [door, threshold.to_html(false)])
	var night := _building_picture(layout, true, 0.0)
	_check(night.get_data() != outdoors.get_data(), "Night changes the projected window lighting")
	var crop := Rect2i(-6, -10, 143, 159)
	for panel in [[outdoors, "Joined exterior"], [indoors, "Connected interiors"], [night, "Lit windows at night"]]:
		var col := [outdoors, indoors, night].find(panel[0])
		_caption(sheet, Vector2i(11 + col * 159, 672), panel[1])
		_crop_into(sheet, panel[0], crop, Vector2i(4 + col * 159, 676), Color.WHITE if col < 2 else map.NIGHT_TINT)
	return sheet


func _activity_sheet() -> Image:
	var sim := Sim.new()
	var sheet := _sheet(Vector2i(405, 357))
	var eating := {}
	var volleyball := {}
	var swimming := {}
	var incident := {}
	sim.set_swim_policy("allow_red")
	for second in range(1, Sim.DAY_LENGTH + 1):
		sim.tick()
		for family in sim.families:
			if family.phase == "eating" and eating.is_empty():
				eating = {"state": sim.snapshot(), "family": family.id}
			if family.phase == "leisure" and family.leisure_kind == "volleyball" and volleyball.is_empty():
				volleyball = {"state": sim.snapshot(), "family": family.id}
			if family.phase == "ocean_swim" and sim.second >= family.since + Sim.OCEAN_WADE_DURATION and swimming.is_empty():
				swimming = {"state": sim.snapshot(), "family": family.id}
			if family.phase == "evacuate" and incident.is_empty():
				incident = {"state": sim.snapshot(), "family": family.id}
	_check(not eating.is_empty() and not volleyball.is_empty() and not swimming.is_empty(), "A real simulated run reaches eating, volleyball and ocean swimming")
	if eating.is_empty() or volleyball.is_empty() or swimming.is_empty():
		return sheet

	_check(sim.restore(eating.state), "Restore real meal snapshot")
	map.present(sim, sim.second + 0.75, null, true)
	var table: Dictionary = map.dining_tables[sim.families[eating.family].table_id]
	var dining_crop := Rect2i(Rect2(table.table_center - Vector2(28, 24), Vector2(56, 48)))
	_activity_pair(sheet, _building_picture(sim.layout, false, 1.0), dining_crop, 6, "Dining table", "seated", table.table_center)

	_check(sim.restore(volleyball.state), "Restore real court snapshot")
	map.present(sim, sim.second + 0.7, null, true)
	var court := sim.layout.amenity_by_id(sim.families[volleyball.family].amenity_id)
	var frame := Amenity.base_image("volleyball", court.rotation)
	var beach := _terrain()
	_blend(beach, frame, Vector2i(court.rect.position + Amenity.art_offset("volleyball")) - WORLD.position)
	_activity_pair(sheet, beach, Rect2i(court.rect).grow(10), 76, "Volleyball court", "volleyball", court.rect.get_center())

	_check(sim.restore(swimming.state), "Restore actual family at sea")
	sim.sargassum = 0
	map.present(sim, sim.second + 0.5, null, true)
	var pose := map._pose(sim.families[swimming.family])
	_check(pose.swim and pose.child_swim and sim.layout.landscape.is_water_pixel(pose.point)
		and sim.layout.landscape.is_water_pixel(pose.child), "Both actual swimmer sprites remain inside the fixed ocean")
	var coast := Rect2i(Vector2i(map.ocean_access.shore) - Vector2i(21, 26), Vector2i(110, 61))
	var clear := _terrain()
	map.picture = clear
	map._draw_actors()
	_caption(sheet, Vector2i(7, 201), "Daylight swim")
	_crop_into(sheet, clear, coast, Vector2i(5, 205))
	var weed := _terrain()
	var low := map.ocean.sargassum_pixels(20)
	var high := map.ocean.sargassum_pixels(90)
	_check(map.ocean.sargassum_pixels(0).is_empty() and high.size() > low.size() and not low.is_empty(),
		"Coast visibly accumulates and clears sargassum")
	for point in high:
		var coast_x: int = map.ocean._shore[point.y - WORLD.position.y]
		var cell := Vector2i((Vector2(point) / Layout.GRID).floor())
		if absi(point.x - coast_x) > 17 or (point.x < coast_x and sim.layout.landscape.terrain_at(cell) != "sand"):
			_check(false, "Seaweed remains on water or shoreline sand")
			break
		weed.set_pixelv(point - WORLD.position, map.ocean.SEAWEED[(point.x + point.y * point.y) & 3])
	map.picture = weed
	map._draw_actors()
	_caption(sheet, Vector2i(125, 201), "Seasonal sargassum")
	_crop_into(sheet, weed, coast, Vector2i(123, 205))
	if not incident.is_empty():
		_check(sim.restore(incident.state), "Restore live red-flag incident")
		map.present(sim, sim.second + 0.5, null, true)
		var evac := map._pose(sim.families[incident.family])
		_check(evac.child_only and evac.distress and evac.child_swim, "Incident renders child evacuation and omits the drowned adult")
		var evacuation := _terrain()
		map.picture = evacuation
		map._draw_actors()
		_check(map.has_color(map.RESCUE_ORANGE), "Visible rescue marker after the incident")
		_caption(sheet, Vector2i(243, 201), "Red-flag evacuation")
		_crop_into(sheet, evacuation, coast, Vector2i(241, 205))
	else:
		_check(false, "Starter unsafe policy can produce the real evacuation pose")
	sim.second = 180
	map.present(sim, 180.0, null, true)
	_check(map.modulate == map.NIGHT_TINT and map.daylight == 0.0, "Midnight dims the map and descendants")
	var draft := sim.layout.duplicate_layout()
	map.present(sim, 180.0, draft, true, true)
	_check(map.modulate == Color.WHITE and map.exterior_view and not map.actors.visible, "Exterior draft is inspectable with neutral working light")
	map.picture = null
	return sheet.get_region(Rect2i(0, 0, sheet.get_width(), 270))


func _activity_pair(sheet: Image, base: Image, crop: Rect2i, y: int, title: String, action: String, center: Vector2) -> void:
	var active := base.duplicate()
	# Both sides contain every static depth piece. Only the dynamic submissions
	# differ between the idle and active frames.
	map.picture = base
	for item in map._depth_plan():
		if item.kind in ["asset", "prop"]:
			map._draw_depth_item(item)
	map.picture = active
	map._draw_actors()
	_caption(sheet, Vector2i(7, y + 10), title + " idle")
	_caption(sheet, Vector2i(139, y + 10), title + " in use")
	_crop_into(sheet, base, crop, Vector2i(5, y + 14))
	_crop_into(sheet, active, crop, Vector2i(137, y + 14))
	var nearby := 0
	var painted := 0
	var overlays: Array[Rect2i] = []
	for mark in map.pixels:
		var box: Rect2 = mark.rect
		overlays.append(Rect2i(box))
		if box.grow(20).has_point(center):
			nearby += 1
			if box.size.x > 14.0 or box.size.y > 10.0:
				painted += 1
	for region in map.sprite_regions:
		overlays.append(Rect2i(Rect2(region.position, region.size.abs())))
	var changed_outside_overlays := 0
	for row in range(crop.position.y, crop.end.y):
		for x in range(crop.position.x, crop.end.x):
			var pixel := Vector2i(x, row)
			var index := pixel - WORLD.position
			if active.get_pixelv(index) != base.get_pixelv(index) and overlays.all(func(box: Rect2i) -> bool: return not box.has_point(pixel)):
				changed_outside_overlays += 1
	_check(nearby > 0 and painted == 0 and changed_outside_overlays == 0 and active.get_data() != base.get_data(),
		"%s action emits small props and sprite overlays without a replacement texture patch" % action)
	map.picture = null


func _building_picture(layout: Layout, exterior: bool, daylight: float) -> Image:
	building_probe.clear_marks()
	building_probe.present(Buildings.resolve_buildings(layout), layout.render_assets())
	building_probe.set_daylight(daylight)
	building_probe.set_view(exterior)
	building_probe.picture = _terrain()
	building_probe._draw()
	return building_probe.picture


func _terrain() -> Image:
	var ground: Image = TERRAIN.get_image().duplicate()
	ground.convert(Image.FORMAT_RGBA8)
	return ground


func _sheet(size: Vector2i) -> Image:
	var sheet := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(PAPER)
	return sheet


func _caption(sheet: Image, at: Vector2i, title: String) -> void:
	var previous := building_probe.picture
	building_probe.picture = sheet
	building_probe._draw_plaque_text(ThemeDB.fallback_font, Vector2(WORLD.position + at), title)
	building_probe.picture = previous


func _blend(sheet: Image, frame: Image, at: Vector2i) -> void:
	sheet.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), at)


func _crop_into(sheet: Image, source: Image, crop: Rect2i, at: Vector2i, tint: Color = Color.WHITE) -> void:
	var area := source.get_region(Rect2i(crop.position - WORLD.position, crop.size))
	if tint != Color.WHITE:
		for y in area.get_height():
			for x in area.get_width():
				area.set_pixel(x, y, area.get_pixel(x, y) * tint)
	_blend(sheet, area, at)


func _save(sheet: Image, name: String) -> void:
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	_check(sheet.save_png("res://.tools/" + name + ".png") == OK, name + " saves")


func _check(condition: bool, reason: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(reason)
