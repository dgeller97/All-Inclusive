extends SceneTree
## Independent behavior checks: real geometry, money, simulation and saved state.
const Layout = preload("res://scripts/layout_model.gd")
const Sim = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_rotation()
	_units()
	_finishes()
	_prices()
	_seasons()
	_swimming()
	print("Revision 9 independent contract: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _empty_layout() -> RefCounted:
	var layout := Layout.new(false)
	for building: Dictionary in layout.buildings.duplicate(true):
		layout.remove_building(building.id)
	for prop: Dictionary in layout.landscape.props.duplicate(true):
		layout.remove_prop(prop.id)
	return layout


func _geometry(layout: RefCounted) -> Dictionary:
	return {"buildings": layout.buildings.duplicate(true), "assets": layout.assets.duplicate(true)}


func _rotation() -> void:
	var sizes := {"bedroom": Vector2(64, 80), "reception": Vector2(112, 72), "buffet": Vector2(120, 72), "pool": Vector2(144, 80)}
	var furniture := {"bedroom": "bed", "reception": "desk", "buffet": "counter", "pool": "lounger"}
	for kind: String in sizes:
		var layout = _empty_layout()
		var made: Dictionary = layout.add_building(kind, Rect2(Vector2.ZERO, sizes[kind]))
		check(made.ok, "Create rotation fixture " + kind)
		if not made.ok:
			continue
		var added: Dictionary = layout.add_asset(furniture[kind], made.id, Vector2i(1, 1))
		check(added.ok, "Create contents for " + kind)
		var before := _geometry(layout)
		for turn in range(4):
			var result: Dictionary = layout.rotate_building(made.id)
			check(result.ok, "Rotate " + kind + " quarter-turn " + str(turn + 1))
			if not result.ok:
				break
			check(layout.building_by_id(made.id).rotation == (turn + 1) % 4, "Building orientation records every turn")
			check(layout.assets[0].rotation == (turn + 1) % 4, "Contents turn with building")
			var restored := Layout.new(false)
			check(restored.restore(bytes_to_var(var_to_bytes(layout.snapshot()))), "Rotated " + kind + " restores")
			check(_geometry(restored) == _geometry(layout), "Rotation save preserves IDs, furniture and doors")
		check(_geometry(layout) == before, "Four rotations exactly recover " + kind + " and its contents")
	var blocked = _empty_layout()
	var room: Dictionary = blocked.add_building("bedroom", Rect2(0, 0, 64, 80))
	var obstacle: Dictionary = blocked.add_building("reception", Rect2(72, 0, 64, 48))
	check(room.ok and obstacle.ok, "Create nearby separate building")
	var original := _geometry(blocked)
	check(not blocked.rotate_building(room.id).ok, "Rotation rejects overlap with a separate building")
	check(_geometry(blocked) == original, "Rejected rotation preserves all original geometry")


func _units() -> void:
	var layout = _empty_layout()
	var left: Dictionary = layout.add_building("bedroom", Rect2(0, 0, 64, 80))
	var right: Dictionary = layout.add_building("bedroom", Rect2(64, 0, 64, 80))
	check(left.ok and right.ok, "Two room footprints can share a wall")
	if not left.ok or not right.ok:
		return
	layout.add_asset("bed", left.id, Vector2i(1, 1))
	layout.add_asset("bed", right.id, Vector2i(1, 1))
	check(layout.building_unit(left.id).size() == 2 and layout.building_unit(right.id).size() == 2, "Adjoining rooms are the same unit")
	check(not layout.shared_doors(layout.building_by_id(left.id)).is_empty(), "Combined rooms have an internal connection")
	check(not layout.route(Vector2(32, 40), Vector2(96, 40)).is_empty(), "Guests can navigate between joined rooms")
	check(layout.set_building_finish(left.id, "facade", "brick").ok and layout.building_by_id(right.id).finishes.facade == "brick", "Connected unit shares facade customization")
	layout.set_building_finish(right.id, "roof", "metal")
	check(layout.building_by_id(left.id).finishes.roof == "metal", "Connected unit shares roof customization")
	var before := _geometry(layout)
	for turn in range(4):
		check(layout.rotate_building(right.id).ok, "Selecting any member rotates the unit")
		check(layout.building_unit(left.id).size() == 2, "Unit stays joined after rotation")
	check(_geometry(layout) == before, "Four unit turns preserve individual rooms and furniture")
	check(layout.remove_building(right.id).ok and layout.building_unit(left.id).size() == 1, "Demolishing one room leaves a valid remaining unit")
	check(layout.shared_doors(layout.building_by_id(left.id)).is_empty(), "Shared opening disappears when neighbor is removed")
	var rejoined: Dictionary = layout.add_building("bedroom", Rect2(64, 0, 64, 80))
	check(rejoined.ok and layout.building_unit(left.id).size() == 2, "Rebuilding alongside reconnects the unit")
	var tight = _empty_layout()
	var first: Dictionary = tight.add_building("bedroom", Rect2(0, 0, 64, 80))
	var second: Dictionary = tight.add_building("bedroom", Rect2(64, 64, 64, 80))
	check(first.ok and second.ok and tight.building_unit(first.id).size() == 2, "Sixteen-pixel shared wall joins staggered rooms")
	check(not tight.shared_doors(tight.building_by_id(first.id)).is_empty(), "Minimum shared wall has a real passage")
	check(not tight.route(Vector2(32, 40), Vector2(96, 104)).is_empty(), "Guests can traverse staggered minimum-wall unit")
	var corners = _empty_layout()
	var single: Dictionary = corners.add_building("bedroom", Rect2(0, 0, 64, 80))
	corners.add_building("bedroom", Rect2(64, 80, 64, 80))
	check(corners.building_unit(single.id).size() == 1, "Corner contact alone never merges rooms")


func _finishes() -> void:
	var layout := Layout.new()
	var draft = layout.duplicate_layout()
	var building_id: int = draft.buildings[4].id
	check(draft.set_building_finish(building_id, "facade", "timber").ok, "Exterior facade can be customized")
	check(draft.set_building_finish(building_id, "roof", "slate").ok, "Roof can be customized independently")
	check(draft.building_by_id(building_id).finishes.wall == "default", "Exterior styling preserves interior walls")
	check(draft.quote_diff(layout).cost > 0 and draft.quote_diff(layout, true).cost == 0, "Exterior uses Regular/Developer construction economy")
	var restored := Layout.new(false)
	check(restored.restore(bytes_to_var(var_to_bytes(draft.snapshot()))), "Exterior finishes save/load")
	check(restored.building_by_id(building_id).finishes == draft.building_by_id(building_id).finishes, "All finish choices restored")
	var before := _geometry(restored)
	var bad: Dictionary = draft.snapshot()
	bad.buildings[0].rotation = 7
	check(not restored.restore(bad) and _geometry(restored) == before, "Malformed building rotation rejected atomically")
	bad = draft.snapshot()
	bad.buildings[0].finishes.roof = "missing"
	check(not restored.restore(bad) and _geometry(restored) == before, "Malformed exterior finish rejected atomically")


func _prices() -> void:
	var sim := Sim.new()
	check(is_equal_approx(sim.price_value(90), 5.0) and is_equal_approx(sim.price_value(120), 0.0) and is_equal_approx(sim.price_value(170), -12.0), "Slider preserves original value anchors")
	var last := 999.0
	for price in range(90, 201, 5):
		sim.set_price(price)
		check(sim.selected_price == price and sim.price_value(price) <= last, "Every slider step accepted and increasing price raises expectations")
		last = sim.price_value(price)
	sim.set_price(-100)
	check(sim.selected_price == 90, "Price clamped at minimum")
	sim.set_price(999)
	check(sim.selected_price == 200, "Price clamped at maximum")
	sim.set_price(123)
	check(sim.selected_price % 5 == 0, "Price snaps to slider step")
	check(sim.bookings_for_price(145) == 4 and sim.bookings_for_price(150) == 3, "Higher price affects booking demand at shown threshold")
	sim.set_price(135)
	for tick in range(20):
		sim.tick()
	check(sim.booked_price == 135, "Bookings lock the selected price")
	var locked_value: float = sim.booked_value
	sim.set_price(200)
	check(sim.selected_price == 200 and sim.booked_price == 135 and sim.booked_value == locked_value, "Midday slider affects next bookings without repricing existing families")
	var loaded := Sim.new()
	check(loaded.restore(bytes_to_var(var_to_bytes(sim.snapshot()))), "Custom selected and locked prices restore")
	check(loaded.selected_price == 200 and loaded.booked_price == 135 and loaded.booked_value == locked_value, "Price save preserves both current and next-day quote")
	while sim.day == 1:
		sim.tick()
	check(sim.reviews.size() == 4, "Custom price cohort completes")
	check(sim.cash == 140 + 4 * 135 - Sim.PAYROLL, "Guests pay the booked slider quote, not the later selected price")
	var cheap := Sim.new()
	var dear := Sim.new()
	cheap.set_price(90)
	dear.set_price(140)
	for candidate in [cheap, dear]:
		candidate.set_swim_policy("closed")
		for tick in range(239):
			candidate.tick()
	check(cheap.reviews.size() == dear.reviews.size() and cheap.average() > dear.average(), "Price still changes satisfaction for matching demand")


func _seasons() -> void:
	var summer := Sim.new()
	summer.set_swim_policy("closed")
	_advance_to_day(summer, 13)
	var winter := Sim.new()
	winter.set_swim_policy("closed")
	_advance_to_day(winter, 31)
	# Begin both seasonal observations with a clean beach; carried-over seaweed
	# is intentionally persistent even after the high-arrival season ends.
	for candidate in [summer, winter]:
		candidate.clean_beach()
		candidate.clean_beach()
	for tick in range(120):
		summer.tick()
		winter.tick()
	check(summer.sargassum > winter.sargassum, "Season creates actual accumulated seaweed")
	check(summer.calendar_state().temperature_c > winter.calendar_state().temperature_c, "Simulation exposes seasonal temperature")
	var loaded := Sim.new()
	check(loaded.restore(bytes_to_var(var_to_bytes(summer.snapshot()))), "Seasonal run restores")
	check(loaded.sargassum == summer.sargassum and loaded.calendar_state() == summer.calendar_state(), "Save preserves buildup, date, light and temperature")
	var old_amount: float = summer.sargassum
	var old_cash: int = summer.cash
	var cleaning: Dictionary = summer.clean_beach()
	check(cleaning.ok and cleaning.cost == 30 and cleaning.removed > 0, "Cleanup reports the actual charge and removed buildup")
	check(summer.sargassum < old_amount, "Cleaning reduces actual buildup")
	check(summer.cash == old_cash - 30, "Cleaning charges exactly once")
	var broke := Sim.new()
	broke.cash = 0
	broke.sargassum = 80.0
	check(not broke.clean_beach().ok and broke.cash == 0 and broke.sargassum == 80.0, "Cannot buy cleanup without money")
	broke.mode = "developer"
	check(broke.clean_beach().ok and broke.cash == 0 and broke.sargassum == 20.0, "Developer cleanup is free and removes sixty buildup")
	var clean := Sim.new()
	var dirty := Sim.new()
	clean.set_swim_policy("closed")
	dirty.set_swim_policy("closed")
	dirty.sargassum = 100.0
	for tick in range(239):
		clean.tick()
		dirty.tick()
	check(clean.reviews.size() == dirty.reviews.size() and clean.average() > dirty.average(), "Beach buildup lowers actual guest reviews")


func _advance_to_day(sim: RefCounted, target_day: int) -> void:
	for tick in range(Sim.DAY_LENGTH * target_day):
		if sim.day >= target_day:
			return
		if sim.stopped:
			sim.continue_after_recap()
		sim.tick()
	check(false, "Could not reach calendar fixture day " + str(target_day))


func _swimming() -> void:
	for policy: String in ["safe", "allow_red", "closed"]:
		var sim := Sim.new()
		check(sim.set_swim_policy(policy), "Set swim policy " + policy)
		check(not sim.set_swim_policy("missing") and sim.swim_policy == policy, "Unknown swim policy rejected")
		var access: Dictionary = sim.layout.ocean_access()
		check(access.has("shore") and access.has("water"), "Ocean has actual shore and water anchors")
		if not access.is_empty():
			check(not sim.layout.route(Layout.ENTRY, access.shore).is_empty(), "Guests can reach ocean access")
		var visited := false
		var saw_incident := false
		var resumed := {}
		var shadows: Array[Dictionary] = []
		var valid := true
		for tick in range(Sim.DAY_LENGTH * 6):
			if sim.stopped:
				sim.continue_after_recap()
			sim.tick()
			for shadow: Dictionary in shadows.duplicate():
				if shadow.sim.stopped:
					shadow.sim.continue_after_recap()
				shadow.sim.tick()
				shadow.remaining -= 1
				if shadow.remaining == 0:
					check(shadow.sim.reviews == sim.reviews and shadow.sim.ocean_incidents == sim.ocean_incidents and shadow.sim.families == sim.families and shadow.sim.cash == sim.cash, "Reloaded swimmer matches uninterrupted run after ten seconds")
					shadows.erase(shadow)
			for family: Dictionary in sim.families:
				if family.phase == "ocean_swim":
					visited = true
				if family.phase in ["to_ocean", "ocean_swim", "from_ocean", "evacuate"] and not resumed.has(family.phase):
					var loaded := Sim.new()
					var snapshot: Dictionary = bytes_to_var(var_to_bytes(sim.snapshot()))
					var accepted: bool = loaded.restore(snapshot)
					check(accepted, policy + " restores active " + family.phase)
					if accepted:
						shadows.append({"sim": loaded, "remaining": 10})
					resumed[family.phase] = true
			if not sim.ocean_incidents.is_empty():
				saw_incident = true
			if policy == "safe" and not sim.ocean_incidents.is_empty():
				valid = false
		check(visited == (policy != "closed"), "Swim participation follows " + policy)
		check(valid, "Safe policy avoids fatal incidents")
		check(saw_incident == (policy == "allow_red"), "Red flag risk can cause a persistent fatal incident; other policies prevent it")
		check(sim.day >= 6, "Swim outcome never deadlocks operating days")
		if policy != "closed":
			check(resumed.has("to_ocean") and resumed.has("ocean_swim") and resumed.has("from_ocean"), "All swim journey phases exercised")
