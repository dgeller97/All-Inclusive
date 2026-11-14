extends RefCounted

signal event_happened(kind: StringName, details: Dictionary)

const DAY_LENGTH := 240
const FINAL_DAY := 3
const OPEN_BOOKINGS := 20
const PAYROLL := 120
const MEAL_VERSION := 1
const TABLE_WALK_DURATION := 4
const EAT_DURATION := 12
const LEGACY_BUFFET_DURATION := 18
const LEISURE_VERSION := 1
const LEISURE_WALK_DURATION := 4
const SHOW_START := 180
const SHOW_LAST_ENTRY := 191
const LEISURE_DURATIONS := {"beach_lounge": 10, "volleyball": 10, "beach_bar": 6, "stage": 10}
const LEISURE_PHASES := ["to_leisure", "leisure", "from_leisure"]
const LEISURE_NOTES := {
	"beach_lounge": "Loved the shaded beach loungers",
	"volleyball": "Had fun at beach volleyball",
	"beach_bar": "Enjoyed the beach bar mocktails",
	"stage": "Loved the evening show",
}
const Layout = preload("res://scripts/layout_model.gd")
const STATIONS := ["reception", "buffet", "pool"]
const DURATIONS := [8, 6, 20]
const PHASES := ["queue", "service", "to_room", "settle", "to_buffet", "wait_table", "to_table", "eating", "to_pool",
	"return_room", "rest", "to_checkout", "exit", "gone"] + LEISURE_PHASES
const TABLE_RESERVATION_PHASES := ["to_table", "eating"]
const LEISURE_DEFAULTS := {
	"amenity_id": -1, "leisure_kind": "", "leisure_step": 0, "leisure_slot": -1, "leisure_origin_id": -1,
	"leisure_origin_slot": -1, "leisure_completed": [],
}
const PACKAGES := [
	{"name": "Budget", "price": 90, "bookings": 4, "value": 5, "cue": "Better value"},
	{"name": "Standard", "price": 120, "bookings": 4, "value": 0, "cue": "Balanced value"},
	{"name": "Premium", "price": 170, "bookings": 3, "value": -12, "cue": "Higher expectations"},
]

var day := 1
var second := 0
var cash := 140
var selected_package := 1
var booked_package := -1
var booked_count := 0
var float_station := 1
var mode := "regular"
var layout := Layout.new()
var pending_layout: Layout
var pending_reserve := 0
var terrace := false
var families: Array[Dictionary] = []
var rooms: Array[int] = []
var reviews: Array[Dictionary] = []
var day_recaps: Array[Dictionary] = []
var milestone := {}
var stopped := false


func _init() -> void:
	_reset_room_slots()


func _reset_room_slots() -> void:
	var readiness := layout.readiness()
	rooms.resize(readiness.room_count)
	rooms.fill(-1)
	terrace = readiness.terrace


func capacity(station: int) -> int:
	return 1 + int(station == float_station) + int(station == 2 and terrace)


func count_at(station: int, phase: String) -> int:
	var count := 0
	for family in families:
		if family.phase == phase and family.station == station:
			count += 1
	return count


func occupied_tables() -> int:
	return count_at(1, "to_table") + count_at(1, "eating")


func occupied_amenity(amenity_id: int) -> int:
	var count := 0
	for family in families:
		if family.amenity_id == amenity_id and family.phase in LEISURE_PHASES:
			count += 1
	return count


func family_in_room(room_index: int) -> Dictionary:
	for family in families:
		if family.id == rooms[room_index]:
			return family
	return {}


func average() -> float:
	if reviews.is_empty():
		return 0.0
	var total := 0
	for review in reviews:
		total += review.score
	return float(total) / reviews.size()


func bookings_for(package: int) -> int:
	return mini(PACKAGES[package].bookings, rooms.size())


func must_defer_construction() -> bool:
	if families.size() < booked_count:
		return true
	for family in families:
		if family.phase != "gone":
			return true
	return false


func construction_status(draft: Layout) -> Dictionary:
	var quote := draft.quote_diff(layout, mode == "developer")
	var available := cash + pending_reserve
	var ready := draft.readiness()
	var reason := ""
	if not ready.ok:
		reason = ready.reasons[0]
	elif stopped:
		reason = "Continue from the Day 3 recap to apply changes."
	elif quote.net > 0 and quote.net > available:
		reason = "Need $%d more to apply these changes." % (quote.net - available)
	return {
		"ok": reason.is_empty(), "reason": reason, "cost": quote.cost,
		"refund": quote.refund, "net": quote.net, "available": available,
		"defer": must_defer_construction(),
	}


func station_name(station: int) -> String:
	return Layout.building_name(layout.building_at(layout.station_point(station)))


func room_name(index: int) -> String:
	var points := layout.room_points()
	if index >= 0 and index < points.size():
		return Layout.building_name(layout.building_at(points[index]))
	return "Room %s" % char(65 + index)


func apply_construction(draft: Layout) -> Dictionary:
	var result := construction_status(draft)
	if not result.ok:
		return result
	var next: Layout = draft.duplicate_layout()
	if result.defer:
		pending_reserve = maxi(result.net, 0)
		cash = result.available - pending_reserve
		pending_layout = next
	else:
		cash = result.available - result.net
		pending_reserve = 0
		pending_layout = null
		_activate_layout(next)
	return result


func cancel_construction() -> bool:
	if pending_layout == null:
		return false
	cash += pending_reserve
	pending_reserve = 0
	pending_layout = null
	return true


func _activate_layout(next: Layout) -> void:
	var had_terrace := terrace
	next.stamp_paid(layout, mode == "developer")
	layout = next
	_reset_room_slots()
	if terrace and not had_terrace:
		event_happened.emit(&"upgrade", {})


func continue_after_recap() -> void:
	if stopped:
		stopped = false
		_open_next_day()


func tick() -> void:
	if stopped:
		return
	second += 1
	if second >= DAY_LENGTH:
		_close_day()
		return

	if second == OPEN_BOOKINGS:
		booked_package = selected_package
		booked_count = bookings_for(booked_package)
		event_happened.emit(&"bookings", {"count": booked_count})
	var arrival_index := second - OPEN_BOOKINGS
	if booked_package >= 0 and arrival_index >= 0 and arrival_index % 6 == 0:
		if arrival_index < booked_count * 6:
			_arrive()

	for family in families:
		if family.until == second:
			_advance(family)
		if family.phase == "rest":
			if second >= _checkout_time(family):
				_transition(family, "to_checkout", 4)
			elif second >= SHOW_START and second <= SHOW_LAST_ENTRY and family.leisure_step < 3:
				family.leisure_step = 3
				_start_leisure(family, "stage", layout.room_points()[family.room])
	_start_queued_services()
	_seat_diners()


func _arrive() -> void:
	var family := {
		"id": families.size(), "room": -1, "station": 0, "phase": "queue",
		"since": second, "until": -1, "joined": second,
		"waits": [0, 0, 0], "upgraded_swim": false, "slot": -1,
		"table_id": -1, "dining_wait": 0,
	}
	family.merge(LEISURE_DEFAULTS.duplicate(true))
	families.append(family)


func _transition(family: Dictionary, phase: String, duration: int = -1) -> void:
	family.phase = phase
	family.since = second
	family.until = second + duration if duration >= 0 else -1


func _queue(family: Dictionary, station: int) -> void:
	family.station = station
	family.joined = second
	_transition(family, "queue")


func _start_queued_services() -> void:
	for station in range(STATIONS.size()):
		var available := capacity(station)
		if station == 0:
			available = mini(available, rooms.count(-1))
		var in_use := []
		for family in families:
			if family.phase == "service" and family.station == station:
				in_use.append(family.slot)
		if in_use.size() >= available:
			continue

		var queue: Array[Dictionary] = []
		for family in families:
			if family.phase == "queue" and family.station == station:
				queue.append(family)
		queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a.joined == b.joined:
				return a.id < b.id
			return a.joined < b.joined
		)

		for family in queue:
			var slot := 0
			while slot in in_use:
				slot += 1
			in_use.append(slot)
			family.slot = slot
			family.waits[station] = second - family.joined
			if station == 2:
				family.upgraded_swim = terrace
			_transition(family, "service", DURATIONS[station])
			if in_use.size() >= available:
				break


func _seat_diners() -> void:
	var waiting: Array[Dictionary] = []
	var reserved := {}
	for family in families:
		if family.phase == "wait_table":
			waiting.append(family)
		elif family.phase in TABLE_RESERVATION_PHASES:
			reserved[family.table_id] = true
	if waiting.is_empty():
		return
	waiting.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.since == b.since:
			return a.id < b.id
		return a.since < b.since
	)
	var next := 0
	for table in layout.dining_tables():
		if reserved.has(table.id):
			continue
		var family := waiting[next]
		family.table_id = table.id
		family.dining_wait = second - family.since
		_transition(family, "to_table", TABLE_WALK_DURATION)
		next += 1
		if next == waiting.size():
			break


func _checkout_time(family: Dictionary) -> int:
	return 200 + family.id * 8


func _start_daytime_leisure(family: Dictionary) -> void:
	var pool := layout.station_point(2)
	var preferred := "beach_lounge" if (day + family.id) % 2 == 1 else "volleyball"
	var alternate := "volleyball" if preferred == "beach_lounge" else "beach_lounge"
	family.leisure_step = 1
	if _start_leisure(family, preferred, pool) or _start_leisure(family, alternate, pool):
		return
	family.leisure_step = 2
	if not _start_leisure(family, "beach_bar", pool):
		_transition(family, "return_room", LEISURE_WALK_DURATION)


func _start_leisure(family: Dictionary, kind: String, origin: Vector2, origin_id: int = -1) -> bool:
	if second + 2 * LEISURE_WALK_DURATION + LEISURE_DURATIONS[kind] > _checkout_time(family):
		return false
	var room := layout.room_points()[family.room]
	for amenity in layout.amenities(kind):
		if layout.route(origin, amenity.point).is_empty() or layout.route(amenity.point, room).is_empty():
			continue
		var used := {}
		for guest in families:
			if guest.amenity_id == amenity.id and guest.phase in LEISURE_PHASES:
				used[guest.leisure_slot] = true
		for slot in range(amenity.capacity):
			if used.has(slot):
				continue
			family.amenity_id = amenity.id
			family.leisure_kind = kind
			family.leisure_origin_slot = family.leisure_slot if origin_id != -1 else -1
			family.leisure_slot = slot
			family.leisure_origin_id = origin_id
			_transition(family, "to_leisure", LEISURE_WALK_DURATION)
			return true
	return false


func _finish_leisure(family: Dictionary) -> void:
	family.leisure_completed.append(family.leisure_kind)
	if family.leisure_step == 1:
		var amenity := layout.amenity_by_id(family.amenity_id)
		family.leisure_step = 2
		if not amenity.is_empty() and _start_leisure(family, "beach_bar", amenity.point, amenity.id):
			return
		family.leisure_step = 1
	_transition(family, "from_leisure", LEISURE_WALK_DURATION)


func _return_from_leisure(family: Dictionary) -> void:
	family.amenity_id = -1
	family.leisure_kind = ""
	family.leisure_slot = -1
	family.leisure_origin_id = -1
	family.leisure_origin_slot = -1
	family.leisure_step = maxi(family.leisure_step, 2)
	_transition(family, "rest")


func _advance(family: Dictionary) -> void:
	match family.phase:
		"service":
			match family.station:
				0:
					var room := rooms.find(-1)
					if room < 0:
						_queue(family, 0)
						return
					rooms[room] = family.id
					family.room = room
					cash += PACKAGES[booked_package].price
					_transition(family, "to_room", 4)
					event_happened.emit(&"checkin", {"room": room, "price": PACKAGES[booked_package].price})
				1:
					family.erase("legacy_meal")
					family.slot = -1
					_transition(family, "wait_table")
				2:
					_start_daytime_leisure(family)
		"to_room":
			_transition(family, "settle", 10)
		"settle":
			_transition(family, "to_buffet", 4)
		"to_buffet":
			_queue(family, 1)
		"to_table":
			_transition(family, "eating", EAT_DURATION)
		"eating":
			_transition(family, "to_pool", 4)
		"to_pool":
			family.erase("legacy_meal")
			family.table_id = -1
			_queue(family, 2)
		"return_room":
			_transition(family, "rest")
		"to_leisure":
			_transition(family, "leisure", LEISURE_DURATIONS[family.leisure_kind])
		"leisure":
			_finish_leisure(family)
		"from_leisure":
			_return_from_leisure(family)
		"to_checkout":
			_checkout(family)
			_transition(family, "exit", 4)
		"exit":
			_transition(family, "gone")


func _checkout(family: Dictionary) -> void:
	rooms[family.room] = -1
	var package: Dictionary = PACKAGES[booked_package]
	var leisure_bonus := mini(3, family.leisure_completed.size())
	var score: int = 92 + package.value + (8 if family.upgraded_swim else 0) + leisure_bonus
	var longest_penalty := 0
	var station_index := -1
	for station in range(STATIONS.size()):
		var penalty := _wait_penalty(family.waits[station])
		score -= penalty
		if penalty > longest_penalty:
			longest_penalty = penalty
			station_index = station
	var dining_penalty := _wait_penalty(family.dining_wait)
	score -= dining_penalty
	var note: String
	if dining_penalty > 0 and dining_penalty >= longest_penalty:
		note = "Long dining table wait"
	elif station_index >= 0:
		note = "Long %s line" % STATIONS[station_index]
	elif family.upgraded_swim:
		note = "Loved the pool terrace"
	elif not family.leisure_completed.is_empty():
		note = LEISURE_NOTES[family.leisure_completed.back()]
	elif booked_package == 0:
		note = "Great value for the family"
	elif booked_package == 2:
		note = "A premium family stay"
	else:
		note = "Good value for the family"
	var review := {
		"day": day, "room": family.room, "score": clampi(score, 0, 100),
		"note": note, "waits": family.waits.duplicate(), "dining_wait": family.dining_wait,
		"leisure_bonus": leisure_bonus,
	}
	reviews.append(review)
	event_happened.emit(&"review", review)


func _wait_penalty(wait: int) -> int:
	return mini(14, floori(float(maxi(0, wait - 6)) / 2.0))


func _close_day() -> void:
	cash -= PAYROLL
	var today := 0
	for review in reviews:
		if review.day == day:
			today += 1
	var recap := {"day": day, "stays": today, "cash": cash}
	day_recaps.append(recap)
	if day == FINAL_DAY:
		stopped = true
		milestone = {"stays": reviews.size(), "average": average(), "terrace": terrace, "cash": cash}
	event_happened.emit(&"day_close", recap)
	if not stopped:
		_open_next_day()


func _open_next_day() -> void:
	day += 1
	second = 0
	booked_package = -1
	booked_count = 0
	families.clear()
	rooms.fill(-1)
	if pending_layout:
		var next := pending_layout
		var quote := next.quote_diff(layout, mode == "developer")
		cash += maxi(-quote.net, 0)
		pending_layout = null
		pending_reserve = 0
		_activate_layout(next)
		event_happened.emit(&"construction_applied", {})


func snapshot() -> Dictionary:
	return {
		"meal_version": MEAL_VERSION,
		"leisure_version": LEISURE_VERSION,
		"day": day, "second": second, "cash": cash,
		"selected_package": selected_package, "booked_package": booked_package,
		"float_station": float_station, "terrace": terrace, "stopped": stopped,
		"booked_count": booked_count, "mode": mode, "layout": layout.snapshot(),
		"pending_layout": pending_layout.snapshot() if pending_layout else {},
		"pending_reserve": pending_reserve,
		"families": families.duplicate(true), "rooms": rooms.duplicate(),
		"reviews": reviews.duplicate(true), "day_recaps": day_recaps.duplicate(true),
		"milestone": milestone.duplicate(true),
	}


func restore(data: Dictionary, legacy: bool = false, require_landscape: bool = false, require_meals: bool = false,
		require_leisure: bool = false) -> bool:
	var has_meals := data.has("meal_version")
	if has_meals and (not data.meal_version is int or data.meal_version != MEAL_VERSION):
		return false
	if require_meals and not has_meals:
		return false
	var has_leisure := data.has("leisure_version")
	if has_leisure and (not data.leisure_version is int or data.leisure_version != LEISURE_VERSION):
		return false
	if require_leisure and not has_leisure:
		return false
	for field in ["day", "second", "cash", "selected_package", "booked_package", "float_station"]:
		if not data.get(field) is int:
			return false
	for field in ["terrace", "stopped"]:
		if not data.get(field) is bool:
			return false
	for field in ["families", "rooms", "reviews", "day_recaps"]:
		if not data.get(field) is Array:
			return false
	if not data.get("milestone") is Dictionary:
		return false
	if data.day < 1 or data.second < 0 or data.second > DAY_LENGTH:
		return false
	if data.selected_package not in [0, 1, 2] or data.booked_package not in [-1, 0, 1, 2]:
		return false
	if data.float_station not in [0, 1, 2]:
		return false
	var restored_layout := Layout.new(false)
	var restored_pending: Layout
	var restored_reserve := 0
	var restored_mode := "regular"
	var demand: int = 0 if data.booked_package < 0 else PACKAGES[data.booked_package].bookings
	var restored_count := demand
	if legacy:
		if data.terrace:
			var pool: Dictionary = restored_layout.buildings.back()
			for item in [["lounger", Vector2i(1, 2)], ["lounger", Vector2i(16, 2)], ["umbrella", Vector2i(2, 7)]]:
				restored_layout.add_asset(item[0], pool.id, item[1])
	else:
		if data.get("mode") not in ["regular", "developer"] or not data.get("layout") is Dictionary:
			return false
		if require_landscape and not data.layout.get("landscape") is Dictionary:
			return false
		if not restored_layout.restore(data.layout):
			return false
		restored_mode = data.mode
		if not data.get("booked_count") is int or data.booked_count < 0 or data.booked_count > demand:
			return false
		restored_count = data.booked_count
		if not data.get("pending_layout") is Dictionary or not data.get("pending_reserve") is int:
			return false
		if not data.pending_layout.is_empty():
			if require_landscape and not data.pending_layout.get("landscape") is Dictionary:
				return false
			restored_pending = Layout.new(false)
			if not restored_pending.restore(data.pending_layout):
				return false
			if not data.pending_layout.has("landscape"):
				prune_migrated_scenery(restored_pending, restored_layout)
			if not restored_pending.readiness().ok:
				return false
			var quote := restored_pending.quote_diff(restored_layout, restored_mode == "developer")
			restored_reserve = maxi(quote.net, 0)
		if restored_reserve != data.pending_reserve:
			return false
	var readiness := restored_layout.readiness()
	if not readiness.ok or data.rooms.size() != readiness.room_count or data.terrace != readiness.terrace:
		return false
	if not has_meals or not has_leisure:
		data = data.duplicate(true)
	if not has_meals and not _migrate_meals(data):
		return false
	if not has_leisure and not _migrate_leisure(data):
		return false
	if not _valid_state(data, restored_count, restored_layout):
		return false

	day = data.day
	second = data.second
	cash = data.cash
	selected_package = data.selected_package
	booked_package = data.booked_package
	booked_count = restored_count
	float_station = data.float_station
	mode = restored_mode
	layout = restored_layout
	pending_layout = restored_pending
	pending_reserve = restored_reserve
	terrace = readiness.terrace
	stopped = data.stopped
	families.assign(data.families.duplicate(true))
	rooms.assign(data.rooms)
	reviews.assign(data.reviews.duplicate(true))
	day_recaps.assign(data.day_recaps.duplicate(true))
	milestone = data.milestone.duplicate(true)
	return true


static func prune_migrated_scenery(plan: Layout, active: Layout) -> void:
	# Old plans could uncover baked scenery by demolishing a building. The
	# migration must not introduce a paid prop that was absent from the live run.
	for prop in plan.landscape.props.duplicate():
		if active.landscape.prop_by_id(prop.id).is_empty():
			plan.remove_prop(prop.id)


func _migrate_meals(data: Dictionary) -> bool:
	for family in data.families:
		if not family is Dictionary or family.get("phase") in ["wait_table", "to_table", "eating"]:
			return false
		family.table_id = -1
		family.dining_wait = 0
		if family.get("phase") == "to_pool" or (family.get("phase") == "service" and family.get("station") == 1):
			family.legacy_meal = true
	for review in data.reviews:
		if not review is Dictionary:
			return false
		review.dining_wait = 0
	return true


func _migrate_leisure(data: Dictionary) -> bool:
	for family in data.families:
		if not family is Dictionary or not family.get("phase") is String or family.phase in LEISURE_PHASES:
			return false
		family.merge(LEISURE_DEFAULTS.duplicate(true), true)
		if family.phase in ["return_room", "rest", "to_checkout", "exit", "gone"]:
			family.leisure_step = 3
	for review in data.reviews:
		if not review is Dictionary:
			return false
		review.leisure_bonus = 0
	return true


func _valid_state(data: Dictionary, bookings: int, plan: Layout) -> bool:
	if data.stopped != (data.day == FINAL_DAY and data.second == DAY_LENGTH):
		return false
	if (data.second < OPEN_BOOKINGS) != (data.booked_package == -1):
		return false
	if data.families.size() > bookings:
		return false
	var table_ids := {}
	for table in plan.dining_tables():
		table_ids[table.id] = true
	var occupied := {}
	var reserved_amenities := {}
	var waiting := false
	for i in range(data.families.size()):
		var family: Variant = data.families[i]
		if not _valid_family(family, i, data.second, data.rooms.size(), table_ids):
			return false
		if not _valid_leisure(family, plan):
			return false
		if family.phase in TABLE_RESERVATION_PHASES:
			if occupied.has(family.table_id):
				return false
			occupied[family.table_id] = true
		if family.phase in LEISURE_PHASES:
			var reservation := Vector2i(family.amenity_id, family.leisure_slot)
			if reserved_amenities.has(reservation):
				return false
			reserved_amenities[reservation] = true
		waiting = waiting or family.phase == "wait_table"
	if waiting and occupied.size() < table_ids.size():
		return false
	for i in range(data.rooms.size()):
		var occupant: Variant = data.rooms[i]
		if not occupant is int or occupant < -1 or occupant >= data.families.size():
			return false
		if occupant >= 0:
			var family: Dictionary = data.families[occupant]
			if family.room != i or family.phase in ["exit", "gone"]:
				return false
	for family in data.families:
		if family.room >= 0 and family.phase not in ["exit", "gone"]:
			if data.rooms[family.room] != family.id:
				return false
	for review in data.reviews:
		if not _int_fields(review, ["day", "room", "score", "dining_wait", "leisure_bonus"]):
			return false
		if review.day < 1 or review.day > data.day or review.room < 0 or review.room >= 8:
			return false
		if review.score < 0 or review.score > 100 or review.leisure_bonus < 0 or review.leisure_bonus > 3 or not review.get("note") is String:
			return false
		if not _valid_waits(review.get("waits")) or review.dining_wait < 0 or review.dining_wait >= DAY_LENGTH:
			return false
	for recap in data.day_recaps:
		if not _int_fields(recap, ["day", "stays", "cash"]):
			return false
	if data.day >= FINAL_DAY and (data.stopped or data.day > FINAL_DAY):
		if not _int_fields(data.milestone, ["stays", "cash"]):
			return false
		if not data.milestone.get("terrace") is bool or not data.milestone.get("average") is float:
			return false
		if not is_finite(data.milestone.average):
			return false
	return true


func _kind_step(kind: String) -> int:
	match kind:
		"beach_lounge", "volleyball":
			return 1
		"beach_bar":
			return 2
		"stage":
			return 3
	return 0


func _valid_leisure(family: Dictionary, plan: Layout) -> bool:
	if not _int_fields(family, ["amenity_id", "leisure_slot", "leisure_step", "leisure_origin_id", "leisure_origin_slot"]):
		return false
	if not family.get("leisure_kind") is String or not family.get("leisure_completed") is Array:
		return false
	if family.leisure_step < 0 or family.leisure_step > 3:
		return false
	var last_step := 0
	for kind in family.leisure_completed:
		if not kind is String:
			return false
		var step := _kind_step(kind)
		if step <= last_step or step > family.leisure_step:
			return false
		last_step = step
	if family.phase not in LEISURE_PHASES:
		if family.leisure_step > 0 and family.phase not in ["return_room", "rest", "to_checkout", "exit", "gone"]:
			return false
		return (family.amenity_id == -1 and family.leisure_slot == -1 and family.leisure_kind.is_empty()
			and family.leisure_origin_id == -1 and family.leisure_origin_slot == -1)
	var amenity := plan.amenity_by_id(family.amenity_id)
	if amenity.is_empty() or amenity.kind != family.leisure_kind or _kind_step(family.leisure_kind) != family.leisure_step:
		return false
	if family.leisure_slot < 0 or family.leisure_slot >= amenity.capacity:
		return false
	if (family.phase == "from_leisure") != (family.leisure_kind in family.leisure_completed):
		return false
	var origin: Vector2 = plan.station_point(2)
	if family.leisure_step == 3:
		origin = plan.room_points()[family.room]
		var departure: int = family.since
		if family.phase != "to_leisure":
			departure -= LEISURE_WALK_DURATION
		if family.phase == "from_leisure":
			departure -= LEISURE_DURATIONS.stage
		if departure < SHOW_START or departure > SHOW_LAST_ENTRY:
			return false
	if family.leisure_origin_id != -1:
		var prior := plan.amenity_by_id(family.leisure_origin_id)
		if prior.is_empty() or family.leisure_step != 2 or prior.kind not in ["beach_lounge", "volleyball"]:
			return false
		if prior.kind not in family.leisure_completed or family.leisure_origin_slot < 0 or family.leisure_origin_slot >= prior.capacity:
			return false
		origin = prior.point
	elif family.leisure_origin_slot != -1 or (family.leisure_step == 2 and not family.leisure_completed.is_empty() and _kind_step(family.leisure_completed[0]) == 1):
		return false
	var activity_duration: int = LEISURE_DURATIONS[family.leisure_kind]
	var duration := activity_duration if family.phase == "leisure" else LEISURE_WALK_DURATION
	var remaining := 0
	match family.phase:
		"to_leisure":
			remaining = activity_duration + LEISURE_WALK_DURATION
		"leisure":
			remaining = LEISURE_WALK_DURATION
	if family.until - family.since != duration or family.until + remaining > _checkout_time(family):
		return false
	var room := plan.room_points()[family.room]
	return not plan.route(origin, amenity.point).is_empty() and not plan.route(amenity.point, room).is_empty()


func _valid_family(family: Variant, index: int, at_second: int, room_count: int, table_ids: Dictionary) -> bool:
	if not _int_fields(family, ["id", "room", "station", "since", "until", "joined", "slot", "table_id", "dining_wait"]):
		return false
	if family.id != index or family.room < -1 or family.room >= 8 or family.station not in [0, 1, 2]:
		return false
	if family.get("phase") not in PHASES or not family.get("upgraded_swim") is bool:
		return false
	if family.phase != "gone" and family.room >= room_count:
		return false
	if family.since < 0 or family.since > at_second or family.joined < 0 or family.joined > at_second:
		return false
	if family.slot not in [-1, 0, 1, 2] or not _valid_waits(family.get("waits")):
		return false
	if family.dining_wait < 0 or family.dining_wait > family.since:
		return false
	if family.has("legacy_meal") and (not family.legacy_meal is bool or not family.legacy_meal):
		return false
	var legacy_meal: bool = family.has("legacy_meal")
	var collecting: bool = family.phase == "service" and family.station == 1
	var duration: int = family.until - family.since
	if legacy_meal and not (collecting or family.phase == "to_pool"):
		return false
	if collecting and (family.since - family.joined != family.waits[1] or duration != (LEGACY_BUFFET_DURATION if legacy_meal else DURATIONS[1])):
		return false
	var table_phase: bool = family.phase in TABLE_RESERVATION_PHASES or (family.phase == "to_pool" and not legacy_meal)
	if table_phase:
		if not table_ids.has(family.table_id) or family.slot != -1:
			return false
		var after_seating: int = {"to_table": 0, "eating": TABLE_WALK_DURATION, "to_pool": TABLE_WALK_DURATION + EAT_DURATION}[family.phase]
		var collection_duration: int = family.since - after_seating - family.dining_wait - family.joined - family.waits[1]
		if collection_duration not in [DURATIONS[1], LEGACY_BUFFET_DURATION] or duration != (EAT_DURATION if family.phase == "eating" else TABLE_WALK_DURATION):
			return false
	elif family.table_id != -1:
		return false
	match family.phase:
		"queue", "service":
			if (family.room == -1) != (family.station == 0):
				return false
		"to_room", "settle", "to_buffet":
			if family.room < 0 or family.station != 0:
				return false
		"wait_table", "to_table", "eating", "to_pool":
			if family.room < 0 or family.station != 1:
				return false
		_:
			if family.room < 0 or family.station != 2:
				return false
	if not table_phase and family.station < 2 and family.dining_wait != 0:
		return false
	if family.phase == "wait_table":
		var collection_duration: int = family.since - family.joined - family.waits[1]
		return family.until == -1 and family.slot == -1 and collection_duration in [DURATIONS[1], LEGACY_BUFFET_DURATION]
	if family.phase in ["queue", "rest", "gone"]:
		return family.until == -1
	if legacy_meal and family.phase == "to_pool" and (duration != 4 or family.since - family.joined - family.waits[1] != LEGACY_BUFFET_DURATION):
		return false
	return family.until > at_second and family.until < DAY_LENGTH and (family.slot >= 0 or table_phase)


func _int_fields(value: Variant, keys: Array) -> bool:
	if not value is Dictionary:
		return false
	for key in keys:
		if not value.get(key) is int:
			return false
	return true


func _valid_waits(value: Variant) -> bool:
	if not value is Array or value.size() != STATIONS.size():
		return false
	for wait in value:
		if not wait is int or wait < 0:
			return false
	return true
