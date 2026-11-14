extends Node2D

const Ocean = preload("res://scripts/ocean.gd")
const Sim = preload("res://scripts/simulation.gd")
const Layout = preload("res://scripts/layout_model.gd")
const BuildingRenderer = preload("res://scripts/building_renderer.gd")
const LandscapeRenderer = preload("res://scripts/landscape_renderer.gd")
const AmenityArt := preload("res://scripts/amenity_renderer.gd")
const WORLD_BOUNDS := Layout.WORLD_BOUNDS
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
const GUEST_SKIN := [Color("#d5936c"), Color("#a86d53"), Color("#ebaa7c"), Color("#bb7d5e"), Color("#c38363")]
const BEACH_BALL := Color("#ed924d")
const DRINK_CUP := Color("#96e2db")
const SHOW_LAMP := Color("#ffec9a")
const SHOW_DUSK := Color("#40395538")

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
var label_font: Font


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base_art = load(BASE_PATH) as Texture2D
	people = load(PEOPLE_PATH) as Texture2D
	landscape_renderer = LandscapeRenderer.new()
	landscape_renderer.name = "Landscape"
	add_child(landscape_renderer)
	ocean = Ocean.new()
	ocean.name = "Ocean"
	add_child(ocean)
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
	var exterior := show_exteriors and not in_design
	var state_changed := simulation != resort or time != visual_time or viewing_draft != in_design or exterior_view != exterior
	simulation = resort
	time = visual_time
	viewing_draft = in_design
	exterior_view = exterior
	ceiling_id = inspect_ceiling_id if viewing_draft else -1
	renderer.set_view(exterior_view, ceiling_id)
	actors.visible = not viewing_draft
	signs.visible = not viewing_draft
	var landscape_time := float(simulation.day - 1) * Sim.DAY_LENGTH + time
	if landscape_changed:
		landscape_revision = layout.landscape.revision
		ocean.set_landscape(layout.landscape)
	landscape_renderer.present(layout.landscape, landscape_time)
	ocean.present(landscape_time)
	if changed:
		visible_layout = layout
		var buildings := layout.buildings.duplicate(true)
		var upgraded: bool = layout.readiness().terrace
		pool_water = Rect2()
		for building in buildings:
			if building.kind == "pool":
				building.upgraded = upgraded
				pool_water = layout.water_rect(building)
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
	var assets_by_id := {}
	var counter_bounds := Rect2()
	var buffet := layout.building_at(counter)
	var interior := layout.building_rect(buffet).grow(-Layout.GRID)
	for asset in layout.assets:
		assets_by_id[asset.id] = asset
		if asset.kind == "counter" and not counter_bounds.has_area() and asset.building_id == buffet.id:
			var bounds := layout.asset_rect(asset)
			if bounds.grow(5.0).has_point(counter):
				counter_bounds = bounds
				for offset in [Vector2(-10, -2), Vector2(-1, -2), Vector2(8, -2)]:
					counter_trays.append(bounds.get_center() + offset.rotated(asset.rotation * PI / 2.0).round())
	for table in layout.dining_tables():
		var axis := Vector2.RIGHT.rotated(assets_by_id[table.id].rotation * PI / 2.0).round()
		var top: Vector2 = table.table_center + axis * -1.0 + Vector2(-axis.y, axis.x) * -2.0
		var adult_side := -1.0 if axis.dot(table.child - table.seat) >= 0.0 else 1.0
		table.adult_plate = top + axis * 3.0 * adult_side
		table.child_plate = top - axis * 3.0 * adult_side
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
	if not simulation or visible_layout != simulation.layout or viewing_draft:
		return
	var sprites: Array[Dictionary] = []
	var in_use := {}
	for station in range(3):
		sprites.append({"point": _approach(station, 1), "row": 3, "frame": 0, "facing": true})
	sprites.append({"point": _approach(simulation.float_station, 2), "row": 3, "frame": 0, "facing": false})
	for family in simulation.families:
		if family.phase == "gone":
			continue
		var pose := _pose(family)
		sprites.append(_guest_sprite(family, pose, false))
		sprites.append(_guest_sprite(family, pose, true))
		if family.phase == "leisure" and amenities.has(family.amenity_id):
			in_use[family.amenity_id] = amenities[family.amenity_id]
	for amenity: Dictionary in in_use.values():
		if amenity.kind == "stage":
			_draw_stage_show(amenity)
	for sprite in sprites:
		if sprite.get("meal", "") == "seated" and actor_visible(sprite.point) and actor_visible(sprite.plate):
			_draw_plate(sprite.plate, true)
	sprites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.point.y < b.point.y)
	for sprite in sprites:
		if actor_visible(sprite.point):
			_draw_actor(sprite)
	for amenity: Dictionary in in_use.values():
		if amenity.kind == "volleyball":
			_draw_volleyball(amenity)


func _guest_sprite(family: Dictionary, pose: Dictionary, child: bool) -> Dictionary:
	var frame: int = pose.frame
	return {
		"point": pose.child if child else pose.point,
		"row": 4 if child else family.id % 3,
		"frame": (frame + 1) % 4 if child and frame > 0 else frame,
		"facing": pose.get("child_facing", pose.facing) if child else pose.facing,
		"swim": pose.swim,
		"meal": pose.get("meal", ""),
		"plate": pose.get("child_plate" if child else "adult_plate", Vector2.INF),
		"meal_age": time - float(family.since),
		"leisure": pose.get("leisure", ""),
		"leisure_age": time - float(family.since),
		"leisure_slot": family.get("leisure_slot", -1),
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
	var resting := leisure == "beach_lounge" or leisure == "stage"
	var child := row == 4
	var facing := 1.0 if actor.facing else -1.0
	if swim:
		foot.y += roundf(sin(time * 5.0 + foot.x) * 1.5)
		_actor_block(Rect2(foot - Vector2(7, 1), Vector2(14, 2)), Color("#b2f2e6"))
	else:
		_actor_block(Rect2(foot - Vector2(5, 1), Vector2(10, 2)), Color(0.16, 0.10, 0.19, 0.20))
	if seated:
		_draw_chair(foot, facing, child)
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
			# Tight source bounds keep the head and shirt readable at sitting height.
			var top := 7 if child else 1
			source.position += Vector2(5, top)
			source.size = Vector2(11, 12 if child else 16)
			destination = Rect2(foot - Vector2(5, 9 if child else 12), Vector2(11, 7 if child else 10))
		if not actor.facing:
			destination.position.x += destination.size.x
			destination.size.x *= -1.0
		_actor_region(destination, source)
	else:
		var height := 8 if child else 12
		var outfit := [Color("#dc7954"), Color("#f5ca68"), Color("#759cbd"), Color("#ede3c9"), Color("#bd6a8b")]
		_actor_block(Rect2(foot - Vector2(3, height), Vector2(6, height)), OUTLINE)
		_actor_block(Rect2(foot - Vector2(2, height - 4), Vector2(4, height - 6)), outfit[row])
		_actor_block(Rect2(foot - Vector2(2, height), Vector2(4, 4)), GUEST_SKIN[row])
	if not meal.is_empty():
		_draw_meal_action(actor, foot, facing, child, GUEST_SKIN[actor.row])
	if not leisure.is_empty():
		_draw_leisure_action(actor, foot, facing, child)


func _draw_chair(foot: Vector2, facing: float, child: bool) -> void:
	var back := foot + Vector2(-facing * 4.0, -5 if child else -7)
	_actor_block(Rect2(back - Vector2(1, 1), Vector2(3, 6 if child else 8)), OUTLINE)
	_actor_block(Rect2(back, Vector2(2, 4 if child else 5)), CHAIR_WOOD)
	_actor_block(Rect2(back, Vector2(2, 1)), Color("#e8b174"))
	_actor_block(Rect2(foot - Vector2(4, 2), Vector2(8, 2)), CHAIR_WOOD)
	_actor_block(Rect2(foot + Vector2(3 * facing - 2, -2), Vector2(5, 2)), Color("#616a83"))
	_actor_block(Rect2(foot + Vector2(4 * facing - 1, 0), Vector2(3, 1)), OUTLINE)


func _draw_plate(at: Vector2, has_food: bool) -> void:
	var center := at.round()
	_actor_block(Rect2(center - Vector2(3, 1), Vector2(7, 3)), PLATE_EDGE)
	_actor_block(Rect2(center - Vector2(2, 2), Vector2(5, 3)), PLATE_RIM)
	if has_food:
		_actor_block(Rect2(center - Vector2(1, 1), Vector2(2, 1)), FOOD)
		_actor_block(Rect2(center + Vector2(1, 0), Vector2.ONE), GARNISH)


func _draw_meal_action(actor: Dictionary, foot: Vector2, facing: float, child: bool, skin: Color) -> void:
	var hand := foot + Vector2(facing * 5.0, -5 if child else -7)
	var plate: Vector2 = actor.plate
	if actor.meal == "seated":
		var bite := fposmod(float(actor.meal_age) + (0.5 if child else 0.0), 1.8)
		var mouth := foot + Vector2(facing * 3.0, -6 if child else -8)
		var reach := hand + (plate - hand).limit_length(5.0)
		var lift := clampf(1.0 - absf(bite - 0.8) / 0.55, 0.0, 1.0)
		hand = reach.lerp(mouth, lift).round()
		_actor_block(Rect2(hand - Vector2(1, 0), Vector2(3, 2)), skin)
		_actor_block(Rect2(hand + Vector2(facing, -1), Vector2.ONE), FOOD if lift > 0.25 else PLATE_RIM)
	elif actor.meal == "collecting" and plate.is_finite() and actor_visible(plate):
		var scoop := clampf((float(actor.meal_age) - 2.0) / 2.0, 0.0, 1.0)
		var pickup := plate + (hand - plate).normalized() * 3.0
		var carrying := pickup.lerp(hand, scoop).round()
		_draw_plate(carrying, scoop > 0.25)
		_actor_block(Rect2(carrying + Vector2(-1, 2), Vector2(3, 1)), skin)
	elif actor.meal == "carrying":
		_draw_plate(hand, true)
		_actor_block(Rect2(hand + Vector2(-1, 2), Vector2(3, 1)), skin)


func _draw_leisure_action(actor: Dictionary, foot: Vector2, facing: float, child: bool) -> void:
	var skin: Color = GUEST_SKIN[actor.row]
	var age: float = actor.leisure_age
	match actor.leisure:
		"beach_lounge":
			var y := -2 if child else -3
			_actor_block(Rect2(foot + Vector2(facing * 3 - 2, y), Vector2(5, 2)), Color("#616a83"))
			_actor_block(Rect2(foot + Vector2(facing * 5 - 1, y + 1), Vector2(3, 2)), skin)
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
			var hand := foot + Vector2(facing * (3 + clap), -5 if child else -7)
			_actor_block(Rect2(hand - Vector2.ONE, Vector2(3, 2)), skin)
			_actor_block(Rect2(hand + Vector2(facing * 2, 0), Vector2.ONE), skin)


func _draw_volleyball(amenity: Dictionary) -> void:
	var arc := fposmod(time * 0.68, 2.0)
	var flight := 1.0 - absf(arc - 1.0)
	var ground := AmenityArt.at(amenity, Vector2(lerpf(21.0, 59.0, flight), lerpf(19.0, 38.0, flight))).round()
	var ball := ground - Vector2(0, 12 + roundf(sin(flight * PI) * 9.0))
	_actor_block(Rect2(ground - Vector2(2, 0), Vector2(4, 2)), Color("#7b555059"))
	_actor_block(Rect2(ball - Vector2(2, 1), Vector2(5, 3)), OUTLINE)
	_actor_block(Rect2(ball - Vector2(1, 2), Vector2(3, 5)), OUTLINE)
	_actor_block(Rect2(ball - Vector2(1, 1), Vector2(3, 3)), BEACH_BALL)
	_actor_block(Rect2(ball - Vector2(1, 1), Vector2(2, 1)), PLATE_RIM)


func _draw_stage_show(amenity: Dictionary) -> void:
	var corner := AmenityArt.at(amenity, Vector2(4, 2)).min(AmenityArt.at(amenity, Vector2(60, 23)))
	var stage_end := AmenityArt.at(amenity, Vector2(4, 2)).max(AmenityArt.at(amenity, Vector2(60, 23)))
	var beat := int(time * 5.0)
	_actor_block(Rect2(corner - Vector2(0, 14), stage_end - corner + Vector2(0, 13)), SHOW_DUSK)
	var lamps := [corner.x + 5.0, stage_end.x - 8.0]
	for index in 2:
		var lamp := Vector2(lamps[index], corner.y - 11.0)
		var lit := posmod(beat / 2 + index, 2) == 0
		var color := SHOW_LAMP if lit else DRINK_CUP
		_actor_block(Rect2(lamp, Vector2(3, 2)), color)
		for stripe in range(3):
			var glow := Color(color, 0.13 - stripe * 0.025)
			_actor_block(Rect2(lamp + Vector2(-stripe, 2 + stripe * 4), Vector2(3 + stripe * 2, 4)), glow)
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


func _actor_block(rect: Rect2, color: Color) -> void:
	actors.draw_rect(rect, color)


func _actor_region(destination: Rect2, source: Rect2) -> void:
	actors.draw_texture_rect_region(people, destination, source)


func _pose(family: Dictionary) -> Dictionary:
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


func _leisure_pose(family: Dictionary) -> Dictionary:
	var amenity: Dictionary = amenities.get(family.amenity_id, {})
	if amenity.is_empty():
		return {}
	var slot: int = family.leisure_slot
	var activity := _amenity_pose(amenity, slot)
	if family.phase == "leisure":
		return activity
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
		departure = _amenity_pose(previous, family.get("leisure_origin_slot", 0))
	var path := visible_layout.route(origin, target)
	if path.is_empty():
		return {}
	var duration := maxf(1.0, float(family.until - family.since))
	var progress := clampf((time - float(family.since)) / duration, 0.0, 1.0)
	var adult_path := path.duplicate()
	var child_path := path.duplicate()
	if not departure.is_empty():
		adult_path.insert(0, departure.point)
		child_path.insert(0, departure.child)
	if not arrival.is_empty():
		adult_path.append(arrival.point)
		child_path.append(arrival.child)
	var adult := _follow_path(adult_path, progress)
	var child := _follow_path(child_path, progress - sin(PI * progress) * 0.035)
	return {
		"point": adult.point, "child": child.point, "facing": adult.facing, "child_facing": child.facing,
		"frame": int(maxf(0.0, time - family.since) * 7.0) % 4 if progress < 1.0 else 0, "swim": false,
	}


func _amenity_pose(amenity: Dictionary, slot: int) -> Dictionary:
	slot = clampi(slot, 0, amenity.capacity - 1)
	var adult_local := Vector2.ZERO
	var child_local := Vector2.ZERO
	var focus_local := Vector2.ZERO
	match amenity.kind:
		"beach_lounge":
			adult_local = Vector2(10, 7 + slot * 12)
			child_local = Vector2(23, 9 + slot * 12)
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
			adult_local = Vector2(8 + slot * 15, 34)
			child_local = Vector2(15 + slot * 15, 37)
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
				return _meal_walk(origin.point, origin.child, table.seat, table.child, age,
					Sim.TABLE_WALK_DURATION, "carrying")
		"eating":
			if not table.is_empty():
				return {
					"point": table.seat, "child": table.child, "frame": 0, "swim": false,
					"facing": table.table_center.x >= table.seat.x, "child_facing": table.table_center.x >= table.child.x,
					"meal": "seated", "adult_plate": table.adult_plate, "child_plate": table.child_plate,
				}
		"to_pool":
			if not table.is_empty():
				var pool := station_points[2]
				return _meal_walk(table.seat, table.child, pool, pool, age, float(family.until - family.since))
	return {}


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
	var inner := pool_water.grow(-10.0)
	var x := inner.position.x + inner.size.x * (float(family.slot) + 1.0) / 4.0
	var point := Vector2(x + sin(time * 1.4 + family.id) * 3.0, inner.get_center().y)
	return {"point": point, "child": point + Vector2(-6, 4), "facing": true, "frame": 0, "swim": true}


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
