extends RefCounted
## Guest motion is sampled from the reservation's activity age. All routes start
## and end at the same dry threshold used by the map's ordinary walking phase.

const Art := preload("res://scripts/facility_renderer.gd")
const Amenity := preload("res://scripts/amenity_renderer.gd")
const SeatedArt := preload("res://scripts/seated_art.gd")
const INK := Color("#4b3749")
const CREAM := Color("#fff1ce")
const AQUA := Color("#a9e4d6")
const GOLD := Color("#f4bd75")
const CORAL := Color("#e89364")


static func entrance(venue: Dictionary, slot: int) -> Dictionary:
	var size := Amenity.ground_size(venue.kind)
	var apron := _apron_local(venue, size, slot)
	return {
		"point": _project(venue, apron[0]), "child": _project(venue, apron[1]),
		"gate": _project(venue, Vector3(size.x * 0.5, size.y - 5.0, 0)),
	}


static func pose(venue: Dictionary, slot: int, progress: float, age: float) -> Dictionary:
	slot = clampi(slot, 0, venue.capacity - 1)
	var size := Amenity.ground_size(venue.kind)
	var apron := _apron_local(venue, size, slot)
	var adult_gate := apron[0]
	var child_gate := apron[1]
	var state := {"adult": adult_gate, "child": child_gate, "adult_action": "", "child_action": "",
		"adult_target": adult_gate, "child_target": child_gate}
	var t := clampf(progress, 0.0, 1.0)
	match venue.kind:
		"lap_pool": _lap(state, adult_gate, child_gate, slot, t)
		"lagoon_pool": _lagoon(state, adult_gate, child_gate, slot, t, age)
		"hot_tub": _hot(state, adult_gate, child_gate, t)
		"kids_pool": _kids(state, adult_gate, child_gate, slot, t, age)
		"waterpark": _waterpark(state, adult_gate, child_gate, slot, t)
		"basketball": _basketball(state, adult_gate, child_gate, slot, t, age)
		"climbing_wall": _climbing(state, adult_gate, child_gate, t, age)
		"arcade": _arcade(state, adult_gate, child_gate, slot, t)
		"cafe": _cafe(state, adult_gate, child_gate, slot, t)
		"nightclub": _club(state, adult_gate, child_gate, slot, t, age)
	var adult: Vector3 = state.adult
	var child: Vector3 = state.child
	var adult_contact: Vector3 = state.adult_target
	var child_contact: Vector3 = state.child_target
	var adult_point := _project(venue, adult)
	var child_point := _project(venue, child)
	var adult_target := _project(venue, state.adult_target)
	var child_target := _project(venue, state.child_target)
	return {
		"point": adult_point, "child": child_point,
		"ground": _project(venue, Vector3(adult.x, adult.y, 0)), "child_ground": _project(venue, Vector3(child.x, child.y, 0)),
		"swim": _wet(venue.kind, adult), "child_swim": _wet(venue.kind, child),
		"facing": adult_target.x >= adult_point.x, "child_facing": child_target.x >= child_point.x,
		"frame": floori(age * 6.0) % 4,
		"leisure": venue.kind, "adult_action": state.adult_action, "child_action": state.child_action,
		"adult_target": adult_target, "child_target": child_target,
		"adult_target_ground": _project(venue, Vector3(adult_contact.x, adult_contact.y, 0)),
		"child_target_ground": _project(venue, Vector3(child_contact.x, child_contact.y, 0)),
		"adult_local": adult, "child_local": child,
	}


static func _apron_local(venue: Dictionary, size: Vector2, slot: int) -> Array[Vector3]:
	var x := size.x * 0.5 + (float(slot) - float(int(venue.capacity) - 1) * 0.5) * 9.0
	var y := size.y - 6.0
	var companion := Vector3(x, y - 6.0, 0)
	if venue.kind == "hot_tub":
		companion = Vector3(x + 8.0, y, 0)
	return [Vector3(x, y, 0), companion]


static func _project(venue: Dictionary, point: Vector3) -> Vector2:
	return Amenity.at(venue, Vector2(point.x, point.y)) - Vector2(0, point.z)


static func _ground(local: Vector2) -> Vector3:
	return Vector3(local.x, local.y, 0)


static func _wet(kind: String, point: Vector3) -> bool:
	return point.z < 1.0 and Art.water_contains(kind, Vector2(point.x, point.y))


static func _mix(t: float, start: float, finish: float) -> float:
	return clampf((t - start) / (finish - start), 0.0, 1.0)


static func _trip(gate: Vector3, via: Vector3, position: Vector3, t: float, entry: float = 0.22) -> Vector3:
	var motion := _mix(minf(t, 1.0 - t), 0.0, entry)
	return gate.lerp(via, motion * 2.0) if motion < 0.5 else via.lerp(position, (motion - 0.5) * 2.0)


static func _lap_entry(gate: Vector3, lane: Vector3, deck_x: float, t: float) -> Vector3:
	var motion := _mix(minf(t, 1.0 - t), 0.0, 0.22)
	if motion < 0.53:
		return gate.lerp(Vector3(deck_x, 54, 0), motion / 0.53)
	if motion < 0.86:
		return Vector3(deck_x, 54, 0).lerp(Vector3(deck_x, lane.y, 0), (motion - 0.53) / 0.33)
	return Vector3(deck_x, lane.y, 0).lerp(lane, (motion - 0.86) / 0.14)


static func _lap(state: Dictionary, a_gate: Vector3, c_gate: Vector3, slot: int, t: float) -> void:
	var lane_y := 13 + slot * 20
	var motion := _mix(t, 0.22, 0.78)
	var sweep := sin(PI * motion)
	var companion := sin(PI * pow(motion, 1.16))
	var adult := Vector3(76 - 58 * sweep, lane_y, 0)
	var child := Vector3(73 - 52 * companion, lane_y + 10, 0)
	state.adult = _lap_entry(a_gate, adult, 90.0, t)
	state.child = _lap_entry(c_gate, child, 92.0, t)
	var direction := -1.0 if motion < 0.5 else 1.0
	state.adult_target = adult + Vector3(direction * 10, 0, 0)
	state.child_target = child + Vector3(direction * 10, 0, 0)
	state.adult_action = "laps" if _wet("lap_pool", state.adult) else ""
	state.child_action = "laps" if _wet("lap_pool", state.child) else ""


static func _lagoon(state: Dictionary, a_gate: Vector3, c_gate: Vector3, slot: int, t: float, age: float) -> void:
	var lane := 25.0 + slot * 23.0
	var fade := smoothstep(0.21, 0.34, t) * (1.0 - smoothstep(0.67, 0.8, t))
	var adult := Vector3(lane + sin(age * 1.9 + slot) * 3.0 * fade, 35, 0)
	var child := Vector3(lane + 4, 47 + cos(age * 1.6 + slot) * 3.0 * fade, 0)
	state.adult = _trip(a_gate, Vector3(45 + slot * 3, 65, 0), adult, t)
	state.child = _trip(c_gate, Vector3(50 + slot * 3, 65, 0), child, t)
	state.adult_target = child
	state.child_target = adult
	state.adult_action = "float"
	state.child_action = "splash"


static func _hot(state: Dictionary, a_gate: Vector3, c_gate: Vector3, t: float) -> void:
	var soak := Vector3(16, 18, 0)
	var stool := Vector3(32, 31, 0)
	state.adult = _trip(a_gate, Vector3(18, 31, 0), soak, t)
	state.child = _trip(c_gate, Vector3(26, 35, 0), stool, t)
	state.adult_target = stool
	state.child_target = soak
	state.adult_action = "soak"
	state.child_action = "relax" if t > 0.22 and t < 0.78 else ""


static func _kids(state: Dictionary, a_gate: Vector3, c_gate: Vector3, slot: int, t: float, age: float) -> void:
	var stool := Vector3(17 + slot * 28, 49, 0)
	var fade := smoothstep(0.22, 0.34, t) * (1.0 - smoothstep(0.66, 0.78, t))
	var wade := Vector3(21 + slot * 22 + sin(age * 2.2) * 2.0 * fade, 27 + cos(age * 2.0) * fade, 0)
	state.adult = _trip(a_gate, Vector3(27 + slot * 12, 51, 0), stool, t)
	state.child = _trip(c_gate, Vector3(24 + slot * 17, 45, 0), wade, t)
	state.adult_target = wade
	state.child_target = stool
	state.adult_action = "supervise" if t > 0.23 and t < 0.77 else ""
	state.child_action = "splash"


static func _waterpark(state: Dictionary, a_gate: Vector3, c_gate: Vector3, slot: int, t: float) -> void:
	var lookout := Vector3(61 + slot * 17, 76, 0)
	state.adult = _trip(a_gate, Vector3(62 + slot * 7, 80, 0), lookout, t, 0.17)
	state.adult_action = "supervise" if t > 0.17 and t < 0.83 else ""
	var tower := Art.slide_start(slot)
	var bottom := Vector3(tower.x, tower.y, 0)
	var drain := Art.slide_point(slot, 1.0)
	var edge := Vector3(75 + slot * 9, 72, 0)
	var walkway := Vector3(11 + slot * 7, 78 - slot * 3, 0)
	if t < 0.08:
		state.child = c_gate.lerp(walkway, _mix(t, 0.0, 0.08))
	elif t < 0.17:
		state.child = walkway.lerp(bottom, _mix(t, 0.08, 0.17))
	elif t < 0.35:
		state.child = bottom.lerp(tower, _mix(t, 0.17, 0.35))
		state.child_action = "ladder"
	elif t < 0.61:
		state.child = Art.slide_point(slot, _mix(t, 0.35, 0.61))
		state.child_action = "slide"
	elif t < 0.81:
		state.child = drain.lerp(edge, _mix(t, 0.61, 0.81))
		state.child_action = "splash"
	elif t < 0.88:
		state.child = edge.lerp(Vector3(58 + slot * 8, 81, 0), _mix(t, 0.81, 0.88))
	else:
		state.child = Vector3(58 + slot * 8, 81, 0).lerp(c_gate, _mix(t, 0.88, 1.0))
	state.adult_target = state.child
	state.child_target = drain if t < 0.7 else c_gate


static func _basketball(state: Dictionary, a_gate: Vector3, c_gate: Vector3, slot: int, t: float, age: float) -> void:
	var direction := -1 if slot == 0 else 1
	var fade := smoothstep(0.21, 0.33, t) * (1.0 - smoothstep(0.68, 0.8, t))
	var handler := Vector3(40 + 15 * direction + sin(age * 1.7 + slot) * 3.0 * fade,
		30 + cos(age * 1.7) * 3.0 * fade, 0)
	var partner := Vector3(40 + 21 * direction, 42, 0)
	state.adult = _trip(a_gate, Vector3(40 + 4 * direction, 51, 0), handler, t)
	state.child = _trip(c_gate, Vector3(40 + 8 * direction, 51, 0), partner, t)
	state.adult_target = Art.RIM
	state.child_target = handler
	state.adult_action = "basketball" if t > 0.22 and t < 0.78 else ""
	state.child_action = "ready" if t > 0.22 and t < 0.78 else ""


static func _climbing(state: Dictionary, a_gate: Vector3, c_gate: Vector3, t: float, age: float) -> void:
	var belay := Vector3(42, 35, 0)
	var bottom := _ground(Art.CLIMB_BASE + Vector2(0, 2))
	state.adult = _trip(a_gate, Vector3(24, 39, 0), belay, t, 0.17)
	state.child = _trip(c_gate, Vector3(32, 37, 0), bottom, t, 0.20)
	# Keep the rope attach point on the selected wall in every orientation.
	state.child_target = Art.CLIMB_ANCHOR
	if t >= 0.2 and t <= 0.8:
		var height := minf(_mix(t, 0.20, 0.53), 1.0 - _mix(t, 0.53, 0.80))
		var x := bottom.x + sin(age * 2.2) * height * 3.0
		state.child = Vector3(x, Art.climb_face(x) + 2.0, 25.0 * height)
		state.child_action = "climb"
		state.adult_action = "belay"
		state.adult_target = state.child_target


static func _arcade(state: Dictionary, a_gate: Vector3, c_gate: Vector3, slot: int, t: float) -> void:
	var controls_a := Art.cabinet_at(slot * 2)
	var controls_c := Art.cabinet_at(slot * 2 + 1)
	state.adult = _trip(a_gate, _ground(controls_a + Vector2(0, 14)), _ground(controls_a + Vector2(0, 9)), t)
	state.child = _trip(c_gate, _ground(controls_c + Vector2(0, 14)), _ground(controls_c + Vector2(0, 9)), t)
	state.adult_target = Vector3(controls_a.x, controls_a.y + 4, 4)
	state.child_target = Vector3(controls_c.x, controls_c.y + 4, 4)
	if t > 0.22 and t < 0.78:
		state.adult_action = "arcade"
		state.child_action = "arcade"


static func _cafe(state: Dictionary, a_gate: Vector3, c_gate: Vector3, slot: int, t: float) -> void:
	var table: Vector2 = Art.CAFE_TABLES[slot]
	var station := Vector3(25 + slot * 14, Art.CAFE_COUNTER.y + 5, 0)
	var station_c := station + Vector3(5, 2, 0)
	var outer := -1.0 if slot == 0 else 1.0
	var seat_a := _ground(table + Vector2(outer * 9, 3))
	var seat_c := _ground(table + Vector2(-outer * 9, 3))
	if t < 0.18:
		state.adult = a_gate.lerp(station, _mix(t, 0.0, 0.18))
		state.child = c_gate.lerp(station_c, _mix(t, 0.0, 0.18))
	elif t < 0.29:
		state.adult = station
		state.child = station_c
		state.adult_action = "collect"
		state.child_action = "collect"
	elif t < 0.49:
		var next_a := Vector3(seat_a.x, table.y - 8.0, 0)
		var next_c := Vector3(seat_c.x, table.y - 8.0, 0)
		state.adult = station.lerp(next_a, _mix(t, 0.29, 0.39)) if t < 0.39 else next_a.lerp(seat_a, _mix(t, 0.39, 0.49))
		state.child = station_c.lerp(next_c, _mix(t, 0.29, 0.39)) if t < 0.39 else next_c.lerp(seat_c, _mix(t, 0.39, 0.49))
		state.adult_action = "carry"
		state.child_action = "carry"
	elif t < 0.81:
		state.adult = seat_a
		state.child = seat_c
		state.adult_action = "cafe_sit"
		state.child_action = "cafe_sit"
	else:
		state.adult = seat_a.lerp(a_gate, _mix(t, 0.81, 1.0))
		state.child = seat_c.lerp(c_gate, _mix(t, 0.81, 1.0))
	if t < 0.29:
		state.adult_target = station - Vector3(0, 5, 5)
		state.child_target = station_c - Vector3(0, 7, 5)
	else:
		state.adult_target = Vector3(table.x + outer * 2, table.y, 3)
		state.child_target = Vector3(table.x - outer * 2, table.y, 3)


static func _club(state: Dictionary, a_gate: Vector3, c_gate: Vector3, slot: int, t: float, age: float) -> void:
	var x := 20 + (slot % 2) * 31
	var y := 31 + (slot / 2) * 17
	var fade := smoothstep(0.22, 0.34, t) * (1.0 - smoothstep(0.66, 0.78, t))
	var step := sin(age * 3.5 + slot) * fade
	var adult := Vector3(x + step * 2.1, y, maxf(0.0, step) * 2.0)
	var child := Vector3(x + 11 - step * 1.3, y + 4, maxf(0.0, -step) * 2.0)
	state.adult = _trip(a_gate, Vector3(x, 56, 0), adult, t)
	state.child = _trip(c_gate, Vector3(x + 10, 56, 0), child, t)
	state.adult_target = child
	state.child_target = adult
	if t > 0.22 and t < 0.78:
		state.adult_action = "dance"
		state.child_action = "dance"


static func is_seated(action: String) -> bool:
	return action in ["relax", "supervise", "cafe_sit", "slide"]


static func draw_action(block: Callable, actor: Dictionary, foot: Vector2, facing: float, child: bool, skin: Color, time: float) -> void:
	var action: String = actor.get("facility_action", "")
	var target: Vector2 = actor.get("facility_target", foot)
	var age: float = actor.leisure_age
	var phase := age * 2.3 + float(actor.leisure_slot) * 1.8
	var hand := foot + Vector2(facing * 4, -5 if child else -7)
	match action:
		"laps", "float", "soak", "splash":
			if actor.swim:
				_water_action(block, foot, phase, action, target)
		"ladder", "climb", "slide":
			var step := 2 if cos(phase * 2.0) > 0.0 else -2
			if action == "climb":
				_mark(block, foot + Vector2(-2, -4), Vector2(5, 2), CORAL)
			var reach := foot + Vector2(facing * 4, (-7 if child else -10) + step)
			_mark(block, reach, Vector2(2, 2), skin)
			_mark(block, foot + Vector2(-facing * 3, -5 - step), Vector2(2, 2), skin)
		"basketball":
			_mark(block, basketball_effect(actor, foot).hand, Vector2(3, 2), skin)
		"ready":
			_mark(block, hand - Vector2(0, 2), Vector2(3, 2), skin)
		"belay":
			_mark(block, hand, Vector2(3, 2), skin)
		"arcade":
			var reach := hand.lerp(target, 0.6 + 0.2 * sin(phase * 4.2))
			_mark(block, reach, Vector2(3, 2), skin)
			if sin(phase * 4.2) > 0.55:
				_mark(block, target + Vector2(1, -3), Vector2(2, 1), GOLD)
		"collect", "carry", "cafe_sit":
			var sip := maxf(0.0, sin(phase * 1.6))
			var cup := hand
			if action == "collect":
				cup = target.lerp(hand, 0.45 + 0.3 * sin(phase))
			elif action == "cafe_sit":
				var shoulder := SeatedArt.shoulder(foot, facing, child)
				var reach := shoulder + (target - shoulder).limit_length(9.0 if child else 11.0)
				cup = reach.lerp(SeatedArt.mouth(foot, facing, child) + Vector2(facing * 2, 2), sip)
				_line(block, shoulder, cup, skin)
				if not actor.get("defer_facility", false):
					draw_cafe_snack(block, target)
			_mark(block, cup - Vector2(1, 2), Vector2(3, 4), INK)
			_mark(block, cup - Vector2(0, 2), Vector2(2, 3), AQUA)
			_mark(block, cup - Vector2(0, 2), Vector2(2, 1), CREAM)
			_mark(block, cup + Vector2(1, 1), Vector2(2, 2), skin)
		"dance":
			var arm := roundf(2.5 * sin(time * 7.4 + actor.leisure_slot))
			_mark(block, hand - Vector2(0, 3 + arm), Vector2(3, 2), skin)
			_mark(block, foot + Vector2(-facing * 5, -7 + arm), Vector2(2, 2), skin)
		"relax", "supervise":
			_mark(block, hand + Vector2(-2, 1), Vector2(3, 2), skin)


static func draw_cafe_snack(block: Callable, target: Vector2) -> void:
	_mark(block, target + Vector2(-2, 2), Vector2(4, 2), CREAM)
	_mark(block, target + Vector2(-1, 2), Vector2(2, 1), CORAL)


static func _water_action(block: Callable, foot: Vector2, phase: float, action: String, target: Vector2) -> void:
	match action:
		"laps":
			var along := (target - foot).normalized()
			var wake := foot - along * 7.0
			var cross := Vector2(-along.y, along.x)
			_mark(block, wake + cross * 2.0, Vector2(3, 1), AQUA)
			_mark(block, wake - along * 3.0 - cross, Vector2(2, 1), CREAM)
			_mark(block, foot + along * 4.0 + cross * sin(phase * 3.4), Vector2(2, 1), AQUA)
		"soak":
			for index in 3:
				var rise := fposmod(phase + index * 1.8, 4.0)
				_mark(block, foot + Vector2(index * 5 - 5, 3 - rise), Vector2.ONE, CREAM)
		_:
			var span := 3.0 + 3.0 * maxf(0.0, sin(phase))
			for side in [-1, 1]:
				_mark(block, foot + Vector2(side * span, 1), Vector2(3, 1), AQUA)
				if action == "splash" and span > 4.5:
					_mark(block, foot + Vector2(side * (span + 1), -3), Vector2.ONE, CREAM)


static func basketball_effect(actor: Dictionary, foot: Vector2) -> Dictionary:
	var hand := foot + Vector2(4 if actor.facing else -4, -7)
	var ground: Vector2 = actor.get("ground", foot)
	var rim: Vector2 = actor.facility_target
	var rim_ground: Vector2 = actor.get("facility_target_ground", rim)
	var cycle := fposmod(float(actor.leisure_age) * 0.57 + int(actor.leisure_slot) * 0.48, 1.0)
	var ball := hand
	var depth := ground.y
	if cycle < 0.53:
		var bounce := absf(sin(cycle * 3.78 * PI))
		ball = hand.lerp(Vector2(hand.x + signf(hand.x - foot.x) * 2, foot.y), bounce)
	elif cycle < 0.83:
		var flight := (cycle - 0.53) / 0.3
		ball = (hand - Vector2(0, 4)).lerp(rim, flight) - Vector2(0, sin(PI * flight) * 13.0)
		depth = lerpf(ground.y, rim_ground.y, flight)
		hand.y -= 4
	else:
		var rebound := (cycle - 0.83) / 0.17
		ball = rim.lerp(hand, rebound) + Vector2(0, sin(PI * rebound) * 8)
		depth = lerpf(rim_ground.y, ground.y, rebound)
	return {"point": ball, "depth": depth, "hand": hand}


static func draw_basketball_ball(block: Callable, ball: Vector2) -> void:
	_mark(block, ball - Vector2(2, 1), Vector2(5, 3), INK)
	_mark(block, ball - Vector2(1, 2), Vector2(3, 5), INK)
	_mark(block, ball - Vector2(1, 1), Vector2(3, 3), CORAL)
	_mark(block, ball, Vector2(1, 2), GOLD)


static func draw_club_lights(block: Callable, venue: Dictionary, darkness: float, time: float) -> void:
	for index in range(-1, Art.CLUB_LAMPS.size()):
		draw_club_light(block, venue, darkness, time, index)


static func draw_club_light(block: Callable, venue: Dictionary, darkness: float, time: float, index: int) -> void:
	var colors := [Color("#ffd689"), Color("#eab4d7"), Color("#b0e5ee")]
	if index >= 0:
		var lamp := _project(venue, Art.CLUB_LAMPS[index])
		var color: Color = colors[index]
		var glow := 0.66 + sin(time * 2.2 + index) * 0.15
		_mark(block, lamp - Vector2(1, 0), Vector2(3, 2), color)
		_mark(block, lamp + Vector2(-2, 2), Vector2(5, 3), Color(color, darkness * glow * 0.22))
		_mark(block, lamp + Vector2(-3, 5), Vector2(7, 3), Color(color, darkness * glow * 0.13))
	else:
		var note := _project(venue, Vector3(42, 14, 16 + sin(time * 2.6) * 2.5))
		_mark(block, note, Vector2(1, 5), GOLD)
		_mark(block, note + Vector2(-2, 4), Vector2(3, 2), GOLD)


static func _mark(block: Callable, at: Vector2, size: Vector2, color: Color) -> void:
	block.call(Rect2(at.round(), size), color)


static func _line(block: Callable, from: Vector2, to: Vector2, color: Color) -> void:
	var count := maxi(1, ceili(from.distance_to(to)))
	for index in range(count + 1):
		_mark(block, from.lerp(to, float(index) / count), Vector2.ONE, color)
