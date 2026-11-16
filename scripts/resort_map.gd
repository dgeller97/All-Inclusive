extends Node2D

const Ocean = preload("res://scripts/ocean.gd")
const Sim = preload("res://scripts/simulation.gd")
const Layout = preload("res://scripts/layout_model.gd")
const BuildingRenderer = preload("res://scripts/building_renderer.gd")
const LandscapeRenderer = preload("res://scripts/landscape_renderer.gd")
const AmenityArt := preload("res://scripts/amenity_renderer.gd")
const FacilityArt := preload("res://scripts/facility_renderer.gd")
const FacilityActivity := preload("res://scripts/facility_activity.gd")
const SeatedArt := preload("res://scripts/seated_art.gd")
const RenderDepth := preload("res://scripts/render_depth.gd")
const LifeguardArt := preload("res://scripts/lifeguard_art.gd")
const WORLD_BOUNDS := Layout.WORLD_BOUNDS
var _staff_stamp := 0
const BASE_PATH := "res://assets/art/resort.png"
const PEOPLE_PATH := "res://assets/art/people.png"
const OUTLINE := Color("#483747")
const LABEL_BG := Color("#392b38")
const LABEL_INK := Color("#fff0d5")
const LABEL_GOLD := Color("#e5bc78")
const PLATE_EDGE := Color("#495e63")
const PLATE_RIM := Color("#fdf3d7")
const FOOD := Color("#d86d48")
const GARNISH := Color("#8fa658")
const CHAIR_WOOD := Color("#945744")
const CHAIR_LIGHT := Color("#e5af7a")
const GUEST_PANTS := [Color("#656880"), Color("#76515e"), Color("#587984"), Color("#576673"), Color("#737a9b")]
const GUEST_SKIN := [Color("#d5936c"), Color("#a86d53"), Color("#ebaa7c"), Color("#bb7d5e"), Color("#c38363")]
const BEACH_BALL := Color("#ed924d")
const DRINK_CUP := Color("#96e2db")
const SHOW_LAMP := Color("#ffec9a")
const NIGHT_TINT := Color("#8d94bd")
const RESCUE_ORANGE := Color("#f4a16c")
const ROPE := Color("#f4cd85")

var simulation: Sim
var time := 0.0
var base_art: Texture2D
var people: Texture2D
var ocean: Ocean
var renderer: BuildingRenderer
var landscape_renderer: LandscapeRenderer
var landscape_revision := -1
var actors := Node2D.new()
var signs := Node2D.new()
var visible_layout: Layout
var viewing_draft := false
var exterior_view := false
var ceiling_id := -1
var room_points: Array[Vector2] = []
var station_points: Array[Vector2] = []
var station_approaches: Array[PackedVector2Array] = []
var dining_tables := {}
var amenities := {}
var counter_points: Array[Vector2] = []
var counter_trays: Array[Vector2] = []
var table_wait_points: Array[Vector2] = []
var pool_water := Rect2()
var pool_turn := 0
var label_font: Font
var daylight := 1.0
var ocean_access := {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base_art = load(BASE_PATH) as Texture2D
	people = load(PEOPLE_PATH) as Texture2D
	landscape_renderer = LandscapeRenderer.new()
	landscape_renderer.name = "Landscape"
	add_child(landscape_renderer)
	ocean = Ocean.new()
	ocean.name = "Ocean"
	landscape_renderer.add_child(ocean)
	landscape_renderer.move_child(ocean, 0)
	renderer = BuildingRenderer.new()
	renderer.name = "Buildings"
	add_child(renderer)

	actors.name = "GuestsAndStaff"
	actors.draw.connect(_draw_actors)
	add_child(actors)
	signs.name = "BuildingLabels"
	signs.draw.connect(_draw_signs)
	add_child(signs)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	font.font_weight = 600
	label_font = font


func present(resort: Sim, visual_time: float, draft: Layout = null, layout_changed: bool = false,
		show_exteriors: bool = false, inspect_ceiling_id: int = -1) -> void:
	var layout := draft if draft else resort.layout
	var landscape_changed := visible_layout != layout or landscape_revision != layout.landscape.revision
	var changed := layout_changed or landscape_changed
	var in_design := draft != null
	var exterior := show_exteriors
	var state_changed := simulation != resort or time != visual_time or viewing_draft != in_design or exterior_view != exterior
	var staff_stamp := hash([resort.lifeguard_assignment, resort.rescue])
	state_changed = state_changed or _staff_stamp != staff_stamp
	_staff_stamp = staff_stamp
	simulation = resort
	time = visual_time
	viewing_draft = in_design
	exterior_view = exterior
	ceiling_id = inspect_ceiling_id if viewing_draft else -1
	renderer.set_view(exterior_view, ceiling_id)
	renderer.set_interleave(not viewing_draft)
	landscape_renderer.set_interleave(not viewing_draft)
	ocean.set_flags_interleaved(not viewing_draft)
	actors.visible = not viewing_draft
	signs.visible = not viewing_draft
	daylight = 1.0 if viewing_draft else float(resort.calendar_state().daylight)
	modulate = NIGHT_TINT.lerp(Color.WHITE, daylight)
	renderer.set_daylight(daylight)
	var landscape_time := float(simulation.day - 1) * Sim.DAY_LENGTH + time
	if landscape_changed:
		landscape_revision = layout.landscape.revision
		ocean.set_landscape(layout.landscape)
	landscape_renderer.present(layout.landscape, landscape_time)
	ocean.present_field(resort.floating_sargassum(time), resort.beach_deposits)
	ocean.present(landscape_time, resort.sargassum, resort.surf_condition())
	if changed:
		ocean.set_swim_access(layout.ocean_access())
		visible_layout = layout
		var buildings := BuildingRenderer.resolve_buildings(layout)
		var upgraded: bool = layout.readiness().terrace
		pool_water = Rect2()
		for building in buildings:
			if building.kind == "pool":
				building.upgraded = upgraded
				pool_water = layout.water_rect(building)
				pool_turn = int(building.rotation)
				break
		renderer.present(buildings, layout.render_assets(), time)
		if not viewing_draft:
			_rebuild_actor_anchors(layout)
	else:
		renderer.advance_time(time)
	if changed or state_changed:
		actors.queue_redraw()
		signs.queue_redraw()


func _rebuild_actor_anchors(layout: Layout) -> void:
	ocean_access = layout.ocean_access()
	room_points = layout.room_points()
	station_points.clear()
	station_approaches.clear()
	for station in range(3):
		var point := layout.station_point(station)
		station_points.append(point)
		station_approaches.append(layout.route(Layout.ENTRY, point))
	_rebuild_dining_anchors(layout)
	amenities.clear()
	for amenity in layout.amenities():
		amenities[amenity.id] = amenity


func _rebuild_dining_anchors(layout: Layout) -> void:
	dining_tables.clear()
	counter_points.clear()
	counter_trays.clear()
	table_wait_points.clear()
	var counter := station_points[1]
	if counter == Vector2.INF:
		return
	var blocked: Array[Vector2] = []
	var counter_bounds := Rect2()
	var buffet := layout.building_at(counter)
	var interior := layout.building_rect(buffet).grow(-Layout.GRID)
	for asset in layout.assets:
		if asset.kind == "counter" and not counter_bounds.has_area() and asset.building_id == buffet.id:
			var bounds := layout.asset_rect(asset)
			if bounds.grow(5.0).has_point(counter):
				counter_bounds = bounds
				for local in [Vector2(7.5, 8.5), Vector2(16.5, 8.5), Vector2(25.5, 8.5)]:
					counter_trays.append(AmenityArt.ground_point(bounds.position, Vector2(32, 16), asset.rotation, local) - Vector2(0, 5.0))
	for table in layout.dining_tables():
		var separation: Vector2 = table.child - table.seat
		var axis := Vector2.RIGHT if absf(separation.x) >= absf(separation.y) else Vector2.DOWN
		if axis.dot(separation) < 0.0:
			axis = -axis
		var towards_diners: Vector2 = (table.seat + table.child) * 0.5 - table.table_center
		var top: Vector2 = table.table_center - Vector2(0, 3)
		if axis.x == 0.0:
			top.x += signf(towards_diners.x) * 2.0
		elif absf(separation.x) <= Layout.GRID * 2.0:
			top.y -= 2.0
		table.adult_plate = top - axis * 4.0
		table.child_plate = top + axis * 4.0
		var anchors := _seating_anchors(table, layout, interior)
		table.adult_sit = anchors[0]
		table.child_sit = anchors[1]
		dining_tables[table.id] = table
		blocked.append(table.seat)
		blocked.append(table.child)
	counter_points.append(counter)
	var nearby: Array[Vector2] = []
	for y in range(-4, 5):
		for x in range(-4, 5):
			var point := counter + Vector2(x, y) * Layout.GRID
			if point != counter and interior.has_point(point) and not blocked.has(point):
				if not layout.route(counter, point).is_empty():
					nearby.append(point)
	nearby.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(counter) < b.distance_squared_to(counter))
	# Give both collection lanes room at the real counter. A narrow aisle can
	# use the same adjacent space for both lanes.
	for point in nearby:
		if counter_bounds.grow(5.0).has_point(point) and counter_points.size() < 4:
			counter_points.append(point)
	if counter_points.size() == 1:
		counter_points.append(_approach(1, 1))
	for point in nearby:
		if not counter_points.has(point) and point != _approach(1, 1) and point != _approach(1, 2):
			table_wait_points.append(point)
			if table_wait_points.size() == 8:
				break


func _seating_anchors(table: Dictionary, layout: Layout, interior: Rect2) -> Array[Vector2]:
	var adult_positions := _seat_candidates(table.seat, layout, interior)
	var child_positions := _seat_candidates(table.child, layout, interior)
	var best := INF
	var chosen: Array[Vector2] = [table.seat, table.child]
	var adult_plate := Rect2(table.adult_plate - Vector2(3, 2), Vector2(7, 4))
	var child_plate := Rect2(table.child_plate - Vector2(3, 2), Vector2(7, 4))
	for adult in adult_positions:
		var adult_body := SeatedArt.upper_body(adult, false)
		for child in child_positions:
			var child_body := SeatedArt.upper_body(child, true, SeatedArt.CHILD_BOOSTER)
			var overlap := adult_body.intersection(child_body).get_area()
			var hidden_plates := adult_body.intersection(adult_plate).get_area() + adult_body.intersection(child_plate).get_area()
			hidden_plates += child_body.intersection(adult_plate).get_area() + child_body.intersection(child_plate).get_area()
			var movement := adult.distance_squared_to(table.seat) + child.distance_squared_to(table.child)
			var reach := maxf(0.0, adult.distance_to(table.adult_plate + Vector2(0, 6)) - 12.0)
			reach += maxf(0.0, child.distance_to(table.child_plate + Vector2(0, 4.0 + SeatedArt.CHILD_BOOSTER)) - 9.0)
			var score := overlap * 100.0 + hidden_plates * 7.0 + movement * 0.23 + reach * 4.0
			if score < best:
				best = score
				chosen = [adult, child]
	return chosen


func _seat_candidates(seat: Vector2, layout: Layout, interior: Rect2) -> Array[Vector2]:
	var candidates: Array[Vector2] = [seat]
	for y in [-3, 0, 3]:
		for x in [-3, 0, 3]:
			var point := seat + Vector2(x, y)
			if point != seat and interior.has_point(point):
				candidates.append(point)
	# A neighboring free aisle gives staggered or cramped pairs more room.
	# Only a one-cell, straight step from the reserved seat is considered.
	for direction in [Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
		var point: Vector2 = seat + direction * 6.0
		if interior.has_point(point) and layout.route(seat, point).size() == 2:
			candidates.append(point)
	return candidates


func _draw() -> void:
	if base_art:
		draw_texture(base_art, WORLD_BOUNDS.position)


func _draw_signs() -> void:
	if not simulation or not visible_layout:
		return
	var room_index := 0
	for building in visible_layout.buildings:
		var bounds := visible_layout.building_rect(building)
		var status := ""
		var ink := LABEL_INK
		if building.kind == "bedroom":
			if room_index < room_points.size() and bounds.has_point(room_points[room_index]):
				var occupied := simulation.rooms[room_index] >= 0
				status = "Occupied" if occupied else "Free"
				ink = LABEL_GOLD if occupied else LABEL_INK
				room_index += 1
			else:
				status = "Needs bed or access"
		else:
			var station := Sim.STATIONS.find(building.kind)
			var waiting := simulation.count_at(station, "queue")
			if station == 1:
				status = _buffet_status(waiting)
			elif waiting > 0:
				status = "%d waiting" % waiting
		if not status.is_empty():
			_draw_status_badge(bounds, status, ink, building.kind != "pool")


func _buffet_status(counter_waiting: int) -> String:
	var table_waiting := simulation.count_at(1, "wait_table")
	if counter_waiting > 0 and table_waiting > 0:
		return "Food %d · Tables %d" % [counter_waiting, table_waiting]
	if counter_waiting > 0:
		return "%d in buffet line" % counter_waiting
	if table_waiting > 0:
		return "%d waiting for tables" % table_waiting
	return ""


func _draw_status_badge(bounds: Rect2, status: String, ink: Color, enclosed: bool) -> void:
	var font_size := 8
	var width := ceilf(label_font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var roof_clearance := 8.0 if enclosed else 0.0
	var point := Vector2(roundf(bounds.get_center().x - width / 2.0), bounds.position.y - roof_clearance - 13.0)
	signs.draw_rect(Rect2(point - Vector2(3, 1), Vector2(width + 6.0, 12.0)), LABEL_BG)
	signs.draw_string(label_font, point + Vector2(0, 8), status, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


func _draw_actors() -> void:
	for item in _depth_plan():
		_draw_depth_item(item)


func _depth_plan() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if not simulation or visible_layout != simulation.layout or viewing_draft:
		return items
	items.append_array(landscape_renderer.depth_items())
	var furnishings := renderer.depth_items()
	items.append_array(furnishings)
	var sprites: Array[Dictionary] = []
	var in_use := {}
	for station in range(3):
		sprites.append({"point": _approach(station, 1), "row": 3, "frame": 0, "facing": true})
	sprites.append({"point": _approach(simulation.float_station, 2), "row": 3, "frame": 0, "facing": false})
	for family in simulation.families:
		if family.phase == "gone":
			continue
		var pose := _pose(family)
		if not pose.get("child_only", false):
			sprites.append(_guest_sprite(family, pose, false))
		sprites.append(_guest_sprite(family, pose, true))
		if family.phase == "leisure" and amenities.has(family.amenity_id):
			in_use[family.amenity_id] = amenities[family.amenity_id]
	for amenity: Dictionary in amenities.values():
		if amenity.kind == "stage" and (daylight < 0.5 or in_use.has(amenity.id)):
			for index in 2:
				var lamp := AmenityArt.stage_lamps(amenity)[index]
				var contact := lamp + Vector2(0, 14)
				var light := _effect("stage_lights", lamp, contact.y + 0.2, Vector2(9, 28))
				light.lamp = index
				items.append(light)
			if in_use.has(amenity.id):
				var stage := AmenityArt.at(amenity, Vector2(32, 14))
				var performer := _effect("stage_performer", stage, stage.y, Vector2(40, 46))
				performer.amenity = amenity
				items.append(performer)
		elif amenity.kind == "nightclub" and in_use.has(amenity.id):
			for index in FacilityArt.CLUB_LAMPS.size():
				var local: Vector3 = FacilityArt.CLUB_LAMPS[index]
				var support := AmenityArt.at(amenity, Vector2(local.x, local.y))
				var light := _effect("club_lights", support - Vector2(0, local.z), support.y + 0.2, Vector2(12, 22))
				light.amenity = amenity
				light.lamp = index
				items.append(light)
			var booth := AmenityArt.at(amenity, Vector2(42, 14))
			var notes := _effect("club_lights", booth, booth.y + 0.5, Vector2(14, 40))
			notes.amenity = amenity
			notes.lamp = -1
			items.append(notes)
		elif amenity.kind == "volleyball" and in_use.has(amenity.id):
			items.append(_volleyball_effect(amenity))
	for sprite in sprites:
		if not actor_visible(sprite.point):
			continue
		var ground: Vector2 = sprite.get("ground", sprite.point)
		if sprite.get("meal", "") == "seated" and actor_visible(sprite.plate):
			items.append(_table_plate(sprite, furnishings))
		var foot: Vector2 = sprite.point
		_append_contact_actions(items, sprite, furnishings)
		items.append({
			"kind": "actor", "tag": "staff" if sprite.row == 3 else "guest", "depth": ground.y,
			"bounds": Rect2(foot - Vector2(10, 23), Vector2(20, 27)), "actor": sprite,
		})
		match sprite.get("facility_action", ""):
			"climb", "belay":
				_append_climbing_rope(items, sprite)
			"basketball":
				var ball := FacilityActivity.basketball_effect(sprite, foot.round())
				items.append(_effect("basketball_ball", ball.point, ball.depth + 0.02))
	_append_lifeguard(items)
	RenderDepth.order(items)
	return items


func _append_lifeguard(items: Array[Dictionary]) -> void:
	if simulation.lifeguard_assignment.is_empty():
		return
	var post: Dictionary = simulation.lifeguard_post(simulation.lifeguard_assignment)
	if post.is_empty():
		return
	var origin: Vector2 = post.origin
	var entry: Vector2 = post.entry
	var facing := entry.x >= origin.x
	items.append({"kind": "lifeguard_post", "tag": "lifeguard_post", "depth": origin.y - 0.1,
		"point": origin, "facing": facing, "bounds": Rect2(origin - Vector2(12, 32), Vector2(24, 36))})
	var rescue: Dictionary = simulation.rescue_positions(time)
	var foot: Vector2 = origin if rescue.is_empty() else rescue.guard
	var swim: bool = not rescue.is_empty() and rescue.guard_swim
	if not rescue.is_empty():
		facing = (rescue.victim.x >= foot.x) if rescue.phase == "swim_out" else entry.x >= foot.x
	items.append({"kind": "lifeguard", "tag": "lifeguard", "point": foot, "depth": foot.y,
		"bounds": Rect2(foot - Vector2(12, 32), Vector2(24, 36)), "facing": facing,
		"swim": swim, "seated": rescue.is_empty()})
	if rescue.is_empty():
		return
	if rescue.family < 0:
		var volunteer := {"point": rescue.victim, "row": 0, "frame": 0, "facing": facing,
			"swim": rescue.victim_swim, "distress": rescue.phase == "swim_out"}
		items.append({"kind": "actor", "tag": "rescue_volunteer", "depth": rescue.victim.y,
			"bounds": Rect2(rescue.victim - Vector2(10, 23), Vector2(20, 27)), "actor": volunteer})
	var float_point: Vector2 = rescue.victim + Vector2(0, -1)
	items.append(_effect("rescue_float", float_point, rescue.victim.y + 0.1, Vector2(12, 6)))


func _effect(tag: String, point: Vector2, depth: float, extent := Vector2(6, 6)) -> Dictionary:
	return {"kind": "effect", "tag": tag, "depth": depth, "point": point,
		"bounds": Rect2(point - extent * 0.5, extent)}


func _table_plate(sprite: Dictionary, furnishings: Array[Dictionary]) -> Dictionary:
	var point: Vector2 = sprite.plate
	var table: Dictionary = dining_tables.get(sprite.get("table_id", -1), {})
	var center: Vector2 = table.get("table_center", point + Vector2(0, 3))
	var contact := _surface_depth(furnishings, "dining_table", sprite.table_id, point, center.y)
	return _effect("dining_plate", point, contact + 0.05, Vector2(8, 6))


func _surface_depth(parts: Array[Dictionary], tag: String, asset_id: int, at: Vector2, fallback: float) -> float:
	for item in parts:
		if item.tag == tag and (asset_id < 0 or item.get("asset_id", -1) == asset_id):
			if item.bounds.grow(1.0).has_point(at):
				fallback = maxf(fallback, item.depth)
	return fallback


func _append_contact_actions(items: Array[Dictionary], sprite: Dictionary, furnishings: Array[Dictionary]) -> void:
	var foot: Vector2 = sprite.point.round()
	var ground: Vector2 = sprite.get("ground", foot)
	var actor_depth := ground.y
	var child: bool = sprite.row == 4
	var facing := 1.0 if sprite.facing else -1.0
	match sprite.get("meal", ""):
		"seated":
			var reach := _meal_reach(sprite, foot, facing, child)
			var table_depth := _surface_depth(furnishings, "dining_table", sprite.table_id, reach.hand, actor_depth)
			sprite.defer_meal = true
			var arms := _effect("meal_contact", reach.hand, lerpf(table_depth, actor_depth, reach.lift) + 0.07, Vector2(24, 20))
			arms.actor = sprite
			items.append(arms)
		"collecting":
			var plate: Vector2 = sprite.plate
			if plate.is_finite():
				var reach := _collection_reach(sprite, foot, facing, child)
				var counter_depth := _surface_depth(furnishings, "furniture_counter", -1, reach.point, actor_depth)
				sprite.defer_meal = true
				var serving := _effect("meal_contact", reach.point, lerpf(counter_depth, actor_depth, reach.progress) + 0.07, Vector2(10, 7))
				serving.actor = sprite
				items.append(serving)
	var action: String = sprite.get("facility_action", "")
	if action in ["cafe_sit", "collect", "arcade"]:
		var target: Vector2 = sprite.facility_target
		var support: Vector2 = sprite.facility_target_ground
		var parts := landscape_renderer.depth_items()
		var tag: String = {"cafe_sit": "cafe_table", "collect": "cafe_counter", "arcade": "arcade_cabinet"}[action]
		var contact := _surface_depth(parts, tag, sprite.amenity_id, target, support.y)
		sprite.defer_facility = true
		var hands := _effect("facility_contact", target, maxf(actor_depth, contact) + 0.07, Vector2(26, 24))
		hands.actor = sprite
		items.append(hands)
		if action == "cafe_sit":
			items.append(_effect("cafe_snack", target, contact + 0.05, Vector2(7, 7)))


func _append_climbing_rope(items: Array[Dictionary], sprite: Dictionary) -> void:
	var foot: Vector2 = sprite.point.round()
	var ground: Vector2 = sprite.ground
	var facing := 1.0 if sprite.facing else -1.0
	var from := foot + (Vector2(-facing, -3) if sprite.facility_action == "climb" else Vector2(4 * facing, -7))
	var to: Vector2 = sprite.facility_target
	var target_ground: Vector2 = sprite.facility_target_ground
	var steps := maxi(1, ceili(from.distance_to(to)))
	for step in range(steps + 1):
		var progress := float(step) / float(steps)
		var pixel := from.lerp(to, progress).round()
		var contact := lerpf(ground.y, target_ground.y, progress)
		items.append({"kind": "effect", "tag": "climbing_rope", "depth": contact + 0.04,
			"point": pixel, "bounds": Rect2(pixel, Vector2.ONE), "actor": sprite})


func _draw_depth_item(item: Dictionary) -> void:
	match item.kind:
		"lifeguard_post":
			LifeguardArt.post(_actor_block, item.point, item.facing)
		"lifeguard":
			LifeguardArt.guard(_actor_block, item.point, item.seated, item.swim, item.facing, time)
		"asset":
			_actor_texture(item.texture, item.position)
		"prop":
			_actor_flag(item.prop)
		"actor":
			_draw_actor(item.actor)
		"effect":
			match item.tag:
				"rescue_float": LifeguardArt.rescue_float(_actor_block, item.point)
				"dining_plate": _draw_plate(item.point, true)
				"climbing_rope": _actor_block(item.bounds, ROPE)
				"basketball_ball": FacilityActivity.draw_basketball_ball(_actor_block, item.point)
				"volleyball_ball": _draw_volleyball_ball(item.point)
				"stage_lights": _draw_stage_light(item.point, item.lamp)
				"stage_performer": _draw_stage_show(item.amenity)
				"club_lights": FacilityActivity.draw_club_light(_actor_block, item.amenity, 1.0 - daylight, time, item.lamp)
				"meal_contact": _draw_contact(item.actor, true)
				"facility_contact": _draw_contact(item.actor, false)
				"cafe_snack": FacilityActivity.draw_cafe_snack(_actor_block, item.point)


func _draw_contact(actor: Dictionary, meal: bool) -> void:
	var foot: Vector2 = actor.point.round()
	var facing := 1.0 if actor.facing else -1.0
	var child: bool = actor.row == 4
	if meal:
		_draw_meal_action(actor, foot, facing, child, GUEST_SKIN[actor.row])
	else:
		FacilityActivity.draw_action(_actor_block, actor, foot, facing, child, GUEST_SKIN[actor.row], time)


func _guest_sprite(family: Dictionary, pose: Dictionary, child: bool) -> Dictionary:
	var frame: int = pose.frame
	var point: Vector2 = pose.get("child_draw", pose.child) if child else pose.get("adult_draw", pose.point)
	return {
		"point": point,
		"row": 4 if child else family.id % 3,
		"frame": (frame + 1) % 4 if child and frame > 0 else frame,
		"facing": pose.get("child_facing", pose.facing) if child else pose.facing,
		"swim": pose.get("child_swim", pose.swim) if child else pose.swim,
		"ground": pose.get("child_ground" if child else "ground", point),
		"distress": pose.get("child_distress", pose.get("distress", false)) if child else pose.get("distress", false),
		"meal": pose.get("meal", ""),
		"plate": pose.get("child_plate" if child else "adult_plate", Vector2.INF),
		"meal_age": time - float(family.since),
		"family_id": family.id,
		"table_id": family.get("table_id", -1),
		"amenity_id": family.get("amenity_id", -1),
		"leisure": pose.get("leisure", ""),
		"leisure_age": time - float(family.since),
		"leisure_slot": family.get("leisure_slot", -1),
		"facility_action": pose.get("child_action" if child else "adult_action", ""),
		"facility_target": pose.get("child_target" if child else "adult_target", Vector2.ZERO),
		"facility_target_ground": pose.get("child_target_ground" if child else "adult_target_ground", point),
		"drink_source": pose.get("child_pickup" if child else "adult_pickup", Vector2.INF),
	}


func actor_visible(world_foot: Vector2) -> bool:
	return not viewing_draft and not renderer.is_interior_hidden(world_foot)


func _draw_actor(actor: Dictionary) -> void:
	var foot: Vector2 = actor.point.round()
	var swim: bool = actor.get("swim", false)
	var row: int = actor.row
	var meal: String = actor.get("meal", "")
	var seated := meal == "seated"
	var leisure: String = actor.get("leisure", "")
	var facility_action: String = actor.get("facility_action", "")
	var resting := leisure in ["beach_lounge", "stage"] or FacilityActivity.is_seated(facility_action)
	var child := row == 4
	var booster := SeatedArt.CHILD_BOOSTER if seated and child else 0.0
	var facing := 1.0 if actor.facing else -1.0
	if swim:
		foot.y += roundf(sin(time * 5.0 + foot.x) * 1.5)
		_actor_block(Rect2(foot - Vector2(7, 1), Vector2(14, 2)), Color("#b2f2e6"))
	else:
		var ground: Vector2 = actor.get("ground", foot)
		_actor_block(Rect2(ground.round() - Vector2(5, 1), Vector2(10, 2)), Color(0.16, 0.10, 0.19, 0.20))
	if seated:
		_draw_chair(foot, facing, child)
	if (seated or resting) and not swim:
		_draw_bent_legs(foot, facing, child, GUEST_PANTS[row], booster)
	if people:
		if row == 4 and people.get_height() < 120:
			row = 0
		var frame_origin := Vector2(actor.frame * 20, row * 24)
		var source := Rect2(frame_origin, Vector2(20, 24))
		var destination := Rect2(foot - Vector2(10, 22), Vector2(20, 24))
		if swim:
			source.position.y += 6 if row == 4 else 0
			source.size.y = 12
			destination = Rect2(foot - Vector2(10, 11), Vector2(20, 12))
		elif seated or resting:
			source = SeatedArt.source(row, child)
			destination = SeatedArt.upper_body(foot, child, booster)
		if not actor.facing:
			# Godot mirrors negative texture widths in place; keep the body anchor.
			destination.size.x *= -1.0
		_actor_region(destination, source)
	else:
		var height := 8 if child else 12
		var outfit := [Color("#dc7954"), Color("#f5ca68"), Color("#759cbd"), Color("#ede3c9"), Color("#bd6a8b")]
		_actor_block(Rect2(foot - Vector2(3, height), Vector2(6, height)), OUTLINE)
		_actor_block(Rect2(foot - Vector2(2, height - 4), Vector2(4, height - 6)), outfit[row])
		_actor_block(Rect2(foot - Vector2(2, height), Vector2(4, 4)), GUEST_SKIN[row])
	if not meal.is_empty() and not actor.get("defer_meal", false):
		_draw_meal_action(actor, foot, facing, child, GUEST_SKIN[actor.row])
	if not leisure.is_empty():
		_draw_leisure_action(actor, foot, facing, child)
	if not facility_action.is_empty() and not actor.get("defer_facility", false):
		FacilityActivity.draw_action(_actor_block, actor, foot, facing, child, GUEST_SKIN[actor.row], time)
	if actor.get("distress", false):
		_draw_rescue_marker(foot, swim)


func _draw_chair(foot: Vector2, facing: float, child: bool) -> void:
	var back := foot + Vector2(-facing * 5.0, -10 if child else -12)
	_actor_block(Rect2(back - Vector2(1, 0), Vector2(3, 7 if child else 9)), OUTLINE)
	_actor_block(Rect2(back, Vector2(1, 6 if child else 8)), CHAIR_LIGHT)
	_actor_block(Rect2(back.x - 1, foot.y - 4, 3, 6), CHAIR_WOOD)
	_actor_block(Rect2(foot - Vector2(4, 4), Vector2(8, 3)), CHAIR_WOOD)
	_actor_block(Rect2(foot - Vector2(4, 4), Vector2(8, 1)), CHAIR_LIGHT)
	if child:
		_actor_block(Rect2(foot - Vector2(3, 4 + SeatedArt.CHILD_BOOSTER), Vector2(7, 2)), Color("#b9745d"))
		_actor_block(Rect2(foot - Vector2(3, 4 + SeatedArt.CHILD_BOOSTER), Vector2(7, 1)), CHAIR_LIGHT)
	_actor_block(Rect2(foot + Vector2(facing * 3 - 1, -1), Vector2(2, 3)), CHAIR_WOOD)


func _draw_bent_legs(foot: Vector2, facing: float, child: bool, pants: Color, booster: float) -> void:
	var knee := foot + Vector2(facing * (3 if child else 4), (-2.0 if child else -3.0) - booster)
	var left := minf(foot.x - 2.0, knee.x - 1.0)
	var right := maxf(foot.x + 2.0, knee.x + 2.0)
	_actor_block(Rect2(left, knee.y - 1, right - left, 3), pants.darkened(0.22))
	_actor_block(Rect2(left + 1, knee.y - 1, right - left - 2, 2), pants)
	_actor_block(Rect2(knee + Vector2(-1, 0), Vector2(2, -knee.y + foot.y)), pants)
	_actor_block(Rect2(knee.x - 1 if facing > 0 else knee.x - 2, foot.y, 4, 1), OUTLINE)


func _draw_plate(at: Vector2, has_food: bool) -> void:
	var center := at.round()
	_actor_block(Rect2(center - Vector2(3, 1), Vector2(7, 3)), PLATE_EDGE)
	_actor_block(Rect2(center - Vector2(2, 2), Vector2(5, 3)), PLATE_RIM)
	if has_food:
		_actor_block(Rect2(center - Vector2(1, 1), Vector2(2, 1)), FOOD)
		_actor_block(Rect2(center + Vector2(1, 0), Vector2.ONE), GARNISH)


func _meal_reach(actor: Dictionary, foot: Vector2, facing: float, child: bool) -> Dictionary:
	var plate: Vector2 = actor.plate
	var bite := fposmod(float(actor.meal_age) + (0.5 if child else 0.0), 1.8)
	var booster := SeatedArt.CHILD_BOOSTER if child else 0.0
	var shoulder := SeatedArt.shoulder(foot, facing, child, booster)
	var mouth := SeatedArt.mouth(foot, facing, child, booster) + Vector2(facing, 1)
	var reach := shoulder + (plate - shoulder).limit_length(9.0 if child else 12.0)
	var lift := clampf(1.0 - absf(bite - 0.8) / 0.55, 0.0, 1.0)
	return {"shoulder": shoulder, "hand": reach.lerp(mouth, lift).round(), "lift": lift}


func _collection_reach(actor: Dictionary, foot: Vector2, facing: float, child: bool) -> Dictionary:
	var hand := foot + Vector2(facing * 5.0, -5 if child else -7)
	var plate: Vector2 = actor.plate
	var scoop := clampf((float(actor.meal_age) - 2.0) / 2.0, 0.0, 1.0)
	var pickup := plate + (hand - plate).normalized() * 3.0
	return {"point": pickup.lerp(hand, scoop).round(), "progress": scoop}


func _draw_meal_action(actor: Dictionary, foot: Vector2, facing: float, child: bool, skin: Color) -> void:
	if actor.meal == "seated":
		var reach := _meal_reach(actor, foot, facing, child)
		var hand: Vector2 = reach.hand
		var shoulder: Vector2 = reach.shoulder
		var steps := maxi(1, ceili(shoulder.distance_to(hand)))
		for step in range(steps + 1):
			var arm := shoulder.lerp(hand, float(step) / steps).round()
			_actor_block(Rect2(arm, Vector2(2, 1)), skin)
		_actor_block(Rect2(hand - Vector2(1, 0), Vector2(2, 2)), skin)
		_actor_block(Rect2(hand + Vector2(facing, -1), Vector2.ONE), FOOD if reach.lift > 0.25 else PLATE_RIM)
	elif actor.meal == "collecting" and actor.plate.is_finite() and actor_visible(actor.plate):
		var reach := _collection_reach(actor, foot, facing, child)
		var carrying: Vector2 = reach.point
		_draw_plate(carrying, reach.progress > 0.25)
		_actor_block(Rect2(carrying + Vector2(-1, 2), Vector2(3, 1)), skin)
	elif actor.meal == "carrying":
		var hand := foot + Vector2(facing * 5.0, -5 if child else -7)
		_draw_plate(hand, true)
		_actor_block(Rect2(hand + Vector2(-1, 2), Vector2(3, 1)), skin)


func _draw_leisure_action(actor: Dictionary, foot: Vector2, facing: float, child: bool) -> void:
	var skin: Color = GUEST_SKIN[actor.row]
	var age: float = actor.leisure_age
	match actor.leisure:
		"volleyball":
			var ready := -maxf(0.0, sin(time * TAU * 0.6 + actor.leisure_slot)) * 7.0
			var reach := Vector2(facing * 4, (-5 if child else -7) + roundf(ready))
			var elbow := foot + Vector2(facing * 3, -5 if child else -8)
			var hand := foot + reach
			_actor_block(Rect2(elbow - Vector2.ONE, Vector2(3, 3)), OUTLINE)
			_actor_block(Rect2(Vector2(hand.x - 1, minf(hand.y, elbow.y)), Vector2(2, absf(hand.y - elbow.y) + 2)), skin)
			_actor_block(Rect2(hand - Vector2(1, 0), Vector2(3, 2)), skin)
		"beach_bar":
			var sip := roundf(3.0 * maxf(0.0, sin((age + (0.7 if child else 0.0)) * 2.2)))
			var hand := foot + Vector2(facing * 5, (-5 if child else -7) - sip)
			var pickup: Vector2 = actor.drink_source
			if pickup.is_finite():
				hand = pickup.lerp(hand, clampf(age / 0.75, 0.0, 1.0)).round()
			_actor_block(Rect2(hand + Vector2(-2, 0), Vector2(4, 2)), skin)
			_actor_block(Rect2(hand + Vector2(-2, -4), Vector2(4, 5)), OUTLINE)
			_actor_block(Rect2(hand + Vector2(-1, -3), Vector2(2, 3)), DRINK_CUP)
			_actor_block(Rect2(hand + Vector2(facing, -5), Vector2.ONE), FOOD)
			_actor_block(Rect2(hand + Vector2(-2, -4), Vector2(4, 1)), PLATE_RIM)
		"stage":
			var clap := 1 if sin(age * 10.0 + actor.leisure_slot) > 0.0 else 0
			var hand := SeatedArt.shoulder(foot, facing, child) + Vector2(facing * clap, -1)
			_actor_block(Rect2(hand - Vector2.ONE, Vector2(3, 2)), skin)
			_actor_block(Rect2(hand + Vector2(facing * 2, 0), Vector2.ONE), skin)


func _volleyball_effect(amenity: Dictionary) -> Dictionary:
	var arc := fposmod(time * 0.68, 2.0)
	var flight := 1.0 - absf(arc - 1.0)
	var ground := AmenityArt.at(amenity, Vector2(lerpf(21.0, 59.0, flight), lerpf(19.0, 38.0, flight))).round()
	var ball := ground - Vector2(0, 12 + roundf(sin(flight * PI) * 9.0))
	return _effect("volleyball_ball", ball, ground.y)


func _draw_volleyball_ball(ball: Vector2) -> void:
	_actor_block(Rect2(ball - Vector2(2, 1), Vector2(5, 3)), OUTLINE)
	_actor_block(Rect2(ball - Vector2(1, 2), Vector2(3, 5)), OUTLINE)
	_actor_block(Rect2(ball - Vector2(1, 1), Vector2(3, 3)), BEACH_BALL)
	_actor_block(Rect2(ball - Vector2(1, 1), Vector2(2, 1)), PLATE_RIM)


func _draw_stage_light(lamp: Vector2, index: int) -> void:
	var color := SHOW_LAMP if index == 0 else Color("#ffcf9a")
	_actor_block(Rect2(lamp, Vector2(3, 2)), color)
	for stripe in range(3):
		var glow := Color(color, (0.13 - stripe * 0.025) * (1.0 - daylight * 0.6))
		_actor_block(Rect2(lamp + Vector2(-stripe, 2 + stripe * 4), Vector2(3 + stripe * 2, 4)), glow)


func _draw_stage_show(amenity: Dictionary) -> void:
	var beat := int(time * 5.0)
	var foot := AmenityArt.at(amenity, Vector2(32, 14)).round()
	foot.y -= 3
	var move := posmod(beat, 4) - 1
	foot.x += move
	_actor_block(Rect2(foot + Vector2(-6, -1), Vector2(12, 2)), Color("#48374756"))
	_draw_actor({"point": foot, "row": 3, "frame": posmod(beat, 4), "facing": true})
	var mic := foot + Vector2(6, -10 - (1 if beat % 2 == 0 else 0))
	_actor_block(Rect2(mic + Vector2(-3, 2), Vector2(3, 2)), GUEST_SKIN[3])
	_actor_block(Rect2(mic + Vector2(0, 1), Vector2(1, 4)), OUTLINE)
	_actor_block(Rect2(mic - Vector2(1, 0), Vector2(3, 2)), DRINK_CUP)
	var note := foot + Vector2(10 + beat % 2 * 2, -18 - beat % 3)
	_actor_block(Rect2(note, Vector2(1, 5)), SHOW_LAMP)
	_actor_block(Rect2(note - Vector2(2, -4), Vector2(3, 2)), SHOW_LAMP)
	_actor_block(Rect2(note, Vector2(3, 1)), SHOW_LAMP)


func _draw_rescue_marker(foot: Vector2, wet: bool) -> void:
	if wet:
		_actor_block(Rect2(foot + Vector2(-5, -2), Vector2(11, 2)), RESCUE_ORANGE)
		_actor_block(Rect2(foot + Vector2(-3, -2), Vector2(2, 2)), PLATE_RIM)
		_actor_block(Rect2(foot + Vector2(3, -2), Vector2(2, 2)), PLATE_RIM)
	var icon := foot - Vector2(3, 23)
	_actor_block(Rect2(icon, Vector2(7, 9)), OUTLINE)
	_actor_block(Rect2(icon + Vector2(1, 1), Vector2(5, 7)), RESCUE_ORANGE)
	_actor_block(Rect2(icon + Vector2(3, 2), Vector2(1, 3)), OUTLINE)
	_actor_block(Rect2(icon + Vector2(3, 6), Vector2.ONE), OUTLINE)


func _actor_block(rect: Rect2, color: Color) -> void:
	actors.draw_rect(rect, color)


func _actor_texture(texture: Texture2D, at: Vector2) -> void:
	actors.draw_texture(texture, at)


func _actor_flag(prop: Dictionary) -> void:
	ocean.draw_flag(actors, prop)


func _actor_region(destination: Rect2, source: Rect2) -> void:
	actors.draw_texture_rect_region(people, destination, source)


func _pose(family: Dictionary) -> Dictionary:
	if not simulation.rescue.is_empty() and simulation.rescue.family == family.id:
		var rescue: Dictionary = simulation.rescue_positions(time)
		return {"point": rescue.victim, "child": rescue.child, "frame": 0,
			"facing": rescue.guard.x >= rescue.victim.x, "swim": rescue.victim_swim,
			"child_swim": rescue.child_swim, "distress": rescue.phase == "swim_out", "child_distress": false}
	if family.phase in Sim.OCEAN_PHASES and not ocean_access.is_empty():
		return _ocean_pose(family)
	var meal := _meal_pose(family)
	if not meal.is_empty():
		return meal
	if family.phase in Sim.LEISURE_PHASES:
		var leisure := _leisure_pose(family)
		if not leisure.is_empty():
			return leisure
	var room := room_points[maxi(family.room, 0)]
	var reception := station_points[0]
	var buffet := station_points[1]
	var pool := station_points[2]
	var path := PackedVector2Array()
	var point := room
	var duration := 4.0
	var age := time - float(family.since)
	match family.phase:
		"queue":
			var queue_stagger := 0
			for other in simulation.families:
				if other.phase == "queue" and other.station == family.station and other.id < family.id:
					queue_stagger += 1
			point = _approach(family.station, 3 + queue_stagger)
			var queue_origin: Vector2 = Layout.ENTRY if family.station == 0 else station_points[family.station]
			path = visible_layout.route(queue_origin, point)
			duration = 2.0
		"service":
			point = station_points[family.station]
			if family.station == 2 and age >= 2.0 and family.until - time > 2.0:
				return _swim_pose(family)
			var origin := _approach(family.station, 3)
			if family.waits[family.station] == 0:
				origin = Layout.ENTRY if family.station == 0 else point
			path = visible_layout.route(origin, point)
			duration = 2.0
		"to_room":
			path = visible_layout.route(reception, room)
		"to_buffet":
			path = visible_layout.route(room, buffet)
		"to_pool":
			path = visible_layout.route(buffet, pool)
		"return_room":
			path = visible_layout.route(pool, room)
		"to_checkout":
			path = visible_layout.route(room, reception)
		"exit":
			path = visible_layout.route(reception, Layout.ENTRY)
	if path.is_empty():
		path = visible_layout.route(Layout.ENTRY, point)
		age = duration
	if path.is_empty():
		return {"point": point, "child": point, "frame": 0, "facing": true, "swim": false}
	var progress := clampf(age / duration, 0.0, 1.0)
	var result := _follow_path(path, progress)
	result.child = _follow_path(path, progress, 8.0).point
	result.frame = int(maxf(age, 0.0) * 7.0) % 4 if progress < 1.0 else 0
	result.swim = false
	return result


func _ocean_pose(family: Dictionary) -> Dictionary:
	var shore: Vector2 = ocean_access.shore
	var lane := posmod(int(family.id), 4)
	var water: Vector2 = ocean_access.water + Vector2(lane * 3, [0, -12, 12, 20][lane])
	var room := room_points[family.room]
	var age := maxf(0.0, time - float(family.since))
	var evacuating: bool = family.phase == "evacuate"
	if family.phase == "to_ocean":
		return _meal_walk(room, room, shore, shore, age, Sim.OCEAN_WALK_DURATION)
	if family.phase == "ocean_swim":
		return _wade_pose(shore, water, clampf(age / Sim.OCEAN_WADE_DURATION, 0.0, 1.0), false,
			family.ocean_red_seconds > 0, false)
	var wet: bool = family.ocean_return_wet
	var wade_time := float(Sim.OCEAN_WADE_DURATION) if wet else 0.0
	if wet and age < wade_time:
		return _wade_pose(shore, water, 1.0 - age / wade_time, true, evacuating, family.ocean_fatality)
	var target := Layout.ENTRY if evacuating else room
	var pose := _meal_walk(shore, shore, target, target, age - wade_time, Sim.OCEAN_WALK_DURATION)
	pose.child_only = family.ocean_fatality
	pose.distress = evacuating
	return pose


func _wade_pose(shore: Vector2, water: Vector2, progress: float, returning: bool,
		distress: bool, child_only: bool) -> Dictionary:
	var adult := shore.lerp(ocean.offshore(water), progress)
	var child := shore.lerp(ocean.offshore(water + Vector2(-7, 8)), progress)
	return {
		"point": adult, "child": child, "facing": not returning, "frame": int(time * 7.0) % 4,
		"swim": visible_layout.landscape.is_water_pixel(adult),
		"child_swim": visible_layout.landscape.is_water_pixel(child),
		"distress": distress, "child_only": child_only,
	}


func _leisure_pose(family: Dictionary) -> Dictionary:
	var amenity: Dictionary = amenities.get(family.amenity_id, {})
	if amenity.is_empty():
		return {}
	var slot: int = family.leisure_slot
	var new_facility: bool = amenity.kind in FacilityArt.KINDS
	var duration := maxf(1.0, float(family.until - family.since))
	var age := maxf(0.0, time - float(family.since))
	var progress := clampf(age / duration, 0.0, 1.0)
	if family.phase == "leisure":
		if new_facility:
			return FacilityActivity.pose(amenity, slot, progress, age)
		return _amenity_pose(amenity, slot)
	var activity := _amenity_handoff(amenity, slot)
	var room := room_points[maxi(family.room, 0)]
	var origin := station_points[2]
	var target: Vector2 = amenity.point
	var departure := {}
	var arrival := activity
	if family.phase == "from_leisure":
		origin = amenity.point
		target = room
		departure = activity
		arrival = {}
	elif family.leisure_step == 3:
		origin = room
	elif amenities.has(family.leisure_origin_id):
		var previous: Dictionary = amenities[family.leisure_origin_id]
		origin = previous.point
		departure = _amenity_handoff(previous, family.get("leisure_origin_slot", 0))
	var path := visible_layout.route(origin, target)
	if path.is_empty():
		return {}
	var adult_path := path.duplicate()
	var child_path := path.duplicate()
	if not departure.is_empty():
		if departure.has("gate"):
			adult_path.insert(0, departure.gate)
			child_path.insert(0, departure.gate)
		adult_path.insert(0, departure.point)
		child_path.insert(0, departure.child)
	if not arrival.is_empty():
		if arrival.has("gate"):
			adult_path.append(arrival.gate)
			child_path.append(arrival.gate)
		adult_path.append(arrival.point)
		child_path.append(arrival.child)
	var adult := _follow_path(adult_path, progress)
	var child := _follow_path(child_path, progress - sin(PI * progress) * 0.035)
	return {
		"point": adult.point, "child": child.point, "facing": adult.facing, "child_facing": child.facing,
		"frame": int(maxf(0.0, time - family.since) * 7.0) % 4 if progress < 1.0 else 0, "swim": false,
	}


func _amenity_handoff(amenity: Dictionary, slot: int) -> Dictionary:
	if amenity.kind in FacilityArt.KINDS:
		return FacilityActivity.entrance(amenity, slot)
	return _amenity_pose(amenity, slot)


func _amenity_pose(amenity: Dictionary, slot: int) -> Dictionary:
	slot = clampi(slot, 0, amenity.capacity - 1)
	var adult_local := Vector2.ZERO
	var child_local := Vector2.ZERO
	var focus_local := Vector2.ZERO
	match amenity.kind:
		"beach_lounge":
			var reverse: bool = amenity.rotation == 3
			adult_local = Vector2(23 if reverse else 8, 5 + slot * 16)
			child_local = Vector2(8 if reverse else 23, 5 + slot * 16)
			focus_local = Vector2(28, 9 + slot * 12)
		"volleyball":
			adult_local = Vector2(23, 25 + slot * 18)
			child_local = Vector2(58, 22 + slot * 18)
			focus_local = Vector2(40, 29)
		"beach_bar":
			adult_local = Vector2(9 + slot * 23, 28)
			child_local = Vector2(20 + slot * 23, 30)
			focus_local = Vector2(24, 15)
		"stage":
			var back_row: bool = amenity.rotation != 2
			adult_local = Vector2(8 + slot * 16, 26 if back_row else 39)
			child_local = Vector2(8 + slot * 16, 39 if back_row else 26)
			focus_local = Vector2(32, 14)
	var adult := AmenityArt.at(amenity, adult_local)
	var child := AmenityArt.at(amenity, child_local)
	var focus := AmenityArt.at(amenity, focus_local)
	var pose := {
		"point": adult, "child": child, "facing": focus.x >= adult.x, "child_facing": focus.x >= child.x,
		"frame": 0, "swim": false, "leisure": amenity.kind,
	}
	if amenity.kind == "beach_bar":
		pose.adult_pickup = AmenityArt.at(amenity, Vector2(adult_local.x, 17)) - Vector2(0, 3)
		pose.child_pickup = AmenityArt.at(amenity, Vector2(child_local.x, 17)) - Vector2(0, 3)
	return pose


func _meal_pose(family: Dictionary) -> Dictionary:
	var age := time - float(family.since)
	var table: Dictionary = dining_tables.get(family.get("table_id", -1), {})
	match family.phase:
		"service":
			if family.station == 1 and not counter_points.is_empty():
				return _collecting_pose(family, age)
		"wait_table":
			return _waiting_pose(family.id, age)
		"to_table":
			if not table.is_empty():
				var origin := _waiting_pose(family.id, float(family.dining_wait))
				var walking := _meal_walk(origin.point, origin.child, table.seat, table.child, age,
					Sim.TABLE_WALK_DURATION, "carrying")
				_blend_to_seats(walking, table, smoothstep(Sim.TABLE_WALK_DURATION - 0.4, Sim.TABLE_WALK_DURATION, age))
				return walking
		"eating":
			if not table.is_empty():
				return {
					"point": table.seat, "child": table.child, "frame": 0, "swim": false,
					"adult_draw": table.adult_sit, "child_draw": table.child_sit,
					"facing": table.adult_plate.x >= table.adult_sit.x, "child_facing": table.child_plate.x >= table.child_sit.x,
					"meal": "seated", "adult_plate": table.adult_plate, "child_plate": table.child_plate,
				}
		"to_pool":
			if not table.is_empty():
				var pool := station_points[2]
				var leaving := _meal_walk(table.seat, table.child, pool, pool, age, float(family.until - family.since))
				_blend_to_seats(leaving, table, 1.0 - smoothstep(0.0, 0.4, age))
				return leaving
	return {}


func _blend_to_seats(pose: Dictionary, table: Dictionary, weight: float) -> void:
	if weight > 0.0:
		pose.adult_draw = pose.point.lerp(table.adult_sit, weight)
		pose.child_draw = pose.child.lerp(table.child_sit, weight)


func _collecting_pose(family: Dictionary, age: float) -> Dictionary:
	var pair := _counter_pair(family.id)
	var origin: Vector2 = pair[0] if family.waits[1] == 0 else _approach(1, 3)
	var child_origin: Vector2 = pair[1] if family.waits[1] == 0 else _approach(1, 4)
	var pose := _meal_walk(origin, child_origin, pair[0], pair[1], age, 2.0)
	if age >= 2.0 and not counter_trays.is_empty():
		pose.meal = "collecting"
		pose.adult_plate = _nearest_tray(pose.point)
		pose.child_plate = _nearest_tray(pose.child)
		pose.facing = pose.adult_plate.x >= pose.point.x
		pose.child_facing = pose.child_plate.x >= pose.child.x
	return pose


func _counter_pair(family_id: int) -> Array[Vector2]:
	var first := (family_id % 2) * 2 if counter_points.size() >= 4 else 0
	return [counter_points[first], counter_points[first + 1]]


func _nearest_tray(point: Vector2) -> Vector2:
	var nearest := counter_trays[0]
	for tray in counter_trays:
		if tray.distance_squared_to(point) < nearest.distance_squared_to(point):
			nearest = tray
	return nearest


func _waiting_pose(family_id: int, age: float) -> Dictionary:
	var pair := _counter_pair(family_id)
	if table_wait_points.size() < 2:
		return _meal_walk(pair[0], pair[1], _approach(1, 1), _approach(1, 2), age, 1.0, "carrying")
	var first := (family_id * 2) % table_wait_points.size()
	var second := (first + 1) % table_wait_points.size()
	return _meal_walk(pair[0], pair[1], table_wait_points[first], table_wait_points[second], age, 1.0, "carrying")


func _meal_walk(from: Vector2, child_from: Vector2, to: Vector2, child_to: Vector2, age: float,
		duration: float, action: String = "") -> Dictionary:
	var progress := clampf(age / duration, 0.0, 1.0)
	var adult_path := visible_layout.route(from, to)
	var child_path := visible_layout.route(child_from, child_to)
	var adult := _follow_path(adult_path, progress) if not adult_path.is_empty() else {"point": from, "facing": true}
	var child := _follow_path(child_path, progress) if not child_path.is_empty() else {"point": child_from, "facing": true}
	var walking := progress < 1.0 and maxi(adult_path.size(), child_path.size()) > 1
	return {
		"point": adult.point, "child": child.point, "facing": adult.facing, "child_facing": child.facing,
		"frame": int(maxf(age, 0.0) * 7.0) % 4 if walking else 0, "swim": false, "meal": action,
	}


func _approach(station: int, steps: int) -> Vector2:
	var path := station_approaches[station]
	return path[maxi(0, path.size() - 1 - steps)] if not path.is_empty() else Layout.ENTRY


func _swim_pose(family: Dictionary) -> Dictionary:
	var size := pool_water.size if pool_turn % 2 == 0 else Vector2(pool_water.size.y, pool_water.size.x)
	var x := 10.0 + (size.x - 20.0) * (float(family.slot) + 1.0) / 4.0
	var local := Vector2(x + sin(time * 1.4 + family.id) * 3.0, size.y * 0.5)
	var point := AmenityArt.ground_point(pool_water.position, size, pool_turn, local)
	var child := AmenityArt.ground_point(pool_water.position, size, pool_turn, local + Vector2(-6, 4))
	return {"point": point, "child": child, "facing": true, "frame": 0, "swim": true}


func _follow_path(points: PackedVector2Array, progress: float, lag: float = 0.0) -> Dictionary:
	var length := 0.0
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])
	var remaining := maxf(0.0, length * progress - lag)
	for i in range(1, points.size()):
		var start := points[i - 1]
		var finish := points[i]
		var segment := start.distance_to(finish)
		if segment <= 0.0:
			continue
		if remaining <= segment:
			return {"point": start.lerp(finish, remaining / segment), "facing": finish.x >= start.x}
		remaining -= segment
	return {"point": points[points.size() - 1], "facing": true}
