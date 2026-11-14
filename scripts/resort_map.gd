extends Node2D

const Ocean = preload("res://scripts/ocean.gd")
const Sim = preload("res://scripts/simulation.gd")
const Layout = preload("res://scripts/layout_model.gd")
const BuildingRenderer = preload("res://scripts/building_renderer.gd")
const WORLD_BOUNDS := Layout.WORLD_BOUNDS
const BASE_PATH := "res://assets/art/resort.png"
const PEOPLE_PATH := "res://assets/art/people.png"
const STATION_NAMES := ["Reception", "Buffet", "Pool"]
const OUTLINE := Color("#483747")
const LABEL_BG := Color("#392b38")
const LABEL_INK := Color("#fff0d5")
const LABEL_GOLD := Color("#e5bc78")

var simulation: Sim
var time := 0.0
var base_art: Texture2D
var people: Texture2D
var ocean: Ocean
var renderer: BuildingRenderer
var actors := Node2D.new()
var signs := Node2D.new()
var visible_layout: Layout
var viewing_draft := false
var room_points: Array[Vector2] = []
var station_points: Array[Vector2] = []
var station_approaches: Array[PackedVector2Array] = []
var pool_water := Rect2()
var label_font: Font


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base_art = load(BASE_PATH) as Texture2D
	people = load(PEOPLE_PATH) as Texture2D
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


func present(resort: Sim, visual_time: float, draft: Layout = null, layout_changed: bool = false) -> void:
	var layout := draft if draft else resort.layout
	var changed := layout_changed or visible_layout != layout
	var state_changed := simulation != resort or time != visual_time or viewing_draft != (draft != null)
	simulation = resort
	time = visual_time
	viewing_draft = draft != null
	actors.visible = not viewing_draft
	signs.visible = not viewing_draft
	ocean.present(float(simulation.day - 1) * Sim.DAY_LENGTH + time)
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


func _draw() -> void:
	if base_art:
		draw_texture(base_art, WORLD_BOUNDS.position)


func _draw_signs() -> void:
	if not simulation or not visible_layout:
		return
	var room_index := 0
	for building in visible_layout.buildings:
		var bounds := visible_layout.building_rect(building)
		var label := ""
		var ink := LABEL_INK
		if building.kind == "bedroom":
			if room_index < room_points.size() and bounds.has_point(room_points[room_index]):
				var occupied := simulation.rooms[room_index] >= 0
				label = "Room %s · %s" % [char(65 + room_index), "Occupied" if occupied else "Free"]
				ink = LABEL_GOLD if occupied else LABEL_INK
				room_index += 1
			else:
				label = "Needs bed or access"
		else:
			var station := Sim.STATIONS.find(building.kind)
			var waiting := simulation.count_at(station, "queue")
			label = STATION_NAMES[station] if waiting == 0 else "%s · %d waiting" % [STATION_NAMES[station], waiting]
		var font_size := 8
		var width := ceilf(label_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		var point := Vector2(roundf(bounds.get_center().x - width / 2.0), bounds.position.y - 12.0)
		signs.draw_rect(Rect2(point - Vector2(3, 1), Vector2(width + 6.0, 12.0)), LABEL_BG)
		signs.draw_string(label_font, point + Vector2(0, 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


func _draw_actors() -> void:
	if not simulation or visible_layout != simulation.layout:
		return
	var sprites: Array[Dictionary] = []
	for station in range(3):
		sprites.append({"point": _approach(station, 1), "row": 3, "frame": 0, "facing": true})
	sprites.append({"point": _approach(simulation.float_station, 2), "row": 3, "frame": 0, "facing": false})
	for family in simulation.families:
		if family.phase == "gone":
			continue
		var pose := _pose(family)
		sprites.append({
			"point": pose.point, "row": family.id % 3, "frame": pose.frame,
			"facing": pose.facing, "swim": pose.swim,
		})
		sprites.append({
			"point": pose.child, "row": 4, "frame": (pose.frame + 1) % 4 if pose.frame > 0 else 0,
			"facing": pose.facing, "swim": pose.swim,
		})
	sprites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.point.y < b.point.y)
	for sprite in sprites:
		_draw_actor(sprite)


func _draw_actor(actor: Dictionary) -> void:
	var foot: Vector2 = actor.point.round()
	var swim: bool = actor.get("swim", false)
	var row: int = actor.row
	if swim:
		foot.y += roundf(sin(time * 5.0 + foot.x) * 1.5)
		actors.draw_rect(Rect2(foot - Vector2(7, 1), Vector2(14, 2)), Color("#b2f2e6"))
	else:
		actors.draw_rect(Rect2(foot - Vector2(5, 1), Vector2(10, 2)), Color(0.16, 0.10, 0.19, 0.20))
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
		if not actor.facing:
			destination.position.x += 20
			destination.size.x = -20
		actors.draw_texture_rect_region(people, destination, source)
	else:
		var height := 8 if row == 4 else 12
		var outfit := [Color("#dc7954"), Color("#f5ca68"), Color("#759cbd"), Color("#ede3c9"), Color("#bd6a8b")]
		actors.draw_rect(Rect2(foot - Vector2(3, height), Vector2(6, height)), OUTLINE)
		actors.draw_rect(Rect2(foot - Vector2(2, height - 4), Vector2(4, height - 6)), outfit[row])
		actors.draw_rect(Rect2(foot - Vector2(2, height), Vector2(4, 4)), Color("#cb8d69"))


func _pose(family: Dictionary) -> Dictionary:
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


func _approach(station: int, steps: int) -> Vector2:
	var path := station_approaches[station]
	return path[maxi(0, path.size() - 1 - steps)]


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
