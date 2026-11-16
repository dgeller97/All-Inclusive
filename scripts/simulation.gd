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
const BEACH_VERSION := 1
const COAST_VERSION := 1
const OCEAN_WALK_DURATION := 8
const OCEAN_WADE_DURATION := 2
const OCEAN_SWIM_DURATION := 14
const OCEAN_PHASES := ["to_ocean", "ocean_swim", "from_ocean", "evacuate"]
const SWIM_POLICIES := ["safe", "allow_red", "closed"]
const OCEAN_DEFAULTS := {"ocean_return_wet": false, "ocean_red_seconds": 0,
	"ocean_fatality": false, "ocean_completed": false, "beach_exposure": 0}
const BEACH_CLEAN_COST := 30
const LIFEGUARD_HIRE_COST := 60
const LIFEGUARD_PAYROLL := 25
const LIFEGUARD_SITES := ["beach", "pool"]
const RESCUE_REACH := 2
const RESCUE_TOW := 3
const RESCUE_RESET := 1
const RESCUE_DURATION := RESCUE_REACH + RESCUE_TOW + RESCUE_RESET
const MIN_PRICE := 90
const MAX_PRICE := 200
const PRICE_STEP := 5
const LEISURE_WALK_DURATION := 4
const SHOW_START := 180
const SHOW_LAST_ENTRY := 191
const Layout = preload("res://scripts/layout_model.gd")
const DeveloperShowcase = preload("res://scripts/developer_showcase.gd")
const FACILITY_CATALOG = Layout.Landscape.PROP_CATALOG
const STARTER_LEISURE := ["beach_lounge", "volleyball", "beach_bar", "stage"]
const DAYTIME_LEISURE := ["volleyball", "beach_lounge", "lap_pool", "lagoon_pool", "hot_tub", "kids_pool",
	"waterpark", "basketball", "climbing_wall", "arcade"]
const REFRESHMENTS := ["beach_bar", "cafe"]
const NIGHTLIFE := ["stage", "nightclub"]
const LEISURE_DURATIONS := {
	"beach_lounge": FACILITY_CATALOG.beach_lounge.duration, "volleyball": FACILITY_CATALOG.volleyball.duration,
	"beach_bar": FACILITY_CATALOG.beach_bar.duration, "stage": FACILITY_CATALOG.stage.duration,
	"lap_pool": FACILITY_CATALOG.lap_pool.duration, "lagoon_pool": FACILITY_CATALOG.lagoon_pool.duration,
	"hot_tub": FACILITY_CATALOG.hot_tub.duration, "kids_pool": FACILITY_CATALOG.kids_pool.duration,
	"waterpark": FACILITY_CATALOG.waterpark.duration, "basketball": FACILITY_CATALOG.basketball.duration,
	"climbing_wall": FACILITY_CATALOG.climbing_wall.duration, "arcade": FACILITY_CATALOG.arcade.duration,
	"cafe": FACILITY_CATALOG.cafe.duration, "nightclub": FACILITY_CATALOG.nightclub.duration,
}
const LEISURE_PHASES := ["to_leisure", "leisure", "from_leisure"]
const LEISURE_NOTES := {
	"beach_lounge": "Loved the shaded beach loungers",
	"volleyball": "Had fun at beach volleyball",
	"beach_bar": "Enjoyed the beach bar mocktails",
	"stage": "Loved the evening show",
	"lap_pool": "Swam laps in the resort pool",
	"lagoon_pool": "Relaxed in the lagoon pool",
	"hot_tub": "Enjoyed the hot tub",
	"kids_pool": "The kids loved the shallow pool",
	"waterpark": "Had fun on the water slides",
	"basketball": "Played basketball together",
	"climbing_wall": "Tried the rock climbing wall",
	"arcade": "Had fun playing arcade games",
	"cafe": "Enjoyed a stop at the cafe",
	"nightclub": "Loved the music at the nightclub",
}
const Calendar = preload("res://scripts/resort_calendar.gd")
const Ocean = preload("res://scripts/ocean.gd")
const Sargassum := preload("res://scripts/sargassum_model.gd")
const AmenityArt := preload("res://scripts/amenity_renderer.gd")
const STATIONS := ["reception", "buffet", "pool"]
const DURATIONS := [8, 6, 20]
const PHASES := ["queue", "service", "to_room", "settle", "to_buffet", "wait_table", "to_table", "eating", "to_pool",
	"return_room", "rest", "to_checkout", "exit", "gone", "water_rescue"] + LEISURE_PHASES + OCEAN_PHASES
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
var selected_price := 120
var booked_price := 0
var booked_value := 0.0
var selected_package := 1:
	set(index):
		selected_package = clampi(index, 0, PACKAGES.size() - 1)
		selected_price = PACKAGES[selected_package].price
var booked_package := -1
var booked_count := 0
var beach_deposits: Array[Dictionary] = []
var sargassum: int:
	get:
		return Sargassum.amount(beach_deposits)
	set(amount):
		# Existing fixture and save callers can still supply a legacy buildup amount.
		beach_deposits = Sargassum.legacy_deposits(amount)
var sargassum_intensity := -1
var sargassum_seed := Sargassum.DEFAULT_SEED
var _developer_month_offset := -1
var _offshore: Array[Dictionary] = []
var swim_policy := "safe"
var ocean_incidents: Array[Dictionary] = []
var lifeguard_assignment := ""
var rescue := {}
var last_rescue := {}
var float_station := 1
var mode := "regular"
var showcase_enabled := false
var showcase_coverage: Array[String] = []
var _can_configure_new_run := true
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
	_offshore = Sargassum.births(0, 1, sargassum_seed, sargassum_intensity)


func configure_new_run(selected_mode: String) -> bool:
	if not _can_configure_new_run or day != 1 or second != 0 or pending_layout != null or selected_mode not in ["regular", "developer"]:
		return false
	if selected_mode == "developer":
		var next_id := Layout._next_id
		var next_prop_id := Layout.Landscape._next_prop_id
		var plan := DeveloperShowcase.build(layout)
		if plan == null:
			Layout._next_id = next_id
			Layout.Landscape._next_prop_id = next_prop_id
			return false
		layout = plan
		_reset_room_slots()
		showcase_enabled = true
	mode = selected_mode
	_can_configure_new_run = false
	return true


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
	return bookings_for_price(PACKAGES[package].price)


func set_price(price: int) -> void:
	price = roundi(float(clampi(price, MIN_PRICE, MAX_PRICE)) / PRICE_STEP) * PRICE_STEP
	selected_package = _price_tier(price)
	selected_price = price


static func price_value(price: int) -> float:
	return float(120 - price) / 6.0 if price <= 120 else float(120 - price) * 0.24


static func _price_tier(price: int) -> int:
	if price < 105:
		return 0
	return 1 if price < 150 else 2


static func price_demand(price: int) -> int:
	return 4 if price < 150 else 3


func bookings_for_price(price: int) -> int:
	return mini(price_demand(price), rooms.size())


func calendar_state() -> Dictionary:
	return Calendar.state(day + maxi(0, _developer_month_offset), second)


func _world_clock(visual_second: float = NAN) -> float:
	return float(day - 1) * DAY_LENGTH + (float(second) if is_nan(visual_second) else visual_second)


func environment_time(visual_second: float = NAN) -> float:
	return _world_clock(visual_second) + maxi(0, _developer_month_offset) * DAY_LENGTH


func developer_month() -> int:
	return 0 if _developer_month_offset < 0 else calendar_state().month


func set_developer_month(month: int) -> bool:
	if mode != "developer" or month < 0 or month > 12:
		return false
	if month == developer_month():
		return true
	var year_days := 12 * Calendar.DAYS_PER_MONTH
	var requested_day := posmod(month - Calendar.START_MONTH, 12) * Calendar.DAYS_PER_MONTH + 1
	_developer_month_offset = -1 if month == 0 else posmod(requested_day - (day - 1), year_days)
	_seed_current_cohort()
	return true


func set_developer_sargassum_intensity(amount: int) -> bool:
	if mode != "developer" or amount < -1 or amount > 100:
		return false
	if amount != sargassum_intensity:
		sargassum_intensity = amount
		_seed_current_cohort()
	return true


func floating_sargassum(visual_second: float = NAN) -> Array[Dictionary]:
	return Sargassum.sample(_offshore, _world_clock(visual_second))


func seed_sargassum_arrival() -> bool:
	if mode != "developer":
		return false
	var patch := Sargassum.raft(int(_world_clock()), Sargassum.FORCED_LANE, sargassum_seed)
	return _add_offshore(patch)


func _seed_current_cohort() -> void:
	var now := int(_world_clock())
	# Seed freshly born rafts at a setting change without calculating past landfalls.
	for patch in Sargassum.births(now, day + maxi(0, _developer_month_offset), sargassum_seed, sargassum_intensity, true):
		_add_offshore(patch)


func _add_offshore(patch: Dictionary) -> bool:
	for existing in _offshore:
		if existing.id == patch.id:
			return false
	_offshore.append(patch)
	return true


func _advance_sargassum() -> void:
	var clock := int(_world_clock())
	for index in range(_offshore.size() - 1, -1, -1):
		var patch := _offshore[index]
		if patch.lands_at <= clock:
			Sargassum.deposit(beach_deposits, patch.row, patch.mass)
			_offshore.remove_at(index)
	var climate_day := floori(environment_time() / DAY_LENGTH) + 1
	for patch in Sargassum.births(clock, climate_day, sargassum_seed, sargassum_intensity):
		_offshore.append(patch)


func surf_condition() -> int:
	return Ocean.condition_at(float(day - 1) * DAY_LENGTH + second)


func set_swim_policy(policy: String) -> bool:
	if policy not in SWIM_POLICIES:
		return false
	swim_policy = policy
	if not _can_enter_ocean():
		for family in families:
			if family.phase == "ocean_swim":
				_return_from_ocean(family, second - family.since > 0)
	return true


func clean_beach() -> Dictionary:
	var available := cash if mode == "regular" else 0
	var cost := BEACH_CLEAN_COST if mode == "regular" else 0
	if sargassum == 0:
		return {"ok": false, "reason": "The beach is already clear.", "cost": 0, "removed": 0}
	if available < cost:
		return {"ok": false, "reason": "Beach cleaning costs $%d." % cost, "cost": 0, "removed": 0}
	var before := sargassum
	Sargassum.remove(beach_deposits, 60 * Sargassum.UNITS_PER_PERCENT)
	var removed := before - sargassum
	cash -= cost
	return {"ok": true, "reason": "", "cost": cost, "removed": removed}


func lifeguard_payroll() -> int:
	return LIFEGUARD_PAYROLL if mode == "regular" and not lifeguard_assignment.is_empty() else 0


func lifeguard_site_available(site: String) -> bool:
	return not lifeguard_post(site).is_empty()


func lifeguard_post(site: String) -> Dictionary:
	return _lifeguard_post(layout, site)


func _lifeguard_post(plan: Layout, site: String) -> Dictionary:
	if site not in LIFEGUARD_SITES:
		return {}
	var entry := plan.station_point(2)
	var away := Vector2.LEFT
	var wet_direction := Vector2.RIGHT
	if site == "beach":
		var access := plan.ocean_access()
		if access.is_empty():
			return {}
		entry = access.shore
		wet_direction = (access.water as Vector2) - entry
	else:
		var pool := _pool_geometry(plan)
		if pool.is_empty():
			return {}
		away = pool.exit_direction
		wet_direction = (pool.water as Rect2).get_center() - entry
	if not entry.is_finite() or plan.route(Layout.ENTRY, entry).is_empty():
		return {}
	var grid := float(Layout.GRID)
	var side := away.orthogonal()
	var candidates := [away * 2.0, side * 2.0, side * -2.0, away + side, away - side]
	if site == "pool":
		# Favor open pool deck beside the exit over a seat outside the deck.
		candidates = [side * -2.0, side * 2.0, away * 2.0, away + side, away - side]
	for offset: Vector2 in candidates:
		var origin := entry + offset * grid
		var path := plan.route(origin, entry)
		# The guard's approach must meet the swimmers from the land side.
		if path.size() >= 2 and path.size() <= 5 and (path[-2] - entry).dot(wet_direction) <= 0.0 \
				and plan.landscape.rect_is_dry(Rect2(origin - Vector2(3, 3), Vector2(6, 6))):
			return {"origin": origin, "entry": entry}
	return {}


func hire_lifeguard(site: String) -> bool:
	var cost := LIFEGUARD_HIRE_COST if mode == "regular" else 0
	if not lifeguard_assignment.is_empty() or (cost > 0 and cash < cost) or not lifeguard_site_available(site):
		return false
	cash -= cost
	lifeguard_assignment = site
	return true


func assign_lifeguard(site: String) -> bool:
	if lifeguard_assignment.is_empty() or not rescue.is_empty() or not lifeguard_site_available(site):
		return false
	lifeguard_assignment = site
	return true


func can_start_rescue_drill() -> bool:
	return mode == "developer" and not stopped and rescue.is_empty() and second + RESCUE_DURATION < DAY_LENGTH \
		and lifeguard_site_available(lifeguard_assignment)


func start_rescue_drill() -> bool:
	if not can_start_rescue_drill():
		return false
	var site := lifeguard_assignment
	for family in families:
		var swimmer: bool = family.phase == "ocean_swim" if site == "beach" else family.phase == "service" and family.station == 2
		if swimmer and second - family.since >= OCEAN_WADE_DURATION and family.until - second >= 3 \
				and second + RESCUE_DURATION + OCEAN_WALK_DURATION < _checkout_time(family):
			return _begin_rescue(site, family, true)
	return _begin_rescue(site, {}, true)


func _pool_geometry(plan: Layout) -> Dictionary:
	for building in plan.buildings:
		if building.kind == "pool":
			return {"water": plan.water_rect(building), "rotation": int(building.rotation), "exit_direction": plan.door_side(building)}
	return {}


func _swimmer_targets(plan: Layout, site: String, family_id: int, slot: int, at: int) -> Dictionary:
	if site == "beach":
		var access := plan.ocean_access()
		var lane := posmod(family_id, 4)
		var desired := (access.water as Vector2) + Vector2(lane * 3, [0, -12, 12, 20][lane])
		return {"target": _ocean_swim_target(desired), "child_target": _ocean_swim_target(desired + Vector2(-7, 8))}
	var pool := _pool_geometry(plan)
	var water: Rect2 = pool.water
	var rotation: int = pool.rotation
	var size := water.size if rotation % 2 == 0 else Vector2(water.size.y, water.size.x)
	var x := 10.0 + (size.x - 20.0) * (float(slot) + 1.0) / 4.0
	var local := Vector2(x + sin(at * 1.4 + family_id) * 3.0, size.y * 0.5)
	return {"target": AmenityArt.ground_point(water.position, size, rotation, local),
		"child_target": AmenityArt.ground_point(water.position, size, rotation, local + Vector2(-6, 4))}


func _ocean_swim_target(point: Vector2) -> Vector2:
	var terrain := Layout.Landscape
	var shore := terrain.coastline()
	var row := clampi(floori(point.y) - terrain.WORLD_ORIGIN.y, 0, shore.size() - 1)
	return Vector2(clampf(point.x, shore[row] + 7.0, terrain.WORLD_BOUNDS.end.x - 9.0), point.y)


func _rescue_record(plan: Layout, site: String, at_day: int, at: int, family_id: int, slot: int, drill: bool) -> Dictionary:
	var post := _lifeguard_post(plan, site)
	if post.is_empty():
		return {}
	var targets := _swimmer_targets(plan, site, maxi(0, family_id), maxi(0, slot), at)
	return {"day": at_day, "family": family_id, "slot": slot, "site": site, "phase": "swim_out",
		"started_at": at, "contact_at": at + RESCUE_REACH, "drop_at": at + RESCUE_REACH + RESCUE_TOW,
		"finished_at": at + RESCUE_DURATION, "origin": post.origin, "entry": post.entry,
		"target": targets.target, "child_target": targets.child_target, "drill": drill}


func _begin_rescue(site: String, family: Dictionary, drill: bool) -> bool:
	if lifeguard_assignment != site or not rescue.is_empty() or second + RESCUE_DURATION >= DAY_LENGTH:
		return false
	var record := _rescue_record(layout, site, day, second, family.get("id", -1), family.get("slot", -1), drill)
	if record.is_empty():
		return false
	rescue = record
	if not family.is_empty():
		_transition(family, "water_rescue", RESCUE_DURATION)
	event_happened.emit(&"rescue_started", rescue.duplicate())
	return true


func rescue_positions(visual_second: float = NAN) -> Dictionary:
	if rescue.is_empty():
		return {}
	var now := float(second) if is_nan(visual_second) else visual_second
	var entry: Vector2 = rescue.entry
	var target: Vector2 = rescue.target
	var start: int = rescue.started_at
	var contact: int = rescue.contact_at
	var drop: int = rescue.drop_at
	var at_walk := start + 0.65
	var guard := entry
	var victim := target
	var path := layout.route(rescue.origin, entry)
	var route_length := float(maxi(1, path.size() - 1) * Layout.GRID)
	var tow_lead := 12.0
	var reset_start := 1.0 - minf(1.0, tow_lead / route_length)
	var child_shore := _path_position(path, 0.6)
	if path.size() >= 2:
		var side := (path[-2] - entry).orthogonal()
		for offset: Vector2 in [side, -side]:
			var handoff := entry + offset
			if not layout.route(entry, handoff).is_empty():
				child_shore = handoff
				break
	var child := (rescue.child_target as Vector2).lerp(child_shore, clampf((now - start) / (drop - start), 0.0, 1.0))
	if now < at_walk:
		guard = _path_position(path, clampf((now - start) / 0.65, 0.0, 1.0))
	elif now < contact:
		guard = entry.lerp(target.move_toward(entry, tow_lead), inverse_lerp(at_walk, contact, now))
	elif now < drop:
		victim = target.lerp(entry, inverse_lerp(contact, drop, now))
		var sea_distance := victim.distance_to(entry)
		if sea_distance >= tow_lead:
			guard = victim.move_toward(entry, tow_lead)
		else:
			guard = _path_position(path, 1.0 - (tow_lead - sea_distance) / route_length)
	else:
		victim = entry
		var reset := clampf((now - drop) / RESCUE_RESET, 0.0, 1.0)
		guard = _path_position(path, reset_start * (1.0 - reset))
		child = child_shore.lerp(entry, reset)
	var water: Rect2 = _pool_geometry(layout).get("water", Rect2())
	var in_water := func(point: Vector2) -> bool:
		return layout.landscape.is_water_pixel(point) if rescue.site == "beach" else water.has_point(point)
	return {"guard": guard, "victim": victim, "child": child, "guard_swim": in_water.call(guard),
		"victim_swim": in_water.call(victim), "child_swim": in_water.call(child),
		"phase": "swim_out" if now < contact else "tow", "site": rescue.site, "family": rescue.family, "drill": rescue.drill}


func _path_position(path: PackedVector2Array, progress: float) -> Vector2:
	if path.is_empty():
		return rescue.entry
	if path.size() == 1:
		return path[0]
	var scaled := progress * (path.size() - 1)
	var step := mini(floori(scaled), path.size() - 2)
	return path[step].lerp(path[step + 1], scaled - step)


func _advance_rescue() -> void:
	if rescue.is_empty():
		return
	if second < int(rescue.finished_at):
		if second >= int(rescue.contact_at):
			rescue.phase = "tow"
		return
	if rescue.family >= 0:
		var family := families[int(rescue.family)]
		if rescue.site == "beach":
			family.beach_rescued = true
			_return_from_ocean(family, false)
		else:
			_transition(family, "return_room", 4)
	var outcome := "drill_complete" if rescue.drill else "rescued"
	var completed := _rescue_outcome(rescue.site, rescue.family, outcome, rescue.drill)
	rescue.clear()
	event_happened.emit(&"rescue_finished", completed.duplicate())


func _rescue_outcome(site: String, family_id: int, outcome: String, drill: bool = false) -> Dictionary:
	last_rescue = {"day": day, "second": second, "site": site, "family": family_id, "outcome": outcome, "drill": drill}
	return last_rescue


func _update_pool_swim(family: Dictionary) -> bool:
	# An occasional adult cramp after the opening milestone. Untended pool
	# guests make their own way out. The deeper red-flag surf has a different risk.
	if day <= FINAL_DAY or day % 3 != 1 or family.id != posmod(day / 3, maxi(1, booked_count)) or second - family.since != 6:
		return false
	if _begin_rescue("pool", family, false):
		return true
	family.pool_self_recovered = true
	_transition(family, "return_room", 4)
	var completed := _rescue_outcome("pool", family.id, "self_recovered")
	event_happened.emit(&"rescue_finished", completed.duplicate())
	return true


func must_defer_construction() -> bool:
	if not rescue.is_empty():
		return true
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
	_advance_sargassum()
	if second >= DAY_LENGTH:
		_close_day()
		return
	_advance_rescue()

	if second == OPEN_BOOKINGS:
		booked_package = selected_package
		booked_price = selected_price
		booked_value = price_value(booked_price)
		booked_count = bookings_for_price(booked_price)
		event_happened.emit(&"bookings", {"count": booked_count})
	var arrival_index := second - OPEN_BOOKINGS
	if booked_package >= 0 and arrival_index >= 0 and arrival_index % 6 == 0:
		if arrival_index < booked_count * 6:
			_arrive()

	for family in families:
		if family.phase == "ocean_swim" and _update_ocean_swim(family):
			continue
		if family.phase == "service" and family.station == 2 and _update_pool_swim(family):
			continue
		if family.until == second:
			_advance(family)
		if family.phase == "rest":
			if second >= _checkout_time(family):
				_transition(family, "to_checkout", 4)
			elif second >= SHOW_START and second <= SHOW_LAST_ENTRY and family.leisure_step < 3:
				family.leisure_step = 3
				_start_leisure_choice(family, NIGHTLIFE, layout.room_points()[family.room])
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
	family.merge(OCEAN_DEFAULTS)
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
			if family.station == station and (family.phase == "service" or (station == 2 and family.phase == "water_rescue" and rescue.get("site") == "pool")):
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
	family.leisure_step = 1
	if _start_leisure_choice(family, DAYTIME_LEISURE, pool):
		return
	family.leisure_step = 2
	if not _start_leisure_choice(family, REFRESHMENTS, pool):
		_transition(family, "return_room", LEISURE_WALK_DURATION)


func _start_leisure_choice(family: Dictionary, kinds: Array, origin: Vector2, origin_id: int = -1) -> bool:
	var offered: Array[String] = []
	for kind in kinds:
		if not layout.amenities(kind).is_empty():
			offered.append(kind)
	var ordered: Array[String] = []
	var already_visiting := {}
	if showcase_enabled:
		for guest in families:
			if guest.phase in LEISURE_PHASES:
				already_visiting[guest.leisure_kind] = true
	var repeat_visits: Array[String] = []
	for index in range(offered.size()):
		var choice := offered[posmod(day + family.id + index, offered.size())]
		if showcase_enabled and (choice in showcase_coverage or already_visiting.has(choice)):
			repeat_visits.append(choice)
		else:
			ordered.append(choice)
	ordered.append_array(repeat_visits)
	for choice in ordered:
		if _start_leisure(family, choice, origin, origin_id):
			return true
	return false


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
	if showcase_enabled and family.leisure_kind not in showcase_coverage:
		showcase_coverage.append(family.leisure_kind)
	if family.leisure_kind in ["beach_lounge", "volleyball", "beach_bar"]:
		family.beach_exposure = maxi(family.beach_exposure, sargassum)
	if family.leisure_step == 1:
		var amenity := layout.amenity_by_id(family.amenity_id)
		family.leisure_step = 2
		if not amenity.is_empty() and _start_leisure_choice(family, REFRESHMENTS, amenity.point, amenity.id):
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
	if family.leisure_step == 3 or not _start_ocean(family):
		_transition(family, "rest")


func _can_enter_ocean() -> bool:
	return swim_policy != "closed" and (surf_condition() != Ocean.Condition.CLOSED or swim_policy == "allow_red")


func _start_ocean(family: Dictionary) -> bool:
	var duration := OCEAN_WALK_DURATION * 2 + OCEAN_WADE_DURATION + OCEAN_SWIM_DURATION
	if second + duration > mini(_checkout_time(family), SHOW_START):
		return false
	if not _can_enter_ocean():
		return false
	var access := layout.ocean_access()
	if access.is_empty() or layout.route(layout.room_points()[family.room], access.shore).is_empty():
		return false
	_transition(family, "to_ocean", OCEAN_WALK_DURATION)
	return true


func _return_from_ocean(family: Dictionary, wet: bool, evacuated: bool = false) -> void:
	family.ocean_return_wet = wet
	_transition(family, "evacuate" if evacuated else "from_ocean", OCEAN_WALK_DURATION + (OCEAN_WADE_DURATION if wet else 0))


func _red_risk_limit(stay_day: int, family_id: int) -> int:
	# Stable per booking so reloading cannot reroll exposure already incurred.
	return 2 + posmod((stay_day % 23) * 31 + family_id * 17, 23)


func _update_ocean_swim(family: Dictionary) -> bool:
	var wet: bool = second - family.since > 0
	if not _can_enter_ocean():
		_return_from_ocean(family, wet)
		return true
	if not wet or surf_condition() != Ocean.Condition.CLOSED:
		return false
	family.ocean_red_seconds += 1
	if family.ocean_red_seconds < _red_risk_limit(day, family.id):
		return false
	if _begin_rescue("beach", family, false):
		# The incident threshold signals distress; successful interception
		# never marks the family as a fatality.
		family.ocean_red_seconds -= 1
		return true
	family.ocean_fatality = true
	_rescue_outcome("beach", family.id, "fatal")
	var incident := {"day": day, "second": second, "family": family.id, "room": family.room}
	ocean_incidents.append(incident)
	reviews.append({"day": day, "room": family.room, "score": 0, "note": "A guest drowned in red-flag surf",
		"waits": family.waits.duplicate(), "dining_wait": family.dining_wait, "leisure_bonus": 0,
		"ocean_fatality": true, "family": family.id, "seaweed_penalty": 0, "price": booked_price, "price_value": booked_value})
	_return_from_ocean(family, true, true)
	event_happened.emit(&"ocean_incident", incident)
	return true


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
					cash += booked_price
					_transition(family, "to_room", 4)
					event_happened.emit(&"checkin", {"room": room, "price": booked_price})
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
			if not _start_ocean(family):
				_transition(family, "rest")
		"to_leisure":
			_transition(family, "leisure", LEISURE_DURATIONS[family.leisure_kind])
		"leisure":
			_finish_leisure(family)
		"from_leisure":
			_return_from_leisure(family)
		"to_ocean":
			if _can_enter_ocean():
				family.beach_exposure = maxi(family.beach_exposure, sargassum)
				_transition(family, "ocean_swim", OCEAN_SWIM_DURATION)
			else:
				_return_from_ocean(family, false)
		"ocean_swim":
			family.ocean_completed = true
			family.beach_exposure = maxi(family.beach_exposure, sargassum)
			_return_from_ocean(family, true)
		"from_ocean":
			family.ocean_return_wet = false
			_transition(family, "rest")
		"evacuate":
			rooms[family.room] = -1
			family.ocean_return_wet = false
			_transition(family, "gone")
		"to_checkout":
			_checkout(family)
			_transition(family, "exit", 4)
		"exit":
			_transition(family, "gone")


func _checkout(family: Dictionary) -> void:
	rooms[family.room] = -1
	var leisure_bonus := mini(3, family.leisure_completed.size())
	var seaweed_penalty := maxi(0, floori(float(family.beach_exposure - 20) / 5.0))
	var score := roundi(92.0 + booked_value) + (8 if family.upgraded_swim else 0) + leisure_bonus - seaweed_penalty
	if family.get("pool_self_recovered", false):
		score -= 5
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
	if seaweed_penalty > 0 and seaweed_penalty >= maxi(dining_penalty, longest_penalty):
		note = "Sargassum affected the beach visit"
	elif dining_penalty > 0 and dining_penalty >= longest_penalty:
		note = "Long dining table wait"
	elif station_index >= 0:
		note = "Long %s line" % STATIONS[station_index]
	elif family.get("pool_self_recovered", false):
		note = "Needed help at the pool"
	elif family.upgraded_swim:
		note = "Loved the pool terrace"
	elif not family.leisure_completed.is_empty():
		note = LEISURE_NOTES[family.leisure_completed.back()]
	elif booked_value > 0:
		note = "Great value for the family"
	elif booked_value <= -7.2:
		note = "A premium family stay"
	else:
		note = "Good value for the family"
	var review := {
		"day": day, "room": family.room, "score": clampi(score, 0, 100),
		"note": note, "waits": family.waits.duplicate(), "dining_wait": family.dining_wait,
		"leisure_bonus": leisure_bonus,
		"seaweed_penalty": seaweed_penalty, "price": booked_price, "price_value": booked_value,
	}
	reviews.append(review)
	event_happened.emit(&"review", review)


func _wait_penalty(wait: int) -> int:
	return mini(14, floori(float(maxi(0, wait - 6)) / 2.0))


func _close_day() -> void:
	var payroll := PAYROLL + lifeguard_payroll()
	cash -= payroll
	Sargassum.wash(beach_deposits)
	var today := 0
	for review in reviews:
		if review.day == day and not review.get("ocean_fatality", false):
			today += 1
	var recap := {"day": day, "stays": today, "cash": cash}
	day_recaps.append(recap)
	if day == FINAL_DAY:
		stopped = true
		milestone = {"stays": reviews.size() - ocean_incidents.size(), "average": average(), "terrace": terrace, "cash": cash}
	var details := recap.duplicate()
	details.payroll = payroll
	event_happened.emit(&"day_close", details)
	if not stopped:
		_open_next_day()


func _open_next_day() -> void:
	day += 1
	second = 0
	booked_package = -1
	booked_price = 0
	booked_value = 0.0
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
	var data := {
		"meal_version": MEAL_VERSION,
		"leisure_version": LEISURE_VERSION,
		"beach_version": BEACH_VERSION,
		"coast_runtime": {
			"version": COAST_VERSION, "month_offset": _developer_month_offset,
			"intensity": sargassum_intensity, "seed": sargassum_seed,
			"deposits": beach_deposits.duplicate(true), "offshore": _offshore.duplicate(true),
			"assignment": lifeguard_assignment, "rescue": rescue.duplicate(true), "last_rescue": last_rescue.duplicate(true),
		},
		"day": day, "second": second, "cash": cash,
		"selected_package": selected_package, "booked_package": booked_package,
		"selected_price": selected_price, "booked_price": booked_price, "booked_value": booked_value,
		"sargassum": sargassum, "swim_policy": swim_policy, "ocean_incidents": ocean_incidents.duplicate(true),
		"float_station": float_station, "terrace": terrace, "stopped": stopped,
		"booked_count": booked_count, "mode": mode, "layout": layout.snapshot(),
		"pending_layout": pending_layout.snapshot() if pending_layout else {},
		"pending_reserve": pending_reserve,
		"families": families.duplicate(true), "rooms": rooms.duplicate(),
		"reviews": reviews.duplicate(true), "day_recaps": day_recaps.duplicate(true),
		"milestone": milestone.duplicate(true),
	}
	if showcase_enabled:
		data.developer_showcase = {"completed": showcase_coverage.duplicate()}
	return data


func restore(data: Dictionary, legacy: bool = false, require_landscape: bool = false, require_meals: bool = false,
		require_leisure: bool = false, require_beach: bool = false) -> bool:
	var next_id := Layout._next_id
	var next_prop_id := Layout.Landscape._next_prop_id
	var restored := _restore(data, legacy, require_landscape, require_meals, require_leisure, require_beach)
	if not restored:
		Layout._next_id = next_id
		Layout.Landscape._next_prop_id = next_prop_id
	return restored


func _restore(data: Dictionary, legacy: bool, require_landscape: bool, require_meals: bool,
		require_leisure: bool, require_beach: bool) -> bool:
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
	var has_beach := data.has("beach_version")
	if has_beach and (not data.beach_version is int or data.beach_version != BEACH_VERSION):
		return false
	if require_beach and not has_beach:
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
	if not has_meals or not has_leisure or not has_beach:
		data = data.duplicate(true)
	if not has_beach and not _migrate_beach(data):
		return false
	if not _valid_beach(data):
		return false
	var restored_layout := Layout.new(false)
	var restored_pending: Layout
	var restored_reserve := 0
	var restored_mode := "regular"
	var demand: int = 0 if data.booked_price == 0 else price_demand(data.booked_price)
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
		if require_beach and data.layout.get("version") != 4:
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
			if require_beach and data.pending_layout.get("version") != 4:
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
	if not has_meals and not _migrate_meals(data):
		return false
	if not has_leisure and not _migrate_leisure(data):
		return false
	if not _valid_state(data, restored_count, restored_layout):
		return false
	var coast: Variant = data.get("coast_runtime") if has_beach and data.has("coast_runtime") else _legacy_coast(data)
	if not _valid_coast(coast, data, restored_mode, restored_layout):
		return false
	var has_showcase := data.has("developer_showcase")
	if has_showcase and (restored_mode != "developer" or not _valid_showcase(data)):
		return false

	day = data.day
	second = data.second
	cash = data.cash
	selected_package = data.selected_package
	booked_package = data.booked_package
	selected_price = data.selected_price
	booked_price = data.booked_price
	booked_value = data.booked_value
	beach_deposits.assign(coast.deposits.duplicate(true))
	_offshore.assign(coast.offshore.duplicate(true))
	_developer_month_offset = coast.month_offset
	sargassum_intensity = coast.intensity
	sargassum_seed = coast.seed
	lifeguard_assignment = coast.assignment
	rescue = coast.rescue.duplicate(true)
	last_rescue = coast.last_rescue.duplicate(true)
	swim_policy = data.swim_policy
	ocean_incidents.assign(data.ocean_incidents.duplicate(true))
	booked_count = restored_count
	float_station = data.float_station
	mode = restored_mode
	_can_configure_new_run = false
	showcase_enabled = has_showcase
	showcase_coverage.clear()
	if has_showcase:
		showcase_coverage.assign(data.developer_showcase.completed)
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


func _valid_showcase(data: Dictionary) -> bool:
	var showcase: Variant = data.developer_showcase
	if not showcase is Dictionary or showcase.size() != 1 or not showcase.get("completed") is Array:
		return false
	if showcase.completed.size() > LEISURE_DURATIONS.size():
		return false
	var completed := {}
	for kind in showcase.completed:
		if not kind is String or not LEISURE_DURATIONS.has(kind) or completed.has(kind):
			return false
		completed[kind] = true
	var observed_today := {}
	for family in data.families:
		for kind in family.leisure_completed:
			if not completed.has(kind):
				return false
			observed_today[kind] = true
	return data.day > 1 or observed_today.size() == completed.size()


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


func _migrate_beach(data: Dictionary) -> bool:
	data.selected_price = PACKAGES[data.selected_package].price
	data.booked_price = 0 if data.booked_package == -1 else PACKAGES[data.booked_package].price
	data.booked_value = 0.0 if data.booked_price == 0 else price_value(data.booked_price)
	data.sargassum = 0
	data.swim_policy = "safe"
	data.ocean_incidents = []
	for family in data.families:
		if not family is Dictionary or family.get("phase") in OCEAN_PHASES:
			return false
		family.merge(OCEAN_DEFAULTS, true)
	return true


func _legacy_coast(data: Dictionary) -> Dictionary:
	var clock: int = (data.day - 1) * DAY_LENGTH + data.second
	var offshore: Array[Dictionary] = []
	for birth in range(maxi(0, clock - Sargassum.MAX_FLIGHT + 1), clock + 1):
		for patch in Sargassum.births(birth, birth / DAY_LENGTH + 1, Sargassum.DEFAULT_SEED, -1):
			if patch.lands_at > clock:
				offshore.append(patch)
	return {"version": COAST_VERSION, "month_offset": -1, "intensity": -1, "seed": Sargassum.DEFAULT_SEED,
		"deposits": Sargassum.legacy_deposits(data.sargassum), "offshore": offshore,
		"assignment": "", "rescue": {}, "last_rescue": {}}


func _valid_coast(coast: Variant, data: Dictionary, restored_mode: String, plan: Layout) -> bool:
	if not _int_fields(coast, ["version", "month_offset", "intensity", "seed"]):
		return false
	if coast.version != COAST_VERSION or coast.month_offset < -1 or coast.month_offset >= 12 * Calendar.DAYS_PER_MONTH:
		return false
	if coast.intensity < -1 or coast.intensity > 100 or (restored_mode != "developer" and (coast.intensity != -1 or coast.month_offset != -1)):
		return false
	if coast.seed < 1 or coast.seed > 2147483647 or coast.get("assignment") not in [""] + LIFEGUARD_SITES:
		return false
	if not Sargassum.valid_deposits(coast.get("deposits")) or Sargassum.amount(coast.deposits) != data.sargassum:
		return false
	var clock: int = (data.day - 1) * DAY_LENGTH + data.second
	if not Sargassum.valid_rafts(coast.get("offshore"), clock, coast.seed):
		return false
	if not coast.get("rescue") is Dictionary or not coast.get("last_rescue") is Dictionary:
		return false
	var active: Dictionary = coast.rescue
	if not _valid_active_rescue(active, coast.assignment, restored_mode, data, plan):
		return false
	for family: Dictionary in data.families:
		if family.phase == "water_rescue" and (active.is_empty() or active.family != family.id):
			return false
	return _valid_rescue_outcome(coast.last_rescue, data, restored_mode)


func _valid_active_rescue(record: Dictionary, assignment: String, restored_mode: String, data: Dictionary, plan: Layout) -> bool:
	if record.is_empty():
		return true
	if data.stopped or not _int_fields(record, ["day", "family", "slot", "started_at", "contact_at", "drop_at", "finished_at"]):
		return false
	if not record.get("drill") is bool or record.get("site") not in LIFEGUARD_SITES or record.site != assignment:
		return false
	if record.day != data.day or record.started_at < 0 or record.started_at > data.second or record.finished_at <= data.second or record.finished_at >= DAY_LENGTH:
		return false
	if record.family < -1 or record.family >= data.families.size() or record.slot not in [-1, 0, 1, 2]:
		return false
	if record.drill:
		if restored_mode != "developer" or (record.family == -1 and record.slot != -1):
			return false
	elif record.family < 0 or record.started_at < OPEN_BOOKINGS:
		return false
	if record.family >= 0:
		var family: Dictionary = data.families[record.family]
		if family.phase != "water_rescue" or family.since != record.started_at or family.until != record.finished_at or family.slot != record.slot:
			return false
		if record.site == "beach" and (family.ocean_completed or family.ocean_return_wet or family.ocean_fatality):
			return false
		if not record.drill and record.site == "beach":
			if family.ocean_red_seconds != _red_risk_limit(data.day, family.id) - 1 \
					or Ocean.condition_at(float(data.day - 1) * DAY_LENGTH + record.started_at) != Ocean.Condition.CLOSED:
				return false
		if not record.drill and record.site == "pool" and (data.day <= FINAL_DAY or data.day % 3 != 1):
			return false
	var expected := _rescue_record(plan, record.site, record.day, record.started_at, record.family, record.slot, record.drill)
	if expected.is_empty():
		return false
	if data.second >= expected.contact_at:
		expected.phase = "tow"
	return record == expected


func _valid_rescue_outcome(result: Dictionary, data: Dictionary, restored_mode: String) -> bool:
	if result.is_empty():
		return true
	if not _int_fields(result, ["day", "second", "family"]) or not result.get("drill") is bool:
		return false
	if result.day < 1 or result.day > data.day or result.second < 0 or result.second >= DAY_LENGTH:
		return false
	if result.day == data.day and (result.second > data.second or result.family >= data.families.size()):
		return false
	if result.get("site") not in LIFEGUARD_SITES or result.family < -1 or result.family >= 4:
		return false
	match result.get("outcome"):
		"drill_complete":
			return result.drill and restored_mode == "developer"
		"rescued":
			return not result.drill and result.family >= 0
		"self_recovered":
			return not result.drill and result.site == "pool" and result.day > FINAL_DAY and result.family >= 0
		"fatal":
			return not result.drill and result.site == "beach" and data.ocean_incidents.any(func(incident: Dictionary) -> bool:
				return incident.day == result.day and incident.second == result.second and incident.family == result.family)
	return false


func _valid_price(price: Variant) -> bool:
	return price is int and price >= MIN_PRICE and price <= MAX_PRICE and price % PRICE_STEP == 0


func _valid_beach(data: Dictionary) -> bool:
	if not _valid_price(data.get("selected_price")) or data.selected_package != _price_tier(data.selected_price):
		return false
	if not data.get("booked_price") is int or not data.get("booked_value") is float or not is_finite(data.booked_value):
		return false
	if data.booked_package == -1:
		if data.booked_price != 0 or data.booked_value != 0.0:
			return false
	elif not _valid_price(data.booked_price) or data.booked_package != _price_tier(data.booked_price) or not is_equal_approx(data.booked_value, price_value(data.booked_price)):
		return false
	if not data.get("sargassum") is int or data.sargassum < 0 or data.sargassum > 100 or data.get("swim_policy") not in SWIM_POLICIES:
		return false
	if not data.get("ocean_incidents") is Array or data.ocean_incidents.size() > data.reviews.size():
		return false
	var incident_keys := {}
	for incident in data.ocean_incidents:
		if not _int_fields(incident, ["day", "second", "family", "room"]):
			return false
		if incident.day < 1 or incident.day > data.day or incident.family < 0 or incident.family >= 4 or incident.room < 0 or incident.room >= 8:
			return false
		if incident.second < OPEN_BOOKINGS or incident.second >= SHOW_START or (incident.day == data.day and incident.second > data.second):
			return false
		if Ocean.condition_at(float(incident.day - 1) * DAY_LENGTH + incident.second) != Ocean.Condition.CLOSED:
			return false
		var key := "%d:%d" % [incident.day, incident.family]
		if incident_keys.has(key):
			return false
		incident_keys[key] = incident.room
		if incident.day == data.day:
			if incident.family >= data.families.size():
				return false
			var family: Variant = data.families[incident.family]
			if not family is Dictionary or family.get("ocean_fatality") != true or family.get("room") != incident.room:
				return false
	for review in data.reviews:
		if not review is Dictionary:
			return false
		if review.has("ocean_fatality"):
			if not _int_fields(review, ["day", "family", "room", "score"]) or review.ocean_fatality != true or review.score != 0:
				return false
			var key := "%d:%d" % [review.day, review.family]
			if incident_keys.get(key, -1) != review.room:
				return false
			incident_keys.erase(key)
		if review.has("price") or review.has("price_value") or review.has("seaweed_penalty"):
			if not _valid_price(review.get("price")) or not review.get("price_value") is float or not is_equal_approx(review.price_value, price_value(review.price)):
				return false
			if not review.get("seaweed_penalty") is int or review.seaweed_penalty < 0 or review.seaweed_penalty > 16:
				return false
	return incident_keys.is_empty()


func _valid_ocean_family(family: Dictionary, data: Dictionary, plan: Layout, current_incidents: Dictionary) -> bool:
	if not _int_fields(family, ["ocean_red_seconds", "beach_exposure"]):
		return false
	for field in ["ocean_return_wet", "ocean_completed", "ocean_fatality"]:
		if not family.get(field) is bool:
			return false
	if family.beach_exposure < 0 or family.beach_exposure > 100 or family.ocean_red_seconds < 0 or family.ocean_red_seconds > OCEAN_SWIM_DURATION:
		return false
	var fatality: bool = current_incidents.has(family.id)
	if family.has("beach_rescued") and (family.beach_rescued != true or fatality or family.ocean_completed
			or family.phase not in ["from_ocean", "rest", "to_checkout", "exit", "gone"] + LEISURE_PHASES):
		return false
	if family.has("pool_self_recovered") and (family.pool_self_recovered != true or data.day <= FINAL_DAY):
		return false
	if fatality != family.ocean_fatality or fatality != (family.ocean_red_seconds >= _red_risk_limit(data.day, family.id)):
		return false
	if fatality and (family.phase not in ["evacuate", "gone"] or family.ocean_completed):
		return false
	if family.phase not in OCEAN_PHASES:
		return not family.ocean_return_wet
	var rescue_overrun := RESCUE_DURATION if family.get("beach_rescued", false) else 0
	if family.leisure_step > 2 or family.until > SHOW_START + rescue_overrun:
		return false
	var access := plan.ocean_access()
	if access.is_empty() or plan.route(plan.room_points()[family.room], access.shore).is_empty():
		return false
	var duration: int = family.until - family.since
	match family.phase:
		"to_ocean":
			return duration == OCEAN_WALK_DURATION and not family.ocean_return_wet and not family.ocean_completed and family.ocean_red_seconds == 0
		"ocean_swim":
			var red := Ocean.condition_at(float(data.day - 1) * DAY_LENGTH + data.second) == Ocean.Condition.CLOSED
			return (duration == OCEAN_SWIM_DURATION and not family.ocean_return_wet and not family.ocean_completed
				and family.ocean_red_seconds <= data.second - family.since and data.swim_policy != "closed"
				and (not red or data.swim_policy == "allow_red"))
		"evacuate":
			return fatality and family.ocean_return_wet and family.since == current_incidents[family.id].second and duration == OCEAN_WALK_DURATION + OCEAN_WADE_DURATION
	return duration == OCEAN_WALK_DURATION + (OCEAN_WADE_DURATION if family.ocean_return_wet else 0)


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
	var reserved_service := {}
	var current_incidents := {}
	var coast: Variant = data.get("coast_runtime", {})
	var rescue_record: Variant = coast.get("rescue", {}) if coast is Dictionary else {}
	for incident in data.ocean_incidents:
		if incident.day == data.day:
			current_incidents[incident.family] = incident
	var waiting := false
	for i in range(data.families.size()):
		var family: Variant = data.families[i]
		if not _valid_family(family, i, data.second, data.rooms.size(), table_ids):
			return false
		if not _valid_leisure(family, plan):
			return false
		if not _valid_ocean_family(family, data, plan, current_incidents):
			return false
		var holds_pool_slot: bool = family.phase == "water_rescue" and rescue_record is Dictionary and rescue_record.get("site") == "pool"
		if family.phase == "service" or holds_pool_slot:
			var service_key := Vector2i(family.station, family.slot)
			if reserved_service.has(service_key):
				return false
			reserved_service[service_key] = true
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
	if kind in DAYTIME_LEISURE:
		return 1
	if kind in REFRESHMENTS:
		return 2
	if kind in NIGHTLIFE:
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
		if family.leisure_step > 0 and family.phase not in ["return_room", "rest", "to_checkout", "exit", "gone", "water_rescue"] + OCEAN_PHASES:
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
			departure -= LEISURE_DURATIONS[family.leisure_kind]
		if departure < SHOW_START or departure > SHOW_LAST_ENTRY:
			return false
	if family.leisure_origin_id != -1:
		var prior := plan.amenity_by_id(family.leisure_origin_id)
		if prior.is_empty() or family.leisure_step != 2 or prior.kind not in DAYTIME_LEISURE:
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
