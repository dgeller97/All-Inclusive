extends SceneTree
## CPU projection probes. --preview writes the live-reservation contact sheet
## and a second debug sheet showing full capacity in every cardinal turn.

const Sim := preload("res://scripts/simulation.gd")
const Layout := preload("res://scripts/layout_model.gd")
const Art := preload("res://scripts/facility_renderer.gd")
const Amenity := preload("res://scripts/amenity_renderer.gd")
const Activity := preload("res://scripts/facility_activity.gd")
const ActorTest := preload("res://tests/dining_visual_test.gd")
const BuildingTest := preload("res://tests/building_renderer_test.gd")
const TERRAIN := preload("res://assets/art/resort.png")
const WORLD := Rect2i(Layout.WORLD_BOUNDS)
const CARD := Vector2i(138, 133)
const TURN_CARD := Vector2i(142, 162)
const PAPER := Color("#392f40")
const PREVIEW_PHASE := {"lap_pool": 0.53, "lagoon_pool": 0.53, "hot_tub": 0.6,
	"kids_pool": 0.61, "waterpark": 0.53, "basketball": 0.57, "climbing_wall": 0.55,
	"arcade": 0.56, "cafe": 0.67, "nightclub": 0.55}
const REP_TURNS := [0, 0, 0, 1, 0, 0, 0, 0, 0, 0]

var map := ActorTest.ActorProbe.new()
var text_art := BuildingTest.Probe.new()
var checks := 0
var failures := 0
var preview := "--preview" in OS.get_cmdline_user_args()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.add_child(map)
	map.atlas = map.people.get_image()
	var contact := _paper(Vector2i(CARD.x * 5 + 14, CARD.y * 2 + 33))
	var turns := _paper(Vector2i(TURN_CARD.x * 4 + 14, TURN_CARD.y * 10 + 31))
	_caption(contact, Vector2i(9, 15), "Resort activities")
	_caption(turns, Vector2i(9, 14), "Full activity reservations")
	for turn in range(4):
		_caption(turns, Vector2i(9 + turn * TURN_CARD.x, 27), "%d degrees" % (90 * turn))
	for index in Art.KINDS.size():
		var kind: String = Art.KINDS[index]
		var art_pixels := {}
		for turn in range(4):
			var sim := _fixture(kind, turn)
			var venue: Dictionary = sim.layout.amenities(kind)[0] if not sim.layout.amenities(kind).is_empty() else {}
			_check(not venue.is_empty(), "%s turn %d uses a reachable dry model placement" % [kind, turn])
			if venue.is_empty():
				continue
			var prop := sim.layout.landscape.prop_by_id(venue.id)
			var frame := Amenity.frame(kind, turn)
			var art := sim.layout.prop_visual_rect(prop)
			_check(Vector2(frame.get_size()) == art.size and frame.get_used_rect().has_area(), "%s turn %d has matching sprite extents" % [kind, turn])
			art_pixels[frame.get_data().hex_encode()] = true
			_test_positions(venue)
			var live := _follow_actual_run(sim, venue)
			if preview:
				var full := _compose(venue, frame)
				_add_full_reservation(venue, full)
				_place_card(turns, full, art, Vector2i(7 + turn * TURN_CARD.x, 31 + index * TURN_CARD.y), venue, TURN_CARD)
				if turn == REP_TURNS[index] and not live.is_empty():
					var actual := _compose(venue, frame)
					var scene := _restore_live_sample(sim, live, actual)
					_place_card(contact, scene, art, Vector2i(7 + (index % 5) * CARD.x, 24 + (index / 5) * CARD.y), venue)
		_check(art_pixels.size() == 4, "%s has four distinct projected orientations" % kind)
	if preview:
		_save(contact, "res://docs/screenshots/activities-preview.png")
		_save(turns, "res://.tools/r10-activity-turns-full.png")
	map.queue_free()
	text_art.free()
	await process_frame
	print("Revision 10 facility visuals: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _fixture(kind: String, turn: int) -> Sim:
	var sim := Sim.new()
	sim.set_swim_policy("closed")
	for prop: Dictionary in sim.layout.landscape.props.duplicate():
		sim.layout.remove_prop(prop.id)
	var placed := sim.layout.add_prop(kind, Vector2i(-12, 0), turn)
	_check(placed.ok, "place %s on dry land at %d degrees" % [kind, turn * 90])
	return sim


func _test_positions(venue: Dictionary) -> void:
	var label := "%s turn %d" % [venue.kind, venue.rotation]
	var bounds: Rect2 = venue.rect
	var visual := Rect2(bounds.position + Amenity.art_offset(venue.kind),
		bounds.size - Amenity.art_offset(venue.kind))
	var entrance := Amenity.at(venue, Vector2(Amenity.ground_size(venue.kind).x / 2, Amenity.ground_size(venue.kind).y))
	_check(venue.point.distance_to(entrance) < 7.0 and not bounds.has_point(venue.point),
		label + " has one real gate on the rotated world approach")
	var occupied: Array[Vector2] = []
	for slot in range(venue.capacity):
		var handoff := Activity.entrance(venue, slot)
		var duration: float = Sim.LEISURE_DURATIONS[venue.kind]
		var first := Activity.pose(venue, slot, 0.0, 0.0)
		var last := Activity.pose(venue, slot, 1.0, duration)
		_check(handoff.point == first.point and handoff.child == first.child
			and last.point == first.point and last.child == first.child
			and not first.swim and not first.child_swim and not last.swim and not last.child_swim,
			label + " starts and returns both actors to the saved dry gate")
		var separated: bool = handoff.point.distance_to(handoff.child) >= 6.0 and occupied.all(func(anchor: Vector2) -> bool:
			return anchor.distance_to(handoff.point) >= 6.0 and anchor.distance_to(handoff.child) >= 6.0)
		_check(separated,
			label + " gives each adult and child a separate full-capacity gate anchor")
		occupied.append_array([handoff.point, handoff.child])
		var prior := first
		var states := {}
		var wet_actor_seen := false
		var height_seen := false
		var continuous := true
		var bounded := true
		for index in range(1, 121):
			var t := float(index) / 120.0
			var current := Activity.pose(venue, slot, t, duration * t)
			states[current.adult_action] = true
			states[current.child_action] = true
			wet_actor_seen = wet_actor_seen or current.swim or current.child_swim
			height_seen = height_seen or current.adult_local.z >= 15.0 or current.child_local.z >= 15.0
			var adult: Vector2 = current.point
			var child: Vector2 = current.child
			continuous = continuous and adult.distance_to(prior.point) < 8.0 and child.distance_to(prior.child) < 8.0
			bounded = (bounded and visual.has_point(adult) and visual.has_point(child) and bounds.has_point(current.ground)
				and bounds.has_point(current.child_ground))
			prior = current
		_check(continuous and bounded, label + " follows a continuous in-bounds route")
		_check(states.size() >= 2, label + " triggers actual timed activity poses")
		_check(wet_actor_seen == Art.water_contains(venue.kind, _known_water(venue.kind)), label + " separates wet and dry facilities")
		if venue.kind in ["climbing_wall", "waterpark"]:
			_check(height_seen, label + " lifts actors along the actual tower or rock face")
	for time in [0.35, 0.46, 0.53, 0.63, 0.71]:
		var points: Array[Vector2] = []
		for slot in range(venue.capacity):
			var value := Activity.pose(venue, slot, time, time * Sim.LEISURE_DURATIONS[venue.kind])
			points.append_array([value.point, value.child])
		var minimum := INF
		for a in range(points.size()):
			for b in range(a + 1, points.size()):
				minimum = minf(minimum, points[a].distance_to(points[b]))
		_check(minimum >= 6.0, "%s keeps full-capacity actors apart at %.2f (%.1f px)" % [label, time, minimum])


func _known_water(kind: String) -> Vector2:
	match kind:
		"lap_pool": return Art.LAP_WATER.get_center()
		"lagoon_pool": return Art.LAGOON_WATER.get_center()
		"hot_tub": return Art.TUB_WATER.get_center()
		"kids_pool": return Art.KIDS_WATER.get_center()
		"waterpark": return Art.SLIDE_WATER.get_center()
	return Vector2.ZERO


func _follow_actual_run(sim: Sim, venue: Dictionary) -> Dictionary:
	var live := {}
	var first := {}
	var leaving := {}
	var coming := {}
	var family_id := -1
	var sample_progress: float = PREVIEW_PHASE[venue.kind]
	for second in range(1, Sim.DAY_LENGTH):
		sim.tick()
		for family: Dictionary in sim.families:
			if family.get("amenity_id") != venue.id:
				continue
			if family_id < 0:
				family_id = family.id
			if family.id != family_id:
				continue
			var duration := float(family.until - family.since)
			var gate := Activity.entrance(venue, family.leisure_slot)
			match family.phase:
				"to_leisure":
					if coming.is_empty():
						map.present(sim, float(family.until), null, true)
						coming = map._pose(family)
						_check(coming.point == gate.point and coming.child == gate.child, "%s actual walk reaches its rotated gate" % venue.kind)
				"leisure":
					if first.is_empty():
						map.present(sim, float(family.since), null, true)
						first = map._pose(family)
						_check(not coming.is_empty() and first.point == coming.point and first.child == coming.child,
							"%s live animation starts where both walkers finished" % venue.kind)
					if live.is_empty() and sim.second >= family.since + floori(duration * sample_progress):
						map.present(sim, float(sim.second), null, true)
						var pose := map._pose(family)
						_check(pose.leisure == venue.kind and (pose.adult_action != "" or pose.child_action != ""),
							"%s actual reserved guest uses the correct activity pose" % venue.kind)
						live = {"state": sim.snapshot(), "time": maxf(float(sim.second), float(family.since) + duration * sample_progress)}
				"from_leisure":
					if leaving.is_empty():
						map.present(sim, float(family.since), null, true)
						leaving = map._pose(family)
						_check(leaving.point == gate.point and leaving.child == gate.child, "%s actual departure begins at its activity gate" % venue.kind)
		if not leaving.is_empty():
			break
	_check(not coming.is_empty() and not live.is_empty() and not leaving.is_empty(),
		"%s turn %d serves every phase in normal play" % [venue.kind, venue.rotation])
	return live


func _restore_live_sample(sim: Sim, live: Dictionary, image: Image) -> Image:
	_check(sim.restore(live.state), "Restore the actual activity reservation")
	map.present(sim, live.time, null, true)
	map.picture = image
	map._draw_actors()
	map.picture = null
	return image


func _add_full_reservation(venue: Dictionary, image: Image) -> void:
	var sprites: Array[Dictionary] = []
	var duration: float = Sim.LEISURE_DURATIONS[venue.kind]
	map.time = duration * PREVIEW_PHASE[venue.kind]
	map.picture = image
	var surface := image.duplicate() as Image
	map.clear_marks()
	if venue.kind == "nightclub":
		Activity.draw_club_lights(map._actor_block, venue, 1.0, map.time)
	for slot in range(venue.capacity):
		var pose := Activity.pose(venue, slot, PREVIEW_PHASE[venue.kind], map.time)
		var family := {"id": slot, "since": 0, "leisure_slot": slot}
		sprites.append(map._guest_sprite(family, pose, false))
		sprites.append(map._guest_sprite(family, pose, true))
	sprites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.ground.y < b.ground.y)
	for sprite in sprites:
		map._draw_actor(sprite)
	_check(_authored_overlays(surface, image, map.pixels, map.sprite_regions, Rect2i(venue.rect)),
		"%s turn %d preserves the base texture outside actor and prop overlays" % [venue.kind, venue.rotation])
	map.picture = null


func _authored_overlays(before: Image, after: Image, blocks: Array[Dictionary], people: Array[Rect2], venue: Rect2i) -> bool:
	var overlays: Array[Rect2i] = []
	for mark in blocks:
		var rect := Rect2i(mark.rect)
		if rect.size.x > 14 or rect.size.y > 8:
			return false
		overlays.append(rect)
	for region in people:
		overlays.append(Rect2i(Rect2(region.position, region.size.abs())))
	var changed := false
	for y in range(venue.position.y, venue.end.y):
		for x in range(venue.position.x, venue.end.x):
			var point := Vector2i(x, y)
			var pixel := point - WORLD.position
			if before.get_pixelv(pixel) == after.get_pixelv(pixel):
				continue
			changed = true
			if overlays.all(func(rect: Rect2i) -> bool: return not rect.has_point(point)):
				return false
	return changed


func _compose(venue: Dictionary, frame: Image) -> Image:
	var surface: Image = TERRAIN.get_image().duplicate()
	surface.convert(Image.FORMAT_RGBA8)
	var at := Vector2i(venue.rect.position + Amenity.art_offset(venue.kind)) - WORLD.position
	surface.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), at)
	return surface


func _place_card(sheet: Image, scene: Image, art: Rect2, at: Vector2i, venue: Dictionary, card: Vector2i = CARD) -> void:
	var label: String = Layout.Landscape.PROP_CATALOG[venue.kind].label
	_caption(sheet, at + Vector2i(5, 11), label)
	var view_size := Vector2i(card.x - 7, card.y - 17)
	var base := Vector2i(art.position + art.size * 0.5) - view_size / 2
	var region := scene.get_region(Rect2i(base - WORLD.position, view_size))
	if venue.kind == "nightclub":
		for y in region.get_height():
			for x in region.get_width():
				region.set_pixel(x, y, region.get_pixel(x, y) * map.NIGHT_TINT)
	sheet.blit_rect(region, Rect2i(Vector2i.ZERO, region.get_size()), at + Vector2i(0, 15))


func _paper(size: Vector2i) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(PAPER)
	return image


func _caption(sheet: Image, at: Vector2i, label: String) -> void:
	text_art.picture = sheet
	text_art._draw_plaque_text(ThemeDB.fallback_font, Vector2(at + WORLD.position), label)


func _save(sheet: Image, path: String) -> void:
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	_check(sheet.save_png(path) == OK, "Save " + path)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(message)
